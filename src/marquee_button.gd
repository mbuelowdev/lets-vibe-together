extends Button
## A button that never grows to fit its label. A label wider than the button scrolls across it
## instead, like a marquee: it rests on its first letters, glides left until its last ones are in
## view, rests there and glides back.
##
## Every text button on the menus is a fixed slot - the columns are 176px wide - but a plain Button
## handed a longer label grows to fit it, both ways, out past the column and the scrim behind it.
## French "Supprimer sauvegarde locale" did exactly that on the settings screen. The UI font only
## comes at 12px, so shrinking the label is no answer, and with 26 locales neither is rewording
## every one that runs long.
##
## clip_text takes the label out of the button's minimum width and changes nothing else about a
## label that fits: Button still draws that one itself, pixel for pixel as before. A label that
## does not fit is drawn here instead, into a clipping window over the stylebox's content box, so
## it never runs over the bevel. It sits where Button would have put it vertically, in the colour
## Button would have used for the state it is in, but left-aligned and slid along a whole pixel at
## a time, like everything else on the 640x360 canvas.
##
## `text` stays the whole label - the screens set it and the egon bridge reads it back - so while
## the marquee is up, Button's own copy is painted transparent rather than cleared.

## Canvas pixels per second the label glides at.
const GLIDE_SPEED := 20.0

## Seconds the label rests at either end before it glides back.
const REST := 1.5

## Every colour Button draws its label in, one per state.
const FONT_COLORS: PackedStringArray = [
	"font_color",
	"font_focus_color",
	"font_hover_color",
	"font_pressed_color",
	"font_hover_pressed_color",
	"font_disabled_color",
]

## Keep a label that does not fit resting on its first letters until the pointer is over the
## button: it glides the moment the pointer arrives and is back at its start the moment it leaves.
## Keyboard and gamepad players never hover, so with this on they only ever see the start of a long
## label.
@export var scroll_only_when_hovered := false

## The content box, clipping whatever is drawn into it: the marquee's copy of the label.
var _window: Control

## The label as the marquee draws it, shaped from the same font, size and language tag as Button's.
var _line := TextLine.new()

## How many whole pixels wider than the content box the label is. 0 while it fits.
var _overflow := 0

## Seconds into the rest-glide-rest-glide cycle - see _scroll().
var _clock := 0.0

## What the fit was last measured from - see _fit_inputs().
var _measured: Array = []

## Button's label colours from before the marquee painted them out, which _draw_label() draws in,
## and which of them the button already overrode, to put back when the label fits again.
var _colors: Dictionary = {}
var _own_overrides: PackedStringArray = []


func _init() -> void:
	clip_text = true


func _ready() -> void:
	_window = Control.new()
	_window.clip_contents = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.visible = false
	_window.draw.connect(_draw_label)
	add_child(_window, false, Node.INTERNAL_MODE_FRONT)
	# Nothing to glide until a label turns out not to fit.
	set_process(false)


## Pixels of the label that have slid out of the window on the left, for the egon bridge. Always 0
## for a label that fits.
func label_scroll() -> int:
	return _scroll()


## Button redraws after everything that can change whether its label fits - new text, a new
## language tag, a new size or theme - and after every change of state, which moves the label and
## recolours it. So a redraw is where both get noticed. The fit is measured after the draw rather
## than inside it: painting Button's label out calls for another redraw, and one asked for in the
## middle of a draw is dropped.
func _draw() -> void:
	if _fit_inputs() != _measured:
		_refit.call_deferred()
	elif _overflow > 0:
		_window.queue_redraw()


## Button draws the translated text, in its font, size and language tag, inside the content margins
## of its normal stylebox.
func _fit_inputs() -> Array:
	return [
		atr(text),
		language,
		get_theme_font("font"),
		get_theme_font_size("font_size"),
		size,
		get_theme_stylebox("normal"),
	]


