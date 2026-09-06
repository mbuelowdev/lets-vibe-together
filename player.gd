extends Node2D

const SPEED := 360.0
const RADIUS := 22.0
const FILL := Color(1.0, 0.82, 0.12, 1.0)
const OUTLINE := Color(0.12, 0.07, 0.02, 1.0)

func _ready() -> void:
	var camera := get_node("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FILL)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, OUTLINE, 4.0, true)

func _process(delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if direction != Vector2.ZERO:
		position += direction.normalized() * SPEED * delta
