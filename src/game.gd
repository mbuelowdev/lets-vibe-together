extends Node2D

## What `screen` reports while the desktop is up. main_menu.gd and settings_screen.gd register
## the same field as "mainMenu" and "settings", so a check can tell which screen is drawn without
## knowing what any of them contains.
const SCREEN_ID := "game"

## One per app the taskbar can select. Home is not one: its icon opens the pause menu instead of a
## screen, so the desktop always shows one of these. Chrome's is the yellow of its logo.
const APP_BACKGROUNDS := {
	"steam": Color("#1b2838"),
	"chrome": Color("#fbbc04"),
	"cs2": Color("#6e3a3a"),
}

const APP_SCREEN_TEXTURES := {
	"cs2": "res://assets/images/screen-base-cs2.png",
}

const SCREEN_NATIVE_WIDTH := 640
const SCREEN_NATIVE_HEIGHT := 360

## Pressing any of these with nothing focused is the player reaching for the UI without a mouse.
const FOCUS_ENTRY_ACTIONS: PackedStringArray = [
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right",
	"ui_accept",
	"ui_focus_next",
	"ui_focus_prev",
]

## Everything _register_bridge_fields() adds, so _exit_tree() can take it all back off again
## without the two lists drifting apart.
const BRIDGE_FIELDS: PackedStringArray = [
	"screen",
	"selectedApp",
	"selectedAppIndex",
	"appSwitchCount",
	"backgroundColor",
	"appIconCount",
	"selectedIconCount",
	"taskbarVisible",
	"hoveredApp",
	"hoverEnterCount",
	"hoveredIconColumn",
	"rubles",
	"savedRubles",
	"savePending",
	"saveFileExists",
	"autosaveEnabled",
	"moneyText",
	"moneyMatchesState",
	"moneySignDrop",
	"clockText",
	"clockMatchesSystemTime",
	"volumeIconColumn",
	"taskbarUtilsVisible",
	"taskbarUtilsClickable",
	"taskbarUtilsOrder",
	"taskbarUtilsRightMargin",
	"screenVisible",
	"screenTexture",
	"screenTextureSize",
	"taskbarAboveScreen",
	"locale",
	"focusedControl",
	"focusedApp",
	"musicTrack",
	"musicMuffled",
]

var _app_switch_count: int = 0
var _background: ColorRect
var _screen: TextureRect
var _cs2_screen: Control
var _taskbar: Control
var _pause_menu: Control
var _screen_textures: Dictionary = {}


func _ready() -> void:
	_background = $UI/Root/Background
	_screen = $UI/Root/Screen
	_cs2_screen = $UI/Root/Cs2Screen
	_taskbar = $UI/Root/Taskbar
	_pause_menu = $PauseLayer/PauseMenu
	_taskbar.app_selected.connect(_on_app_selected)
	_taskbar.home_pressed.connect(_on_home_pressed)
	_pause_menu.settings_closed.connect(_on_pause_settings_closed)
	_apply_app(_taskbar.selected_app_id())
	_play_music()
	_register_bridge_fields()


## The desktop has its own track. Arriving through Start's fade, the menu track is already gone
## and SceneTransition is still covering the screen, so this fades the desktop's song in with
## the picture. A boot that never visited the menu (`--scene res://src/game.tscn`) has no fade
## covering it and starts the track at full level. The pause menu muffles it while it is up.
func _play_music() -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	var fade := 0.0
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and transition.is_busy():
		fade = transition.fade_in_seconds()
	music.play(music.GAME_TRACK, fade)


## Godot routes ui_* navigation through the focused Control and drops it when there is none, so
## from a cold boot the first key or button press does nothing at all and the UI reads as frozen
## to anyone not using the mouse. This spends that press on entering the UI instead, at the lit
## taskbar icon: the taskbar is all the desktop has to focus, and its icons ring left and right on
## their own (taskbar.tscn).
func _unhandled_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action in FOCUS_ENTRY_ACTIONS:
		if not event.is_action_pressed(action):
			continue
		var entry: TextureButton = _taskbar.app_button(_taskbar.selected_index())
		if entry != null:
			entry.grab_focus()
			get_viewport().set_input_as_handled()
		return


func _on_app_selected(app_id: String) -> void:
	_apply_app(app_id)
	_app_switch_count += 1


