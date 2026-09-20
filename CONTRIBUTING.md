# Contributing

## Workflow

All work happens on issue branches and lands on `main` via squash-merged PRs.

### 1. Create the branch from the issue

```bash
gh issue develop <number> --checkout
```

Creates `<number>-<slugified-issue-title>`, links it to the issue, and checks it out.

### 2. Commit freely while working

Intermediate commits are squashed on merge, so they need no convention.

### 3. Rebase before opening, and whenever main moves ahead

```bash
git fetch origin
git rebase origin/main
git push --force-with-lease
```

GitHub blocks the merge button while a branch is behind `main`.

### 4. Open the PR

```bash
gh pr create --title "<human-readable sentence>" --body "Closes #<number>"
```

- **Title** is a real sentence, usually the issue title. It becomes the squash commit on `main`.
- **Body** must include `Closes #<number>`.

### 5. Squash merge

Use **Squash and merge**. The commit on `main` reads `Add runtime control flow (#12)`, with the `(#12)` appended by GitHub.

`main` takes squash merges only, keeps a linear history, and requires every CI job to pass.

## Local checks

CI (`.github/workflows/ci.yml`) runs four jobs on every push and PR:

- **`lint`** — `gdlint` and `gdformat --check`.
- **`test`** — the gdUnit4 suite on Godot 4.5, 4.6 and 4.7, pinned to the latest patch of each. A failure on one version does not stop the others.
- **`export`** — exports `ci/export_smoke/` on the oldest and newest version and runs the binary, which covers what only breaks once `res://` is a PCK.
- **`fixtures`** — rebuilds the compiler-built fixture and checks it still matches what is committed.

When a new minor version of Godot is released, add it to the `test` and `export` matrices, drop the oldest, and bump the vendored gdUnit4 to a release that covers the new range.

### Linting and formatting

```bash
pip install gdtoolkit
```

From the repo root:

```bash
gdlint .            # report lint violations
gdformat --check .  # report files that need reformatting
gdformat .          # reformat in place
```

Config lives in `gdlintrc` and `gdformatrc` (no leading dot, a gdtoolkit convention); both exclude `.git/` and the vendored `gdUnit4/`. `gdformatrc` pins `line_length: 99` to work around an upstream `@abstract` bug, so leave it until that is fixed.

### Running tests

Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (v6.2.1), vendored under `addons/gdUnit4/` and enabled as an editor plugin. Suites live under `test/` (`unit`, `integration`, `fixtures`, `helpers`) and extend `GdUnitTestSuite`.

Unexpected `push_error`, `push_warning` and engine errors fail a test (`gdunit4/report/godot/push_error` in `project.godot`). Tests that expect them extend `WeavlyTestSuite` ([test/helpers/weavly_test_suite.gd](test/helpers/weavly_test_suite.gd)) and call `assert_logged(errors, warnings)` after the code that logs them. Each expected string must be contained in one logged message:

```gdscript
_service.set_group_pattern("[")
assert_logged(["missing terminating ]", "Failed to compile image group_pattern"])
```

Prefer it over gdUnit4's `assert_error()`, which asserts only one error per call.

**In the editor**: right-click a test file or folder in the FileSystem dock and choose **Run Tests**, or use the **GdUnit** dock.

**Headless**, from the repo root:

```bash
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test --ignoreHeadlessMode -c
```

`-c` continues a suite after a failure. Reports land in `reports/` (gitignored). `godot` must be on your PATH; on Windows, create a `godot.bat` shim pointing at the executable.

### Compiler-built fixtures

`test/fixtures/integration/ci_smoke/` is a Weavly project: `src/` holds the `.wvl` sources, `build/` the committed JSON the integration tests load. It covers every statement type, so it is where a change in the compiler's output shape shows up.

Edit the sources, never `build/`, and commit both together:

```bash
cd test/fixtures/integration/ci_smoke && weavly build
```

Keep the sources split, with `globals.wvl` declaring the variables and `story.wvl` holding the nodes, so the build still covers the compiler's cross-file declaration merge. An integration test enforces this.

The `fixtures` job builds with a pinned `weavly` from PyPI; `.github/workflows/compiler-latest.yml` does the same weekly against the newest release. When that weekly run fails, decide whether the new output is intended: if it is, bump the pin in `ci.yml`, rebuild and adjust the addon to match; if not, it is an upstream bug.

### Check project.godot after importing

`config/features` in `project.godot` pins the oldest supported Godot version. Opening the project or running `--import` with a newer Godot rewrites that pin and can add compatibility keys, which raises the addon's minimum version and fails the oldest `test` and `export` jobs. Importing also rewrites line endings in the vendored `.import` files.

After any import:

```bash
git diff project.godot
git checkout -- project.godot addons/gdUnit4
```

## Releasing

Bump `version` in `addons/weavly/plugin.cfg`, merge it, then tag the commit on `main`:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

`.github/workflows/release.yml` checks the tag against `plugin.cfg`, runs the suite, packages `addons/weavly/` into `weavly-<tag>.zip` and creates the release with generated notes.

`v*` tags cannot be moved or deleted, so confirm the version bump landed before tagging.

### What ends up in the archive

The Asset Library installs the repository archive into the user's project, so it holds the addon and nothing else. The `export-ignore` rules in `.gitattributes` strip the rest, `project.godot` included; add a rule when you add a top-level file or directory.

This affects `git archive` only, leaving clones and raw file URLs untouched. Because the root `LICENSE` and `README.md` are stripped, `addons/weavly/` keeps its own copies — keep the licence in step with the root one.
