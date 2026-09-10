extends Node2D

## What `screen` reports while the desktop is up. main_menu.gd and settings_screen.gd register
## the same field as "mainMenu" and "settings", so a check can tell which screen is drawn without
## knowing what any of them contains.
const SCREEN_ID := "game"

const APP_BACKGROUNDS := {
	"home": Color("#2e4272"),
	"steam": Color("#1b2838"),
	"chrome": Color("#3f6b3a"),
	"cs2": Color("#6e3a3a"),
}

const APP_SCREEN_TEXTURES := {
	"cs2": "res://assets/images/screen-base-cs2.png",
}

const SCREEN_NATIVE_WIDTH := 640
const SCREEN_NATIVE_HEIGHT := 360

const SAVE_QUIT_KEY := "SAVE_QUIT"

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

var _app_switch_count: int = 0
var _background: ColorRect
var _screen: TextureRect
var _taskbar: Control
var _save_quit_button: Button
var _settings: Node
var _screen_textures: Dictionary = {}


func _ready() -> void:
	_background = $UI/Root/Background
	_screen = $UI/Root/Screen
	_taskbar = $UI/Root/Taskbar
	_save_quit_button = $UI/Root/SaveQuitButton
	_background.color = APP_BACKGROUNDS["home"]
	_taskbar.app_selected.connect(_on_app_selected)
	_save_quit_button.pressed.connect(_on_save_quit_pressed)
	_settings = get_node_or_null("/root/Settings")
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	_refresh_labels()
	_apply_app_screen(_taskbar.selected_app_id())
	_apply_home_controls(_taskbar.selected_app_id())
	_wire_focus_navigation()
	_stop_music()
	_register_bridge_fields()


## The desktop is past the front end, so the menu track has to go. The menu already stops it on
## Start; this covers a boot that never visited the menu (`--scene res://src/game.tscn`).
func _stop_music() -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	music.stop()


## Godot's geometric neighbour search only walks Control parents and gives up at the first node
## that has none, so Save & Quit and the taskbar - separate branches under UI/Root - could never
## reach each other by arrow key or d-pad. Wiring them by hand also survives the button being
## hidden: find_valid_focus_neighbor follows the chain past any control that is not visible.
func _wire_focus_navigation() -> void:
	for i in _taskbar.app_button_count():
		var button: TextureButton = _taskbar.app_button(i)
		button.focus_neighbor_top = button.get_path_to(_save_quit_button)
		button.focus_neighbor_bottom = button.get_path_to(_save_quit_button)
	_update_taskbar_focus_links()


## Up and down off Save & Quit both lead to whichever taskbar icon is lit, so leaving the taskbar
## upwards and wrapping into it downwards always pass through the same icon.
func _update_taskbar_focus_links() -> void:
	var entry: TextureButton = _taskbar.app_button(_taskbar.selected_index())
	if entry == null:
		return
	_save_quit_button.focus_neighbor_top = _save_quit_button.get_path_to(entry)
	_save_quit_button.focus_neighbor_bottom = _save_quit_button.get_path_to(entry)


## Godot routes ui_* navigation through the focused Control and drops it when there is none, so
## from a cold boot the first key or button press does nothing at all and the UI reads as frozen
## to anyone not using the mouse. This spends that press on entering the UI instead.
func _unhandled_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action in FOCUS_ENTRY_ACTIONS:
		if not event.is_action_pressed(action):
			continue
		var control := _focus_entry_control()
		if control != null:
			control.grab_focus()
			get_viewport().set_input_as_handled()
		return


## Where that first press lands: Save & Quit on the home screen, and the lit taskbar icon on
## every other app, where the button is hidden.
func _focus_entry_control() -> Control:
	if _save_quit_button.is_visible_in_tree():
		return _save_quit_button
	return _taskbar.app_button(_taskbar.selected_index())


func _on_app_selected(app_id: String) -> void:
	if APP_BACKGROUNDS.has(app_id):
		_background.color = APP_BACKGROUNDS[app_id]
	_apply_app_screen(app_id)
	_apply_home_controls(app_id)
	_update_taskbar_focus_links()
	_app_switch_count += 1


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


## Save & Quit belongs to the home screen; other apps draw their own full-canvas art. Language,
## resolution, window mode and Delete local save are not here any more - they moved to
## settings_screen.tscn, which the main menu opens.
func _apply_home_controls(app_id: String) -> void:
	_save_quit_button.visible = app_id == "home"


## Settings replaced wholesale from disk, which can carry a different locale. Settings has
## already put it into effect by the time this fires, so all that is left is to redraw in it.
## Only an egon scenario does this at runtime; a real player's file is read once, in the
## autoload's _ready(), before this scene exists.
func _on_settings_loaded() -> void:
	_refresh_labels()


## Every label Home draws, in the locale in effect. This screen never sets a locale itself: the
## Settings autoload applies the saved one at boot and the settings screen applies a new one,
## both before this scene exists. The font tag has to be set on each control rather than
## inherited - it is what sends Japanese to the ja face and Korean to Galmuri.
func _refresh_labels() -> void:
	var font_language := TranslationServer.get_locale().get_slice("_", 0)
	_save_quit_button.language = font_language
	_save_quit_button.text = tr(SAVE_QUIT_KEY)


## Both halves the label promises. Neither flush is the only thing standing between the
## player and data loss - settings write as they change, progress autosaves on an interval -
## because closing a browser tab never reaches this handler. Saving here is what makes the
## button honest for the player who does use it.
## On the web export quit stops the main loop rather than closing the tab.
func _on_save_quit_pressed() -> void:
	if _settings != null:
		_settings.save_settings()
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.save_game()
	get_tree().quit()


func _register_bridge_fields() -> void:
	var bridge := get_node("/root/EgonBridge")
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
	bridge.register_field("saveQuitButtonVisible", func() -> bool: return _is_save_quit_button_visible())
	bridge.register_field("focusedControl", func() -> String: return _focused_control_name())
	bridge.register_field("focusedApp", func() -> String: return _taskbar.focused_app_id())


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


func _is_save_quit_button_visible() -> bool:
	if _save_quit_button == null or not is_instance_valid(_save_quit_button):
		return false
	return _save_quit_button.is_visible_in_tree()


func _focused_control_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return "" if focused == null else String(focused.name)


func _color_to_hex(color: Color) -> String:
	return "#%s" % color.to_html(false).to_lower()
