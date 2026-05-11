# CLAUDE.md

## Project

Godot 4.5 (Forward+) addon that runs Weavly programs at runtime by consuming JSON emitted by the Weavly compiler. Does not parse `.wvl` source.

- Addon code: `addons/weavly/src/`
- Engine scene: `addons/weavly/src/weavly_engine.tscn` — the instantiable `WeavlyEngine` node, scripted with `DefaultEngine`.

## Relationship to the compiler

Sibling repo at `../compiler` (Python) turns `.wvl` into JSON; this addon consumes it. Read-only upstream — output-shape changes start there, this repo follows.

Compiler context (commands, grammar, JSON output shape): @../compiler/CLAUDE.md

**Naming clash:** "the compiler" = the Python project. `WeavlyCompiler` ([core/weavly_compiler.gd](addons/weavly/src/core/weavly_compiler.gd)) = a GDScript JSON-to-model deserializer, not a `.wvl` compiler.

## Layout

```
addons/weavly/src/
  weavly_engine.tscn                # instantiable WeavlyEngine node, scripted with DefaultEngine
  core/
    weavly_engine.gd                # WeavlyEngine: abstract base — signals + service refs
    weavly_compiler.gd              # JSON dict -> WeavlyModel.* objects
    weavly_statement_executor.gd    # dispatch Statement to the right service
    weavly_expression_evaluator.gd  # evaluate WeavlyExpression trees
  models/
    weavly_model.gd                 # all model types as inner classes (WeavlyModel.NarrationLine, .MatchBlock, ...)
  services/
    interfaces/                     # abstract contracts, one per service
    implementations/                # default_*, list_*, group_* variants (incl. default_engine.gd)
  resources/                        # Godot Resources: WeavlyCharacter, Weavly{Number,String,Flag}Variable
  utils/                            # weavly_file_utils, weavly_text_utils
```

### Conventions

- One outer `class_name` per file, matching the filename. Exception: `WeavlyModel` holds every model type as an inner class — reference as `WeavlyModel.NarrationLine` etc.
- Services use interface/implementation split. `DefaultEngine` auto-instantiates default services in `_ready()`; override per-service via its `*_service_script` `@export` vars in the inspector.
- `.gd.uid` files are Godot-generated, never edit by hand.
- JSON field names and statement type strings live as `KEY_*` / `TYPE_*` constants at the top of [core/weavly_compiler.gd](addons/weavly/src/core/weavly_compiler.gd). Must mirror the Python compiler's emitted shape.

## Adding a new statement type

Cross-cuts both repos. Update `compiler` first (grammar + `WvlTransformer`), then here:

1. Add `KEY_*` / `TYPE_*` constants in [weavly_compiler.gd](addons/weavly/src/core/weavly_compiler.gd) if needed.
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

`WeavlyEngine` ([core/weavly_engine.gd](addons/weavly/src/core/weavly_engine.gd)) is abstract — `start / enter_node / next / finish` are `pass` bodies by design. Runtime control flow lives in `DefaultEngine` ([services/implementations/default_engine.gd](addons/weavly/src/services/implementations/default_engine.gd)). Compiler/executor/evaluator layers are largely wired.
