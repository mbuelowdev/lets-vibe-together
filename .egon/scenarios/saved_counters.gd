## A save file already on disk holding skins and targets beside a seven-digit balance, so a check
## can prove both counts are read from it at game start and that the taskbar packs them against a
## wider balance than the boot one.
##
## Written and then read through the same GameState.load_game() a cold boot calls, the way
## saved_progress does it.
extends RefCounted

const SAVED_RUBLES := 1_234_567
const SAVED_SKINS := 12
## Four digits, so the count is drawn with a group separator.
const SAVED_TARGETS := 1234


func apply() -> void:
	var state: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if state == null:
		push_error("saved_counters scenario: GameState autoload is missing")
		return
	var config := ConfigFile.new()
	config.set_value(state.SAVE_SECTION, "version", state.SAVE_VERSION)
	config.set_value(state.SAVE_SECTION, "rubles", SAVED_RUBLES)
	config.set_value(state.SAVE_SECTION, "skins", SAVED_SKINS)
	config.set_value(state.SAVE_SECTION, "targets", SAVED_TARGETS)
	if config.save(state.SAVE_PATH) != OK:
		push_error("saved_counters scenario: could not write %s" % state.SAVE_PATH)
		return
	state.load_game()
