# CLAUDE.md

## Project

Godot addon that runs Weavly programs at runtime by consuming JSON emitted by the Weavly compiler, plus editor tooling to edit and compile `.wvl` files inside Godot. The runtime does not parse `.wvl` source. The dev project targets Forward+; CI tests 4.5, 4.6 and 4.7.

- Addon code: `addons/weavly/src/`
- Starter UIs: `addons/weavly/ui/`, optional scenes on top of the runtime that use only its public API. Showcase projects live in the separate godot-demos repo, not here.
- Engine scene: `addons/weavly/src/weavly_engine.tscn` — the instantiable `WeavlyEngine` node, scripted with `WeavlyDefaultEngine`.
- `dialogue/` is a gitignored scratch project for trying the editor tooling by hand, so it is absent from a fresh clone. Create one with `weavly init dialogue`; that path is what `weavly/dialogue_project_dir` defaults to.

## Relationship to the compiler

Sibling repo at `../weavly-compiler` (Python) turns `.wvl` into JSON; this addon consumes it. Read-only upstream — output-shape changes start there, this repo follows.

Compiler context (commands, grammar, JSON output shape): @../weavly-compiler/CLAUDE.md — this import only resolves when that repo is checked out beside this one; without it, read the compiler's own docs instead.

CI guards that shape: `test/fixtures/integration/ci_smoke/` is a real Weavly project (`src/` sources, committed `build/` JSON) that a pinned compiler rebuilds on every PR, plus a weekly run against the newest release. Edit the `.wvl` sources and rebuild with `weavly build`; never hand-edit `build/`.

**Naming notes:** "the compiler" = the Python project. `WeavlyDeserializer` ([core/weavly_deserializer.gd](addons/weavly/src/core/weavly_deserializer.gd)) = the GDScript JSON-to-model reader (its `compile_*` methods deserialize, they don't compile `.wvl`). `WeavlyCompilerRunner` ([editor/weavly_compiler_runner.gd](addons/weavly/src/editor/weavly_compiler_runner.gd)) = editor-side wrapper that shells out to the actual Python compiler.

## Layout

```
addons/weavly/src/
  weavly_engine.tscn                # instantiable WeavlyEngine node, scripted with WeavlyDefaultEngine
  core/
    weavly_deserializer.gd          # JSON dict -> WeavlyModel.* objects (KEY_*/TYPE_* constants)
    weavly_statement_executor.gd    # dispatch Statement to the right service
    weavly_expression_evaluator.gd  # evaluate WeavlyExpression trees
    weavly_storylet_selector.gd     # list_pool/peek_pool: pick storylet nodes from pools
  engine/
    weavly_engine.gd                # WeavlyEngine: @abstract base — signals + service refs
    default_engine.gd               # WeavlyDefaultEngine: runtime control flow, service setup
  editor/                           # @tool editor plugin: .wvl main-screen editor, import
                                    # plugin, create-file menu, syntax highlighter,
                                    # compiler runner (invokes the Python compiler)
  models/
    weavly_model.gd                 # all model types as inner classes (WeavlyModel.NarrationLine, .MatchBlock, ...)
  services/
    weavly_media_index.gd           # shared path index + group regex for image/video services
    interfaces/                     # abstract contracts, one per service
    implementations/                # default_* implementations
  resources/                        # Godot Resources: WeavlyCharacter, Weavly{Number,String,Flag}Variable
  utils/                            # weavly_file_utils, weavly_text_utils

addons/weavly/ui/
  weavly_ui.gd                      # WeavlyUI: @abstract base, connects an engine by export or autoload name
  weavly_choice_list.gd             # WeavlyChoiceList: options as buttons or links, one selection for mouse and keys
  novel/, passage/                  # one folder per style: scene, script, own Theme, optional character subclass

test/                               # gdUnit4 tests: unit/ mirrors src/, ui/ covers addons/weavly/ui/, integration/, fixtures/, helpers/
                                    # fixtures/integration/ci_smoke/ is compiler-built, see above
ci/                                 # export smoke test: export_smoke/ is a small game CI exports,
                                    # external_media/ is copied next to the exported binary
```

### Conventions

- One outer `class_name` per file, matching the filename. Exception: `WeavlyModel` holds every model type as an inner class — reference as `WeavlyModel.NarrationLine` etc.
- Services use interface/implementation split. `WeavlyDefaultEngine` auto-instantiates default services in `_ready()`; override per-service via its `*_service_script` `@export` vars in the inspector.
- `.gd.uid` files are Godot-generated, never edit by hand.
- JSON field names and statement type strings live as `KEY_*` / `TYPE_*` constants at the top of [core/weavly_deserializer.gd](addons/weavly/src/core/weavly_deserializer.gd). Must mirror the Python compiler's emitted shape.

## Adding a new statement type

Cross-cuts both repos. Update `weavly-compiler` first (grammar + `WvlTransformer`), then here:

1. Add `KEY_*` / `TYPE_*` constants in [weavly_deserializer.gd](addons/weavly/src/core/weavly_deserializer.gd) if needed.
2. Add `compile_<type>` and wire into the `match` in `compile_statement`.
3. Add the model class in [weavly_model.gd](addons/weavly/src/models/weavly_model.gd), extending `Statement` (or `LineStatement` for line-type statements).
4. Add `execute_<type>` in [weavly_statement_executor.gd](addons/weavly/src/core/weavly_statement_executor.gd), wire into the `is_instance_of` chain.
5. New side effects: add to the relevant service interface + every implementation.

## Workflow

Issue-driven, squash-merged PRs. Full version: [CONTRIBUTING.md](CONTRIBUTING.md). For issue N:

1. `gh issue develop N --checkout` — creates `N-<slug>` branch linked to the issue.
2. Commit freely; intermediate commits get squashed on merge.
3. PR title = human sentence (usually the issue title); body must include `Closes #N`.
4. Squash merge produces one commit on `main`: `<title> (#<pr-number>)`.

Never commit directly to `main`. Never use the branch slug as a commit message.

## Status

`WeavlyEngine` ([engine/weavly_engine.gd](addons/weavly/src/engine/weavly_engine.gd)) is `@abstract`; runtime control flow lives in `WeavlyDefaultEngine` ([engine/default_engine.gd](addons/weavly/src/engine/default_engine.gd)). Every statement type the compiler emits is deserialized, executed and covered by tests, and the editor tooling is wired.

Releases are tag-driven from `plugin.cfg`; see CONTRIBUTING.
