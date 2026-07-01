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

CI (`.github/workflows/ci.yml`) runs three checks on every push and PR: `gdlint`, `gdformat --check`, and the GUT test suite. Running them locally first means green locally ≈ green in CI.

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

Config lives in `gdlintrc` and `gdformatrc` (no leading dot — that's the gdtoolkit convention). Both exclude `.git/` and the vendored `gut/` addon. `gdformatrc` pins `line_length: 99` as a workaround for an upstream `@abstract` off-by-one bug — see the comment in that file.

### Running tests

Tests use [GUT](https://github.com/bitwes/Gut) (v9.5.0), which is vendored under `addons/gut/` and enabled as an editor plugin.

> **Note:** Some tests intentionally exercise error paths (type mismatches, missing variables, division by zero). These trigger `push_error` calls that always appear in the Godot debugger panel, even when the test passes. Tests that expect this behaviour call `assert_push_error` / `assert_engine_error` to mark the errors as handled — if you see debugger errors while running the suite, check whether the test passes before investigating further.

**In the editor** (best for iterating on a single suite): open the project, click the **GUT** tab in the bottom panel, and press **Run All** — or use the directory/script fields to run just one folder or file. Test directories live under `test/` (`unit`, `integration`, `fixtures`, `helpers`).

**Headless** (what CI runs) from the repo root:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

`godot` must be on your PATH. On Windows the executable is named something like `Godot_v4.5.1-stable_win64_console.exe` — create a `godot.bat` shim pointing at it.
