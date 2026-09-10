## A first run: no settings file, every dropdown back on its ambient fallback.
##
## user:// is per-origin on the web build and outlives a page load, so a check that changes a
## setting leaves that setting behind for every check that boots afterwards. Any check in this
## suite that touches the settings dropdowns should either start from this scenario or put the
## value back before it ends.
extends RefCounted


func apply() -> void:
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("Settings")
	if settings == null:
		push_error("no_settings scenario: Settings autoload is missing")
		return
	settings.clear()
