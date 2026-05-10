# CLAUDE.md

## Project

Godot 4.5 addon that runs Weavly programs at runtime. Consumes the JSON output produced by the Weavly compiler — does not parse `.wvl` source itself.

- Engine: Godot 4.5 (Forward+ renderer)
- Addon code: `addons/weavly/src/`
- Demo scene: `addons/weavly/src/weavly_engine.tscn`

## Relationship to the compiler

The compiler (sibling repo at `../compiler`) turns `.wvl` source into JSON. This addon is the GDScript-side consumer of that JSON. When the compiler's output shape changes, this addon must follow.

Compiler context (commands, grammar, test layout, JSON output shape):
@../compiler/CLAUDE.md

Treat the compiler as a read-only upstream from here — don't edit it. Output-shape changes start in the compiler repo.

**Naming clash to watch for:** The Python project is called "the compiler". This addon also has a class `WeavlyCompiler` ([core/weavly_compiler.gd](addons/weavly/src/core/weavly_compiler.gd)), which is actually a JSON-to-model deserializer — it does not compile `.wvl`. When in doubt, "compiler" = the Python project; `WeavlyCompiler` = the GDScript loader.

## Layout

```
addons/weavly/src/
  core/
    weavly_engine.gd                # WeavlyEngine: runtime entry, holds service refs, signals
    weavly_compiler.gd              # JSON dict -> WeavlyModel.* objects
    weavly_statement_executor.gd    # dispatch a Statement to the right service
    weavly_expression_evaluator.gd  # evaluate WeavlyExpression trees
    weavly_engine.tscn              # demo scene wiring services into an engine
  models/
    weavly_model.gd                 # single file, all model types as nested classes (WeavlyModel.NarrationLine, .MatchBlock, ...)
  services/
    interfaces/                     # abstract contracts (one file per service)
    implementations/                # default_*, list_*, group_* variants per interface
  resources/                        # Godot Resource subclasses: WeavlyCharacter, Weavly{Number,String,Flag}Variable
  utils/                            # weavly_file_utils, weavly_text_utils
```

### Conventions

- One outer class per file (`class_name`), matches the filename.
- `WeavlyModel` is the exception: it's a single file holding every model type as an inner class. Reference them as `WeavlyModel.NarrationLine`, `WeavlyModel.MatchBlock`, etc.
- Services follow an interface/implementation split. The engine is configured by injecting concrete services into a `WeavlyEngine` node — see `weavly_engine.tscn` for an example.
- `.gd.uid` files are Godot-generated, never edit by hand.

### Key strings

JSON field names and statement type strings live as constants at the top of [core/weavly_compiler.gd](addons/weavly/src/core/weavly_compiler.gd) (`KEY_*`, `TYPE_*`). These mirror what the Python compiler emits — keep them in sync.

## Adding a new statement type

Cross-cuts both repos. In `compiler` first (grammar + `WvlTransformer`), then here:

1. Add `KEY_*` / `TYPE_*` constants in [weavly_compiler.gd](addons/weavly/src/core/weavly_compiler.gd) if needed.
2. Add a `compile_<type>` function and wire it into the `match` in `compile_statement`.
3. Add the model class inside [weavly_model.gd](addons/weavly/src/models/weavly_model.gd) (extend `Statement` or `Block`).
4. Add `execute_<type>` in [weavly_statement_executor.gd](addons/weavly/src/core/weavly_statement_executor.gd) and wire into the `is_instance_of` chain.
5. If the executor needs a new side effect, add it to the relevant service interface + every implementation.

## Workflow

Issue-driven, squash-merged PRs. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full version. When asked to work on issue N:

1. `gh issue develop N --checkout` — creates and checks out `N-<slug>` branch, links it to the issue
2. Commit freely — intermediate commits get squashed on merge
3. PR title = human sentence (usually the issue title); body must include `Closes #N`
4. Squash merge produces one clean commit on `main`: `<title> (#<pr-number>)`

Never commit directly to `main`. Never use the branch slug as a commit message.

## Status

`WeavlyEngine.start / enter_node / next / finish` are still stubs — the runtime control flow is in progress. The compiler/executor/evaluator layers are largely wired.
