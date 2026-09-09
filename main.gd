extends Node2D

const APP_BACKGROUNDS := {
	"home": Color("#2e4272"),
	"steam": Color("#1b2838"),
	"chrome": Color("#3f6b3a"),
	"cs2": Color("#6e3a3a"),
}

var _app_switch_count: int = 0
var _background: ColorRect
var _taskbar: Control


func _ready() -> void:
	_background = $UI/Background
	_taskbar = $UI/Taskbar
	_background.color = APP_BACKGROUNDS["home"]
	_taskbar.app_selected.connect(_on_app_selected)
	_register_bridge_fields()


func _on_app_selected(app_id: String) -> void:
	if APP_BACKGROUNDS.has(app_id):
		_background.color = APP_BACKGROUNDS[app_id]
	_app_switch_count += 1


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


func _is_taskbar_visible() -> bool:
	if _taskbar == null or not is_instance_valid(_taskbar):
		return false
	if not _taskbar.visible:
		return false
	var base := _taskbar.get_node_or_null("Base") as TextureRect
	return base != null and base.texture != null


func _color_to_hex(color: Color) -> String:
	return "#%s" % color.to_html(false).to_lower()
