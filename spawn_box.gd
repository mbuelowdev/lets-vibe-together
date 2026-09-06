extends Node2D

const SIZE := Vector2(280, 280)
const COLOR := Color("#00E5FF")
const LINE_WIDTH := 5.0

func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	draw_rect(rect, Color(COLOR, 0.14), true)
	draw_rect(rect, COLOR, false, LINE_WIDTH)
