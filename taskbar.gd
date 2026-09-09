extends Control

signal app_selected(app_id: String)

const APP_IDS: PackedStringArray = ["home", "steam", "chrome", "cs2"]
const ICON_SHEET_PATH := "res://assets/library/image/taskbar-app-icons.png"
const BASE_TEXTURE_PATH := "res://assets/library/image/taskbar-base.png"
const ICON_DRAW_SIZE := 32
const ICON_SHEET_COLUMNS := 4
const COL_UNSELECTED := 0
const COL_SELECTED := 1
const COL_UNSELECTED_HOVER := 2
const COL_SELECTED_HOVER := 3

var _selected_index: int = 0
var _hovered_index: int = -1
var _hover_enter_count: int = 0
var _buttons: Array[TextureButton] = []
var _normal_textures: Array[AtlasTexture] = []
var _selected_textures: Array[AtlasTexture] = []
var _hover_textures: Array[AtlasTexture] = []
var _selected_hover_textures: Array[AtlasTexture] = []


func _ready() -> void:
	var base := $Base as TextureRect
	var base_texture: Texture2D = load(BASE_TEXTURE_PATH)
	if base != null:
		if base.texture == null:
			base.texture = base_texture
		base.stretch_mode = TextureRect.STRETCH_SCALE
		base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		base.texture_filter = TEXTURE_FILTER_NEAREST
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base_texture = base.texture
	var height := 0
	if base_texture != null:
		height = base_texture.get_height()
	offset_top = -float(height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var apps := $Apps as Control
	if apps != null:
		apps.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_buttons = [
		$Apps/AppHome as TextureButton,
		$Apps/AppSteam as TextureButton,
		$Apps/AppChrome as TextureButton,
		$Apps/AppCs2 as TextureButton,
	]
	_build_atlas_textures()
	for i in _buttons.size():
		var button := _buttons[i]
		_configure_button(button, i)
		button.pressed.connect(_on_app_pressed.bind(i))
		button.mouse_entered.connect(_on_app_mouse_entered.bind(i))
		button.mouse_exited.connect(_on_app_mouse_exited.bind(i))
	_refresh_icon_textures()


func select_app(index: int) -> void:
	var clamped := clampi(index, 0, APP_IDS.size() - 1)
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


func _on_app_pressed(index: int) -> void:
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
	var cell_h := float(sheet.get_height()) / 4.0
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
	for row in APP_IDS.size():
		_normal_textures.append(_make_atlas(sheet, COL_UNSELECTED, row, cell_w, cell_h))
		_selected_textures.append(_make_atlas(sheet, COL_SELECTED, row, cell_w, cell_h))
		_hover_textures.append(_make_atlas(sheet, unselected_hover_col, row, cell_w, cell_h))
		_selected_hover_textures.append(_make_atlas(sheet, selected_hover_col, row, cell_w, cell_h))


func _make_atlas(sheet: Texture2D, col: int, row: int, cell_w: float, cell_h: float) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
	atlas.filter_clip = true
	return atlas


func _configure_button(button: TextureButton, index: int) -> void:
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_filter = TEXTURE_FILTER_NEAREST
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(ICON_DRAW_SIZE, ICON_DRAW_SIZE)
	button.anchor_left = 0.0
	button.anchor_right = 0.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = float(index * ICON_DRAW_SIZE)
	button.offset_right = float((index + 1) * ICON_DRAW_SIZE)
	button.offset_top = -float(ICON_DRAW_SIZE)
	button.offset_bottom = 0.0


func _refresh_icon_textures() -> void:
	for i in _buttons.size():
		var is_selected := i == _selected_index
		var is_hovered := i == _hovered_index
		if is_selected and is_hovered:
			_buttons[i].texture_normal = _selected_hover_textures[i]
		elif is_hovered:
			_buttons[i].texture_normal = _hover_textures[i]
		elif is_selected:
			_buttons[i].texture_normal = _selected_textures[i]
		else:
			_buttons[i].texture_normal = _normal_textures[i]
