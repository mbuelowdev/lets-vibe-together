## A balance far above the starting one, so a check can prove the taskbar balance is read from
## GameState rather than the placeholder string baked into taskbar.tscn.
extends RefCounted

const RICH_RUBLES := 1_234_567


func apply() -> void:
	# Engine.get_main_loop() rather than the bare GameState identifier: autoloads are undefined
	# under --check-only, and a RefCounted scenario has no get_node() of its own.
	var state: Node = Engine.get_main_loop().root.get_node_or_null("GameState")
	if state == null:
		push_error("rich scenario: GameState autoload is missing")
		return
	# Before the balance changes, not after: GameState persists on an interval now, and a
	# fortune written to user:// would be inherited by every check that boots afterwards.
	# The suite shares one origin, and its storage outlives a page load.
	state.disable_autosave()
	state.set_rubles(RICH_RUBLES)