## Home has no screen: its icon opens the pause menu, and the app the player was on stays selected
## and drawn under the shade.
func _on_home_pressed() -> void:
	_pause_menu.open()


func _apply_app(app_id: String) -> void:
	if APP_BACKGROUNDS.has(app_id):
		_background.color = APP_BACKGROUNDS[app_id]
	_apply_app_screen(app_id)
	# Hidden, not stopped: a match queued on CS2 plays on while another app is up.
	_cs2_screen.visible = app_id == "cs2"


func _apply_app_screen(app_id: String) -> void:
	if not APP_SCREEN_TEXTURES.has(app_id):
		_screen.texture = null
		_screen.visible = false
		return
	var texture := _load_screen_texture(String(APP_SCREEN_TEXTURES[app_id]))
	if texture == null:
		_screen.texture = null
		_screen.visible = false
		return
	_screen.texture = texture
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.texture_filter = TEXTURE_FILTER_NEAREST
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_size := texture.get_size()
	if int(tex_size.x) == SCREEN_NATIVE_WIDTH and int(tex_size.y) == SCREEN_NATIVE_HEIGHT:
		_screen.stretch_mode = TextureRect.STRETCH_KEEP
	else:
		_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.visible = true


func _load_screen_texture(path: String) -> Texture2D:
	if _screen_textures.has(path):
		return _screen_textures[path]
	var texture: Texture2D = load(path)
	if texture == null:
		push_error("main: missing screen texture at %s" % path)
		return null
	_screen_textures[path] = texture
	return texture


## The settings screen was open over the desktop, from the pause menu. On its way out it took
## `screen`, `focusedControl`, `locale`, `rubles` and `saveFileExists` off the bridge - names this
## scene registers too - so they go back. It may also have changed the locale.
func _on_pause_settings_closed() -> void:
	_cs2_screen.refresh_labels()
	_register_bridge_fields()


func _register_bridge_fields() -> void:
	# The egon bot's bridge: there in repo runs and its debug exports, dropped from release builds.
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	bridge.register_field("screen", func() -> String: return SCREEN_ID)
	bridge.register_field("selectedApp", func() -> String: return _taskbar.selected_app_id())
	bridge.register_field("selectedAppIndex", func() -> int: return _taskbar.selected_index())
	bridge.register_field("appSwitchCount", func() -> int: return _app_switch_count)
	bridge.register_field("backgroundColor", func() -> String: return _color_to_hex(_background.color))
	bridge.register_field("appIconCount", func() -> int: return _taskbar.APP_IDS.size())
	bridge.register_field("selectedIconCount", func() -> int: return _taskbar.selected_icon_count())
	bridge.register_field("taskbarVisible", func() -> bool: return _is_taskbar_visible())
	bridge.register_field("hoveredApp", func() -> String: return _taskbar.hovered_app_id())
	bridge.register_field("hoverEnterCount", func() -> int: return _taskbar.hover_enter_count())
	bridge.register_field("hoveredIconColumn", func() -> int: return _taskbar.hovered_icon_column())
	bridge.register_field("rubles", func() -> int: return _game_state_rubles())
	bridge.register_field("savedRubles", func() -> int: return _last_saved_rubles())
	bridge.register_field("savePending", func() -> bool: return _save_pending())
	bridge.register_field("saveFileExists", func() -> bool: return _save_file_exists())
	bridge.register_field("autosaveEnabled", func() -> bool: return _autosave_enabled())
	bridge.register_field("moneyText", func() -> String: return _taskbar.money_text())
	bridge.register_field("moneyMatchesState", func() -> bool: return _taskbar.money_matches_state())
	bridge.register_field("moneySignDrop", func() -> int: return _taskbar.money_sign_drop())
	bridge.register_field("clockText", func() -> String: return _taskbar.clock_text())
	bridge.register_field("clockMatchesSystemTime", func() -> bool: return _taskbar.clock_matches_system_time())
	bridge.register_field("volumeIconColumn", func() -> int: return _taskbar.volume_icon_column())
	bridge.register_field("taskbarUtilsVisible", func() -> int: return _taskbar.utils_visible())
	bridge.register_field("taskbarUtilsClickable", func() -> bool: return _taskbar.utils_clickable())
	bridge.register_field("taskbarUtilsOrder", func() -> Array: return _taskbar.utils_order())
	bridge.register_field("taskbarUtilsRightMargin", func() -> int: return _taskbar.utils_right_margin())
	bridge.register_field("screenVisible", func() -> bool: return _is_screen_visible())
	bridge.register_field("screenTexture", func() -> String: return _screen_texture_path())
	bridge.register_field("screenTextureSize", func() -> String: return _screen_texture_size())
	bridge.register_field("taskbarAboveScreen", func() -> bool: return _is_taskbar_above_screen())
	bridge.register_field("locale", func() -> String: return TranslationServer.get_locale())
	bridge.register_field("focusedControl", func() -> String: return _focused_control_name())
	bridge.register_field("focusedApp", func() -> String: return _taskbar.focused_app_id())
	bridge.register_field("musicTrack", func() -> String: return _music_track())
	bridge.register_field("musicMuffled", func() -> bool: return _music_muffled())


