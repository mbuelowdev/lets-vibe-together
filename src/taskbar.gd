extends Control

signal app_selected(app_id: String)

## The Home icon was pressed. Home is not an app: game.gd opens the pause menu for it, and the
## selection stays where it was.
signal home_pressed
signal clock_pressed

## One per icon, in taskbar order. The first is Home, which keeps its icon and its hover art but
## is never the selected one. The last four are placeholders with no app behind them yet - see
## APP_ICON_ROWS and game.gd's PLACEHOLDER_SCREENS.
const APP_IDS: PackedStringArray = [
	"home",
	"gaming_community",
	"chrome",
	"cs2",
	"skills",
	"scammer",
	"telephone",
	"office",
	"floorplanner",
]
const HOME_INDEX := 0
## Where the desktop opens: the first icon after Home.
const FIRST_APP_INDEX := 1
const ICON_SHEET_PATH := "res://assets/images/taskbar-app-icons.png"
const ICON_SHEET_COLUMNS := 4

## Rows on the sheet, which is a fixed 4x4 of 32px cells and not the number of icons on the bar.
const ICON_SHEET_ROWS := 4

## The sheet row each icon draws from, parallel to APP_IDS. One row per icon until Skills and
## the four placeholders borrow Chrome's: they have no art of their own yet, and a placeholder
## icon that is visibly Chrome's is a better reminder of that than rows of guesswork would be.
## Give one a row of its own on the sheet and its 2 here becomes that row.
const APP_ICON_ROWS: PackedInt32Array = [0, 1, 2, 3, 2, 2, 2, 2, 2]
const COL_UNSELECTED := 0
const COL_SELECTED := 1
const COL_UNSELECTED_HOVER := 2
const COL_SELECTED_HOVER := 3

## The util sheet is one row of 32x32 cells; only the volume cell is used, and it is baked
## into taskbar.tscn as an AtlasTexture so the editor preview matches the game.
const UTIL_SHEET_CELL := 32.0
const UTIL_COL_VOLUME := 2
const CLOCK_FORMAT := "%02d:%02d"
const CLOCK_TICK_SECONDS := 1.0

## The skin and target counters left of the balance: pixels between each icon and its count, and
## between a count and whatever is right of it - the next icon, or the balance's first digit. The
## second is three times DIGIT_GROUP_SEPARATOR, so a count never reads as the balance's top group.
const COUNTER_ICON_GAP := 2
const COUNTER_GAP := 12

## The floating "+2" / "-2" that plays over a readout when its value changes.
const VALUE_CHANGE_POPUP := preload("res://src/value_change_popup.gd")

## Every value the tray draws out of GameState: the node under Utils that draws it, the reader to
## call for it, and the signal it changes on. One row is all a readout needs here - a value added
## later wants this row, its nodes in taskbar.tscn, and the private var / reader / *_changed
## signal trio in game_state.gd. Nothing else in this file names a value.
const READOUTS := [
	{"label": "Money", "getter": "rubles", "signal": "rubles_changed"},
	{"label": "SkinsCount", "getter": "skins", "signal": "skins_changed"},
	{"label": "TargetsCount", "getter": "targets", "signal": "targets_changed"},
]

var _selected_index: int = FIRST_APP_INDEX
var _hovered_index: int = -1
var _focused_index: int = -1
var _hover_enter_count: int = 0
var _buttons: Array[TextureButton] = []
var _normal_textures: Array[AtlasTexture] = []
var _selected_textures: Array[AtlasTexture] = []
var _hover_textures: Array[AtlasTexture] = []
var _selected_hover_textures: Array[AtlasTexture] = []
var _divider: ColorRect
var _volume_icon: TextureRect
var _clock: Label
var _clock_elapsed: float = 0.0
var _money: Label
var _money_sign: Label
var _skins_icon: TextureRect
var _skins_count: Label
var _targets_icon: TextureRect
var _targets_count: Label
var _utils: Control
var _game_state: Node

## Per readout, the value its label currently draws, so a change knows what it changed from.
var _shown: Dictionary = {}


