## A first run: no save file, the balance back at STARTING_RUBLES.
##
## Progress persists to user://, which is per-origin and outlives a page load, so a check
## that leaves the player rich leaves every check booting afterwards rich too. Any check
## asserting a specific balance should start from here rather than from `default`.
extends RefCounted


func apply() -> void:
	var state: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if state == null:
		push_error("no_save scenario: GameState autoload is missing")
		return
	state.clear_save()
