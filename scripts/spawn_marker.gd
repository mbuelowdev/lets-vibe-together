extends Node2D

const BOX_SIZE := Vector2(128, 128)
const OUTLINE_WIDTH := 4.0
const COLOR_BOX := Color("#F9C74F")


func _draw() -> void:
	var half := BOX_SIZE * 0.5
	var rect := Rect2(-half, BOX_SIZE)
	draw_rect(rect, Color("#F9C74F", 0.2), true)
	draw_rect(rect, COLOR_BOX, false, OUTLINE_WIDTH)
