# CLAUDE.md

## Project

Godot 4.5 (Forward+) addon that runs Weavly programs at runtime by consuming JSON emitted by the Weavly compiler, plus editor tooling to edit and compile `.wvl` files inside Godot. The runtime does not parse `.wvl` source.

- Addon code: `addons/weavly/src/`
- Engine scene: `addons/weavly/src/weavly_engine.tscn` — the instantiable `WeavlyEngine` node, scripted with `WeavlyDefaultEngine`.
- Sample dialog project: `dialog/` (`src/` holds `.wvl` sources, `build/` the compiled JSON).

## Relationship to the compiler

Sibling repo at `../weavly-compiler` (Python) turns `.wvl` into JSON; this addon consumes it. Read-only upstream — output-shape changes start there, this repo follows.

Compiler context (commands, grammar, JSON output shape): @../weavly-compiler/CLAUDE.md

**Naming notes:** "the compiler" = the Python project. `WeavlyDeserializer` ([core/weavly_deserializer.gd](addons/weavly/src/core/weavly_deserializer.gd)) = the GDScript JSON-to-model reader (its `compile_*` methods deserialize, they don't compile `.wvl`). `WeavlyCompilerRunner` ([editor/weavly_compiler_runner.gd](addons/weavly/src/editor/weavly_compiler_runner.gd)) = editor-side wrapper that shells out to the actual Python compiler.

## Layout

```
addons/weavly/src/
  weavly_engine.tscn                # instantiable WeavlyEngine node, scripted with WeavlyDefaultEngine
  core/
    weavly_deserializer.gd          # JSON dict -> WeavlyModel.* objects (KEY_*/TYPE_* constants)
    weavly_statement_executor.gd    # dispatch Statement to the right service
    weavly_expression_evaluator.gd  # evaluate WeavlyExpression trees
  engine/
    weavly_engine.gd                # WeavlyEngine: @abstract base — signals + service refs
    default_engine.gd               # WeavlyDefaultEngine: runtime control flow, service setup
  editor/                           # @tool editor plugin: .wvl main-screen editor, import
                                    # plugin, create-file menu, syntax highlighter,
                                    # compiler runner (invokes the Python compiler)
  models/
    weavly_model.gd                 # all model types as inner classes (WeavlyModel.NarrationLine, .MatchBlock, ...)
  services/
    interfaces/                     # abstract contracts, one per service
    implementations/                # default_* and list_* variants
  resources/                        # Godot Resources: WeavlyCharacter, Weavly{Number,String,Flag}Variable
  utils/                           # weavly_file_utils, weavly_text_utils

test/                               # gdUnit4 tests: unit/ mirrors src/, integration/, fixtures/, helpers/
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

`WeavlyEngine` ([engine/weavly_engine.gd](addons/weavly/src/engine/weavly_engine.gd)) is `@abstract`; runtime control flow lives in `WeavlyDefaultEngine` ([engine/default_engine.gd](addons/weavly/src/engine/default_engine.gd)). Deserializer/executor/evaluator layers and the editor tooling are wired.
