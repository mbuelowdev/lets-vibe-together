extends Node2D

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
const BASE_RESOLUTION := Vector2i(SCREEN_NATIVE_WIDTH, SCREEN_NATIVE_HEIGHT)

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
const SAVE_QUIT_KEY := "SAVE_QUIT"
const DELETE_SAVE_KEY := "DELETE_SAVE"
const DELETE_SAVE_CONFIRM_KEY := "DELETE_SAVE_CONFIRM"
const DELETE_SAVE_YES_KEY := "DELETE_SAVE_YES"
const DELETE_SAVE_CANCEL_KEY := "DELETE_SAVE_CANCEL"

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

var _app_switch_count: int = 0
var _background: ColorRect
var _screen: TextureRect
var _taskbar: Control
var _language_select: OptionButton
var _resolution_select: OptionButton
var _window_mode_select: OptionButton
var _delete_save_button: Button
var _save_quit_button: Button
var _confirm_delete: Control
var _confirm_message: Label
var _confirm_yes_button: Button
var _confirm_cancel_button: Button
var _settings: Node
var _screen_textures: Dictionary = {}


func _ready() -> void:
	_background = $UI/Root/Background
	_screen = $UI/Root/Screen
	_taskbar = $UI/Root/Taskbar
	_language_select = $UI/Root/LanguageSelect
	_resolution_select = $UI/Root/ResolutionSelect
	_window_mode_select = $UI/Root/WindowModeSelect
	_delete_save_button = $UI/Root/DeleteSaveButton
	_save_quit_button = $UI/Root/SaveQuitButton
	_confirm_delete = $UI/Root/ConfirmDelete
	_confirm_message = $UI/Root/ConfirmDelete/Panel/Message
	_confirm_yes_button = $UI/Root/ConfirmDelete/Panel/ConfirmYesButton
	_confirm_cancel_button = $UI/Root/ConfirmDelete/Panel/ConfirmCancelButton
	_background.color = APP_BACKGROUNDS["home"]
	_taskbar.app_selected.connect(_on_app_selected)
	_language_select.item_selected.connect(_on_language_selected)
	_resolution_select.item_selected.connect(_on_resolution_selected)
	_window_mode_select.item_selected.connect(_on_window_mode_selected)
	_delete_save_button.pressed.connect(_on_delete_save_pressed)
	_save_quit_button.pressed.connect(_on_save_quit_pressed)
	_confirm_yes_button.pressed.connect(_on_confirm_delete_pressed)
	_confirm_cancel_button.pressed.connect(_on_cancel_delete_pressed)
	_settings = get_node_or_null("/root/Settings")
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	_refresh_settings_controls()
	_apply_boot_window_state()
	_apply_app_screen(_taskbar.selected_app_id())
	_apply_home_controls(_taskbar.selected_app_id())
	_wire_focus_navigation()
	_register_bridge_fields()


## Godot's geometric neighbour search only walks Control parents and gives up at the first node
## that has none, so the settings stack and the taskbar - separate branches under UI/Root - could
## never reach each other by arrow key or d-pad. Wiring the column by hand also survives the stack
## being hidden: find_valid_focus_neighbor follows the chain past any control that is not visible.
func _wire_focus_navigation() -> void:
	var column: Array[Control] = [
		_language_select,
		_resolution_select,
		_window_mode_select,
		_delete_save_button,
		_save_quit_button,
	]
	for i in column.size():
		if i > 0:
			column[i].focus_neighbor_top = column[i].get_path_to(column[i - 1])
		if i + 1 < column.size():
			column[i].focus_neighbor_bottom = column[i].get_path_to(column[i + 1])
	for i in _taskbar.app_button_count():
		var button: TextureButton = _taskbar.app_button(i)
		button.focus_neighbor_top = button.get_path_to(_save_quit_button)
		button.focus_neighbor_bottom = button.get_path_to(_language_select)
	_wire_dialog_focus()
	_update_taskbar_focus_links()


## The dialog is modal, so focus has to stay inside it: every direction and both tab
## directions lead to the other button. Left unwired, an arrow key walks the geometric
## search straight out through the shade into the settings column the player can neither
## see nor click, and the focus ring disappears behind the panel.
func _wire_dialog_focus() -> void:
	_link_dialog_buttons(_confirm_yes_button, _confirm_cancel_button)
	_link_dialog_buttons(_confirm_cancel_button, _confirm_yes_button)


func _link_dialog_buttons(from: Control, to: Control) -> void:
	var path := from.get_path_to(to)
	from.focus_neighbor_left = path
	from.focus_neighbor_right = path
	from.focus_neighbor_top = path
	from.focus_neighbor_bottom = path
	from.focus_next = path
	from.focus_previous = path


