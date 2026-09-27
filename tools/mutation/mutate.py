"""Mutation testing for the Weavly addon.

Mutates one line of an addon script at a time (flips a comparison, deletes a statement,
negates a condition, swaps and/or, shifts a number, changes a string constant), runs the
gdUnit4 suite in a copy of the project and records which tests fail. A mutant no test
catches points at behaviour nothing checks.

Pass the scripts or folders a change touched; without any, it mutates every addon script,
which takes about two hours on 8 workers. The copies
live in --out under the system temp folder, never in the working copy, and report.md there
lists the score per script, every surviving mutant and, after a full run, the tests that
caught nothing. Results are kept per state of the repository, so a rerun after an
interruption only runs what is left. --clean deletes that folder and the copies' user data.

Not every survivor is a gap: some mutants can't change behaviour, and drawing code is
rarely worth asserting. A test that catches nothing isn't necessarily redundant either,
since only .gd lines are mutated, not scenes, themes or fixtures.
"""

import argparse
import collections
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Empty, Queue

REPO = Path(__file__).resolve().parents[2]
DEFAULT_PATHS = ["addons/weavly/runtime", "addons/weavly/editor", "addons/weavly/ui"]
TEST_TIMEOUT_SECONDS = 10
MAX_RESUMES = 8
PROJECT_NAME = "Weavly mutation"
NO_FILE_LOGGING = "file_logging/enable_file_logging=false\nfile_logging/enable_file_logging.pc=false\n"

ANSI = re.compile(r"\x1b\[[0-9;]*m")
RESULT_LINE = re.compile(r"(res://test/\S+\.gd) > (\S+) (PASSED|FAILED|ERROR|ABORTED|FLAKY|SKIPPED)")
NO_DELETE = re.compile(
    r"^(func|static func|var|const|class|class_name|extends|signal|enum|@|if |elif |else|for |while |"
    r"match |pass$|return .|super\(|#|await )"
)
TOKEN_RULES = [
    ("REL", r"==", ["!="]),
    ("REL", r"!=", ["=="]),
    ("REL", r"<=", ["<"]),
    ("REL", r">=", [">"]),
    ("REL", r"(?<![<\-=])<(?![<=])", ["<="]),
    ("REL", r"(?<![>\-=])>(?![>=])", [">="]),
    ("LOG", r"(?<=\s)and(?=\s)", ["or"]),
    ("LOG", r"(?<=\s)or(?=\s)", ["and"]),
    ("LOG", r"\bnot ", [""]),
    ("BOOL", r"\btrue\b", ["false"]),
    ("BOOL", r"\bfalse\b", ["true"]),
    ("ARITH", r"(?<=\s)\+(?=\s)", ["-"]),
    ("ARITH", r"(?<=\s)-(?=\s)", ["+"]),
    ("ARITH", r"(?<=\s)\*(?=\s)", ["/"]),
    ("ARITH", r"\+=", ["-="]),
    ("ARITH", r"-=", ["+="]),
    ("NUM", r"(?<![\w.])\d+(?![\w.])", None),
]
CONST_STRING = re.compile(r'^(const \w+(?:: *String)? *= *")([^"\\]+)(".*)$')


