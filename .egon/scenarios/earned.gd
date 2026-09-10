## The balance changed during play, with autosave left on, so a check can prove the change
## reaches the file without anyone pressing Save & Quit.
##
## An absolute value rather than add_rubles(), so the check does not have to know what
## STARTING_RUBLES is and stops mattering the next time that number is tuned.
extends RefCounted

const EARNED_RUBLES := 7777


func apply() -> void:
	var state: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if state == null:
		push_error("earned scenario: GameState autoload is missing")
		return
	# From a known floor: any file an earlier check left behind is gone before this writes.
	state.clear_save()
	state.set_rubles(EARNED_RUBLES)
