extends Node2D

const APP_BACKGROUNDS := {
	"home": Color("#2e4272"),
	"steam": Color("#1b2838"),
	"chrome": Color("#3f6b3a"),
	"cs2": Color("#6e3a3a"),
}

const APP_SCREEN_TEXTURES := {
	"cs2": "res://assets/library/image/screen-base-cs2.png",
}

const SCREEN_NATIVE_WIDTH := 640
const SCREEN_NATIVE_HEIGHT := 360

var _app_switch_count: int = 0
var _background: ColorRect
var _screen: TextureRect
var _taskbar: Control
var _screen_textures: Dictionary = {}


func _ready() -> void:
	_background = $UI/Background
	_screen = $UI/Screen
	_taskbar = $UI/Taskbar
	_background.color = APP_BACKGROUNDS["home"]
	_taskbar.app_selected.connect(_on_app_selected)
	_apply_app_screen(_taskbar.selected_app_id())
	_register_bridge_fields()


func _on_app_selected(app_id: String) -> void:
	if APP_BACKGROUNDS.has(app_id):
		_background.color = APP_BACKGROUNDS[app_id]
	_apply_app_screen(app_id)
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
	bridge.register_field("screenVisible", func() -> bool: return _is_screen_visible())
	bridge.register_field("screenTexture", func() -> String: return _screen_texture_path())
	bridge.register_field("screenTextureSize", func() -> String: return _screen_texture_size())
	bridge.register_field("taskbarAboveScreen", func() -> bool: return _is_taskbar_above_screen())


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


func _color_to_hex(color: Color) -> String:
	return "#%s" % color.to_html(false).to_lower()