## The Music autoload's own state rather than anything this scene keeps, so a check can tell the
## desktop's song from the menu's and see the pause menu's muffle come and go.
func _music_track() -> String:
	var music := get_node_or_null("/root/Music")
	return "" if music == null else String(music.track_path())


func _music_muffled() -> bool:
	var music := get_node_or_null("/root/Music")
	return false if music == null else bool(music.is_muffled())


## Read straight off the autoload rather than off the taskbar label, so a check can compare
## the two and catch a display that has drifted from the state it is meant to show.
func _game_state_rubles() -> int:
	var state := get_node_or_null("/root/GameState")
	return 0 if state == null else state.rubles()


## The balance as of the last write, against which `rubles` is what is in memory: a check
## that compares the two proves the autosave actually reached the file.
func _last_saved_rubles() -> int:
	var state := get_node_or_null("/root/GameState")
	return -1 if state == null else int(state.last_saved_rubles())


## Lets a check await the coalesced write rather than guess at its timing.
func _save_pending() -> bool:
	var state := get_node_or_null("/root/GameState")
	return false if state == null else bool(state.save_pending())


func _save_file_exists() -> bool:
	var state := get_node_or_null("/root/GameState")
	return false if state == null else bool(state.save_file_exists())


func _autosave_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return false if state == null else bool(state.autosave_enabled())


func _is_screen_visible() -> bool:
	if _screen == null or not is_instance_valid(_screen):
		return false
	return _screen.is_visible_in_tree() and _screen.texture != null


func _screen_texture_path() -> String:
	if _screen == null or not is_instance_valid(_screen) or _screen.texture == null:
		return ""
	return _screen.texture.resource_path


func _screen_texture_size() -> String:
	if _screen == null or not is_instance_valid(_screen) or _screen.texture == null:
		return ""
	if _screen.stretch_mode == TextureRect.STRETCH_KEEP:
		var tex_size := _screen.texture.get_size()
		return "%dx%d" % [int(tex_size.x), int(tex_size.y)]
	var rect_size := _screen.size
	return "%dx%d" % [int(rect_size.x), int(rect_size.y)]


func _is_taskbar_above_screen() -> bool:
	if _screen == null or _taskbar == null:
		return false
	if not is_instance_valid(_screen) or not is_instance_valid(_taskbar):
		return false
	if _screen.get_parent() != _taskbar.get_parent():
		return false
	return _taskbar.get_index() > _screen.get_index()


func _is_taskbar_visible() -> bool:
	if _taskbar == null or not is_instance_valid(_taskbar):
		return false
	if not _taskbar.visible:
		return false
	var base := _taskbar.get_node_or_null("Base") as TextureRect
	return base != null and base.texture != null


func _focused_control_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return "" if focused == null else String(focused.name)


func _color_to_hex(color: Color) -> String:
	return "#%s" % color.to_html(false).to_lower()


## Providers close over nodes this scene is about to free, and Save & Quit takes the player
## off the desktop, so anything left registered would hand every check that runs afterwards a
## taskbar that is not there. `screen` and `focusedControl` are registered by main_menu.gd too:
## SceneTree tears the old scene down and readies the new one inside a single deferred call, so
## the menu re-registers both before the bridge next pushes a snapshot.
func _exit_tree() -> void:
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	for field in BRIDGE_FIELDS:
		bridge.unregister_field(field)
