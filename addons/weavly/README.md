# Weavly

Plays [Weavly](https://github.com/weavly-lang/weavly-compiler) branching dialogues at runtime, plus editor tooling for writing and compiling `.wvl` files inside Godot.

Enable **Weavly** under *Project Settings → Plugins*, then instance `addons/weavly/src/weavly_engine.tscn` in your scene:

```gdscript
@onready var engine: WeavlyEngine = $WeavlyEngine


func _ready() -> void:
    engine.line_service.executed_narration_line.connect(_show_line)
    engine.option_service.options_added.connect(_show_options)
    engine.start("start")
```

By default the engine loads compiled dialogue from `res://dialogue/build`. For exports, add `*.json` to *Filters to export non-resource files* in your export preset.

For the editor tooling you also need the Weavly compiler (0.4.0 or newer): `uv tool install weavly`.

Documentation: <https://weavly-lang.github.io/weavly-docs/>

Source and issues: <https://github.com/weavly-lang/weavly-godot-addon>

Licensed under the MIT License, see [LICENSE](LICENSE).