## Layout, mouse filters and the resting icon textures are all baked into taskbar.tscn so the
## editor preview matches the game. Only the selection/hover swap stays in code.
func _ready() -> void:
	_buttons = [
		$Apps/AppHome as TextureButton,
		$Apps/AppGamingCommunity as TextureButton,
		$Apps/AppChrome as TextureButton,
		$Apps/AppCs2 as TextureButton,
		$Apps/AppSkills as TextureButton,
		$Apps/AppScammer as TextureButton,
		$Apps/AppTelephone as TextureButton,
		$Apps/AppOffice as TextureButton,
		$Apps/AppFloorplanner as TextureButton,
	]
	_build_atlas_textures()
	for i in _buttons.size():
		var button := _buttons[i]
		button.pressed.connect(_on_app_pressed.bind(i))
		button.mouse_entered.connect(_on_app_mouse_entered.bind(i))
		button.mouse_exited.connect(_on_app_mouse_exited.bind(i))
		button.focus_entered.connect(_on_app_focus_entered.bind(i))
		button.focus_exited.connect(_on_app_focus_exited.bind(i))
	_refresh_icon_textures()
	_divider = $Utils/Divider as ColorRect
	_volume_icon = $Utils/Volume as TextureRect
	_clock = $Utils/Clock as Label
	_money = $Utils/Money as Label
	_money_sign = $Utils/MoneySign as Label
	_skins_icon = $Utils/SkinsIcon as TextureRect
	_skins_count = $Utils/SkinsCount as Label
	_targets_icon = $Utils/TargetsIcon as TextureRect
	_targets_count = $Utils/TargetsCount as Label
	_utils = $Utils as Control
	_clock.gui_input.connect(_on_clock_gui_input)
	_update_clock()
	_bind_game_state()


## Every readout is pushed on change rather than polled in _process: they move when the player
## earns or buys something, not on a clock, so a per-frame read would be pure waste. The first
## draw is primed here instead of animated, so a balance read from the save file is on screen from
## the first frame without floating a "+4  242" over the taskbar for something nobody just earned.
func _bind_game_state() -> void:
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		push_error("taskbar: GameState autoload is missing; the balance will not update")
		return
	for readout in READOUTS:
		_game_state.connect(readout["signal"], _on_value_changed.bind(readout))
		_draw_value(readout, false)


## The signal carries the new value; which readout it belongs to is bound at connect time.
func _on_value_changed(_value: int, readout: Dictionary) -> void:
	_draw_value(readout, true)


## Redraw one readout, and float the difference over it when the change happened in front of the
## player. format_amount(), never format_rubles(): the ruble sign is static text on its own
## control, whose sole job is to carry the 2px vertical nudge that lands Galmuri11's glyph on the
## same baseline as Pixelify Sans's digits, so it must never be folded back into this string.
func _draw_value(readout: Dictionary, animate: bool) -> void:
	var label := _readout_label(readout)
	if label == null or _game_state == null:
		return
	var value: int = _game_state.call(readout["getter"])
	label.text = _game_state.format_amount(value)
	# Everything packed left of a readout moves when its number changes width.
	_pack_counters()
	var key: String = readout["getter"]
	var delta: int = value - int(_shown.get(key, value))
	_shown[key] = value
	if animate and delta != 0:
		_play_change(label, delta)


func _readout_label(readout: Dictionary) -> Label:
	if _utils == null:
		return null
	return _utils.get_node_or_null(String(readout["label"])) as Label


## The popup is parented to the cluster rather than to the readout: it climbs out of the taskbar
## and over whatever app is open, and Utils is drawn after the icons and the app screen.
func _play_change(label: Label, delta: int) -> void:
	var popup: Label = VALUE_CHANGE_POPUP.new()
	_utils.add_child(popup)
	popup.play(label, delta, _game_state.format_amount)


