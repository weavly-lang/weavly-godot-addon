# Contributing

## Workflow

All work happens on issue branches and lands on `main` via squash-merged PRs. Every change should trace back to a GitHub issue.

### 1. Create the branch from the issue

```bash
gh issue develop <number> --checkout
```

This creates a branch named `<number>-<slugified-issue-title>` (e.g. `12-add-runtime-control-flow`), links it to the issue on GitHub, and checks it out locally.

### 2. Commit freely while working

Intermediate commits are squashed away on merge, so they don't need to follow any convention. Use whatever helps you work (`wip`, `fix typo`, `add scene`).

### 3. Rebase before opening (or if main moved ahead)

```bash
git fetch origin
git rebase origin/main
git push --force-with-lease
```

This keeps history linear — no merge commits. GitHub will also block the merge button if your branch is behind `main`, so you'll need to do this before merging even if you skipped it at PR creation time.

### 4. Open the PR

```bash
gh pr create --title "<human-readable sentence>" --body "Closes #<number>"
```

- **Title** is a real sentence — usually identical to the issue title. It becomes the squash commit message on `main`.
- **Body** must include `Closes #<number>` so the issue auto-closes when the PR merges.

### 5. Squash merge

Use **Squash and merge** in the GitHub UI. The result on `main` looks like:

```
Add runtime control flow (#12)
```

The `(#12)` is added automatically by GitHub.

## Local checks

CI (`.github/workflows/ci.yml`) runs `gdlint`, `gdformat --check`, and the gdUnit4 test suite on every push and PR. The tests run on every supported Godot version (4.5, 4.6 and 4.7, pinned to the latest patch of each); a failure on one version does not stop the others. When a new minor version of Godot is released, add it to the matrix, drop the oldest, and bump the vendored gdUnit4 to a release that covers the new range. A third job exports the test game in `ci/export_smoke/` on the oldest and newest version and runs the exported binary, which is the only way to catch bugs that appear once `res://` is a PCK. A fourth job rebuilds the compiler-built fixture (see below). Running the checks locally first means green locally ≈ green in CI.

### Compiler-built fixtures

`test/fixtures/integration/ci_smoke/` is a real Weavly project: `src/` holds the `.wvl` sources, `build/` the committed JSON the integration test loads. It covers every statement type, so it is where the addon notices a change in the compiler's output shape.

The `fixtures` job installs a pinned `weavly` from PyPI, runs `weavly build`, and fails if the result differs from the committed `build/`. The pin keeps an upstream release from failing unrelated PRs; a separate weekly workflow (`.github/workflows/compiler-latest.yml`, also runnable on demand) does the same against the newest release, so a shape change surfaces there instead.

After editing the sources, rebuild and commit `build/` along with them:

```bash
cd test/fixtures/integration/ci_smoke && weavly build
```

When the weekly run fails, check whether the new output is intended: if it is, bump the pin in `ci.yml`, rebuild, and adjust the addon to match; if not, it is an upstream bug.

### Linting and formatting

Linting and formatting use [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdlint` + `gdformat`), a Python package:

```bash
pip install gdtoolkit
```

Run both from the repo root:

```bash
gdlint .          # report lint violations
gdformat --check .  # report files that need reformatting (no changes written)
gdformat .          # reformat files in place
```

Config lives in `gdlintrc` and `gdformatrc` (no leading dot — that's the gdtoolkit convention). Both exclude `.git/` and the vendored `gdUnit4/` addon. `gdformatrc` pins `line_length: 99` as a workaround for an upstream `@abstract` off-by-one bug — see the comment in that file.

### Running tests

Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (v6.2.1), which is vendored under `addons/gdUnit4/` and enabled as an editor plugin. Suites live under `test/` (`unit`, `integration`, `fixtures`, `helpers`) and extend `GdUnitTestSuite`.

Unexpected `push_error`, `push_warning` and engine errors fail the test (`gdunit4/report/godot/push_error` in `project.godot`). Tests that expect them extend `WeavlyTestSuite` ([test/helpers/weavly_test_suite.gd](test/helpers/weavly_test_suite.gd)) and call `assert_logged(errors, warnings)` after the code that logs them. Each expected string must be contained in one logged message:

```gdscript
_service.set_group_pattern("[")
assert_logged(["missing terminating ]", "Failed to compile image group_pattern"])
```

Use `assert_logged` instead of gdUnit4's `assert_error()`, which can only assert one error per call. The errors still show up in the Godot debugger panel even when the test passes.

**In the editor** (best for iterating on a single suite): open the project, then right-click a test file or folder in the FileSystem dock and choose **Run Tests**, or use the **GdUnit** dock.

**Headless** (what CI runs) from the repo root:

```bash
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test --ignoreHeadlessMode -c
```

`-c` keeps running the remaining tests of a suite after a failure. Reports are written to `reports/` (ignored by git).

`godot` must be on your PATH. On Windows the executable is named something like `Godot_v4.5.1-stable_win64_console.exe` — create a `godot.bat` shim pointing at it.
