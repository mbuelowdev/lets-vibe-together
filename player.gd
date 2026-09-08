extends Node2D

const MOVE_SPEED := 240.0
const MOVE_STEP := 48.0
const CAMERA_SMOOTHING_SPEED := 8.0

const _MOVE_DIRS: Dictionary = {
	"move_left": Vector2.LEFT,
	"move_right": Vector2.RIGHT,
	"move_up": Vector2.UP,
	"move_down": Vector2.DOWN,
}

var move_count: int = 0
var _skip_hold_this_frame: bool = false


func _ready() -> void:
	($Outline as Polygon2D).polygon = _regular_ngon(34.0)
	($Clip/Mask as Polygon2D).polygon = _regular_ngon(32.0)
	_fit_portrait()
	var camera: Camera2D = $Camera2D as Camera2D
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false
	camera.zoom = Vector2.ONE
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	for action: String in _MOVE_DIRS:
		if event.is_action_pressed(action) and not event.is_echo():
			position += (_MOVE_DIRS[action] as Vector2) * MOVE_STEP
			move_count += 1
			_skip_hold_this_frame = true


func _process(delta: float) -> void:
	if not _skip_hold_this_frame:
		position += Input.get_vector("move_left", "move_right", "move_up", "move_down") * MOVE_SPEED * delta
	_skip_hold_this_frame = false


func _regular_ngon(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 16:
		var angle: float = float(i) * TAU / 16.0
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _fit_portrait() -> void:
	var portrait: Sprite2D = $Clip/Portrait as Sprite2D
	var texture: Texture2D = portrait.texture
	if texture == null:
		return
	var size: Vector2 = texture.get_size()
	var shortest: float = minf(size.x, size.y)
	if shortest <= 0.0:
		return
	var cover: float = 64.0 / shortest
	portrait.centered = true
	portrait.position = Vector2.ZERO
	portrait.scale = Vector2(cover, cover)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_circle_clip(portrait)


func _apply_circle_clip(portrait: Sprite2D) -> void:
	var shader: Shader = Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (dot(p, p) > 1.0) {
		discard;
	}
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	portrait.material = material
