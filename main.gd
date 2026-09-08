extends Node2D

const PlayerScript = preload("res://player.gd")
const BridgeScript = preload("res://egon/egon_bridge.gd")

const SPAWN := Vector2(1440, 810)
const PLAYER_MIN := Vector2(32, 32)
const PLAYER_MAX := Vector2(2848, 1588)
const WORLD_WIDTH := 2880

@onready var world: Node2D = $World
@onready var player: PlayerScript = $Player
@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	process_priority = 1
	player.global_position = SPAWN
	camera.reset_smoothing()
	camera.force_update_scroll()
	_register_bridge_fields()
	_dump_snapshot_soon()


func _process(_delta: float) -> void:
	_clamp_player()


func _clamp_player() -> void:
	player.global_position = player.global_position.clamp(PLAYER_MIN, PLAYER_MAX)


func _egon_bridge() -> BridgeScript:
	return get_node("/root/EgonBridge") as BridgeScript


func _register_bridge_fields() -> void:
	var bridge: BridgeScript = _egon_bridge()
	bridge.register_field("playerX", func() -> float: return round(player.global_position.x))
	bridge.register_field("playerY", func() -> float: return round(player.global_position.y))
	bridge.register_field("cameraX", func() -> float: return round(camera.get_screen_center_position().x))
	bridge.register_field("cameraY", func() -> float: return round(camera.get_screen_center_position().y))
	bridge.register_field(
		"cameraLagPx",
		func() -> float:
			var px: float = round(player.global_position.x)
			var py: float = round(player.global_position.y)
			var cx: float = round(camera.get_screen_center_position().x)
			var cy: float = round(camera.get_screen_center_position().y)
			return round(Vector2(cx, cy).distance_to(Vector2(px, py)))
	)
	bridge.register_field("cameraSmoothingEnabled", func() -> bool: return camera.position_smoothing_enabled)
	bridge.register_field("moveCount", func() -> int: return player.move_count)
	bridge.register_field("hasBackground", func() -> bool: return world != null)
	bridge.register_field("worldWidth", func() -> int: return WORLD_WIDTH)


func _dump_snapshot_soon() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("EGON_SNAPSHOT: %s" % JSON.stringify(_egon_bridge().snapshot()))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--egon-tap="):
			_apply_tap_and_dump(arg.substr("--egon-tap=".length()))
			return


func _apply_tap_and_dump(action: String) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	player._unhandled_input(ev)
	_clamp_player()
	print("EGON_SNAPSHOT_AFTER_TAP: %s" % JSON.stringify(_egon_bridge().snapshot()))
	var elapsed: float = 0.0
	while elapsed < 2.0:
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	print("EGON_SNAPSHOT_AFTER_CATCHUP: %s" % JSON.stringify(_egon_bridge().snapshot()))