func _refit() -> void:
	_measured = _fit_inputs()
	var box := get_theme_stylebox("normal")
	var left := box.get_margin(SIDE_LEFT)
	var room := size.x - left - box.get_margin(SIDE_RIGHT)
	_line.clear()
	_line.add_string(atr(text), get_theme_font("font"), get_theme_font_size("font_size"), language)
	var overflow := maxi(0, ceili(_line.get_size().x - room))
	if (overflow > 0) != (_overflow > 0):
		_paint_out_own_label(overflow > 0)
	_overflow = overflow
	_clock = 0.0
	_window.position = Vector2(left, 0)
	_window.size = Vector2(room, size.y)
	_window.visible = overflow > 0
	_window.queue_redraw()
	set_process(overflow > 0)


## Button's own copy of the label, painted out while the marquee draws it and back once it fits.
## The colours it would have drawn in are taken first, for _draw_label(), and any the button
## already overrode go back on afterwards rather than being dropped.
func _paint_out_own_label(out: bool) -> void:
	begin_bulk_theme_override()
	for color_name in FONT_COLORS:
		if out:
			_colors[color_name] = get_theme_color(color_name)
			if has_theme_color_override(color_name):
				_own_overrides.append(color_name)
			add_theme_color_override(color_name, Color.TRANSPARENT)
		elif _own_overrides.has(color_name):
			add_theme_color_override(color_name, _colors[color_name])
		else:
			remove_theme_color_override(color_name)
	if not out:
		_own_overrides.clear()
	end_bulk_theme_override()


## With scroll_only_when_hovered the clock only runs while the pointer is over the button. It picks
## up past the first rest, so the label glides the moment the pointer arrives, and it is wound back
## to 0 when the pointer leaves.
func _process(delta: float) -> void:
	var was := _scroll()
	if not scroll_only_when_hovered:
		_clock += delta
	elif is_hovered():
		_clock = maxf(_clock, REST) + delta
	else:
		_clock = 0.0
	if _scroll() != was:
		_window.queue_redraw()


## 0 while the label rests on its first letters, _overflow while it rests on its last, and whole
## pixels in between.
func _scroll() -> int:
	var glide := _overflow / GLIDE_SPEED
	var t := fmod(_clock, 2.0 * (REST + glide))
	if t < REST:
		return 0
	if t < REST + glide:
		return floori((t - REST) * GLIDE_SPEED)
	if t < 2.0 * REST + glide:
		return _overflow
	return _overflow - floori((t - 2.0 * REST - glide) * GLIDE_SPEED)


## Centred in the content box of the stylebox for the state the button is in, the way Button
## centres its own - the pressed styles have a taller top margin, so a pressed label sits lower.
func _draw_label() -> void:
	var box := _state_stylebox()
	var top := box.get_margin(SIDE_TOP)
	var room := size.y - top - box.get_margin(SIDE_BOTTOM)
	var y := top + (room - _line.get_size().y) / 2.0
	_line.draw(_window.get_canvas_item(), Vector2(-_scroll(), y), _colors[_state_color()])


## Button's own choice of stylebox and of label colour for each state.
func _state_stylebox() -> StyleBox:
	match get_draw_mode():
		DRAW_HOVER:
			return get_theme_stylebox("hover")
		DRAW_PRESSED:
			return get_theme_stylebox("pressed")
		DRAW_HOVER_PRESSED:
			return get_theme_stylebox("hover_pressed")
		DRAW_DISABLED:
			return get_theme_stylebox("disabled")
	return get_theme_stylebox("normal")


func _state_color() -> String:
	match get_draw_mode():
		DRAW_HOVER:
			return "font_hover_color"
		DRAW_PRESSED:
			return "font_pressed_color"
		DRAW_HOVER_PRESSED:
			return "font_hover_pressed_color"
		DRAW_DISABLED:
			return "font_disabled_color"
	return "font_focus_color" if has_focus(true) else "font_color"
