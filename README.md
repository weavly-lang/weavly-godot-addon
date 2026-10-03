# Weavly Godot Addon

[![CI](https://github.com/weavly-lang/weavly-godot-addon/actions/workflows/ci.yml/badge.svg)](https://github.com/weavly-lang/weavly-godot-addon/actions/workflows/ci.yml)

A Godot 4.5+ addon that plays [Weavly](https://github.com/weavly-lang/weavly-compiler) branching dialogues at runtime. The Weavly compiler turns `.wvl` source into JSON, and this addon runs that JSON in your game. It also lets you write and compile `.wvl` files inside the Godot editor.

**Documentation: <https://weavly-lang.github.io/weavly-docs/>**

## Features

- **Runtime engine**: a `WeavlyEngine` node that plays lines, options, `match` and `random` blocks, variables, jumps and detours, the game's functions and commands, storylet pools and meta keys.
- **No UI lock-in**: your game listens to signals and draws the dialogue however it likes.
- **Starter UIs**: visual novel, Twine-style passage, card, chat, speech bubbles and a debug overlay, ready to drop in or copy.
- **Swappable services**: replace any part of the runtime through the engine's `*_service_script` exports.
- **Editor tooling**: a `.wvl` editor with syntax highlighting and one-click compiling.

## Installation

1. Download `weavly-<version>.zip` from [Releases](https://github.com/weavly-lang/weavly-godot-addon/releases) and extract it into your project, so the addon lands in `addons/weavly`.
2. Enable **Weavly** under *Project Settings → Plugins*.
3. For the editor tooling, install the Weavly compiler (0.5.0 or newer) and restart Godot:

   ```bash
   uv tool install weavly
   ```

## Quick start

Instance `addons/weavly/runtime/weavly_engine.tscn` in your scene, connect to its signals and start a node:

```gdscript
@onready var engine: WeavlyEngine = $WeavlyEngine


func _ready() -> void:
    engine.line_service.executed_narration_line.connect(_show_line)
    engine.line_service.executed_character_line.connect(_show_line)
    engine.option_service.options_added.connect(_show_options)
    engine.start("start")


# Lines pause the dialogue until next() is called.
func _on_continue_pressed() -> void:
    engine.next()


func _on_option_pressed(option: WeavlyModel.Option) -> void:
    engine.option_service.choose_option(option)
```

Values your game owns, like the player's gold, are declared `extern var` in `@env` and set with `engine.variable_service.set_variable()`. `engine.get_state()` leaves them out, so save them with your game's own data.

The engine loads compiled dialogue from `res://dialogue/build` by default. For exports, add `*.json` to *Filters to export non-resource files* in your export preset.

Or skip the code: add one of the starter UIs from `addons/weavly/ui/` to your scene and set its `engine` to the engine node.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). The vendored test framework under `addons/gdUnit4/` is MIT as well and isn't part of the addon you ship.
