## The game in French. French is the language whose "Delete local save" - "Supprimer sauvegarde
## locale" - was the first label too wide for its button, so a check can prove that label scrolls
## inside the settings column rather than pushing the button out of it.
##
## Picked through Settings.set_locale(), the same setter the language dropdown calls, then loaded
## again: set_locale() writes the file and puts French into effect but announces nothing, and the
## reload's `loaded` is what tells the menu that is already up to redraw in it.
extends RefCounted

const LOCALE := "fr"


func apply() -> void:
	# Engine.get_main_loop() rather than the bare Settings identifier: autoloads are undefined
	# under --check-only, and a RefCounted scenario has no get_node() of its own.
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("Settings")
	if settings == null:
		push_error("french scenario: Settings autoload is missing")
		return
	settings.set_locale(LOCALE)
	settings.load_settings()
