extends Control
## The Settings screen: master volume, language, resolution, window mode and Delete local save,
## opened from the main menu's Settings button and left through Back - or ui_cancel from anywhere
## on it - to the menu again.
##
## Built the way the menu is: full-canvas room art, the menu's scrim down the middle, and a
## column of 176x34 controls on res://resources/theme.tres, 8px apart. There is no title, so the
## column is centred on the canvas rather than sitting below the desk. Back is not in that
## column: it is screen chrome, a narrower button in the bottom-left, outside the scrim. The
## scrim is a copy of main_menu.tscn's, not a shared resource: change one and change the other,
## or the two screens stop reading as one front end. settingsScrimRect is there so a check
## notices.
##
## The volume slider tops the column with its caption over it: an 18px caption and the 16px slider
## fill one 34px slot, so the column keeps its rhythm. Pixelify Sans needs 16px of that caption,
## but the CJK faces need 17, and a box smaller than its text grows both ways - which would lift
## the column's top off y=79 in those locales. Focus on the slider shows as Godot's own highlight -
## a brighter track and grabber - not the white ring the buttons draw: Slider has no focus style
## for the theme to set.
##
## The slider gives the right 36px of its row to a percentage readout - a 4px gap, then a 32px box
## that fits "100%" right-aligned - so the row still spans exactly the column's 176px.
##
## The three dropdowns used to live on the desktop's Home app. They moved here as they were -
## same node names, same sizes, same popup styling - but the tables behind them moved to the
## Settings autoload instead, because a saved value has to be in effect from boot rather than
## from the first time someone opens this screen. So this script only draws: it reads the tables
## to fill the dropdowns and hands every pick, and every notch of the slider, to a Settings
## setter, which puts it into effect and writes it to disk. Nothing here outlives the screen.
##
## Delete local save came over from Home later, with the question it asks first. It sits last
## in the column, so a player walking top to bottom passes every harmless option before
## reaching it. It does not go through Settings: it wipes progress, which GameState owns, and
## leaves every preference where it was. Back lives off the column so it is not the next stop
## after a destructive control, and so leave is chrome rather than another setting.
##
## The menu track keeps playing: this is a side room, not a new song. Music is an autoload, so
## the scene change does not stop it; this screen only asks it to muffle. Back does not un-muffle
## - the menu does that in its own `_ready()`, so there is no clear gap while the scene swaps.

const MAIN_MENU_SCENE := "res://src/main_menu.tscn"

## What `screen` reports while this scene is up, next to main_menu.gd's "mainMenu" and game.gd's
## "game".
const SCREEN_ID := "settings"

const BACK_KEY := "SETTINGS_BACK"
const MASTER_VOLUME_KEY := "SETTINGS_MASTER_VOLUME"
const DELETE_SAVE_KEY := "DELETE_SAVE"
const DELETE_SAVE_CONFIRM_KEY := "DELETE_SAVE_CONFIRM"
const DELETE_SAVE_YES_KEY := "DELETE_SAVE_YES"
const DELETE_SAVE_CANCEL_KEY := "DELETE_SAVE_CANCEL"

## Pressing any of these with nothing focused is the player reaching for the UI without a mouse.
## Same list as main_menu.gd's, and for the same reason.
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
	"settingsVisible",
	"settingsBackground",
	"settingsScrimVisible",
	"settingsScrimBehindUi",
	"settingsScrimRect",
	"settingsColumnRect",
	"settingsControls",
	"settingsBackText",
	"masterVolumeLabelText",
	"masterVolumeSliderVisible",
	"masterVolumeSliderValue",
	"masterVolumeValueText",
	"masterBusVolume",
	"languageSelectVisible",
	"languageOptions",
	"selectedLanguage",
	"locale",
	"resolutionSelectVisible",
	"resolutionOptions",
	"selectedResolution",
	"windowSize",
	"contentScale",
	"windowModeSelectVisible",
	"windowModeOptions",
	"selectedWindowMode",
	"windowMode",
	"savedLocale",
	"savedResolutionScale",
	"savedWindowMode",
	"savedMasterVolume",
	"settingsFileExists",
	"settingsPersistent",
	"deleteSaveButtonVisible",
	"confirmDeleteVisible",
	"confirmDeleteMessage",
	"saveFileExists",
	"rubles",
	"focusedControl",
]