def read_lines(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").split("\n")


def code_mask(line):
    mask = [False] * len(line)
    i, quote = 0, None
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "#":
            break
        else:
            mask[i] = True
        i += 1
    return mask


def bracket_delta(line, mask):
    return sum((c in "([{") - (c in ")]}") for i, c in enumerate(line) if mask[i])


def mutants_for_file(root, rel):
    lines = read_lines(root / rel)
    found = []
    depth = 0
    for n, line in enumerate(lines):
        mask = code_mask(line)
        start_depth = depth
        depth += bracket_delta(line, mask)
        s = line.strip()
        m = CONST_STRING.match(line)
        if m:
            found.append(("STR", n, m.group(1) + m.group(2)[1:] + m.group(3)))
            continue
        if not s or s.startswith(("#", "class_name", "extends", "@export", "signal", "enum")):
            continue
        indent = line[: len(line) - len(line.lstrip())]
        whole = start_depth == 0 and depth == 0
        if whole and indent and not NO_DELETE.match(s) and not s.endswith(":"):
            found.append(("DEL", n, indent + "pass"))
        m = re.match(r"^(\s*)(if|elif|while) (.+):$", line)
        if m and whole and all(mask[len(m.group(1)) : len(line) - 1]):
            found.append(("NEG", n, f"{m.group(1)}{m.group(2)} not ({m.group(3)}):"))
        for kind, pattern, replacements in TOKEN_RULES:
            for mm in re.finditer(pattern, line):
                if not mask[mm.start()]:
                    continue
                if kind == "NUM":
                    value = int(mm.group(0))
                    replacements = [str(value + 1)] if value != 1 else ["0", "2"]
                for r in replacements:
                    found.append((kind, n, line[: mm.start()] + r + line[mm.end() :]))
    return [
        {"file": rel, "line": n + 1, "kind": kind, "orig": lines[n], "new": new}
        for kind, n, new in found
        if new != lines[n]
    ]


def project_files():
    out = subprocess.check_output(["git", "ls-files", "-co", "--exclude-standard"], cwd=REPO, text=True)
    return [f for f in out.splitlines() if (REPO / f).is_file() and not f.startswith("tools/")]


def tree_hash(files):
    h = hashlib.sha1()
    for f in sorted(files):
        h.update(f.encode())
        h.update((REPO / f).read_bytes())
    return h.hexdigest()[:12]


def sync(files, src_root, dst_root):
    for f in files:
        src, dst = src_root / f, dst_root / f
        data = src.read_bytes()
        if not dst.exists() or dst.read_bytes() != data:
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(data)
    wanted = set(files)
    for folder in ("addons/weavly", "test"):
        for path in (dst_root / folder).rglob("*"):
            rel = path.relative_to(dst_root).as_posix()
            if path.is_file() and rel not in wanted and path.suffix not in (".uid", ".import"):
                path.unlink()


def configure_project(root, name):
    path = root / "project.godot"
    text = path.read_text(encoding="utf-8")
    text = re.sub(r'config/name=".*"', f'config/name="{name}"', text)
    setting = f"settings/test/test_timeout_seconds={TEST_TIMEOUT_SECONDS}"
    if setting not in text:
        text = text.replace("[gdunit4]\n", f"[gdunit4]\n\n{setting}\n", 1)
    if NO_FILE_LOGGING not in text:
        text += f"\n[debug]\n\n{NO_FILE_LOGGING}"
    path.write_text(text, encoding="utf-8")


def user_data_root():
    if os.name == "nt":
        return Path(os.environ["APPDATA"]) / "Godot" / "app_userdata"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot" / "app_userdata"


def clean(out_dir):
    removed = [out_dir] if out_dir.exists() else []
    removed += sorted(user_data_root().glob(f"{PROJECT_NAME} *"))
    for path in removed:
        shutil.rmtree(path)
        print(f"Removed {path}")
    if not removed:
        print("Nothing to clean")


def kill_tree(proc):
    if os.name == "nt":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
    else:
        os.killpg(proc.pid, signal.SIGKILL)


def run_godot(godot, root, args, timeout):
    proc = subprocess.Popen(
        [godot, "--headless", "--path", str(root), *args],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=os.name != "nt",
    )
    try:
        out, _ = proc.communicate(timeout=timeout)
        timed_out = False
    except subprocess.TimeoutExpired:
        kill_tree(proc)
        out, _ = proc.communicate()
        timed_out = True
    return ANSI.sub("", out.decode("utf-8", "replace")), timed_out


def console_verdicts(out):
    return {f"{m.group(1)}::{m.group(2)}": m.group(3) for m in RESULT_LINE.finditer(out)}


def report_verdicts(report_dir):
    xmls = list(Path(report_dir).rglob("results.xml"))
    if not xmls:
        return None
    try:
        root = ET.parse(xmls[0]).getroot()
    except ET.ParseError:
        return None
    verdicts = {}
    for suite in root.iter("testsuite"):
        path = f"res://{suite.get('package')}/{suite.get('name')}.gd"
        for case in suite.iter("testcase"):
            failed = case.find("failure") is not None or case.find("error") is not None
            verdicts[f"{path}::{case.get('name')}"] = "FAILED" if failed else "PASSED"
    return verdicts


def run_suite(godot, root, order, timeout):
    """Verdict per test. A crash or hang fails the running test and the run resumes after it."""
    verdicts, crashes, logs = {}, [], []
    ignores = []
    for _ in range(MAX_RESUMES):
        report_dir = root / "mutation_reports"
        shutil.rmtree(report_dir, ignore_errors=True)
        args = [
            "-s",
            "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
            "-a",
            "res://test",
            "--ignoreHeadlessMode",
            "-c",
            "-rd",
            str(report_dir),
            "-rc",
            "1",
        ]
        for ignored in ignores:
            args += ["-i", ignored]
        out, timed_out = run_godot(godot, root, args, timeout)
        logs.append(out)
        report = report_verdicts(report_dir)
        if report is not None and not timed_out:
            verdicts.update(report)
            break
        verdicts.update(console_verdicts(out))
        remaining = [t for t in order if t not in verdicts]
        if not remaining:
            break
        verdicts[remaining[0]] = "TIMEOUT" if timed_out else "CRASH"
        crashes.append(remaining[0])
        open_suites = {t.split("::")[0] for t in remaining[1:]}
        done_suites = {t.split("::")[0] for t in order} - open_suites
        ignores = sorted(done_suites) + [t.replace("::", ":") for t in verdicts if t.split("::")[0] in open_suites]
    return verdicts, crashes, "\n".join(logs)


def prepare(args, files):
    base = args.out / "base"
    base.mkdir(parents=True, exist_ok=True)
    sync(files, REPO, base)
    configure_project(base, f"{PROJECT_NAME} base")
    print("Importing the project copy...", flush=True)
    run_godot(args.godot, base, ["--import"], 600)
    print("Running the unmutated suite...", flush=True)
    verdicts, crashes, out = run_suite(args.godot, base, [], args.timeout)
    failing = sorted(t for t, v in verdicts.items() if v != "PASSED")
    if not verdicts or failing or crashes:
        print(out[-3000:])
        sys.exit(f"The unmutated suite must pass first; failing: {failing or crashes or 'no report'}")
    order = list(console_verdicts(out)) or sorted(verdicts)
    return base, order


def run(args):
    files = project_files()
    results_dir = args.out / "results" / tree_hash(files)
    results_dir.mkdir(parents=True, exist_ok=True)
    base, order = prepare(args, files)

    targets = sorted(
        {f for f in files if f.endswith(".gd") and any(f == p or f.startswith(p.rstrip("/") + "/") for p in args.paths)}
    )
    mutants = [m for f in targets for m in mutants_for_file(base, f)]
    for m in mutants:
        m["id"] = hashlib.sha1(json.dumps(m, sort_keys=True).encode()).hexdigest()[:16]
    todo = [m for m in mutants if not (results_dir / f"{m['id']}.json").exists()]
    print(f"{len(mutants)} mutants in {len(targets)} scripts, {len(todo)} to run", flush=True)

    queue = Queue()
    for m in todo:
        queue.put(m)
    lock = threading.Lock()
    done = [0]
    started = time.time()

    def worker(index):
        root = args.out / "workers" / f"w{index}"
        if not (root / ".godot").exists():
            shutil.rmtree(root, ignore_errors=True)
            shutil.copytree(base, root, ignore=shutil.ignore_patterns("mutation_reports"))
        sync(files, base, root)
        configure_project(root, f"{PROJECT_NAME} w{index}")
        while True:
            try:
                m = queue.get_nowait()
            except Empty:
                return
            path = root / m["file"]
            original = (base / m["file"]).read_bytes()
            lines = read_lines(base / m["file"])
            lines[m["line"] - 1] = m["new"]
            path.write_bytes("\n".join(lines).encode("utf-8"))
            try:
                verdicts, crashes, out = run_suite(args.godot, root, order, args.timeout)
            finally:
                path.write_bytes(original)
            parse_error = re.search(r"Parse Error:[^\n]*\n\s*at: GDScript::reload \(res://" + re.escape(m["file"]), out)
            result = dict(m)
            result.update(
                {
                    "invalid": bool(parse_error),
                    "failed": sorted(t for t, v in verdicts.items() if v != "PASSED"),
                    "crashes": crashes,
                }
            )
            (results_dir / f"{m['id']}.json").write_text(json.dumps(result), encoding="utf-8")
            status = "SURVIVED"
            if parse_error:
                status = "invalid"
            elif result["failed"]:
                status = f"caught by {len(result['failed'])}"
            with lock:
                done[0] += 1
                rate = done[0] / max(1.0, time.time() - started) * 60
                progress = f"[{done[0]}/{len(todo)} {rate:.0f}/min]"
                print(f"{progress} {m['file']}:{m['line']} {m['kind']} {status}", flush=True)

    with ThreadPoolExecutor(args.workers) as pool:
        for future in [pool.submit(worker, i) for i in range(args.workers)]:
            future.result()

    ids = {m["id"] for m in mutants}
    results = [json.loads(p.read_text(encoding="utf-8")) for p in results_dir.glob("*.json")]
    full = set(args.paths) == set(DEFAULT_PATHS)
    write_report(args.out, [r for r in results if r["id"] in ids], order if full else None)


def write_report(out_dir, results, tests):
    valid = [r for r in results if not r["invalid"]]
    survived = [r for r in valid if not r["failed"]]
    by_file = collections.defaultdict(lambda: [0, 0])
    for r in valid:
        by_file[r["file"]][1] += 1
        by_file[r["file"]][0] += bool(r["failed"])
    catches = collections.Counter(t for r in valid for t in r["failed"])
    score = 100 * (len(valid) - len(survived)) / max(1, len(valid))

    lines = [
        "# Mutation report",
        "",
        f"{len(valid) - len(survived)} of {len(valid)} mutants caught ({score:.1f}%), "
        f"{len(results) - len(valid)} didn't parse.",
        "",
        "| Script | Caught | Score |",
        "|---|---|---|",
    ]
    for f, (caught, total) in sorted(by_file.items(), key=lambda x: x[1][0] / x[1][1]):
        lines.append(f"| {f} | {caught}/{total} | {100 * caught / total:.0f}% |")
    lines += ["", f"## Survivors ({len(survived)})", ""]
    for f in sorted({r["file"] for r in survived}):
        lines.append(f"### {f}")
        lines.append("")
        for r in sorted((r for r in survived if r["file"] == f), key=lambda r: r["line"]):
            new = "(deleted)" if r["kind"] == "DEL" else f"`{r['new'].strip()}`"
            lines.append(f"- {r['line']} {r['kind']}: `{r['orig'].strip()}` → {new}")
        lines.append("")
    if tests is not None:
        silent = [t for t in tests if not catches[t]]
        lines += [f"## Tests that caught no mutant ({len(silent)})", ""]
        lines += [f"- {t.replace('res://test/', '')}" for t in silent]
    report = out_dir / "report.md"
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    matrix = {r["id"]: {"file": r["file"], "line": r["line"], "kind": r["kind"], "failed": r["failed"]} for r in valid}
    (out_dir / "matrix.json").write_text(json.dumps(matrix), encoding="utf-8")
    print(f"\n{score:.1f}% caught, {len(survived)} survived. Report: {report}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="*", default=DEFAULT_PATHS, help="scripts or folders to mutate")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"), help="Godot console executable")
    parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    parser.add_argument("--timeout", type=int, default=120, help="seconds per suite run")
    parser.add_argument("--out", type=Path, default=Path(tempfile.gettempdir()) / "weavly-mutation")
    parser.add_argument("--clean", action="store_true", help="delete the output folder and the copies' user data")
    args = parser.parse_args()
    if args.clean:
        clean(args.out)
        return
    args.paths = [p.replace("\\", "/") for p in args.paths]
    run(args)


if __name__ == "__main__":
    main()