## The column's two open ends both lead to whichever taskbar icon is lit, so leaving the taskbar
## upwards and wrapping into it downwards always pass through the same icon.
func _update_taskbar_focus_links() -> void:
	var entry: TextureButton = _taskbar.app_button(_taskbar.selected_index())
	if entry == null:
		return
	_language_select.focus_neighbor_top = _language_select.get_path_to(entry)
	_save_quit_button.focus_neighbor_bottom = _save_quit_button.get_path_to(entry)


## Godot routes ui_* navigation through the focused Control and drops it when there is none, so
## from a cold boot the first key or button press does nothing at all and the UI reads as frozen
## to anyone not using the mouse. This spends that press on entering the UI instead.
func _unhandled_input(event: InputEvent) -> void:
	# While the question is up it owns every press the GUI did not take. Buttons consume
	# ui_accept themselves, so what reaches here is the escape hatch and the keys that would
	# otherwise re-enter a UI the player is not looking at.
	if _confirm_delete.visible:
		if event.is_action_pressed("ui_cancel"):
			_hide_confirm_delete()
			get_viewport().set_input_as_handled()
		return
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


## Where that first press lands: the top of the settings stack on the home screen, and the lit
## taskbar icon on every other app, where the stack is hidden.
func _focus_entry_control() -> Control:
	if _language_select.is_visible_in_tree():
		return _language_select
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


## The dropdowns belong to the home screen; other apps draw their own full-canvas art.
func _apply_home_controls(app_id: String) -> void:
	var on_home := app_id == "home"
	_language_select.visible = on_home
	_resolution_select.visible = on_home
	_window_mode_select.visible = on_home
	_delete_save_button.visible = on_home
	_save_quit_button.visible = on_home
	if not on_home:
		# The modal blocks the taskbar, so no player reaches this line with the dialog open -
		# but a scenario or a future caller can switch apps directly, and a question left
		# hanging over the CS2 screen would be asking about a button that is no longer there.
		_hide_confirm_delete()


## Rebuild all three dropdowns from the saved settings. Split out of _ready() because the
## egon scenario that seeds a settings file needs to re-run exactly this, and because the
## three have to be repopulated together: _apply_language() rewrites the window-mode labels.
func _refresh_settings_controls() -> void:
	_populate_languages()
	_populate_resolutions()
	_populate_window_modes()
	_apply_language(_language_select.selected)


## Settings replaced wholesale from disk. Only an egon scenario does this at runtime; a real
## player's file is read once, in the autoload's _ready(), before this scene exists.
func _on_settings_loaded() -> void:
	_refresh_settings_controls()
	_apply_boot_window_state()


## Mode before size: _apply_resolution() refuses to touch a window that is not windowed, so a
## saved 1280x720 only lands once the mode has been put back.
##
## With nothing saved this does nothing at all, rather than applying what the dropdowns picked
## off the live window - a first run would otherwise resize and re-centre itself for no reason.
##
## On the web build both are close to no-ops: the canvas already tracks the browser window
## (html/canvas_resize_policy=2), and a browser will not grant fullscreen without a user
## gesture, so a saved fullscreen boots windowed until the player picks it again.
func _apply_boot_window_state() -> void:
	if _saved_window_mode_key().is_empty() and _saved_resolution_scale() <= 0:
		return
	_apply_window_mode(_window_mode_select.selected)


func _saved_locale() -> String:
	return "" if _settings == null else String(_settings.locale())


func _saved_resolution_scale() -> int:
	return 0 if _settings == null else int(_settings.resolution_scale())


func _saved_window_mode_key() -> String:
	return "" if _settings == null else String(_settings.window_mode_key())


## An OptionButton popup is its own Window, so it inherits neither the button's font size
## override nor the root viewport's nearest-neighbour filter. Without the filter the popup
## samples the pixel font through a linear one, which only shows up once the window is
## scaled past 640x360: every glyph picks up grey fringes and the list looks washed out.
func _style_popup(select: OptionButton) -> PopupMenu:
	var popup := select.get_popup()
	popup.theme = select.theme
	popup.add_theme_font_size_override("font_size", 12)
	popup.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	return popup


func _populate_languages() -> void:
	_language_select.clear()
	var popup := _style_popup(_language_select)
	for i in LANGUAGES.size():
		_language_select.add_item(_language_name(i), i)
		popup.set_item_language(i, _font_language(i))
	_language_select.select(_boot_language_index())
	_apply_language(_language_select.selected)


func _language_locale(index: int) -> String:
	return String(LANGUAGES[index][0])


