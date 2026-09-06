extends Node2D

const SPEED := 320.0
const RADIUS := 36.0
const COLOR := Color(0.22, 0.78, 0.28)

func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, COLOR)


func _process(delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if direction != Vector2.ZERO:
		position += direction.normalized() * SPEED * delta
