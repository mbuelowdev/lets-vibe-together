extends Node
## Player preferences: the options on offer, what picking one does to the engine, and
## user://settings.cfg, which remembers what the player picked and is re-applied at boot.
##
## Registered as the `Settings` autoload, ahead of the others, so a saved locale and window
## are already in effect when the first scene draws. Autoload identifiers are undefined
## under `--check-only`, so reach it as `get_node("/root/Settings")` from gameplay scripts
## rather than the bare `Settings`.
##
## The option tables live here rather than on the settings screen, because that screen is
## not the only thing that needs them: a saved value has to be checked against the table it
## came from and put into effect at boot, long before anyone opens it. settings_screen.gd is
## a view over this node - it reads the tables to fill its dropdowns and hands every pick
## straight back to a setter here, which puts it into effect and writes it.
##
## Values are stored as they mean, never as the dropdown row that displays them. LANGUAGES
## and RESOLUTION_SCALES are ordered lists that will gain entries, and a saved index would
## quietly start pointing at a different one. An unset value is "" or 0 and means "no
## preference yet", which leaves the engine where it booted: the OS locale, and whatever
## window the project settings opened.
##
## Writes happen on every change rather than at "Save & Quit". On the web build the player
## closes the tab and that handler never runs. Nothing is debounced: the dropdowns change
## once per pick, and a volume drag writes once per notch the slider crosses - a couple of
## dozen small writes for a full sweep, which is not worth a debounce that could lose the last
## one to a closed tab.
##
## This is preferences only. Progress (GameState's rubles) is not persisted.
##
## Also binds the UI font fallback chain in `_init()` so it is in place before any Control
## shapes text. That has to live here because this autoload is the first node that runs.

## Emitted when the whole stored set is replaced from disk - load_settings() or clear() -
## so listeners can re-read every value at once. Deliberately not emitted from the setters:
## the settings screen is their only caller and redraws itself after every pick, and a
## per-setter signal would send that straight back to it as a second redraw.
signal loaded

const PATH := "user://settings.cfg"
const SECTION := "video"
const AUDIO_SECTION := "audio"

## Bus 0 is always the master bus: the engine will not remove it or move another in front.
const MASTER_BUS := 0

## Whole percent, which is what the slider shows. The engine boots the master bus at 100, but
## a first run (and a file with no [audio] section) uses MASTER_VOLUME_DEFAULT, so unlike the
## video values a missing preference still has to be applied. 0 is a real choice - muted -
## not "unset".
const MASTER_VOLUME_MAX := 100
const MASTER_VOLUME_DEFAULT := 25

## Offered languages as [locale, name written in that language], ordered by player share.
## The locale drives TranslationServer; its language subtag doubles as the text server tag
## that picks a font out of res://resources/ui-font.tres.
const LANGUAGES: Array[Array] = [
	["en", "English"],
	["zh_Hans", "简体中文"],
	["ru", "Русский"],
	["es", "Español"],
	["pt", "Português"],
	["de", "Deutsch"],
	["ja", "日本語"],
	["fr", "Français"],
	["pl", "Polski"],
	["ko", "한국어"],
	["zh_Hant", "繁體中文"],
	["tr", "Türkçe"],
	["uk", "Українська"],
	["it", "Italiano"],
	["cs", "Čeština"],
	["hu", "Magyar"],
	["vi", "Tiếng Việt"],
	["sv", "Svenska"],
	["nl", "Nederlands"],
	["da", "Dansk"],
	["id", "Bahasa Indonesia"],
	["fi", "Suomi"],
	["nb", "Norsk"],
	["ro", "Română"],
	["el", "Ελληνικά"],
	["bg", "Български"],
]

## The canvas every offered resolution is a whole multiple of: project.godot's viewport size.
const BASE_RESOLUTION := Vector2i(640, 360)

## Every offered resolution is the base multiplied by a whole number, so the project's
## canvas_items/integer stretch upscales the art by exact pixels with no letterbox:
## 640x360, 1280x720, 1920x1080, 2560x1440, 3840x2160, 7680x4320.
const RESOLUTION_SCALES: PackedInt32Array = [1, 2, 3, 4, 6, 12]