func _language_name(index: int) -> String:
	return String(LANGUAGES[index][1])


## Text server language tag. The two fusion-pixel faces cover the same codepoints and
## Galmuri covers Korean on top of both, so without a tag the first font in the chain that
## has the glyph wins: the tag is what sends Japanese to the ja face and Korean to Galmuri.
func _font_language(index: int) -> String:
	return _language_locale(index).get_slice("_", 0)


## The OS locale picks the boot selection. compare_locales scores a full locale against our
## shorter codes (zh_CN against zh_Hans, de_DE against de) and returns 0 when nothing about
## them matches, so a language we do not offer lands on English.
func _index_for_locale(locale: String) -> int:
	var best := 0
	var best_score := 0
	for i in LANGUAGES.size():
		var score := TranslationServer.compare_locales(locale, _language_locale(i))
		if score > best_score:
			best_score = score
			best = i
	return best


## The saved locale first, the OS locale only on a first run. Matched exactly rather than
## through _index_for_locale(): we only ever write codes from LANGUAGES, so anything else is
## a hand-edit or a language we have dropped, and the OS is a better guess than the English
## that the fuzzy match returns for everything it does not recognise.
func _boot_language_index() -> int:
	var saved := _saved_locale()
	if not saved.is_empty():
		for i in LANGUAGES.size():
			if _language_locale(i) == saved:
				return i
	return _index_for_locale(TranslationServer.get_locale())


func _on_language_selected(index: int) -> void:
	_apply_language(index)
	_store_language(index)


func _store_language(index: int) -> void:
	if _settings == null or index < 0 or index >= LANGUAGES.size():
		return
	_settings.set_locale(_language_locale(index))


## The locale drives translations. OptionButton captions and popups are their own
## windows, so the font tag has to be set on each control rather than inherited.
func _apply_language(index: int) -> void:
	if index < 0 or index >= LANGUAGES.size():
		return
	TranslationServer.set_locale(_language_locale(index))
	var font_language := _font_language(index)
	_language_select.language = font_language
	_resolution_select.language = font_language
	_window_mode_select.language = font_language
	_save_quit_button.language = font_language
	_delete_save_button.language = font_language
	_confirm_message.language = font_language
	_confirm_yes_button.language = font_language
	_confirm_cancel_button.language = font_language
	_set_popup_item_language(_resolution_select, font_language)
	_set_popup_item_language(_window_mode_select, font_language)
	_refresh_window_mode_labels()
	_save_quit_button.text = tr(SAVE_QUIT_KEY)
	_delete_save_button.text = tr(DELETE_SAVE_KEY)
	_confirm_message.text = tr(DELETE_SAVE_CONFIRM_KEY)
	_confirm_yes_button.text = tr(DELETE_SAVE_YES_KEY)
	_confirm_cancel_button.text = tr(DELETE_SAVE_CANCEL_KEY)


## PopupMenu is a Window, not a Control, so it has no language property. The tag lives
## on each item and picks the CJK/Korean face the same way the language list does.
func _set_popup_item_language(select: OptionButton, font_language: String) -> void:
	var popup := select.get_popup()
	for i in popup.item_count:
		popup.set_item_language(i, font_language)


func _populate_resolutions() -> void:
	_resolution_select.clear()
	_style_popup(_resolution_select)
	for i in RESOLUTION_SCALES.size():
		var resolution := _resolution_for_index(i)
		_resolution_select.add_item("%dx%d" % [resolution.x, resolution.y], i)
	_resolution_select.select(_boot_resolution_index())


func _resolution_for_index(index: int) -> Vector2i:
	return BASE_RESOLUTION * RESOLUTION_SCALES[index]


## Exact match on the current window, otherwise the largest listed resolution that still
## fits inside it, so the dropdown never boots showing a size the window is not at.
func _index_for_window_size(window_size: Vector2i) -> int:
	var best := 0
	for i in RESOLUTION_SCALES.size():
		var resolution := _resolution_for_index(i)
		if resolution == window_size:
			return i
		if resolution.x <= window_size.x and resolution.y <= window_size.y:
			best = i
	return best


## The saved scale is the multiplier, not the row: RESOLUTION_SCALES will gain entries, and a
## stored row index would start meaning a different size the moment it does.
func _boot_resolution_index() -> int:
	var saved := _saved_resolution_scale()
	if saved > 0:
		var index := RESOLUTION_SCALES.find(saved)
		if index >= 0:
			return index
	return _index_for_window_size(DisplayServer.window_get_size())


func _on_resolution_selected(index: int) -> void:
	_apply_resolution(index)
	_store_resolution(index)


