# Weavly

Runs [Weavly](https://github.com/weavly-lang/weavly-compiler) branching dialogues at runtime, plus editor tooling for writing and compiling `.wvl` files inside Godot.

Enable **Weavly** under *Project Settings → Plugins*, then instance `addons/weavly/src/weavly_engine.tscn` in your scene:

```gdscript
@onready var engine: WeavlyEngine = $WeavlyEngine


func _ready() -> void:
    engine.line_service.executed_narration_line.connect(_show_narration)
    engine.option_service.options_added.connect(_show_options)
    engine.start("start")
```

The engine has no UI of its own; your game listens to service signals and renders however it likes. By default it loads compiled dialogue JSON from `res://dialogue/build`. For exports, add `*.json` to *Filters to export non-resource files* in your export preset, otherwise the dialogue JSON is not packed.

For the editor tooling you also need the Weavly compiler (0.4.0 or newer): `uv tool install weavly`.

Full documentation, the language reference and the issue tracker:
<https://github.com/weavly-lang/weavly-godot-addon>

Licensed under the MIT License, see [LICENSE](LICENSE).
