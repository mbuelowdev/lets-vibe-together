extends CharacterBody2D

const MOVE_SPEED := 320.0
const RADIUS := 24.0
const LATCH_TIME := 0.12
const WORLD_LIMIT := 1416.0
const COLOR_DISC := Color("#4CC9F0")
const COLOR_RING := Color("#9BE7FF")

var _latch := {
	"move_up": 0.0,
	"move_down": 0.0,
	"move_left": 0.0,
	"move_right": 0.0,
}


func _unhandled_input(event: InputEvent) -> void:
	for action in _latch.keys():
		if event.is_action_pressed(action):
			_latch[action] = LATCH_TIME


func _process(delta: float) -> void:
	for action in _latch.keys():
		if _latch[action] > 0.0:
			_latch[action] = maxf(_latch[action] - delta, 0.0)


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if _is_active("move_up"):
		dir.y -= 1.0
	if _is_active("move_down"):
		dir.y += 1.0
	if _is_active("move_left"):
		dir.x -= 1.0
	if _is_active("move_right"):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	velocity = dir * MOVE_SPEED
	move_and_slide()
	position.x = clampf(position.x, -WORLD_LIMIT, WORLD_LIMIT)
	position.y = clampf(position.y, -WORLD_LIMIT, WORLD_LIMIT)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, COLOR_DISC)
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 48, COLOR_RING, 5.0, true)


func _is_active(action: String) -> bool:
	return Input.is_action_pressed(action) or _latch[action] > 0.0