## The counters pack leftward from the balance's first digit instead of sitting in fixed slots.
## The balance is right-aligned in a slot wide enough for nine digits, so a counter in a fixed
## slot beside it would stand off by a gap that shrinks every time the player earns. Only the
## horizontal offsets are written here; box heights, fonts and the icons' centring stay in
## taskbar.tscn, whose offsets are this packing at boot so the editor preview matches the game.
func _pack_counters() -> void:
	if [_money, _skins_icon, _skins_count, _targets_icon, _targets_count].has(null):
		return
	var right := _money.offset_right - _money.get_minimum_size().x
	for counter in [[_targets_icon, _targets_count], [_skins_icon, _skins_count]]:
		right = _place_left_of(counter[1], right - COUNTER_GAP)
		right = _place_left_of(counter[0], right - COUNTER_ICON_GAP)


## Right edge on `right`, at the control's minimum width - a label's text, an icon's texture - and
## returns its left edge for the next control along.
func _place_left_of(control: Control, right: float) -> float:
	var left := right - control.get_combined_minimum_size().x
	control.offset_left = left
	control.offset_right = right
	return left


## The clock only draws minutes, so a one-second tick is finer than it needs to be and still
## cheap; Label.set_text early-returns when the string is unchanged, so most ticks cost nothing.
func _process(delta: float) -> void:
	_clock_elapsed += delta
	if _clock_elapsed < CLOCK_TICK_SECONDS:
		return
	_clock_elapsed = 0.0
	_update_clock()


## The icons ring left and right on their own - taskbar.tscn wires the neighbours - so game.gd only
## asks for the lit one, to land the first key press on it.
func app_button(index: int) -> TextureButton:
	if index < 0 or index >= _buttons.size():
		return null
	return _buttons[index]


func focused_index() -> int:
	return _focused_index


func focused_app_id() -> String:
	if _focused_index < 0:
		return ""
	return APP_IDS[_focused_index]


## Never Home: the clamp starts after it.
func select_app(index: int) -> void:
	var clamped := clampi(index, FIRST_APP_INDEX, APP_IDS.size() - 1)
	if clamped == _selected_index:
		return
	_selected_index = clamped
	_refresh_icon_textures()
	app_selected.emit(APP_IDS[_selected_index])


func selected_index() -> int:
	return _selected_index


func selected_app_id() -> String:
	return APP_IDS[_selected_index]


func selected_icon_count() -> int:
	var count := 0
	for i in _buttons.size():
		var texture := _buttons[i].texture_normal
		if texture == _selected_textures[i] or texture == _selected_hover_textures[i]:
			count += 1
	return count


func hovered_index() -> int:
	return _hovered_index


func hovered_app_id() -> String:
	if _hovered_index < 0:
		return ""
	return APP_IDS[_hovered_index]


func hover_enter_count() -> int:
	return _hover_enter_count


func hovered_icon_column() -> int:
	if _hovered_index < 0:
		return -1
	var texture := _buttons[_hovered_index].texture_normal
	if texture == _selected_hover_textures[_hovered_index]:
		return COL_SELECTED_HOVER
	if texture == _hover_textures[_hovered_index]:
		return COL_UNSELECTED_HOVER
	if texture == _selected_textures[_hovered_index]:
		return COL_SELECTED
	if texture == _normal_textures[_hovered_index]:
		return COL_UNSELECTED
	return -1


## The whole readout as the player reads it, recomposed from the two controls it is split
## across, so a check can assert the balance without knowing about the split.
func money_text() -> String:
	if _money == null or _money_sign == null or _game_state == null:
		return ""
	return "%s%s%s" % [_money.text, _game_state.DIGIT_GROUP_SEPARATOR, _money_sign.text]


## True when the drawn readout is the formatted global balance. Read live, so a label left
## stale by a missed signal reports false instead of quietly disagreeing with GameState.
func money_matches_state() -> bool:
	if _money == null or _money_sign == null or _game_state == null:
		return false
	return money_text() == _game_state.format_rubles(_game_state.rubles())


