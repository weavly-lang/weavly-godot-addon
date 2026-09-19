# Weavly Godot Addon

A Godot 4.5+ addon that runs [Weavly](https://github.com/weavly-lang/weavly-compiler) dialog programs at runtime. Weavly is a small DSL for writing branching dialogs; the [compiler](https://github.com/weavly-lang/weavly-compiler) (Python) turns `.wvl` source into JSON, and this addon consumes that JSON in your game. It also ships editor tooling so you can write and compile `.wvl` files without leaving Godot.

## Features

- **Runtime engine** — an instantiable `WeavlyEngine` node that loads compiled dialogs and drives them statement by statement: narration and character lines, options, `match`/`random` blocks, variables, gotos, and custom commands.
- **Signal-based UI contract** — the engine has no UI of its own. Your game listens to service signals (`executed_narration_line`, `options_added`, `executed_command`, `variable_changed`, ...) and renders however it likes.
- **Swappable services** — every concern (lines, options, variables, nodes, characters, images, videos, commands, statement flow) sits behind an abstract service. Override any of them via the engine's `*_service_script` exports in the inspector.
- **Asset indexing** — images, videos, character resources, and variable resources are discovered from configurable folders at startup, with optional regex grouping for random variant selection.
- **Editor tooling** — a main-screen `.wvl` editor with syntax highlighting, a create-file context menu, and one-click (or on-save) compilation via the Weavly CLI.

## Installation

1. Copy `addons/weavly` into your project's `addons/` folder.
2. Enable **Weavly** under *Project Settings → Plugins*.
3. For the editor tooling, install the [Weavly compiler](https://github.com/weavly-lang/weavly-compiler) (0.1.0 or newer). With [uv](https://docs.astral.sh/uv/getting-started/installation/):

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
    engine.finished_dialog.connect(_on_dialog_finished)
    engine.start("start")


# Lines pause the engine; call next() when the player wants to continue.
func _on_continue_pressed() -> void:
    engine.next()


# Options pause the engine until one is chosen.
func _on_option_selected(option: WeavlyModel.Option) -> void:
    engine.option_service.choose_option(option)
```

By default the engine loads compiled dialog JSON from `res://dialog/build` and indexes media and resources from `res://media/images`, `res://media/videos`, `res://characters`, and `res://variables` — all configurable via exports on the `WeavlyEngine` node.

For exports, add `*.json` to *Filters to export non-resource files* in your export preset, otherwise the dialog JSON is not packed.

### Media outside the game

`image_path` and `video_path` also accept paths outside `res://` — an absolute path or `user://` — for assets you want to ship next to the executable and swap without rebuilding, which is mostly interesting for video. The path decides how they are read: `res://` uses the resource system, anything else reads from disk.

The engine reads these paths when it enters the tree, so set them before adding it:

```gdscript
func _ready() -> void:
    var engine: WeavlyEngine = preload("res://addons/weavly/src/weavly_engine.tscn").instantiate()
    if not OS.has_feature("editor"):
        engine.video_path = OS.get_executable_path().get_base_dir().path_join("media/videos")
    add_child(engine)
```

The `editor` check matters because `OS.get_executable_path()` points at the Godot binary while running from the editor, not at your project. External media is not part of the export, so your build step has to copy that folder next to the executable.

Character and variable `.tres` resources stay `res://` only: they reference their script by resource uid, which does not survive outside the project. Dialog and variable JSON works with either kind of path.

## Writing dialogs in the editor

Right-click a folder in the FileSystem dock and choose **WeavlyFile...** to create a `.wvl` file, or double-click an existing one to open it in the Weavly main screen. The panel saves with `Ctrl+S` and can compile the dialog project on demand or on every save.

Relevant settings:

- `weavly/dialog_project_dir` (project setting) — the Weavly project the compile button builds, default `res://dialog`.
- `weavly/executable_path` (editor setting) — path to the `weavly` CLI, default `weavly`.

Language reference, grammar, and compiler commands live in the [compiler repo](https://github.com/weavly-lang/weavly-compiler).

## Development

Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (`test/`), linting and formatting use [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdlintrc` / `gdformatrc`); both run in CI, with the tests running on Godot 4.5, 4.6 and 4.7. See [CONTRIBUTING.md](CONTRIBUTING.md) for the issue-driven workflow.
