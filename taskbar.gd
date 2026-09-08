extends Control

signal app_selected(app_id: String)

const APP_IDS: PackedStringArray = ["home", "steam", "chrome", "cs2"]
const ICON_SHEET_PATH := "res://assets/library/image/taskbar-app-icons.png"
const BASE_TEXTURE_PATH := "res://assets/library/image/taskbar-base.png"
const ICON_DRAW_SIZE := 32

var _selected_index: int = 0
var _buttons: Array[TextureButton] = []
var _normal_textures: Array[AtlasTexture] = []
var _selected_textures: Array[AtlasTexture] = []


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
		if _buttons[i].texture_normal == _selected_textures[i]:
			count += 1
	return count


func _on_app_pressed(index: int) -> void:
	select_app(index)


func _build_atlas_textures() -> void:
	_normal_textures.clear()
	_selected_textures.clear()
	var sheet: Texture2D = load(ICON_SHEET_PATH)
	if sheet == null:
		push_error("taskbar: missing icon sheet at %s" % ICON_SHEET_PATH)
		return
	var cell_w := float(sheet.get_width()) / 2.0
	var cell_h := float(sheet.get_height()) / 4.0
	for row in APP_IDS.size():
		_normal_textures.append(_make_atlas(sheet, 0, row, cell_w, cell_h))
		_selected_textures.append(_make_atlas(sheet, 1, row, cell_w, cell_h))


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
		if i == _selected_index:
			_buttons[i].texture_normal = _selected_textures[i]
		else:
			_buttons[i].texture_normal = _normal_textures[i]
