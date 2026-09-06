extends Node2D

const BOX_SIZE := Vector2(320, 320)
const LIME := Color("#32CD32")
const LINE_WIDTH := 6.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-BOX_SIZE * 0.5, BOX_SIZE)
	var fill := LIME
	fill.a = 0.28
	draw_rect(rect, fill, true)
	draw_rect(rect, LIME, false, LINE_WIDTH)
