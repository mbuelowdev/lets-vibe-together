extends Node3D

const ProjectileScene := preload("res://projectile.tscn")

@onready var _camera: Camera3D = $Camera3D
@onready var _player: MeshInstance3D = $Player

var _last_ground_aim: Variant = null


func _ready() -> void:
	_camera.look_at(_player.global_position)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_shoot_toward_cursor(event.position)


func _shoot_toward_cursor(screen_pos: Vector2) -> void:
	var aim: Variant = _ground_point_under_cursor(screen_pos)
	if aim == null:
		aim = _last_ground_aim
	if aim == null:
		return
	_last_ground_aim = aim

	var from := _player.global_position
	var to: Vector3 = aim
	to.y = from.y
	var offset := to - from
	if offset.length_squared() < 0.0001:
		return

	var projectile: Projectile = ProjectileScene.instantiate()
	projectile.position = from
	projectile.direction = offset.normalized()
	add_child(projectile)


func _ground_point_under_cursor(screen_pos: Vector2) -> Variant:
	var plane := Plane(Vector3.UP, 0.0)
	return plane.intersects_ray(
		_camera.project_ray_origin(screen_pos),
		_camera.project_ray_normal(screen_pos)
	)
