extends Node
## Player preferences, written to user://settings.cfg as they change and re-applied at boot.
##
## Registered as the `Settings` autoload, ahead of the others, so the main scene can read a
## saved value while it is still building its dropdowns. Autoload identifiers are undefined
## under `--check-only`, so reach it as `get_node("/root/Settings")` from gameplay scripts
## rather than the bare `Settings`.
##
## Values are stored as they mean, never as the dropdown row that displays them. LANGUAGES
## and RESOLUTION_SCALES in main.gd are ordered lists that will gain entries, and a saved
## index would quietly start pointing at a different one. An unset value is "" or 0 and means
## "no preference yet", which leaves main.gd's boot-time fallbacks in charge.
##
## Nothing here knows what a valid locale or scale is: main.gd owns those tables and checks
## what it reads against them, so a hand-edited file cannot walk an index off the end.
##
## Writes happen on every change rather than at "Save & Quit". On the web build the player
## closes the tab and that handler never runs, and three dropdowns moved by hand are nowhere
## near frequent enough for the write to need debouncing.
##
## This is preferences only. Progress (GameState's rubles) is not persisted.

## Emitted when the whole stored set is replaced from disk - load_settings() or clear() -
## so listeners can re-read every value at once. Deliberately not emitted from the setters:
## main.gd applies a change itself before recording it, and a per-setter signal would send
## that straight back to it as a second apply.
signal loaded

const PATH := "user://settings.cfg"
const SECTION := "video"

## Empty means "follow the OS locale". A code we no longer offer is treated the same way.
var _locale := ""

## A multiplier out of main.gd's RESOLUTION_SCALES, not an index into it. 0 means unset.
var _resolution_scale := 0

## A key out of main.gd's WINDOW_MODE_KEYS ("WINDOW_MODE_BORDERLESS"), not a Window.MODE_*
## int: the keys are ours and stable, the enum belongs to the engine. "" means unset.
var _window_mode_key := ""


func _ready() -> void:
	load_settings()


func _notification(what: int) -> void:
	# Redundant on paper - every setter has already written - but a desktop close is the one
	# exit that costs nothing to double-cover.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


## Public so an egon scenario can seed a file and re-run the exact path a cold boot takes;
## the check vocabulary has no page-reload step.
func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(PATH)
	if error != OK:
		# No file on a first run, or one that will not parse. Either way the defaults stand,
		# and the next setter call overwrites the bad file.
		return
	_locale = String(config.get_value(SECTION, "locale", ""))
	_resolution_scale = int(config.get_value(SECTION, "resolution_scale", 0))
	_window_mode_key = String(config.get_value(SECTION, "window_mode", ""))
	loaded.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "locale", _locale)
	config.set_value(SECTION, "resolution_scale", _resolution_scale)
	config.set_value(SECTION, "window_mode", _window_mode_key)
	var error := config.save(PATH)
	if error != OK:
		# A read-only or full user:// is the player's problem to fix, not a reason to take
		# the game down: the session keeps its settings, they just will not outlive it.
		push_warning("Settings: could not write %s (error %d)" % [PATH, error])


## Forget every preference and remove the file. For the egon scenario that has to undo what
## an earlier check persisted - user:// is per-origin and outlives a page load.
func clear() -> void:
	_locale = ""
	_resolution_scale = 0
	_window_mode_key = ""
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	loaded.emit()


## False when user:// will not survive the page being closed: a browser in private mode, or
## one with site data blocked. Nothing branches on it - the game saves either way - but a
## check can assert it, and it explains a setting that will not stick.
func is_persistent() -> bool:
	return OS.is_userfs_persistent()


func file_exists() -> bool:
	return FileAccess.file_exists(PATH)


func locale() -> String:
	return _locale


func set_locale(value: String) -> void:
	if value == _locale:
		return
	_locale = value
	save_settings()


func resolution_scale() -> int:
	return _resolution_scale


func set_resolution_scale(value: int) -> void:
	if value == _resolution_scale:
		return
	_resolution_scale = value
	save_settings()


func window_mode_key() -> String:
	return _window_mode_key


func set_window_mode_key(value: String) -> void:
	if value == _window_mode_key:
		return
	_window_mode_key = value
	save_settings()
