extends Node2D

@onready var player := $Player
@onready var camera := $Player/Camera2D
@onready var spawn := $SpawnMarker

var _egon_state_cb


func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__egon = window.__egon || {};", true)
		_egon_state_cb = JavaScriptBridge.create_callback(_on_egon_state)
		var window_obj = JavaScriptBridge.get_interface("window")
		window_obj.__egon.state = _egon_state_cb
	else:
		print("EGON_STATE ", _state_json())


func _on_egon_state(_args) -> String:
	return _state_json()


func _state_json() -> String:
	var player_pos: Vector2 = player.global_position
	var spawn_pos: Vector2 = spawn.global_position
	var cam_center: Vector2 = camera.get_screen_center_position()
	var payload := {
		"ready": true,
		"playerX": snappedf(player_pos.x, 0.01),
		"playerY": snappedf(player_pos.y, 0.01),
		"spawnX": snappedf(spawn_pos.x, 0.01),
		"spawnY": snappedf(spawn_pos.y, 0.01),
		"cameraFollowError": snappedf(cam_center.distance_to(player_pos), 0.01),
		"moveSpeed": player.MOVE_SPEED,
		"spawnBoxSize": spawn.BOX_SIZE.x,
	}
	return JSON.stringify(payload)
