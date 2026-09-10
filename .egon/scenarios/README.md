# Scenarios

One file per scenario: `{name}.gd`, exposing `func apply() -> void:`. The file name is the
scenario name — nothing registers by hand, so nothing depends on `_ready()` ordering.

```gdscript
## The victory screen after a full run.
extends RefCounted


func apply() -> void:
	GameState.score = 4200
	get_tree().change_scene_to_file("res://scenes/endgame.tscn")
```

The leading `##` line is what GAME_MAP shows to later planners, so say what state it
establishes.

A scenario puts the game into a state using the game's own setters and scene changes. It
is never state injected from outside, so a refactor that breaks it breaks it loudly.

`default` is reserved and always available: it means the game as it normally boots, and
needs no file here.

Load one with `?egon_scenario={name}` in the browser, or
`godot --headless --path . --quit-after 60 -- --egon-scenario={name}` headless.

Scenarios persist across features. Never delete one with the feature that added it —
later features' regression checks depend on it still working. They run in debug builds
only.
