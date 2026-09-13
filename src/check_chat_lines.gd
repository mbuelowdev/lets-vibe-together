extends SceneTree
## Checks every chat line in locale/chat.csv exists and fits the chat window's two-line labels.
##   godot --headless --path . --script res://src/check_chat_lines.gd

const ChatWindow := preload("res://src/gaming_community_chat_window.gd")
const MAX_LINES := 2


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	TranslationServer.set_locale("en")
	var window := (load("res://src/gaming_community_chat_window.tscn") as PackedScene).instantiate()
	window.profile = {"avatar": Vector2i.ZERO}
	root.add_child(window)
	var label := window.get_node("Log/TargetLine/Content/Text") as Label
	var failures := 0
	for key in ChatWindow.line_keys():
		var text := TranslationServer.translate(key)
		if text == key:
			print("MISSING  %s" % key)
			failures += 1
			continue
		label.text = text
		if label.get_line_count() > MAX_LINES:
			print("TOO LONG %s (%d lines): %s" % [key, label.get_line_count(), text])
			failures += 1
	print("%d chat lines, %d problems" % [ChatWindow.line_keys().size(), failures])
	quit(1 if failures > 0 else 0)
