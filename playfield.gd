extends Node2D

const GRID_COLOR := Color(0.32, 0.32, 0.32)
const GRID_SPACING := 160.0
const GRID_EXTENT := 2400.0
const LINE_WIDTH := 2.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var x := -GRID_EXTENT
	while x <= GRID_EXTENT:
		draw_line(Vector2(x, -GRID_EXTENT), Vector2(x, GRID_EXTENT), GRID_COLOR, LINE_WIDTH)
		x += GRID_SPACING
	var y := -GRID_EXTENT
	while y <= GRID_EXTENT:
		draw_line(Vector2(-GRID_EXTENT, y), Vector2(GRID_EXTENT, y), GRID_COLOR, LINE_WIDTH)
		y += GRID_SPACING
