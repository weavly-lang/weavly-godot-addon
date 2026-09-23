# Weavly Godot Addon

[![CI](https://github.com/weavly-lang/weavly-godot-addon/actions/workflows/ci.yml/badge.svg)](https://github.com/weavly-lang/weavly-godot-addon/actions/workflows/ci.yml)

A Godot 4.5+ addon that runs [Weavly](https://github.com/weavly-lang/weavly-compiler) dialogue programs at runtime. Weavly is a small DSL for branching dialogues: its Python compiler turns `.wvl` source into JSON, and this addon consumes that JSON in your game. It also ships editor tooling so you can write and compile `.wvl` files without leaving Godot.

## Features

- **Runtime engine** — an instantiable `WeavlyEngine` node that loads compiled dialogues and drives them statement by statement: narration and character lines, options, `match`/`random` blocks, variables, gotos, and custom commands.
- **Signal-based UI contract** — the engine has no UI of its own. Your game listens to service signals (`executed_narration_line`, `options_added`, `executed_command`, `variable_changed`, ...) and renders however it likes.
- **Swappable services** — every concern (lines, options, variables, nodes, characters, images, videos, commands, statement flow) sits behind an abstract service. Override any of them via the engine's `*_service_script` exports in the inspector.
- **Asset indexing** — images, videos, character resources, and variable resources are discovered from configurable folders at startup, with optional regex grouping for random variant selection.
- **Editor tooling** — a main-screen `.wvl` editor with syntax highlighting, a create-file context menu, and one-click (or on-save) compilation via the Weavly CLI.

## Installation

1. Download the latest `weavly-<version>.zip` from [Releases](https://github.com/weavly-lang/weavly-godot-addon/releases) and extract it into your project root, so the addon lands in `addons/weavly`.
2. Enable **Weavly** under *Project Settings → Plugins*.
3. For the editor tooling, install the [Weavly compiler](https://github.com/weavly-lang/weavly-compiler) (0.3.0 or newer). With [uv](https://docs.astral.sh/uv/getting-started/installation/):

   ```bash
   uv tool install weavly
   ```

   With Python 3.11+ already installed, `pipx install weavly` works too. Restart Godot afterwards so it picks up the updated PATH, or point the editor setting `weavly/executable_path` at the `weavly` executable.

## Quick start

Instance `addons/weavly/src/weavly_engine.tscn` in your scene, then connect to its services and start a node:

```gdscript
@onready var engine: WeavlyEngine = $WeavlyEngine


func _ready() -> void:
    engine.line_service.executed_narration_line.connect(_show_narration)
    engine.line_service.executed_character_line.connect(_show_character_line)
    engine.option_service.options_added.connect(_show_options)
    engine.finished_dialogue.connect(_on_dialogue_finished)
    engine.start("start")


# Lines pause the engine; call next() when the player wants to continue.
func _on_continue_pressed() -> void:
    engine.next()


# Options pause the engine until one is chosen.
func _on_option_selected(option: WeavlyModel.Option) -> void:
    engine.option_service.choose_option(option)
```

By default the engine loads compiled dialogue JSON from `res://dialogue/build` and indexes media and resources from `res://media/images`, `res://media/videos`, `res://characters`, and `res://variables` — all configurable via exports on the `WeavlyEngine` node.

For exports, add `*.json` to *Filters to export non-resource files* in your export preset, otherwise the dialogue JSON is not packed.

### Variables

Declare each variable once, either in an `@env` block in a `.wvl` file or as a `WeavlyNumberVariable`, `WeavlyStringVariable` or `WeavlyFlagVariable` resource under `variable_path`. A name declared twice is an error when the engine loads; if a `.wvl` file and a resource declare the same name, the `.wvl` declaration is used.

A variable declared with `extern name: type` in `.wvl` gets its value from outside the script: from a resource with that name and type, or from game code calling `engine.variable_service.set_variable()`. Reading it before either has happened is an error.

### Commands

Any `@name` that isn't a Weavly keyword is a command for your game. Its comma-separated arguments are expressions, evaluated when the command runs:

```
@play_sound "door", $volume * 0.5
```

```gdscript
func _ready() -> void:
    engine.command_service.executed_command.connect(_on_command)


func _on_command(command: WeavlyModel.CommandStatement, args: Array) -> void:
    match command.id:
        "play_sound":
            play_sound(args[0], args[1])
```

Commands don't pause the dialogue. If an argument can't be evaluated, the error is reported and the command is skipped.

### Runtime errors

Mistakes a script makes at runtime, such as reading an undefined variable, are reported with the `.wvl` file and line of the statement that caused them, like `story.wvl:12: error: Variable 'score' isn't defined.` The engine also emits `runtime_error(message, source, line)`, so a game can show or log them.

### Media outside the game

`image_path` and `video_path` also accept paths outside `res://` — an absolute path or `user://` — for assets you want to ship next to the executable and swap without rebuilding. The path decides how they are read: `res://` uses the resource system, anything else reads from disk.

The engine reads these paths when it enters the tree, so set them before adding it:

```gdscript
func _ready() -> void:
    var engine: WeavlyEngine = preload("res://addons/weavly/src/weavly_engine.tscn").instantiate()
    if not OS.has_feature("editor"):
        engine.video_path = OS.get_executable_path().get_base_dir().path_join("media/videos")
    add_child(engine)
```

The `editor` check is needed because `OS.get_executable_path()` points at the Godot binary when running from the editor. External media is not part of the export, so your build step has to copy that folder next to the executable.

Character and variable `.tres` resources stay `res://` only, since they reference their script by resource uid. Dialogue and variable JSON works with either kind of path.

## Writing dialogues in the editor

Right-click a folder in the FileSystem dock and choose **WeavlyFile...** to create a `.wvl` file, or double-click an existing one to open it in the Weavly main screen. The panel saves with `Ctrl+S` and can compile the dialogue project on demand or on every save.

Relevant settings:

- `weavly/dialogue_project_dir` (project setting) — the Weavly project the compile button builds, default `res://dialogue`.
- `weavly/executable_path` (editor setting) — path to the `weavly` CLI, default `weavly`.

Language reference, grammar, and compiler commands live in the [compiler repo](https://github.com/weavly-lang/weavly-compiler).

## Development

Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (`test/`), linting and formatting use [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdlintrc` / `gdformatrc`). CI runs the suite on Godot 4.5, 4.6 and 4.7, exports a test game and runs the binary, and rebuilds the test fixtures with the published compiler. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow.

## License

[MIT](LICENSE). The vendored test framework under `addons/gdUnit4/` is MIT as well ([license](addons/gdUnit4/LICENSE)) and is a development dependency, not part of the addon you ship.