## Pixels the sign's box sits below the amount's, measured between their vertical centres so
## it stays honest if either box is resized. This is the baseline correction, read off the
## scene rather than trusted, because nothing else on screen would show it drifting.
func money_sign_drop() -> int:
	if _money == null or _money_sign == null:
		return 0
	var amount_centre := _money.position.y + _money.size.y * 0.5
	var sign_centre := _money_sign.position.y + _money_sign.size.y * 0.5
	return int(round(sign_centre - amount_centre))


## The two counts as drawn.
func skins_text() -> String:
	return "" if _skins_count == null else _skins_count.text


func targets_text() -> String:
	return "" if _targets_count == null else _targets_count.text


## True when both drawn counts are GameState's. Read live, like money_matches_state().
func counters_match_state() -> bool:
	if _skins_count == null or _targets_count == null or _game_state == null:
		return false
	return (
		_skins_count.text == _game_state.format_amount(_game_state.skins())
		and _targets_count.text == _game_state.format_amount(_game_state.targets())
	)


## Pixels between the target count's right edge and the balance's first digit, measured off the
## laid-out controls: COUNTER_GAP while the row is packed, something else if the balance changed
## width and the counters were left where they were.
func counters_money_gap() -> int:
	if _money == null or _targets_count == null:
		return -1
	var digits_left := _money.position.x + _money.size.x - _money.get_minimum_size().x
	return int(round(digits_left - (_targets_count.position.x + _targets_count.size.x)))


func clock_text() -> String:
	if _clock == null:
		return ""
	return _clock.text


## True when the drawn string is the local system time in 24-hour HH:MM. Read live rather than
## remembered, so a clock that stopped ticking or reformatted itself reports false.
func clock_matches_system_time() -> bool:
	return _clock != null and _clock.text == _system_clock_text()


## Atlas column the volume icon is drawing, so a check proves the right sheet cell is on screen
## rather than trusting the scene file. -1 when the icon is not an atlas region of the sheet.
func volume_icon_column() -> int:
	if _volume_icon == null:
		return -1
	var atlas := _volume_icon.texture as AtlasTexture
	if atlas == null or atlas.region.size.x <= 0.0:
		return -1
	return int(atlas.region.position.x / atlas.region.size.x)


## The balance and the counts are readouts, not buttons; only the clock takes the pointer, to open
## the debug menu.
func utils_clickable() -> bool:
	for control in _util_controls():
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	return false


func utils_visible() -> int:
	var count := 0
	for control in _util_controls():
		if control.is_visible_in_tree():
			count += 1
	return count


## Cluster contents in reading order, so a check can assert it without pinning the pixel offsets
## the scene owns. Sorted by right edge, not left: the balance is right-aligned in a slot far wider
## than its digits and the counters pack against the digits, so they can start inside the slot -
## its left edge is then left of theirs while everything it draws is to their right.
func utils_order() -> Array:
	var entries: Array = []
	for control in _util_controls():
		entries.append([control.position.x + control.size.x, String(control.name).to_lower()])
	entries.sort()
	var names: Array = []
	for entry in entries:
		names.append(entry[1])
	return names


## Gap in pixels between the cluster's right edge and the taskbar's, which is what "attached to
## the right" means once the window is resized.
func utils_right_margin() -> int:
	var controls := _util_controls()
	if controls.is_empty():
		return -1
	var rightmost := -INF
	for control in controls:
		rightmost = maxf(rightmost, control.position.x + control.size.x)
	return int(round(size.x - rightmost))


func _on_clock_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		clock_pressed.emit()
		accept_event()


func _on_app_pressed(index: int) -> void:
	if index == HOME_INDEX:
		home_pressed.emit()
		return
	select_app(index)


func _on_app_mouse_entered(index: int) -> void:
	if _hovered_index == index:
		return
	_hovered_index = index
	_hover_enter_count += 1
	_refresh_icon_textures()


func _on_app_mouse_exited(index: int) -> void:
	if _hovered_index != index:
		return
	_hovered_index = -1
	_refresh_icon_textures()


