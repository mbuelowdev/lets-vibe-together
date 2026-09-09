## A save file already on disk, so a check can prove the balance is read from it at game
## start rather than defaulted to STARTING_RUBLES.
##
## Written here and then read through the same GameState.load_game() a cold boot calls: the
## check vocabulary has no page-reload step, so this exercises every line of the load path
## except the one that decides when it runs.
extends RefCounted

## Nowhere near STARTING_RUBLES, so a passing check cannot be the default quietly agreeing
## with the saved value.
const SAVED_RUBLES := 4242


func apply() -> void:
	var state: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if state == null:
		push_error("saved_progress scenario: GameState autoload is missing")
		return
	var config := ConfigFile.new()
	config.set_value(state.SAVE_SECTION, "version", state.SAVE_VERSION)
	config.set_value(state.SAVE_SECTION, "rubles", SAVED_RUBLES)
	if config.save(state.SAVE_PATH) != OK:
		push_error("saved_progress scenario: could not write %s" % state.SAVE_PATH)
		return
	state.load_game()
