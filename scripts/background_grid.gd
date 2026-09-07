extends Node2D

const DOT_SPACING := 96.0
const WORLD_HALF_EXTENT := 1536.0
const COLOR_DOT := Color("#3A4160")
const COLOR_MARK := Color("#4A5480")


func _draw() -> void:
	var start := int(-WORLD_HALF_EXTENT)
	var end := int(WORLD_HALF_EXTENT)
	var step := int(DOT_SPACING)
	var x := start
	while x <= end:
		var y := start
		while y <= end:
			var pos := Vector2(x, y)
			if x % 384 == 0 and y % 384 == 0:
				draw_circle(pos, 7.0, COLOR_MARK)
			else:
				draw_circle(pos, 3.0, COLOR_DOT)
			y += step
		x += step