func _store_resolution(index: int) -> void:
	if _settings == null or index < 0 or index >= RESOLUTION_SCALES.size():
		return
	_settings.set_resolution_scale(RESOLUTION_SCALES[index])


## A fullscreen window owns its own size, so the pick is only recorded there; it takes
## effect when the mode dropdown goes back to Windowed.
func _apply_resolution(index: int) -> void:
	if index < 0 or index >= RESOLUTION_SCALES.size():
		return
	var window := get_window()
	if window == null or window.mode != Window.MODE_WINDOWED:
		return
	window.size = _resolution_for_index(index)
	_center_window(window)


func _populate_window_modes() -> void:
	_window_mode_select.clear()
	_style_popup(_window_mode_select)
	for i in WINDOW_MODE_KEYS.size():
		_window_mode_select.add_item(tr(WINDOW_MODE_KEYS[i]), i)
	_window_mode_select.select(_boot_window_mode_index())


## add_item copies the string at call time, so a locale change has to rewrite the items.
func _refresh_window_mode_labels() -> void:
	var count := mini(_window_mode_select.item_count, WINDOW_MODE_KEYS.size())
	for i in count:
		_window_mode_select.set_item_text(i, tr(WINDOW_MODE_KEYS[i]))


func _index_for_window_mode(mode: int) -> int:
	var index := WINDOW_MODE_VALUES.find(mode)
	return 0 if index < 0 else index


## The saved key is one of ours, not a Window.MODE_* int, so the engine renumbering its enum
## cannot turn a saved "windowed" into something else. Falls back to the live window.
func _boot_window_mode_index() -> int:
	var saved := _saved_window_mode_key()
	if not saved.is_empty():
		var index := WINDOW_MODE_KEYS.find(saved)
		if index >= 0:
			return index
	var window := get_window()
	return 0 if window == null else _index_for_window_mode(window.mode)


func _on_window_mode_selected(index: int) -> void:
	_apply_window_mode(index)
	_store_window_mode(index)


func _apply_window_mode(index: int) -> void:
	if index < 0 or index >= WINDOW_MODE_VALUES.size():
		return
	var window := get_window()
	if window == null:
		return
	window.mode = WINDOW_MODE_VALUES[index]
	if window.mode == Window.MODE_WINDOWED:
		_apply_resolution(_resolution_select.selected)


func _store_window_mode(index: int) -> void:
	if _settings == null or index < 0 or index >= WINDOW_MODE_KEYS.size():
		return
	_settings.set_window_mode_key(WINDOW_MODE_KEYS[index])


## Keep the window reachable after a resize: the largest sizes can exceed the display, so
## never push its top-left outside the usable area.
func _center_window(window: Window) -> void:
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var offset := (usable.size - window.size) / 2
	window.position = usable.position + Vector2i(maxi(offset.x, 0), maxi(offset.y, 0))


## Wiping a save is the only thing on this screen the player cannot undo, so it asks first.
##
## The question is a Control inside the main canvas rather than a ConfirmationDialog. That is
## a Window, and a second window is not covered by the project's integer stretch: it would
## draw crisp 1:1 chrome and 12px text over a game upscaled 2x or 4x, and on the web export
## it is a DOM overlay outside the canvas entirely.
func _on_delete_save_pressed() -> void:
	_confirm_delete.visible = true
	# Cancel, not Yes. The key that opened the dialog is the same key that activates whatever
	# holds focus, so the destructive option must never be the one sitting under it.
	_confirm_cancel_button.grab_focus()


## clear_save() does both halves in one call - removes the file and puts the balance back to
## STARTING_RUBLES - and leaves the state clean, so the next autosave tick has nothing to
## flush and the file stays gone.
func _on_confirm_delete_pressed() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.clear_save()
	_hide_confirm_delete()


func _on_cancel_delete_pressed() -> void:
	_hide_confirm_delete()