var _background: TextureRect
var _scrim: TextureRect
var _master_volume_label: Label
var _master_volume_slider: HSlider
var _master_volume_value: Label
var _language_select: OptionButton
var _resolution_select: OptionButton
var _window_mode_select: OptionButton
var _delete_save_button: Button
var _back_button: Button
var _confirm_delete: Control
var _confirm_message: Label
var _confirm_yes_button: Button
var _confirm_cancel_button: Button

## Every control that takes focus, top to bottom, which is also the order focus walks it.
var _focus_ring: Array[Control] = []

## The whole column as drawn, top to bottom and left to right within a row: the volume caption,
## the slider and its percentage readout, then the rest of the ring. Neither label takes focus.
var _column: Array[Control] = []

var _settings: Node
var _state: Node


func _ready() -> void:
	_background = $Background
	_scrim = $Scrim
	_master_volume_label = $MasterVolumeLabel
	_master_volume_slider = $MasterVolumeSlider
	_master_volume_value = $MasterVolumeValue
	_language_select = $LanguageSelect
	_resolution_select = $ResolutionSelect
	_window_mode_select = $WindowModeSelect
	_delete_save_button = $DeleteSaveButton
	_back_button = $BackButton
	_confirm_delete = $ConfirmDelete
	_confirm_message = $ConfirmDelete/Panel/Message
	_confirm_yes_button = $ConfirmDelete/Panel/ConfirmYesButton
	_confirm_cancel_button = $ConfirmDelete/Panel/ConfirmCancelButton
	_focus_ring = [
		_master_volume_slider,
		_language_select,
		_resolution_select,
		_window_mode_select,
		_delete_save_button,
	]
	_back_button.focus_mode = Control.FOCUS_CLICK
	_column = [_master_volume_label, _master_volume_slider, _master_volume_value]
	_column.append_array(_focus_ring.slice(1))
	# get_node rather than get_node_or_null: this screen is a view of that autoload and has
	# nothing to show without it.
	_settings = get_node("/root/Settings")
	_state = get_node_or_null("/root/GameState")
	# Where the window cannot be resized - the web build - the dropdown stays in the column but
	# disabled: hiding it would pull the rest of the column up and take a stop out of the ring.
	_resolution_select.disabled = not _settings.can_resize_window()
	_master_volume_slider.value_changed.connect(_on_master_volume_changed)
	_language_select.item_selected.connect(_on_language_selected)
	_resolution_select.item_selected.connect(_on_resolution_selected)
	_window_mode_select.item_selected.connect(_on_window_mode_selected)
	_delete_save_button.pressed.connect(_on_delete_save_pressed)
	_confirm_yes_button.pressed.connect(_on_confirm_delete_pressed)
	_confirm_cancel_button.pressed.connect(_on_cancel_delete_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_settings.loaded.connect(_on_settings_loaded)
	_refresh_controls()
	_wire_focus_navigation()
	_muffle_music()
	_register_bridge_fields()


## Side room: keep the menu track, put it behind a door. Idempotent if the menu already muffled
## before the scene change, and a no-op if the Music autoload is missing.
func _muffle_music() -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	music.set_muffled(true)


## Rebuild the slider, the three dropdowns and every label from what Settings holds now. Together,
## because the window-mode items, the volume caption and the Back label are translated: a language
## change rewrites them.
##
## No signal from the slider: drawing the stored value must not hand it back to Settings as a pick.
func _refresh_controls() -> void:
	_master_volume_slider.set_value_no_signal(_settings.master_volume())
	_refresh_master_volume_value()
	_populate_languages()
	_populate_resolutions()
	_populate_window_modes()
	_refresh_labels()


## Settings replaced wholesale from disk. Only an egon scenario does that at runtime, and it
## runs on the first frame, while the menu is up - this is here so the screen cannot go stale,
## not because any current path reaches it.
func _on_settings_loaded() -> void:
	_refresh_controls()


## Every translated string on the screen, in whatever locale is in effect. OptionButton captions
## and popups are their own windows, so the font tag has to be set on each control rather than
## inherited; the tag is the locale's language subtag, which is what sends Japanese to the ja
## face and Korean to Galmuri.
##
## The slider draws no text, so it is the one control in the ring without a tag to set.
func _refresh_labels() -> void:
	var font_language := TranslationServer.get_locale().get_slice("_", 0)
	_master_volume_label.language = font_language
	_back_button.language = font_language
	_confirm_message.language = font_language
	_confirm_yes_button.language = font_language
	_confirm_cancel_button.language = font_language
	for control in _focus_ring:
		var button := control as Button
		if button != null:
			button.language = font_language
	_set_popup_item_language(_resolution_select, font_language)
	_set_popup_item_language(_window_mode_select, font_language)
	_refresh_window_mode_labels()
	_master_volume_label.text = tr(MASTER_VOLUME_KEY)
	_delete_save_button.text = tr(DELETE_SAVE_KEY)
	_back_button.text = tr(BACK_KEY)
	_confirm_message.text = tr(DELETE_SAVE_CONFIRM_KEY)
	_confirm_yes_button.text = tr(DELETE_SAVE_YES_KEY)
	_confirm_cancel_button.text = tr(DELETE_SAVE_CANCEL_KEY)


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


## PopupMenu is a Window, not a Control, so it has no language property. The tag lives
## on each item and picks the CJK/Korean face the same way the language list does.
func _set_popup_item_language(select: OptionButton, font_language: String) -> void:
	var popup := select.get_popup()
	for i in popup.item_count:
		popup.set_item_language(i, font_language)


func _populate_languages() -> void:
	_language_select.clear()
	var popup := _style_popup(_language_select)
	for i in _settings.LANGUAGES.size():
		_language_select.add_item(_language_name(i), i)
		popup.set_item_language(i, _font_language(i))
	_language_select.select(_language_row())


func _language_locale(index: int) -> String:
	return String(_settings.LANGUAGES[index][0])


func _language_name(index: int) -> String:
	return String(_settings.LANGUAGES[index][1])


## Each language's name is drawn in its own face, whatever the screen's locale. The two
## fusion-pixel faces cover the same codepoints and Galmuri covers Korean on top of both, so
## without a tag the first font in the chain that has the glyph wins.
func _font_language(index: int) -> String:
	return _language_locale(index).get_slice("_", 0)


## compare_locales scores a full locale against our shorter codes (zh_CN against zh_Hans, de_DE
## against de) and returns 0 when nothing about them matches, so a language we do not offer
## lands on English.
func _index_for_locale(locale: String) -> int:
	var best := 0
	var best_score := 0
	for i in _settings.LANGUAGES.size():
		var score := TranslationServer.compare_locales(locale, _language_locale(i))
		if score > best_score:
			best_score = score
			best = i
	return best


## The saved locale first, the one in effect - the OS locale - only when nothing is saved.
## Matched exactly rather than through _index_for_locale(): Settings only ever writes codes from
## its LANGUAGES, so anything else is a hand-edit or a language we have dropped, and the OS is a
## better guess than the English that the fuzzy match returns for everything it does not
## recognise.
func _language_row() -> int:
	var saved := String(_settings.locale())
	if not saved.is_empty():
		for i in _settings.LANGUAGES.size():
			if _language_locale(i) == saved:
				return i
	return _index_for_locale(TranslationServer.get_locale())


func _populate_resolutions() -> void:
	_resolution_select.clear()
	_style_popup(_resolution_select)
	for i in _settings.RESOLUTION_SCALES.size():
		var resolution := _resolution_for_index(i)
		_resolution_select.add_item("%dx%d" % [resolution.x, resolution.y], i)
	_resolution_select.select(_resolution_row())


func _resolution_for_index(index: int) -> Vector2i:
	return _settings.BASE_RESOLUTION * _settings.RESOLUTION_SCALES[index]


## Exact match on the current window, otherwise the largest listed resolution that still
## fits inside it, so the dropdown never shows a size the window is not at.
func _index_for_window_size(window_size: Vector2i) -> int:
	var best := 0
	for i in _settings.RESOLUTION_SCALES.size():
		var resolution := _resolution_for_index(i)
		if resolution == window_size:
			return i
		if resolution.x <= window_size.x and resolution.y <= window_size.y:
			best = i
	return best


## The saved scale is the multiplier, not the row: RESOLUTION_SCALES will gain entries, and a
## stored row index would start meaning a different size the moment it does.
func _resolution_row() -> int:
	var saved := int(_settings.resolution_scale())
	if saved > 0:
		var index: int = _settings.RESOLUTION_SCALES.find(saved)
		if index >= 0:
			return index
	return _index_for_window_size(DisplayServer.window_get_size())


func _populate_window_modes() -> void:
	_window_mode_select.clear()
	_style_popup(_window_mode_select)
	for i in _settings.WINDOW_MODE_KEYS.size():
		_window_mode_select.add_item(tr(_settings.WINDOW_MODE_KEYS[i]), i)
	_window_mode_select.select(_window_mode_row())


## add_item copies the string at call time, so a locale change has to rewrite the items.
func _refresh_window_mode_labels() -> void:
	var count := mini(_window_mode_select.item_count, _settings.WINDOW_MODE_KEYS.size())
	for i in count:
		_window_mode_select.set_item_text(i, tr(_settings.WINDOW_MODE_KEYS[i]))


func _index_for_window_mode(mode: int) -> int:
	var index: int = _settings.WINDOW_MODE_VALUES.find(mode)
	return 0 if index < 0 else index


## The saved key is one of ours, not a Window.MODE_* int, so the engine renumbering its enum
## cannot turn a saved "windowed" into something else. Falls back to the live window.
func _window_mode_row() -> int:
	var saved := String(_settings.window_mode_key())
	if not saved.is_empty():
		var index: int = _settings.WINDOW_MODE_KEYS.find(saved)
		if index >= 0:
			return index
	var window := get_window()
	return 0 if window == null else _index_for_window_mode(window.mode)


## Fires on every notch of a drag, not only on release, so the change is heard while the grabber
## is still moving.
func _on_master_volume_changed(value: float) -> void:
	_settings.set_master_volume(roundi(value))
	_refresh_master_volume_value()


## Digits and a percent sign, which Pixelify Sans draws in every locale, so unlike the other labels
## the readout needs neither a font tag nor a translation.
func _refresh_master_volume_value() -> void:
	_master_volume_value.text = "%d%%" % roundi(_master_volume_slider.value)


func _on_language_selected(index: int) -> void:
	_settings.set_locale(_language_locale(index))
	_refresh_labels()


func _on_resolution_selected(index: int) -> void:
	_settings.set_resolution_scale(_settings.RESOLUTION_SCALES[index])


func _on_window_mode_selected(index: int) -> void:
	_settings.set_window_mode_key(_settings.WINDOW_MODE_KEYS[index])


## Wiping a save is the only thing on this screen the player cannot undo, so it asks first.
##
## The question is a Control inside this canvas rather than a ConfirmationDialog. That is a
## Window, and a second window is not covered by the project's integer stretch: it would draw
## crisp 1:1 chrome and 12px text over a screen upscaled 2x or 4x, and on the web export it is a
## DOM overlay outside the canvas entirely.
func _on_delete_save_pressed() -> void:
	_confirm_delete.visible = true
	# Cancel, not Yes. The key that opened the question is the same key that activates whatever
	# holds focus, so the destructive option must never be the one sitting under it.
	_confirm_cancel_button.grab_focus()


## clear_save() does both halves in one call - removes the file and puts the balance back to
## STARTING_RUBLES - and leaves the state clean, so the next autosave tick has nothing to flush
## and the file stays gone. Nothing here needs redrawing: the menu's Start/Continue label reads
## the file again when Back brings it up.
func _on_confirm_delete_pressed() -> void:
	if _state != null:
		_state.clear_save()
	_hide_confirm_delete()


func _on_cancel_delete_pressed() -> void:
	_hide_confirm_delete()


## Focus lands back on the button that asked rather than nowhere: Godot releases focus when the
## focused control is hidden, and a player who got here by keyboard would otherwise have to spend
## a press re-entering the column from cold.
func _hide_confirm_delete() -> void:
	_confirm_delete.visible = false
	_delete_save_button.grab_focus()


## Same ring as the menu's, without Back: ui_down off Delete comes round to the volume slider
## and ui_up off the slider reaches Delete, so no press ever does nothing. Back is FOCUS_CLICK,
## so walking the column never lands on it - leave is ui_cancel, or a mouse click on the
## corner. The slider keeps ui_left and ui_right for the volume; ui_up and ui_down leave it
## like any other control.
func _wire_focus_navigation() -> void:
	var count := _focus_ring.size()
	for i in count:
		var control := _focus_ring[i]
		control.focus_neighbor_top = control.get_path_to(_focus_ring[(i + count - 1) % count])
		control.focus_neighbor_bottom = control.get_path_to(_focus_ring[(i + 1) % count])
	_wire_dialog_focus()


## The question is modal, so focus has to stay inside it: every direction and both tab directions
## lead to the other button. Left unwired, an arrow key walks the geometric search straight out
## through the shade into the column the player can neither see nor click, and the focus ring
## disappears behind the panel.
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


## ui_cancel is Back from anywhere on the screen - Esc, or B on a gamepad - so nobody has to walk
## the column to leave - except while the delete question is up, where it answers the question.
##
## Otherwise the menu's first-press rule: with nothing focused, the press only enters the column,
## at the top, and is spent doing that.
func _unhandled_input(event: InputEvent) -> void:
	# While the question is up it owns every press the GUI did not take. Buttons consume
	# ui_accept themselves, so what reaches here is the escape hatch and the keys that would
	# otherwise re-enter a column the player is not looking at.
	if _confirm_delete.visible:
		if event.is_action_pressed("ui_cancel"):
			_hide_confirm_delete()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		# Before the scene change, which takes this node out of the tree and its viewport with it.
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action in FOCUS_ENTRY_ACTIONS:
		if not event.is_action_pressed(action):
			continue
		_focus_ring[0].grab_focus()
		get_viewport().set_input_as_handled()
		return


## Nothing to save on the way out: every pick was written the moment it was made. Nothing to
## fall back to either, so a scene that will not open is said loudly and the player is left on a
## screen that still works rather than a half-torn-down one.
func _on_back_pressed() -> void:
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("settings_screen: could not open %s (error %d)" % [MAIN_MENU_SCENE, error])


## The dropdown fields and the saved/window fields are the ones game.gd registered while the
## dropdowns lived on Home, under the same names and meanings, so the checks that read them only
## had to change where they go to look. The delete-save fields came from Home the same way, and
## saveFileExists and rubles mean what the desktop's do, so a check can prove a deletion without
## leaving this screen.
func _register_bridge_fields() -> void:
	# The egon bot's bridge: there in repo runs and its debug exports, dropped from release builds.
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	bridge.register_field("screen", func() -> String: return SCREEN_ID)
	bridge.register_field("settingsVisible", func() -> bool: return is_visible_in_tree())
	bridge.register_field("settingsBackground", func() -> String: return _background_path())
	bridge.register_field("settingsScrimVisible", func() -> bool: return _is_scrim_visible())
	bridge.register_field("settingsScrimBehindUi", func() -> bool: return _is_scrim_behind_ui())
	bridge.register_field("settingsScrimRect", func() -> String: return _scrim_rect())
	bridge.register_field("settingsColumnRect", func() -> String: return _column_rect())
	bridge.register_field("settingsControls", func() -> Array: return _column_names())
	bridge.register_field("settingsBackText", func() -> String: return _back_button.text)
	bridge.register_field("masterVolumeLabelText", func() -> String: return _master_volume_label.text)
	bridge.register_field("masterVolumeSliderVisible", func() -> bool: return _is_visible(_master_volume_slider))
	bridge.register_field("masterVolumeSliderValue", func() -> int: return roundi(_master_volume_slider.value))
	bridge.register_field("masterVolumeValueText", func() -> String: return _master_volume_value.text)
	bridge.register_field("masterBusVolume", func() -> int: return int(_settings.master_bus_volume()))
	bridge.register_field("languageSelectVisible", func() -> bool: return _is_visible(_language_select))
	bridge.register_field("languageOptions", func() -> Array: return _item_texts(_language_select))
	bridge.register_field("selectedLanguage", func() -> String: return _selected_text(_language_select))
	bridge.register_field("locale", func() -> String: return TranslationServer.get_locale())
	bridge.register_field("resolutionSelectVisible", func() -> bool: return _is_visible(_resolution_select))
	bridge.register_field("resolutionOptions", func() -> Array: return _item_texts(_resolution_select))
	bridge.register_field("selectedResolution", func() -> String: return _selected_text(_resolution_select))
	bridge.register_field("windowSize", func() -> String: return _window_size())
	bridge.register_field("contentScale", func() -> int: return _content_scale())
	bridge.register_field("windowModeSelectVisible", func() -> bool: return _is_visible(_window_mode_select))
	bridge.register_field("windowModeOptions", func() -> Array: return _item_texts(_window_mode_select))
	bridge.register_field("selectedWindowMode", func() -> String: return _selected_text(_window_mode_select))
	bridge.register_field("windowMode", func() -> String: return _window_mode())
	bridge.register_field("savedLocale", func() -> String: return String(_settings.locale()))
	bridge.register_field("savedResolutionScale", func() -> int: return int(_settings.resolution_scale()))
	bridge.register_field("savedWindowMode", func() -> String: return String(_settings.window_mode_key()))
	bridge.register_field("savedMasterVolume", func() -> int: return int(_settings.master_volume()))
	bridge.register_field("settingsFileExists", func() -> bool: return bool(_settings.file_exists()))
	bridge.register_field("settingsPersistent", func() -> bool: return bool(_settings.is_persistent()))
	bridge.register_field("deleteSaveButtonVisible", func() -> bool: return _is_visible(_delete_save_button))
	bridge.register_field("confirmDeleteVisible", func() -> bool: return _is_visible(_confirm_delete))
	bridge.register_field("confirmDeleteMessage", func() -> String: return _confirm_message.text)
	bridge.register_field("saveFileExists", func() -> bool: return _save_file_exists())
	bridge.register_field("rubles", func() -> int: return _rubles())
	bridge.register_field("focusedControl", func() -> String: return _focused_control_name())


## Providers close over nodes this scene is about to free, so they all come off on the way out.
## `screen` and `focusedControl` are registered by every screen, and `locale`, `rubles` and
## `saveFileExists` by the desktop too; whichever screen comes up next registers its own before
## the bridge pushes another snapshot - the same hand-over main_menu.gd describes.
func _exit_tree() -> void:
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	for field in BRIDGE_FIELDS:
		bridge.unregister_field(field)


func _is_visible(control: Control) -> bool:
	return control != null and is_instance_valid(control) and control.is_visible_in_tree()


func _background_path() -> String:
	if _background == null or not is_instance_valid(_background) or _background.texture == null:
		return ""
	return _background.texture.resource_path


func _is_scrim_visible() -> bool:
	if _scrim == null or not is_instance_valid(_scrim):
		return false
	return _scrim.is_visible_in_tree() and _scrim.texture != null


## Same test as main_menu.gd's: over the backdrop and under every control in the column. Child
## order is the whole of that layering, so this reads it back rather than trusting the scene file.
func _is_scrim_behind_ui() -> bool:
	if not _is_scrim_visible():
		return false
	if _background == null or not is_instance_valid(_background):
		return false
	if _scrim.get_index() <= _background.get_index():
		return false
	for control in _column:
		if control == null or not is_instance_valid(control):
			return false
		if _scrim.get_index() >= control.get_index():
			return false
	return true


## Where the scrim landed, as "x,y,WxH" - the format of main_menu.gd's mainMenuScrimRect, so a
## check can hold the two screens to the same column.
func _scrim_rect() -> String:
	if _scrim == null or not is_instance_valid(_scrim):
		return ""
	return _rect_text(_scrim.get_rect())


## The bounding box of the whole column, as "x,y,WxH". Centred on the 640x360 canvas it is
## "232,79,176x202"; any control nudged off that in the editor moves it. Back is not in this
## box: it sits in the bottom-left as chrome.
func _column_rect() -> String:
	var rect := Rect2()
	for i in _column.size():
		var control := _column[i]
		if control == null or not is_instance_valid(control):
			return ""
		rect = control.get_rect() if i == 0 else rect.merge(control.get_rect())
	return _rect_text(rect)


func _rect_text(rect: Rect2) -> String:
	return "%d,%d,%dx%d" % [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]


## Node names rather than text: the dropdowns' caption is whatever is selected, and the slider
## has none. Top to bottom - left to right within the volume row - with both labels included, so a
## check can prove both which controls are here and their order.
func _column_names() -> Array:
	var out: Array = []
	for control in _column:
		if control == null or not is_instance_valid(control):
			continue
		out.append(String(control.name))
	return out


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
	return tr(_settings.WINDOW_MODE_KEYS[_index_for_window_mode(window.mode)])


func _window_size() -> String:
	var window_size := DisplayServer.window_get_size()
	return "%dx%d" % [window_size.x, window_size.y]


## Whole-pixel upscale factor the stretch system is drawing the 640x360 canvas at.
func _content_scale() -> int:
	var window_size := DisplayServer.window_get_size()
	var base: Vector2i = _settings.BASE_RESOLUTION
	return maxi(1, mini(window_size.x / base.x, window_size.y / base.y))


func _save_file_exists() -> bool:
	return false if _state == null else bool(_state.save_file_exists())


func _rubles() -> int:
	return 0 if _state == null else int(_state.rubles())


func _focused_control_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return "" if focused == null else String(focused.name)
