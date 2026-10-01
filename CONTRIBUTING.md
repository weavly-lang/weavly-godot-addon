# Contributing

## Workflow

Work happens on issue branches and lands on `main` as squash-merged PRs.

1. `gh issue develop <number> --checkout` creates a branch linked to the issue.
2. Commit freely; commits are squashed on merge. Rebase on `origin/main` when it moves ahead.
3. Open the PR with a sentence as title (usually the issue title) and `Closes #<number>` in the body.
4. **Squash and merge** once CI passes. The title becomes the commit on `main`.

## Checks

CI runs lint, the test suite on Godot 4.5, 4.6 and 4.7, an export smoke test (`ci/export_smoke/`), and a rebuild of the compiler-built fixtures. To run them locally:

```bash
pip install gdtoolkit
gdlint .
gdformat --check .
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test --ignoreHeadlessMode -c
```

Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), vendored in `addons/gdUnit4/`. An unexpected `push_error` or `push_warning` fails a test; tests that expect one extend `WeavlyTestSuite` and call `assert_logged(errors, warnings)`.

After opening the project with a Godot version other than the newest supported one, discard what it rewrote with `git checkout -- project.godot addons/gdUnit4`.

## Fixtures

Every folder under `test/fixtures/` and `ci/export_smoke/` with a `src/` folder is a Weavly project. Edit its `.wvl` sources, never `build/`, and rebuild from that folder with `weavly build`. CI fails when a committed `build/` doesn't match what the pinned compiler produces; a weekly run does the same against the newest compiler release.

## Mutation testing

`tools/mutation/mutate.py` checks whether the tests notice small bugs in the addon scripts. Its docstring explains how to run it and read the report.

## Releasing

1. Bump `version` in `addons/weavly/plugin.cfg` and merge it.
2. Tag that commit on `main`: `git tag v<version> && git push origin v<version>`.

The release workflow checks the tag against `plugin.cfg`, runs the tests and publishes `weavly-<tag>.zip`. Tags can't be moved or deleted, so check the bump landed first.

Only `addons/weavly/` ships: `.gitattributes` strips everything else from the archive, so add an `export-ignore` rule for any new top-level file or folder. `addons/weavly/` keeps its own `README.md` and `LICENSE` for that reason.
