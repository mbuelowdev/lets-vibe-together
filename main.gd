extends Node2D

const WORLD_WIDTH := 3456
const WORLD_HEIGHT := 1944
const PLAYER_START := Vector2(1728, 972)

var world: Node2D
var player
var camera: Camera2D


func _ready() -> void:
	world = $World
	player = $Player
	camera = player.get_node("Camera2D")
	player.global_position = PLAYER_START
	player.bounds = Rect2(Vector2.ZERO, Vector2(WORLD_WIDTH, WORLD_HEIGHT))
	camera.reset_smoothing()
	camera.force_update_scroll()
	var bridge := get_node("/root/EgonBridge")
	bridge.register_field("playerX", func() -> float: return round(player.global_position.x))
	bridge.register_field("playerY", func() -> float: return round(player.global_position.y))
	bridge.register_field("moveCount", func() -> int: return player.move_count)
	bridge.register_field("cameraX", func() -> float: return round(camera.get_screen_center_position().x))
	bridge.register_field("cameraY", func() -> float: return round(camera.get_screen_center_position().y))
	bridge.register_field(
		"cameraSmoothingEnabled",
		func() -> bool: return camera.position_smoothing_enabled
	)
	bridge.register_field("hasBackground", func() -> bool: return world != null)
	bridge.register_field("worldWidth", func() -> int: return WORLD_WIDTH)