## The sheet has no focus column, and a focused icon means the same thing to the player as one
## under the pointer, so focus borrows the hover artwork. It is tracked apart from _hovered_index
## because the two can sit on different icons at once (pointer on one, caret on another) and the
## hover bridge fields must keep reporting the pointer alone.
func _on_app_focus_entered(index: int) -> void:
	if _focused_index == index:
		return
	_focused_index = index
	_refresh_icon_textures()


func _on_app_focus_exited(index: int) -> void:
	if _focused_index != index:
		return
	_focused_index = -1
	_refresh_icon_textures()


func _build_atlas_textures() -> void:
	_normal_textures.clear()
	_selected_textures.clear()
	_hover_textures.clear()
	_selected_hover_textures.clear()
	var sheet: Texture2D = load(ICON_SHEET_PATH)
	if sheet == null:
		push_error("taskbar: missing icon sheet at %s" % ICON_SHEET_PATH)
		return
	var cell_w := float(sheet.get_width()) / float(ICON_SHEET_COLUMNS)
	var cell_h := float(sheet.get_height()) / float(ICON_SHEET_ROWS)
	var inferred_columns := 0
	if cell_h > 0.0:
		inferred_columns = int(floor(float(sheet.get_width()) / cell_h + 0.0001))
	var unselected_hover_col := COL_UNSELECTED_HOVER
	var selected_hover_col := COL_SELECTED_HOVER
	if inferred_columns < ICON_SHEET_COLUMNS:
		push_warning(
			"taskbar: icon sheet has fewer than %d columns (inferred %d); reusing unselected/selected for hover"
			% [ICON_SHEET_COLUMNS, inferred_columns]
		)
		unselected_hover_col = COL_UNSELECTED
		selected_hover_col = COL_SELECTED
	for i in APP_IDS.size():
		var row := _icon_row(i)
		_normal_textures.append(_make_atlas(sheet, COL_UNSELECTED, row, cell_w, cell_h))
		_selected_textures.append(_make_atlas(sheet, COL_SELECTED, row, cell_w, cell_h))
		_hover_textures.append(_make_atlas(sheet, unselected_hover_col, row, cell_w, cell_h))
		_selected_hover_textures.append(_make_atlas(sheet, selected_hover_col, row, cell_w, cell_h))


## The sheet row for an icon, falling back to its own index for an icon added to APP_IDS without
## a row beside it, and clamped so a missing row draws something rather than an empty rect.
func _icon_row(index: int) -> int:
	var row := APP_ICON_ROWS[index] if index < APP_ICON_ROWS.size() else index
	return clampi(row, 0, ICON_SHEET_ROWS - 1)


func _make_atlas(sheet: Texture2D, col: int, row: int, cell_w: float, cell_h: float) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
	atlas.filter_clip = true
	return atlas


func _refresh_icon_textures() -> void:
	# _build_atlas_textures() bailed: keep the resting textures taskbar.tscn supplied.
	if _normal_textures.is_empty():
		return
	for i in _buttons.size():
		var is_selected := i == _selected_index
		var is_highlighted := i == _hovered_index or i == _focused_index
		if is_selected and is_highlighted:
			_buttons[i].texture_normal = _selected_hover_textures[i]
		elif is_highlighted:
			_buttons[i].texture_normal = _hover_textures[i]
		elif is_selected:
			_buttons[i].texture_normal = _selected_textures[i]
		else:
			_buttons[i].texture_normal = _normal_textures[i]


func _util_controls() -> Array[Control]:
	var controls: Array[Control] = []
	var members := [
		_skins_icon, _skins_count, _targets_icon, _targets_count,
		_money, _money_sign, _divider, _volume_icon, _clock,
	]
	for control in members:
		if control != null and is_instance_valid(control):
			controls.append(control)
	return controls


func _update_clock() -> void:
	if _clock == null:
		return
	_clock.text = _system_clock_text()


## Time.get_time_dict_from_system() defaults to local time and reports hours as 0-23, so the
## 24-hour format is the dictionary read straight out - there is no am/pm to strip.
func _system_clock_text() -> String:
	var now := Time.get_time_dict_from_system()
	return CLOCK_FORMAT % [int(now["hour"]), int(now["minute"])]
