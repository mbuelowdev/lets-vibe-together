extends Node2D

const WORLD_SIZE := 12000.0
const TILE := 64
const LANDMARK_SPACING := 720.0

func _ready() -> void:
	_add_tiled_ground()
	var landmarks := LandmarkLayer.new()
	add_child(landmarks)

func _add_tiled_ground() -> void:
	var image := Image.create(TILE * 2, TILE * 2, false, Image.FORMAT_RGBA8)
	var light := Color(0.22, 0.48, 0.40, 1.0)
	var dark := Color(0.14, 0.32, 0.28, 1.0)
	var grid := Color(0.62, 0.88, 0.70, 1.0)
	for y in TILE * 2:
		for x in TILE * 2:
			var checker := (x < TILE) != (y < TILE)
			image.set_pixel(x, y, light if checker else dark)
	for i in TILE * 2:
		image.set_pixel(i, 0, grid)
		image.set_pixel(0, i, grid)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, WORLD_SIZE, WORLD_SIZE)
	sprite.centered = true
	add_child(sprite)


class LandmarkLayer extends Node2D:
	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var half := WORLD_SIZE * 0.5 - LANDMARK_SPACING
		var y := -half
		while y <= half:
			var x := -half
			while x <= half:
				if absf(x) > 1.0 or absf(y) > 1.0:
					var hue := fposmod(x * 0.0008 + y * 0.0013, 1.0)
					var color := Color.from_hsv(hue, 0.72, 0.95)
					var center := Vector2(x, y)
					draw_colored_polygon(
						PackedVector2Array([
							center + Vector2(0, -22),
							center + Vector2(22, 0),
							center + Vector2(0, 22),
							center + Vector2(-22, 0),
						]),
						color
					)
				x += LANDMARK_SPACING
			y += LANDMARK_SPACING
