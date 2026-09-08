extends Node2D

const MAX_SPEED := 420.0
const ACCELERATION := 1200.0
const FRICTION := 1400.0
const TAP_IMPULSE := 240.0
const RADIUS := 54.0
const MASK_RADIUS := 48.0
const PORTRAIT_DIAMETER := 96.0
const CIRCLE_POINTS := 48

var velocity := Vector2.ZERO
var move_count := 0
var bounds := Rect2(Vector2.ZERO, Vector2(3456, 1944))

var _steer := Vector2.ZERO


func _ready() -> void:
	_fill_circle_polygon($Outline, RADIUS)
	var mask: Polygon2D = $Mask
	_fill_circle_polygon(mask, MASK_RADIUS)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var portrait: Sprite2D = mask.get_node("Portrait")
	portrait.centered = true
	var tex: Texture2D = portrait.texture
	if tex != null:
		var tex_size := tex.get_size()
		var shorter: float = minf(tex_size.x, tex_size.y)
		if shorter > 0.0:
			var s := PORTRAIT_DIAMETER / shorter
			portrait.scale = Vector2(s, s)


func _unhandled_input(event: InputEvent) -> void:
	_try_tap(event, "move_left", Vector2.LEFT)
	_try_tap(event, "move_right", Vector2.RIGHT)
	_try_tap(event, "move_up", Vector2.UP)
	_try_tap(event, "move_down", Vector2.DOWN)


func _physics_process(delta: float) -> void:
	_steer = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _steer != Vector2.ZERO:
		velocity = velocity.move_toward(_steer.normalized() * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	global_position.x += velocity.x * delta
	global_position.y += velocity.y * delta
	var min_x: float = bounds.position.x + RADIUS
	var max_x: float = bounds.end.x - RADIUS
	var min_y: float = bounds.position.y + RADIUS
	var max_y: float = bounds.end.y - RADIUS
	if global_position.x < min_x:
		global_position.x = min_x
		velocity.x = 0.0
	elif global_position.x > max_x:
		global_position.x = max_x
		velocity.x = 0.0
	if global_position.y < min_y:
		global_position.y = min_y
		velocity.y = 0.0
	elif global_position.y > max_y:
		global_position.y = max_y
		velocity.y = 0.0


func _try_tap(event: InputEvent, action: String, dir: Vector2) -> void:
	if event.is_action_pressed(action) and not event.is_echo():
		move_count += 1
		velocity += TAP_IMPULSE * dir
		velocity = velocity.limit_length(MAX_SPEED)


func _fill_circle_polygon(poly: Polygon2D, radius: float) -> void:
	var pts := PackedVector2Array()
	pts.resize(CIRCLE_POINTS)
	for i in CIRCLE_POINTS:
		var angle := TAU * (float(i) / float(CIRCLE_POINTS))
		pts[i] = Vector2(cos(angle), sin(angle)) * radius
	poly.polygon = pts
