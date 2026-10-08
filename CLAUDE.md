# CLAUDE.md

## Project

Godot addon that runs Weavly programs at runtime by consuming JSON emitted by the Weavly compiler, plus editor tooling to edit and compile `.wvl` files inside Godot. The runtime does not parse `.wvl` source. The dev project targets Forward+; CI tests 4.5, 4.6 and 4.7.

- Runtime: `addons/weavly/runtime/`, everything a game needs.
- Editor tooling: `addons/weavly/editor/`, only runs inside the Godot editor.
- Starter UIs: `addons/weavly/ui/`, optional scenes on top of the runtime that use only its public API. Showcase projects live in the separate godot-demos repo, not here.
- Engine scene: `addons/weavly/runtime/weavly_engine.tscn` — the instantiable `WeavlyEngine` node.
- `dialogue/` is a gitignored folder of scratch Weavly projects (the starter-UI playtests, `editor_test`) for trying things by hand, so it is absent from a fresh clone. Create one with `weavly init dialogue/<name>`. The editor builds and indexes the open file's project: the parent of the nearest `src` folder above it.

## Relationship to the compiler

Sibling repo at `../weavly-compiler` (Python) turns `.wvl` into JSON; this addon consumes it. Read-only upstream — output-shape changes start there, this repo follows.

Compiler context (commands, grammar, JSON output shape): @../weavly-compiler/CLAUDE.md — this import only resolves when that repo is checked out beside this one; without it, read the compiler's own docs instead.

CI guards that shape: every fixture folder with a `src/` folder is a real Weavly project (`.wvl` sources, committed `build/` JSON) that a pinned compiler rebuilds on every PR, plus a weekly run against the newest release. `test/fixtures/integration/ci_smoke/` covers every statement type. Edit the `.wvl` sources and rebuild with `weavly build`; never hand-edit `build/`.

**Naming notes:** "the compiler" = the Python project. `WeavlyDeserializer` ([core/weavly_deserializer.gd](addons/weavly/runtime/core/weavly_deserializer.gd)) = the GDScript JSON-to-model reader. `WeavlyCompilerRunner` ([editor/weavly_compiler_runner.gd](addons/weavly/editor/weavly_compiler_runner.gd)) = editor-side wrapper that shells out to the actual Python compiler.

## Layout

```
addons/weavly/runtime/
  weavly_engine.tscn                # instantiable WeavlyEngine node
  core/
    weavly_deserializer.gd          # JSON dict -> WeavlyModel.* objects (KEY_*/TYPE_* constants)
    weavly_statement_executor.gd    # dispatch Statement to the right service
    weavly_expression_evaluator.gd  # evaluate WeavlyExpression trees
    weavly_storylet_selector.gd     # list_pool/peek_pool: pick storylet nodes from pools
    weavly_meta_reader.gd           # get_node_meta and meta(): a node's meta value or the key's default
    weavly_option_builder.gd        # offered options: the display rule, pool(...) items, refresh
    weavly_story.gd                 # WeavlyStory: the compiled story the engine owns, and type checks
  engine/
    weavly_engine.gd                # WeavlyEngine: signals, control flow, service setup, saving
  models/
    weavly_model.gd                 # all model types as inner classes (WeavlyModel.NarrationLine, .MatchBlock, ...)
  services/
    interfaces/                     # abstract contracts, one per service
    implementations/                # default_* implementations
  resources/                        # Godot Resources: WeavlyCharacter
  utils/                            # weavly_file_utils, weavly_text_utils

addons/weavly/editor/               # @tool editor plugin: .wvl main-screen editor, node outline,
                                    # find bar, code navigation (project index, Ctrl+click, hover,
                                    # back/forward), import plugin, create-file menu, syntax
                                    # highlighter, compiler runner (invokes the Python compiler)

addons/weavly/ui/
  weavly_ui.gd                      # WeavlyUI: @abstract base, connects an engine by export or autoload name
  weavly_choice_list.gd             # WeavlyChoiceList: options as buttons or links, one selection for mouse and keys
  novel/, passage/, card/, chat/, bubble/  # one folder per style: scene, script, own Theme, optional extra classes
  debug/                            # WeavlyDebugUI: overlay with variables, nodes, pools and runtime errors

test/                               # gdUnit4 tests: unit/ mirrors runtime/ and editor/, ui/ covers addons/weavly/ui/, integration/, fixtures/, helpers/
                                    # fixtures with a src/ folder are compiler-built, see above
ci/                                 # export smoke test: export_smoke/ is a small game CI exports
tools/mutation/                     # mutate.py: mutation testing, see its docstring
```

### Conventions

- One outer `class_name` per file, matching the filename. Exception: `WeavlyModel` holds every model type as an inner class — reference as `WeavlyModel.NarrationLine` etc.
- Services use interface/implementation split. `WeavlyEngine` creates the default services (`WeavlyDefault*Service`) in `_ready()`; scripts in its `custom_services` export replace the service they extend.
- `.gd.uid` files are Godot-generated, never edit by hand.
- JSON field names and statement type strings live as `KEY_*` / `TYPE_*` constants at the top of [core/weavly_deserializer.gd](addons/weavly/runtime/core/weavly_deserializer.gd). Must mirror the Python compiler's emitted shape.

## Adding a new statement type

Cross-cuts both repos. Update `weavly-compiler` first (grammar + `WvlTransformer`), then here:

1. Add `KEY_*` / `TYPE_*` constants in [weavly_deserializer.gd](addons/weavly/runtime/core/weavly_deserializer.gd) if needed.
2. Add `read_<type>` and wire into the `match` in `read_statement`.
3. Add the model class in [weavly_model.gd](addons/weavly/runtime/models/weavly_model.gd), extending `Statement` (or `LineStatement` for line-type statements).
4. Add `execute_<type>` in [weavly_statement_executor.gd](addons/weavly/runtime/core/weavly_statement_executor.gd), wire into the `is_instance_of` chain.
5. New side effects: add to the relevant service interface + every implementation.

## Documentation

- User docs live in the separate docs repo, published at <https://weavly-lang.github.io/weavly-docs/>. This repo has no docs folder.
- README.md and CONTRIBUTING.md stay short: what a newcomer needs, nothing more. Never add reference sections to them.
- Working notes go in `NOTES.md` at the repo root, which is gitignored.

## Workflow

Issue-driven, squash-merged PRs. Full version: [CONTRIBUTING.md](CONTRIBUTING.md). For issue N:

1. `gh issue develop N --checkout` — creates `N-<slug>` branch linked to the issue.
2. Commit freely; intermediate commits get squashed on merge.
3. PR title = human sentence (usually the issue title); body must include `Closes #N`.
4. Squash merge produces one commit on `main`: `<title> (#<pr-number>)`.

Never commit directly to `main`. Never use the branch slug as a commit message.

## Status

`WeavlyEngine` ([engine/weavly_engine.gd](addons/weavly/runtime/engine/weavly_engine.gd)) is one concrete class; games customize it through services or by subclassing it. Every statement type the compiler emits is deserialized, executed and covered by tests, and the editor tooling is wired.

Releases are tag-driven from `plugin.cfg`; see CONTRIBUTING.
