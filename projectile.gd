class_name Projectile
extends MeshInstance3D

const SPEED := 22.0
const LIFETIME := 3.5
const MAX_RANGE := 45.0

var direction := Vector3.FORWARD

var _origin := Vector3.ZERO
var _age := 0.0


func _ready() -> void:
	_origin = global_position


func _process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_age += delta
	if _age >= LIFETIME or global_position.distance_to(_origin) > MAX_RANGE:
		queue_free()
