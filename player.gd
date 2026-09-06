extends Sprite2D

const SPEED := 320.0
const DISPLAY_SIZE := 128.0

func _ready() -> void:
	_fit_to_circle()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * SPEED * delta


func _fit_to_circle() -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	var max_dim := maxf(tex_size.x, tex_size.y)
	if max_dim > 0.0:
		scale = Vector2.ONE * (DISPLAY_SIZE / max_dim)