## Window modes in dropdown order. Keys look up locale/ui.csv. Godot's MODE_FULLSCREEN
## is already the borderless "fullscreen window"; MODE_EXCLUSIVE_FULLSCREEN is exclusive.
const WINDOW_MODE_KEYS: PackedStringArray = [
	"WINDOW_MODE_WINDOWED",
	"WINDOW_MODE_BORDERLESS",
	"WINDOW_MODE_FULLSCREEN",
]
const WINDOW_MODE_VALUES: PackedInt32Array = [
	Window.MODE_WINDOWED,
	Window.MODE_FULLSCREEN,
	Window.MODE_EXCLUSIVE_FULLSCREEN,
]

## Empty means "follow the OS locale". A code we no longer offer is treated the same way.
var _locale := ""

## A multiplier out of RESOLUTION_SCALES, not an index into it. 0 means unset.
var _resolution_scale := 0

## A key out of WINDOW_MODE_KEYS ("WINDOW_MODE_BORDERLESS"), not a Window.MODE_* int: the
## keys are ours and stable, the enum belongs to the engine. "" means unset.
var _window_mode_key := ""

## 0 to MASTER_VOLUME_MAX. 0 is a real choice - muted - not "unset".
var _master_volume := MASTER_VOLUME_DEFAULT


func _init() -> void:
	_bind_ui_font_fallbacks()


func _ready() -> void:
	load_settings()


## Web has no system fonts. Pixelify Sans only covers Latin/Cyrillic/Greek, so CJK and the
## ruble sign have to come from the faces listed on ui-font.tres. Those fallbacks are copied
## onto the base FontFile as well: HTML5's text server walks FontFile.fallbacks, and the
## typed Font array on FontVariation has been seen empty after a packed web load.
func _bind_ui_font_fallbacks() -> void:
	var variation := load("res://resources/ui-font.tres") as FontVariation
	if variation == null:
		return
	var chain: Array[Font] = [
		load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf") as Font,
		load("res://assets/fonts/fusion-pixel-12px-proportional-ja.ttf") as Font,
		load("res://assets/fonts/Galmuri11.ttf") as Font,
	]
	for font in chain:
		if font == null:
			push_warning("Settings: UI font fallback failed to load")
			return
	variation.fallbacks = chain
	if variation.base_font != null:
		variation.base_font.fallbacks = chain


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
		# and the next setter call overwrites the bad file. Volume is the one default that
		# is not the engine's boot state, so it still has to be applied.
		_apply_master_volume(_master_volume)
		return
	_locale = String(config.get_value(SECTION, "locale", ""))
	_resolution_scale = int(config.get_value(SECTION, "resolution_scale", 0))
	_window_mode_key = String(config.get_value(SECTION, "window_mode", ""))
	# A file from before the slider existed has no [audio] section and boots at the default.
	_master_volume = _clamp_master_volume(config.get_value(AUDIO_SECTION, "master_volume", MASTER_VOLUME_DEFAULT))
	_apply_saved()
	loaded.emit()


## Put what the file says into effect. On a cold boot this runs before the first scene
## exists, which is why no screen applies a saved value itself - they only draw in whatever
## is already in effect.
##
## Only values that are set and still offered: anything else is a hand-edit or an option we
## have dropped, and the engine's own boot state is a better guess than trusting it.
##
## Mode before size: _apply_resolution_scale() refuses to touch a window that is not
## windowed, so a saved 1280x720 only lands once the mode has been put back.
##
## On the web build the window half is close to a no-op: the canvas already tracks the
## browser window (html/canvas_resize_policy=2), and a browser will not grant fullscreen
## without a user gesture, so a saved fullscreen boots windowed until the player picks it
## again.
func _apply_saved() -> void:
	if _is_offered_locale(_locale):
		TranslationServer.set_locale(_locale)
	var mode_index := WINDOW_MODE_KEYS.find(_window_mode_key)
	if mode_index >= 0:
		_apply_window_mode(mode_index)
	_apply_resolution_scale(_resolution_scale)
	_apply_master_volume(_master_volume)