## Focus lands back on the button that opened the dialog rather than nowhere: Godot releases
## focus when the focused control is hidden, and a player who got here by keyboard would
## otherwise have to spend a press re-entering the UI from cold.
func _hide_confirm_delete() -> void:
	_confirm_delete.visible = false
	if _delete_save_button.is_visible_in_tree():
		_delete_save_button.grab_focus()


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
	bridge.register_field("languageSelectVisible", func() -> bool: return _is_language_select_visible())
	bridge.register_field("languageOptions", func() -> Array: return _item_texts(_language_select))
	bridge.register_field("selectedLanguage", func() -> String: return _selected_text(_language_select))
	bridge.register_field("locale", func() -> String: return TranslationServer.get_locale())
	bridge.register_field("resolutionSelectVisible", func() -> bool: return _is_resolution_select_visible())
	bridge.register_field("resolutionOptions", func() -> Array: return _item_texts(_resolution_select))
	bridge.register_field("selectedResolution", func() -> String: return _selected_text(_resolution_select))
	bridge.register_field("windowSize", func() -> String: return _window_size())
	bridge.register_field("contentScale", func() -> int: return _content_scale())
	bridge.register_field("windowModeSelectVisible", func() -> bool: return _is_window_mode_select_visible())
	bridge.register_field("windowModeOptions", func() -> Array: return _item_texts(_window_mode_select))
	bridge.register_field("selectedWindowMode", func() -> String: return _selected_text(_window_mode_select))
	bridge.register_field("windowMode", func() -> String: return _window_mode())
	bridge.register_field("saveQuitButtonVisible", func() -> bool: return _is_save_quit_button_visible())
	bridge.register_field("deleteSaveButtonVisible", func() -> bool: return _is_delete_save_button_visible())
	bridge.register_field("confirmDeleteVisible", func() -> bool: return _is_confirm_delete_visible())
	bridge.register_field("confirmDeleteMessage", func() -> String: return _confirm_delete_message())
	bridge.register_field("savedLocale", func() -> String: return _saved_locale())
	bridge.register_field("savedResolutionScale", func() -> int: return _saved_resolution_scale())
	bridge.register_field("savedWindowMode", func() -> String: return _saved_window_mode_key())
	bridge.register_field("settingsFileExists", func() -> bool: return _settings_file_exists())
	bridge.register_field("settingsPersistent", func() -> bool: return _settings_persistent())
	bridge.register_field("focusedControl", func() -> String: return _focused_control_name())
	bridge.register_field("focusedApp", func() -> String: return _taskbar.focused_app_id())


func _settings_file_exists() -> bool:
	return false if _settings == null else bool(_settings.file_exists())


func _settings_persistent() -> bool:
	return false if _settings == null else bool(_settings.is_persistent())


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


func _is_language_select_visible() -> bool:
	if _language_select == null or not is_instance_valid(_language_select):
		return false
	return _language_select.is_visible_in_tree()


func _is_resolution_select_visible() -> bool:
	if _resolution_select == null or not is_instance_valid(_resolution_select):
		return false
	return _resolution_select.is_visible_in_tree()


func _is_window_mode_select_visible() -> bool:
	if _window_mode_select == null or not is_instance_valid(_window_mode_select):
		return false
	return _window_mode_select.is_visible_in_tree()


func _is_save_quit_button_visible() -> bool:
	if _save_quit_button == null or not is_instance_valid(_save_quit_button):
		return false
	return _save_quit_button.is_visible_in_tree()


func _is_delete_save_button_visible() -> bool:
	if _delete_save_button == null or not is_instance_valid(_delete_save_button):
		return false
	return _delete_save_button.is_visible_in_tree()


func _is_confirm_delete_visible() -> bool:
	if _confirm_delete == null or not is_instance_valid(_confirm_delete):
		return false
	return _confirm_delete.is_visible_in_tree()


## The message as drawn, so a check can prove the dialog followed a language change rather
## than keeping the English baked into main.tscn.
func _confirm_delete_message() -> String:
	if _confirm_message == null or not is_instance_valid(_confirm_message):
		return ""
	return _confirm_message.text


func _item_texts(select: OptionButton) -> Array:
	var out: Array = []
	if select == null or not is_instance_valid(select):
		return out
	for i in select.item_count:
		out.append(select.get_item_text(i))
	return out


func _selected_text(select: OptionButton) -> String:
	if select == null or not is_instance_valid(select):
		return ""
	var index := select.selected
	if index < 0:
		return ""
	return select.get_item_text(index)


## The mode the window is actually in, which can differ from the dropdown if the user
## left fullscreen through the window manager rather than the dropdown.
func _window_mode() -> String:
	var window := get_window()
	if window == null:
		return ""
	return tr(WINDOW_MODE_KEYS[_index_for_window_mode(window.mode)])


func _window_size() -> String:
	var size := DisplayServer.window_get_size()
	return "%dx%d" % [size.x, size.y]


## Whole-pixel upscale factor the stretch system is drawing the 640x360 canvas at.
func _content_scale() -> int:
	var size := DisplayServer.window_get_size()
	return maxi(1, mini(size.x / BASE_RESOLUTION.x, size.y / BASE_RESOLUTION.y))


func _focused_control_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return "" if focused == null else String(focused.name)


func _color_to_hex(color: Color) -> String:
	return "#%s" % color.to_html(false).to_lower()
