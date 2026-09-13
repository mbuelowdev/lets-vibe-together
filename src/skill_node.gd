extends Button
## One skill in the tree: a bordered frame with the skill's art inside it.
##
## Spawned by skills_screen.gd, one per positioned skill in the catalog, and told which of the
## states below to draw whenever the unlocked set or the balance changes. It decides nothing.
## Whether a skill can be bought is Skills.lock_state()'s answer and pressing one only tells the
## screen it was pressed; no money is counted or spent anywhere in this file.
##
## A Button rather than something the screen draws and hit-tests itself, so the tree gets hover,
## focus, keyboard and gamepad activation from the framework: the player can tab through the nodes
## and buy one with ui_accept without ever touching the mouse, and the screen only has to move the
## view to keep up (see skills_screen.gd's _bring_into_view()). The themed stylebox is overridden
## away - it is a chunky 32px-tall window button, and this is a framed icon - so everything a node
## shows is drawn in _draw() below.
##
## ## No text on the node
##
## A node carries no name and no price; the tooltip the screen raises on hover says both. The
## card is a framed icon, and the name, effect and price would all fight the art for the same
## forty pixels.
##
## ## The art is a placeholder
##
## Every node draws the same crossed box where its art will go, the way the CS2 stages draw their
## names where their gifs will go. The box is already the size the art will be, ART_SIZE square,
## so dropping real art in moves nothing else on the canvas.

## The four ways a node can read. Three are about buying it, and with no text on the card the
## colours carry all three on their own: BOUGHT lights up in the palette's blue, BUYABLE is dark
## behind a white edge, UNBUYABLE is the same dark behind a red one. The fourth is the hierarchy -
## a node whose requirements are not met yet is not priced at all, it is dimmed back towards the
## app's green until the nodes above it are bought.
##
## This is Skills.Lock collapsed onto what is drawn: Lock.ALREADY is BOUGHT, Lock.NONE is BUYABLE,
## Lock.COST is UNBUYABLE, and everything left - an unmet requirement, or an id this build's
## catalog does not carry - is LOCKED. The screen does that mapping; this file only draws.
enum State {
	BOUGHT,
	BUYABLE,
	UNBUYABLE,
	LOCKED,
}

## The state names, indexed by State.
const STATE_NAMES: PackedStringArray = ["bought", "buyable", "unbuyable", "locked"]

## The frame, and the art inside it. FRAME_INSET is the border's room: one pixel of it is the line
## drawn today, and the rest is what a heavier border - one that varies with the skill's price -
## has to grow into without moving the art or the layout.
const ART_SIZE := 32
const FRAME_INSET := 4
const WIDTH := ART_SIZE + FRAME_INSET * 2
const HEIGHT := WIDTH

## How far inside the art box the placeholder cross is drawn.
const PLACEHOLDER_INSET := 6.0

## Every stylebox slot Button draws a background from. All of them are emptied: the frame below is
## drawn instead, and a slot left alone would put the window-button bevel back under one state.
const STYLEBOX_SLOTS: PackedStringArray = ["normal", "hover", "pressed", "focus", "disabled"]

## What each state draws in. The node sits on the Skills app's green (#3f6b3a), so the fills are
## the palette's navy and blue rather than anything that would sink into it, and LOCKED is a
## deliberately desaturated near-green: an unreachable node should recede into the background
## without disappearing from it.
##
## UNBUYABLE's red is the palette's #6e3a3a lifted until it reads as a colour rather than as a
## dark edge at 1px on navy. It is the node's only difference from BUYABLE, so it has to carry the
## whole message on its own.
const STATE_COLORS := {
	State.BOUGHT: {
		"fill": Color("#2e4272"),
		"border": Color("#ffffff"),
		"mark": Color("#6a86c8"),
	},
	State.BUYABLE: {
		"fill": Color("#1b2838"),
		"border": Color("#ffffff"),
		"mark": Color("#7d8fa3"),
	},
	State.UNBUYABLE: {
		"fill": Color("#1b2838"),
		"border": Color("#a35c5c"),
		"mark": Color("#7a4a4a"),
	},
	State.LOCKED: {
		"fill": Color("#23302a"),
		"border": Color("#4a5f45"),
		"mark": Color("#33453a"),
	},
}

## Hairline the frame, art box and placeholder cross are drawn at.
const STROKE := 1.0

var _state: int = State.LOCKED


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	for slot in STYLEBOX_SLOTS:
		add_theme_stylebox_override(slot, StyleBoxEmpty.new())
	# The node is drawn differently under the pointer and under focus, and neither of those
	# redraws a Button whose every stylebox is empty.
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func state() -> int:
	return _state


func state_name() -> String:
	return STATE_NAMES[_state]


func set_state(to: int) -> void:
	if to == _state:
		return
	_state = to
	queue_redraw()


func _draw() -> void:
	var colors: Dictionary = STATE_COLORS[_state]
	var frame := Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT))
	draw_rect(frame, colors["fill"], true)
	draw_rect(frame, colors["border"], false, STROKE)
	var art := frame.grow(-FRAME_INSET)
	draw_rect(art, colors["mark"], false, STROKE)
	var cross := art.grow(-PLACEHOLDER_INSET)
	draw_line(cross.position, cross.end, colors["mark"], STROKE)
	draw_line(Vector2(cross.position.x, cross.end.y), Vector2(cross.end.x, cross.position.y), colors["mark"], STROKE)
	# One ring outside the frame under the pointer or the focus, rather than a different fill: the
	# fill is what says whether the node is bought, and hover must not be able to fake that.
	if is_hovered() or has_focus():
		draw_rect(frame.grow(STROKE), colors["border"], false, STROKE)
