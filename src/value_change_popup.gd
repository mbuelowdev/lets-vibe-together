extends Label
## The floating "+2" / "-2" that plays over a taskbar readout when its value changes.
##
## One of these is spawned per change, by taskbar.gd, and frees itself when it has played. It is
## feedback only: the readout underneath has already been redrawn with the new value, so a popup
## that never spawned, or was cut short by a scene change, costs the player nothing.
##
## Parented to the taskbar's Utils cluster, which is drawn last and so puts the popup above the
## app icons and whatever app fills the canvas. It climbs out of the taskbar as it goes, which is
## why it is not clipped to the row.
##
## The tween runs on this node's process mode, so a popup spawned behind the pause menu freezes
## with the rest of the desktop and finishes when the player resumes.

## Canvas pixels the popup climbs, measured so it ends clear of the taskbar's top edge (the row is
## 32px and a readout's digits sit at its centre).
const RISE_PIXELS := 20.0

## Quick up, then a beat holding still where the player's eye has landed.
const RISE_SECONDS := 1.0
const HOLD_SECONDS := 0.5

## Radius of the whole-pixel nudge each popup spawns inside. Two changes in quick succession
## otherwise stack exactly, and the two numbers draw over each other into something unreadable.
const JITTER_RADIUS := 2.0

const GAIN_COLOR := Color("#6ce06c")
const LOSS_COLOR := Color("#ff5c5c")

## The apps behind the taskbar are any colour at all - Chrome's backdrop is bright yellow - so the
## text carries its own dark outline rather than trusting the background to be dark. Both Pixelify
## faces are imported with antialiasing off, so the stroke stays hard-edged at this size.
##
## 4 is a heavy stroke: it is laid over the glyph rather than around it, so at font size 12 it
## thins the digits into outlines of themselves. That is the chosen look, picked off renders at
## 0, 1, 2 and 4 over the yellow Chrome backdrop.
const OUTLINE_COLOR := Color(0.04, 0.05, 0.06, 0.92)
const OUTLINE_SIZE := 4

## The size every number on the taskbar is set in; see the note on ui-font.tres about the 12px grid.
const FONT_SIZE := 12


## Float `delta` over `anchor`, formatted by the same formatter the readout draws with, so a ruble
## gain groups its digits like the balance does. Call it after adding the popup to the tree: the
## tween needs a tree, and the position is read off the laid-out anchor.
func play(anchor: Control, delta: int, formatter: Callable) -> void:
	var gain := delta > 0
	text = "%s%s" % ["+" if gain else "-", formatter.call(absi(delta))]
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", GAIN_COLOR if gain else LOSS_COLOR)
	add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Centred on the digits the readout draws, not on its box: a readout is right-aligned in a slot
	# wider than its number, so the two have nothing to do with each other.
	var digits_centre := anchor.position.x + anchor.size.x - anchor.get_minimum_size().x * 0.5
	var width := get_minimum_size().x
	size = Vector2(width, anchor.size.y)
	position = Vector2(digits_centre - width * 0.5, anchor.position.y) + _jitter()
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - RISE_PIXELS, RISE_SECONDS) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_callback(queue_free)


## Whole pixels, and evenly spread over the disc rather than bunched at its centre: the canvas is
## 640x360 and everything else on it sits on the pixel grid.
func _jitter() -> Vector2:
	var angle := randf() * TAU
	var radius := sqrt(randf()) * JITTER_RADIUS
	return Vector2(cos(angle) * radius, sin(angle) * radius).round()
