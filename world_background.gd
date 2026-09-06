extends Sprite2D

const COLOR_A := Color("#1e3a5f")
const COLOR_B := Color("#e8eef6")
const CELL_SIZE := 80.0
const CELLS := 100

func _ready() -> void:
	var img := Image.create(CELLS, CELLS, false, Image.FORMAT_RGBA8)
	for y in range(CELLS):
		for x in range(CELLS):
			img.set_pixel(x, y, COLOR_A if ((x + y) % 2) == 0 else COLOR_B)
	texture = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	scale = Vector2(CELL_SIZE, CELL_SIZE)
