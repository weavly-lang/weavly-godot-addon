# Weavly Godot Addon

[![CI](https://github.com/weavly-lang/weavly-godot-addon/actions/workflows/ci.yml/badge.svg)](https://github.com/weavly-lang/weavly-godot-addon/actions/workflows/ci.yml)

A Godot 4.5+ addon that runs [Weavly](https://github.com/weavly-lang/weavly-compiler) dialogue programs at runtime. Weavly is a small DSL for branching dialogues: its Python compiler turns `.wvl` source into JSON, and this addon consumes that JSON in your game. It also ships editor tooling so you can write and compile `.wvl` files without leaving Godot.

## Features

- **Runtime engine** — an instantiable `WeavlyEngine` node that loads compiled dialogues and drives them statement by statement: narration and character lines, options, `match`/`random` blocks, variables, gotos, and custom commands.
- **Signal-based UI contract** — the engine has no UI of its own. Your game listens to service signals (`executed_narration_line`, `options_added`, `executed_command`, `variable_changed`, ...) and renders however it likes.
- **Starter UIs** — ready-made dialogue UIs to drop into a scene, restyle through their theme, or copy as a starting point.
- **Swappable services** — every concern (lines, options, variables, nodes, characters, images, videos, commands, statement flow) sits behind an abstract service. Override any of them via the engine's `*_service_script` exports in the inspector.
- **Asset indexing** — images, videos, character resources, and variable resources are discovered from configurable folders at startup, with optional regex grouping for random variant selection.
- **Editor tooling** — a main-screen `.wvl` editor with syntax highlighting, a create-file context menu, and one-click (or on-save) compilation via the Weavly CLI.

## Installation

1. Download the latest `weavly-<version>.zip` from [Releases](https://github.com/weavly-lang/weavly-godot-addon/releases) and extract it into your project root, so the addon lands in `addons/weavly`.
2. Enable **Weavly** under *Project Settings → Plugins*.
3. For the editor tooling, install the [Weavly compiler](https://github.com/weavly-lang/weavly-compiler) (0.4.0 or newer). With [uv](https://docs.astral.sh/uv/getting-started/installation/):

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

Game code can only set declared variables; `set_variable()` on an undeclared name reports an error and changes nothing. Declare variables your game owns as `extern`.

Line and option text can use any expression in `{}`, such as `{$name}` or `{$price * 2}`; `\{` is a literal brace. The line and option signals deliver copies with `text` filled in when they're shown, and an expression that fails is reported and left out. A character line written `$name: ...` arrives with the variable's value as `name` and the variable's id in `raw_name`. For text outside dialogue, `WeavlyTextUtils.inject_variables(text, engine)` fills in `{$name}` variables in any string.

Numbers are shown with at most two decimals and whole numbers without any, so `1 / 3` shows as `0.33` and `10` as `10`; games that need other formatting can pass their own pipeline to `inject_variables`. Numbers also compare approximately: `==`, `!=`, `<=` and `>=` treat values that differ only by floating-point rounding as equal, so `0.1 + 0.2 == 0.3` is true and `0.1 + 0.2 > 0.3` is false.

### Options, match and random

An `@options` block whose options all have a false condition is skipped, and so is a `@random` block without an eligible case, since conditions that can all be false are a normal pattern.

`@random` and `random()` roll with the engine's own `RandomNumberGenerator`, `engine.rng`, so the rest of the game doesn't shift Weavly's rolls. Set `random_seed` on the engine to a value other than 0 to get the same rolls on every run, for tests or to reproduce a bug report.

A hint is shown but can't be chosen. When every available option in a block is a hint, `options_added` still delivers them, but the dialogue waits for `next()` as it does after a line and then continues after the block, so show a continue button instead of choices:

```gdscript
func _show_options(options: Array[WeavlyModel.Option]) -> void:
    var choosable: bool = options.any(func(option: WeavlyModel.Option) -> bool: return not option.hint)
    continue_button.visible = not choosable
```

`@match all` evaluates every condition first and then runs the bodies of the matching cases in order, so a `@set` in one body doesn't change which later cases match.

### Commands

Any `@name` that isn't a Weavly keyword is a command for your game. Its comma-separated arguments are expressions, evaluated when the command runs:

```
@play_sound "door", $volume * 0.5
```

```gdscript
func _ready() -> void:
    engine.command_service.executed_command.connect(_on_command)


func _on_command(command: WeavlyModel.CommandStatement) -> void:
    match command.id:
        "play_sound":
            play_sound(command.values[0], command.values[1])
```

Commands don't pause the dialogue. To wait for an effect, call `engine.hold()` in the handler and `engine.release()` when it's done. While the dialogue is held, `next()` does nothing, so a continue button can't cut the wait short, and holds are counted, so several commands can wait at once:

```gdscript
        "shake":
            engine.hold()
            await shake_camera(command.values[0])
            engine.release()
```

If an argument can't be evaluated, the error is reported and the command is skipped.

### Storylets

A node with an `@meta` block is a storylet: the game picks it from a pool instead of jumping to it by name. Pools and slots are declared in `@env` (`city: pool`, `bob: slot`), and a node joins them in its `@meta`:

```
@node bob_greets
@meta
pool: city
slot: bob
when: $gold > 2
priority: 1
weight: 1 + skip_count()
once: true
@endmeta
Bob waves at you.
@endnode
```

`engine.list_pool(["city"])` returns the ids of the nodes to offer, as an `Array[String]` in selection order:

1. The members of all given pools, a node in several of them counted once.
2. Only nodes whose `when` is true and whose `weight` is above 0. `priority` defaults to 0 and `weight` to 1.
3. Highest `priority` first. Nodes with the same priority are shuffled by weight with `engine.rng`, so a node with weight 2 comes first about twice as often as one with weight 1.
4. A node is left out when a node before it already took one of its slots. Slots block across all given pools, and nodes without slots are always listed.

`list_pool` accepts several pools, as in `engine.list_pool(["city", "city_night"])`, and an optional limit: `engine.list_pool(["city"], 3)` stops once it has taken three nodes, so a game that shows three cards only pulls three. Without a limit, or with `-1`, it takes every node it can. It updates skip counts: every listed node goes back to 0, and every eligible node that wasn't listed goes up by 1, including those past the limit. `skip_count(node)` reads that count in a script, and without an argument it means the current node, so `weight: 1 + skip_count()` makes a node likelier the longer it waits. Skip counts are saved with the state.

`engine.draw(["city"])` starts a dialogue with the first node in selection order, the first entry `list_pool` would return, and returns `true`, or returns `false` and starts nothing when no node is eligible. It takes several pools like `list_pool`, and while a dialogue runs it warns and does nothing, like `start()`. In a script, `@draw city, city_night` leaves the current node and enters the drawn one like `@goto`; when no node is eligible, it does nothing and the node continues with the next line. Both update skip counts: the drawn node goes back to 0 and every other eligible node goes up by 1.

`engine.peek_pool(["city"], 3)` returns what `list_pool` with the same pools and limit would return at that moment without changing anything: skip counts stay as they are and the generator is restored, so a following `list_pool` makes the same picks. `not engine.peek_pool(["city"]).is_empty()` asks whether anything is there. `engine.node_service.get_node_meta(id)` gives a node's pools and slots.

A pool name that isn't declared is reported as a runtime error and counts as empty. A `when`, `priority` or `weight` that fails is reported at its line in the `@meta` block, and the node isn't eligible. `@goto` and `start()` ignore the metadata, so an explicit jump always works.

### Rendering a node

`engine.render(node_id)` runs a whole node at once instead of waiting for `next()` after every line, for a node shown as a UI card or a Twine-style passage. It returns filled copies of what the node produced, in order, as an `Array[WeavlyModel.Statement]`:

- `NarrationLine` and `CharacterLine` with their text filled in, as the line signals deliver them;
- `CommandStatement` with its evaluated arguments in `values`, collected instead of emitted;
- `OptionBlock` with the options whose condition is true, hints included. `@continue` arrives as a block with one option.

Conditions, `{}` expressions, `@if`, `@match`, `@random`, `@goto` and `@draw` work as in normal play, and `@finish` ends the render. It isn't a dry run: `@set`, visits and `entered_node` happen as usual, while `started_dialogue` and `finished_dialogue` don't fire. Option actions don't run during the render, and while a dialogue runs, `render()` warns and does nothing.

```gdscript
for entry: WeavlyModel.Statement in engine.render("tavern_card"):
    if entry is WeavlyModel.CharacterLine:
        card.add_line(entry.name, entry.text)
    elif entry is WeavlyModel.CommandStatement:
        match entry.id:
            "header":
                card.set_header(entry.values[0])
    elif entry is WeavlyModel.OptionBlock:
        for option: WeavlyModel.Option in entry.options:
            card.add_button(option.text, option.hint, func() -> void: engine.choose(option))
```

When the player picks a rendered option, `engine.choose(option)` starts a dialogue that runs only that option's action; the rest of the node already ran. Without a jump the dialogue ends after the action, and a `@goto` plays on into the next node. `engine.render_option(option)` instead runs the action in one pass like `render()`, following jumps, and returns what it produced, so a game can move from card to card. Both accept only options from a render, not hints; after one of them, only the options it produced can be chosen next.

After a render, `get_state()` returns the state as the last rendered node was entered, marked as rendered. `set_state()` restores it without starting a dialogue, so render the node again after `state_loaded`; with the saved generator, it renders the same.

### Saving and loading

`engine.get_state()` returns the runtime state as a Dictionary of JSON-safe values: variable values, visit and skip counts, the random number generator, and the state of any custom service that saves its own. Weavly doesn't write files, so the game stores the state however it likes, for example inside its own save:

```gdscript
func save_game() -> void:
    var file: FileAccess = FileAccess.open("user://save.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(engine.get_state()))


func load_game() -> void:
    var text: String = FileAccess.get_file_as_string("user://save.json")
    engine.set_state(JSON.parse_string(text))
```

During a dialogue, the state is the one taken when the current node was entered, and `set_state()` replays that node from its first statement, with the same `@random` and `random()` rolls. A save therefore loses progress inside the current node, so keep nodes short if the player can save at any time. `set_state()` emits `state_loaded` once, and `reset_state()` goes back to the state after loading, for a new game. With a `random_seed`, that includes the generator, so the new game rolls like the first one; without it, the generator keeps rolling on. What the game did in response to Weavly, like media shown or music started by a command, isn't part of the state.

### Runtime errors

Mistakes a script makes at runtime, such as reading an undefined variable, are reported with the `.wvl` file and line of the statement that caused them, like `story.wvl:12: error: Variable 'score' isn't defined.` The engine also emits `runtime_error(message, source, line)`, so a game can show or log them.

### Images and videos

Images and videos are found in `image_path` and `video_path`, including subfolders, and their id is the path relative to that folder without extension, so `splash.png` is `splash` and `alice/icon.png` is `alice/icon`. Files that differ only in extension, like `icon.png` and `icon.jpg`, share an id; both paths are reported and the first is used.

With `image_group_pattern` or `video_group_pattern` set, files in the same folder whose names are the same once the pattern is removed form a group. With `_\d+$`, `alice/icon_1.png` and `alice/icon_2.png` are both `alice/icon`, while `bob/icon_3.png` is `bob/icon`. Every `get_image("alice/icon")` or `get_video("alice/icon")` picks a new file from the group, so keep the returned resource if the same line should show the same file twice.

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

## Starter UIs

`addons/weavly/ui/` has ready-made dialogue UIs built on the same signals your own UI would use. Drop one into a scene, restyle it through its theme, or copy it as a starting point. Each one extends `WeavlyUI` and connects to an engine in one of two ways:

- `engine`: an engine node in the same scene, picked in the inspector.
- `engine_autoload`: the name of an autoloaded engine, such as `Dialogue`, looked up when the UI is ready. When both are set, `engine` wins.

Assigning `engine` in code works too, and assigning another engine later reconnects the UI:

```gdscript
$WeavlyNovelUI.engine = Dialogue
```

The UIs don't interpret commands, so handle `executed_command` in your game as usual.

### Visual novel

`addons/weavly/ui/novel/weavly_novel_ui.tscn` is a visual novel UI in the style of Ren'Py. It shows lines in a textbox at the bottom, with a nameplate for character lines, and reveals the text at `characters_per_second` (`0` shows it at once). A click or `advance_action` (`ui_accept` by default) completes a line that's still revealing, the next one continues. Options appear as a menu in the middle of the screen, with hints disabled. Mouse and keys share one selection, as in most game menus: the menu opens with nothing selected, hovering an option or the first arrow key or `advance_action` press selects one, and a click or `advance_action` chooses it. Hints can't be selected. The UI hides itself while no dialogue runs.

Lines show as written. With `bbcode_enabled`, the textbox renders BBCode in lines instead, including in values filled in from `{}`, so a player-entered name containing `[` is parsed too.

The nameplate shows the character's `display_name`, or the name as written when there's no character with that id. For a nameplate color, create the character as a `WeavlyNovelCharacter` and set `name_color`; a plain `WeavlyCharacter` uses the theme's color. The look lives in `weavly_novel_theme.tres`, with the nameplate as the `WeavlyNovelNameplate` type variation.

### Passage

`addons/weavly/ui/passage/weavly_passage_ui.tscn` is a hypertext UI in the style of Twine, built on [rendering](#rendering-a-node) instead of stepping. `show_passage("tavern")` renders the node and shows it as one passage: every line as a paragraph, character lines with the speaker's name in bold, and each options block as links in place, with hints muted. Clicking a link calls `render_option()`, which runs the option and follows its jump, and the result becomes the next passage. With `append` on, earlier passages stay above the new one, with the chosen link in place of their links. Links share one selection between mouse and keys, like the visual novel menu, and the page scrolls to follow it.

A passage with nothing to choose is an ending: the UI emits `finished`, and the game decides what comes next, for example `clear()` and a new `show_passage()`. Rendered commands aren't interpreted; the UI emits each one with `command_rendered(command)`, in order. `bbcode_enabled` works like in the visual novel UI. The look lives in `weavly_passage_theme.tres`.

### Card

`addons/weavly/ui/card/weavly_card_ui.tscn` deals [storylets](#storylets) as a hand of cards. `deal(["city"])` asks `list_pool` for up to `hand_size` storylets (3 by default) and renders each one as a card: its lines are the face, and its options are buttons on the card, with hints disabled. A card with exactly one option to choose is a button as a whole. Picking an option calls `render_option()`, and what it produced replaces the hand as an outcome card, which can have options of its own. When the outcome has nothing left to choose, *Continue* deals a new hand from the same pools. A deal without any eligible storylet emits `hand_empty` and hides the UI. Cards and options share one selection between mouse and keys, like the other starter UIs. Rendered commands are emitted with `command_rendered(command)`, `bbcode_enabled` works like in the other UIs, and the look lives in `weavly_card_theme.tres`.

Keep a card's node to what the card shows, and let its option jump to an effect node that holds the state changes:

```
@node inn_stranger
@meta
pool: city
when: not visited(inn_stranger_effect)
@endmeta
A stranger at the inn waves you over.
@options
@option "Join them" -> inn_stranger_effect
@endoptions
@endnode

@node inn_stranger_effect
@increase $gold 5
You win 5 gold at cards.
@endnode
```

Showing a card renders its node, and rendering counts a visit, so `once: true` and `visited()` on the card itself mean "was shown". Put them on the effect node to mean "was picked", as the `when` above does.

All three UIs build their options with `WeavlyChoiceList`, and `WeavlyUI.create_line_label()` turns a line into a paragraph with the speaker's name in bold; both can be reused in your own UI.

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
