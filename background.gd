extends Sprite2D

const WORLD_SIZE := 12000.0

func _ready() -> void:
	texture = preload("res://assets/beige_background.jpg")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	region_enabled = true
	region_rect = Rect2(0, 0, WORLD_SIZE, WORLD_SIZE)
	centered = true