func _is_offered_locale(value: String) -> bool:
	for language in LANGUAGES:
		if String(language[0]) == value:
			return true
	return false


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "locale", _locale)
	config.set_value(SECTION, "resolution_scale", _resolution_scale)
	config.set_value(SECTION, "window_mode", _window_mode_key)
	config.set_value(AUDIO_SECTION, "master_volume", _master_volume)
	var error := config.save(PATH)
	if error != OK:
		# A read-only or full user:// is the player's problem to fix, not a reason to take
		# the game down: the session keeps its settings, they just will not outlive it.
		push_warning("Settings: could not write %s (error %d)" % [PATH, error])


## Forget every preference and remove the file. For the egon scenario that has to undo what
## an earlier check persisted - user:// is per-origin and outlives a page load.
##
## The locale and the master volume go back to where a first run has them too, because
## load_settings() already applied whatever the old file said. The window is left where it is.
func clear() -> void:
	_locale = ""
	_resolution_scale = 0
	_window_mode_key = ""
	_master_volume = MASTER_VOLUME_DEFAULT
	TranslationServer.set_locale(OS.get_locale())
	_apply_master_volume(_master_volume)
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


## Puts the locale into effect as well as recording it, so nothing can store a language the
## game is not showing.
func set_locale(value: String) -> void:
	TranslationServer.set_locale(value)
	if value == _locale:
		return
	_locale = value
	save_settings()


func resolution_scale() -> int:
	return _resolution_scale


## Applied even when the value is unchanged. The window can drift from what is stored -
## dragged to a new size, or taken out of fullscreen by the window manager - and picking the
## stored value again is how the player puts it back.
func set_resolution_scale(value: int) -> void:
	_apply_resolution_scale(value)
	if value == _resolution_scale:
		return
	_resolution_scale = value
	save_settings()


func window_mode_key() -> String:
	return _window_mode_key


## Same terms as set_resolution_scale(). Going back to Windowed also brings back the stored
## resolution, which may have been picked while fullscreen and never shown.
func set_window_mode_key(value: String) -> void:
	var index := WINDOW_MODE_KEYS.find(value)
	if index >= 0:
		_apply_window_mode(index)
		_apply_resolution_scale(_resolution_scale)
	if value == _window_mode_key:
		return
	_window_mode_key = value
	save_settings()


func master_volume() -> int:
	return _master_volume


## Heard at once and written at once, like every other setter, so the slider is live while it
## is being dragged and the last position survives a closed tab.
func set_master_volume(value: int) -> void:
	value = _clamp_master_volume(value)
	_apply_master_volume(value)
	if value == _master_volume:
		return
	_master_volume = value
	save_settings()


## What the master bus is actually playing at, in the same whole percent, so a check can prove
## the slider reached the engine and not only the file.
func master_bus_volume() -> int:
	return roundi(AudioServer.get_bus_volume_linear(MASTER_BUS) * MASTER_VOLUME_MAX)


func _clamp_master_volume(value: Variant) -> int:
	return clampi(int(value), 0, MASTER_VOLUME_MAX)


## 0 is -inf dB, which the bus plays as silence.
func _apply_master_volume(percent: int) -> void:
	AudioServer.set_bus_volume_linear(MASTER_BUS, float(percent) / MASTER_VOLUME_MAX)


## A fullscreen window owns its own size, so a scale picked there is only recorded; it takes
## effect when the mode goes back to Windowed. 0 and scales we no longer offer mean "no
## preference" and leave the window alone.
func _apply_resolution_scale(scale: int) -> void:
	if not RESOLUTION_SCALES.has(scale):
		return
	var window := get_window()
	if window == null or window.mode != Window.MODE_WINDOWED:
		return
	window.size = BASE_RESOLUTION * scale
	_center_window(window)


func _apply_window_mode(index: int) -> void:
	var window := get_window()
	if window == null:
		return
	window.mode = WINDOW_MODE_VALUES[index]


## Keep the window reachable after a resize: the largest sizes can exceed the display, so
## never push its top-left outside the usable area.
func _center_window(window: Window) -> void:
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var offset := (usable.size - window.size) / 2
	window.position = usable.position + Vector2i(maxi(offset.x, 0), maxi(offset.y, 0))
