extends Control
## The Skills app: the skill tree, on a canvas the player drags.
##
## The tree is far larger than the 640x360 it is drawn on and only ever will be larger, so the
## screen is a window onto it rather than a picture of it. `World` holds every node at the
## position skill_tree_layout.gd computed; the window is `World.position` (the pan), and
## `Viewport` clips what falls outside. Nothing is culled or re-laid-out as the view moves - a
## tree is tens of nodes, not thousands, and the clip is free.
##
## Opening the app centres the view on the start node every time. A player who cannot find the
## tree they left has no way back to it - there is no minimap and no recentre button - so the app
## always opens somewhere known. When trees get big enough that losing your place matters more
## than finding the start does, this is the line to change.
##
## ## The tooltip
##
## The nodes carry no text at all - see skill_node.gd - so this tooltip is the only place a skill
## is named, described or priced, and it is raised the moment the pointer, or the keyboard focus,
## lands on a node. It is this screen's own panel rather than Godot's tooltip, for two reasons:
## Godot's waits out a dwell delay before it appears, and it is a Window, drawn outside the
## 640x360 canvas and so at the wrong scale for everything around it.
##
## A node whose parents are not bought yet is a spoiler: the tree is on screen but what it does
## is not. Those tooltips say only ??? until every parent is bought, which is the frontier the
## player can actually reach. Bought, buyable and unbuyable (too expensive) all show the real
## name, because those are the next unlockable nodes, not the ones behind them.
##
## Being outside `World` it is never panned with the tree, so its 12px text stays put as the
## canvas moves under it.
##
## ## What this screen is allowed to decide
##
## Nothing about money or unlocking. It asks Skills.lock_state() how to draw each node and calls
## Skills.unlock() when one is pressed; the price, the prerequisites and the spend are all behind
## that one call. It reads GameState only to format a price and to know when to redraw.
##
## ## Dragging and clicking with the same button
##
## Both are the left button, and a tree is dragged far more often than it is bought from, so a
## press that travels more than DRAG_SLOP before it is released is a drag and buys nothing - even
## when it started on a node. That is why the nodes' `gui_input` is wired to the same handler as
## the background's: while a button is held, Godot sends motion to the control that was pressed,
## so a drag that starts on a node is only visible from the node.

const Catalog := preload("res://src/skill_catalog.gd")
const Layout := preload("res://src/skill_tree_layout.gd")
const SkillNode := preload("res://src/skill_node.gd")

## Canvas pixels the pointer may travel between press and release and still count as a click.
const DRAG_SLOP := 3.0

## How far past the outermost node the centre of the view may be pushed. Small enough that the
## tree can never be panned off the screen and lost, large enough that a node on the edge can be
## brought away from it to be read.
const PAN_MARGIN := 80.0

## Whole pixels of clearance left around a node the view is scrolled to. See _bring_into_view().
const FOCUS_MARGIN := 8.0

## How far past the outermost node centre the edge layer's rectangle reaches. The lines run
## between centres, so they fit without it; the margin is there so a one-node tree's layer is not
## zero-sized. See _frame_edges().
const EDGE_FRAME_MARGIN := 64.0

## Canvas pixels between a node's card and the tooltip beside it.
const TOOLTIP_GAP := 6.0

## What a locked node's tooltip says until its parents are bought. Same glyph in every locale:
## it is a mask, not a word.
const HIDDEN_KEY := "SKILLS_HIDDEN"

## The price line, coloured by whether the player can pay it. The red is value_change_popup.gd's
## LOSS_COLOR, so the price you cannot meet is the same red as money leaving the taskbar. Locked
## nodes hide the price behind ???, so the dim grey is only a fallback if a price is shown anyway.
const TIP_PRICE_BUYABLE := Color("#ffffff")
const TIP_PRICE_UNBUYABLE := Color("#ff5c5c")
const TIP_PRICE_LOCKED := Color("#93a08c")

## The edges, drawn under the nodes. An edge is lit by what it leads to rather than by what it
## costs: white once the child is bought, pale while the parent is bought and the child is
## therefore reachable, and a darker green than the app's background while it is neither.
const EDGE_TAKEN := Color("#ffffff")
const EDGE_OPEN := Color("#b9d4b2")
const EDGE_CLOSED := Color("#33562f")

## Hairline the edges are drawn at, in canvas pixels. One screen pixel at 1:1.
const EDGE_WIDTH := 1.0

var _viewport: Control
var _world: Control
var _edges: Control
var _node_layer: Control
var _game_state: Node
var _skills: Node
var _tooltip: PanelContainer
var _tip_name: Label
var _tip_description: Label
var _tip_price: Label

## The skill the tooltip is up for, or empty when it is down, and whether the focus raised it
## rather than the pointer. Clicking a node focuses it, so without knowing which route put the
## tooltip there, one raised by the pointer would stay up after the pointer had gone.
var _tip_id := ""
var _tip_by_focus := false

## Node centres in world pixels, keyed by skill id, straight from Layout.positions().
var _positions: Dictionary = {}

## The spawned nodes, keyed by the same ids.
var _nodes: Dictionary = {}

## Where the view may be centred, in world pixels: the nodes' extent grown by PAN_MARGIN.
var _pan_bounds := Rect2()

## World.position, unrounded. The node is drawn on whole pixels but the pan is accumulated at full
## precision, so a slow drag does not lose the fractions it is made of.
var _pan := Vector2.ZERO

var _dragging := false
var _drag_last := Vector2.ZERO

## Canvas pixels travelled since the left button went down, which is what tells a click from a
## drag once it comes back up.
var _drag_travel := 0.0


func _ready() -> void:
	_viewport = $Viewport
	_world = $Viewport/World
	_edges = $Viewport/World/Edges
	_node_layer = $Viewport/World/Nodes
	_tooltip = $Tooltip
	_tip_name = $Tooltip/Margin/Lines/TipName
	_tip_description = $Tooltip/Margin/Lines/TipDescription
	_tip_price = $Tooltip/Margin/Lines/TipPrice
	_game_state = get_node_or_null("/root/GameState")
	_skills = get_node_or_null("/root/Skills")
	_edges.draw.connect(_draw_edges)
	_viewport.gui_input.connect(_on_view_input.bind(_viewport))
	_viewport.resized.connect(_on_viewport_resized)
	visibility_changed.connect(_on_visibility_changed)
	if _game_state != null:
		_game_state.unlocked_skills_changed.connect(_on_unlocked_skills_changed)
		# Affordability is half of what a node draws, so the tree redraws when the balance moves
		# and not only when something is bought.
		_game_state.rubles_changed.connect(_on_rubles_changed)
	_build()
	# Deferred: Viewport's size comes from the layout pass, which has not run yet.
	center_on_start.call_deferred()


## Put the start node back in the middle of the window.
func center_on_start() -> void:
	var start := Layout.start_id()
	_center_on(_positions.get(start, Vector2.ZERO))


## One node per positioned skill, wired to this screen. The catalog is static, so this runs once:
## an unlock changes what a node draws, never which nodes exist.
func _build() -> void:
	_positions = Layout.positions()
	for id in Catalog.ids():
		if not _positions.has(id):
			continue
		var node: Button = SkillNode.new()
		# Named for the skill, so `focusedControl` on the bridge reads back as the skill id.
		node.name = id
		_node_layer.add_child(node)
		node.position = (_positions[id] - node.size * 0.5).round()
		node.pressed.connect(_on_node_pressed.bind(id))
		node.mouse_entered.connect(_show_tooltip.bind(id, false))
		node.mouse_exited.connect(_hide_tooltip.bind(id, false))
		node.focus_entered.connect(_on_node_focused.bind(id))
		node.focus_exited.connect(_hide_tooltip.bind(id, true))
		# See the note on dragging at the top of the file.
		node.gui_input.connect(_on_view_input.bind(node))
		_nodes[id] = node
	_pan_bounds = Layout.bounds(_positions).grow(PAN_MARGIN)
	_frame_edges()
	_refresh()


## Give the edge layer a rectangle that covers every line it draws.
##
## A CanvasItem is culled by its own rect, and anything drawn outside that rect is culled with it.
## Left at its default size the layer was a 40x40 square at the world origin, so panning that one
## corner off the screen took every connection in the tree with it, wherever the lines themselves
## were. Sizing the layer to the tree fixes that at the source; _draw_edges() then works in the
## layer's space rather than the world's.
func _frame_edges() -> void:
	var frame := Layout.bounds(_positions).grow(EDGE_FRAME_MARGIN)
	_edges.position = frame.position
	_edges.size = frame.size


func _price_text(id: String) -> String:
	var cost := Catalog.cost(id)
	if cost <= 0 or _game_state == null:
		return ""
	return _game_state.format_rubles(cost)


## Redrawn from the whole tree rather than from the change: unlocking one node can relight several
## others that were waiting on it, and paying for it can price a third out of reach.
func _refresh() -> void:
	for id in _nodes:
		_nodes[id].set_state(_state_of(id))
	_edges.queue_redraw()
	# A purchase repaints the node under the pointer, so the tooltip over it has to follow: the
	# price it was showing has just been paid.
	_update_tooltip()


## How a node should draw, which is Skills.lock_state() collapsed onto SkillNode.State. One call
## per node: it is the same answer unlock() will give, so what the player sees and what they get
## cannot disagree.
func _state_of(id: String) -> int:
	if _skills == null:
		return SkillNode.State.LOCKED
	var lock: int = _skills.lock_state(id)
	if lock == _skills.Lock.ALREADY:
		return SkillNode.State.BOUGHT
	if lock == _skills.Lock.NONE:
		return SkillNode.State.BUYABLE
	if lock == _skills.Lock.COST:
		return SkillNode.State.UNBUYABLE
	return SkillNode.State.LOCKED


func _on_unlocked_skills_changed(_skill_ids: PackedStringArray) -> void:
	_refresh()


func _on_rubles_changed(_rubles: int) -> void:
	_refresh()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		# Deferred for the same reason as in _ready(): on the frame the app is selected the
		# window has not been laid out yet, so its middle is not known.
		center_on_start.call_deferred()


func _on_viewport_resized() -> void:
	# The window changed shape around a fixed pan, which may have left the tree outside it.
	_set_pan(_pan)


## A node was pressed. The only place in the game an unlock is asked for.
func _on_node_pressed(id: String) -> void:
	if _drag_travel > DRAG_SLOP:
		# The press ended a drag: the player was moving the tree, not buying this. See
		# _forget_drag() for why this cannot be left over from an older one.
		return
	if _skills == null:
		return
	# The refusal that counts. lock_state() has already dimmed or priced this node, but a
	# scheduled payout or another purchase can move the balance between that redraw and this
	# click, so what is drawn is a hint and this is the gate. A refusal changes nothing and needs
	# no redraw; a purchase emits unlocked_skills_changed, which lands in _refresh().
	_skills.unlock(id)


## Left drag to pan. Connected to the background and to every node - see the note on dragging at
## the top of the file.
func _on_view_input(event: InputEvent, source: Control) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_dragging = false
				# A node pressed under this release emits `pressed` from it, so the travel has to
				# outlive the release - and no longer than that. ui_accept on a focused node
				# arrives with no press behind it and must not inherit the last drag's distance.
				_forget_drag.call_deferred()
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			_drag_last = _pointer(button, source)
			_drag_travel = 0.0
	elif event is InputEventMouseMotion and _dragging:
		var here := _pointer(event as InputEventMouseMotion, source)
		var moved := here - _drag_last
		_drag_last = here
		_drag_travel += moved.length()
		_set_pan(_pan + moved)


## Where the pointer is, in window pixels - out of the event, and through the transform of the
## control the event was delivered to, which is why that control is bound into the connection. An
## event's position is in the receiving control's own space, and a node's space is the world's;
## the background's is the window's already.
##
## Not Control.get_local_mouse_position(): on the root viewport that is read back off the OS
## cursor rather than off the event, so nothing driven by synthetic input would move the view.
func _pointer(event: InputEventMouse, source: Control) -> Vector2:
	var into_window := _viewport.get_global_transform().affine_inverse() * source.get_global_transform()
	return into_window * event.position


func _forget_drag() -> void:
	_drag_travel = 0.0


## Put `point` - a world position - in the middle of the window.
func _center_on(point: Vector2) -> void:
	_set_pan(_viewport.size * 0.5 - point)


## The pan, clamped so the middle of the window stays over the tree, and written to the world on
## whole pixels: a card drawn on a half pixel is a blurred card.
func _set_pan(to: Vector2) -> void:
	_pan = _clamp_pan(to)
	_world.position = _pan.round()
	if not _tip_id.is_empty():
		_place_tooltip(_nodes[_tip_id])


## `to` with the view centre held inside _pan_bounds. The centre rather than the edges, because
## clamping the edges of a tree smaller than the window would fight with centring it.
func _clamp_pan(to: Vector2) -> Vector2:
	var middle := _viewport.size * 0.5
	# pan = middle - centre, so the bounds on the centre invert into bounds on the pan.
	var low := middle - _pan_bounds.end
	var high := middle - _pan_bounds.position
	return Vector2(clampf(to.x, low.x, high.x), clampf(to.y, low.y, high.y))


## Where a node is drawn, in window pixels.
func _screen_rect(node: Control) -> Rect2:
	return Rect2(node.position + _pan, node.size)


## Focus lands on a node: bring it into view first, then raise its tooltip over where it ended up.
##
## A click focuses the node the pointer is already over, and that tooltip belongs to the pointer -
## it has to come down when the pointer leaves, not when the focus does. So only focus that
## arrives on its own claims the tooltip as the keyboard's.
func _on_node_focused(id: String) -> void:
	_bring_into_view(id)
	_show_tooltip(id, not _nodes[id].is_hovered())


## Raise the tooltip over `id`, at once - a dwell delay is time spent not answering the question
## the player already asked by pointing at the node. The pointer arriving over a focused node
## takes it over, because the pointer is the more recent of the two.
func _show_tooltip(id: String, by_focus: bool) -> void:
	_tip_id = id
	_tip_by_focus = by_focus
	_update_tooltip()


## Taken down only by the node it is up for, and only by the route that raised it: the pointer
## leaving one node as it arrives at the next arrives in either order, and a click both presses a
## node and focuses it, so a tooltip the pointer raised must not outlive the pointer just because
## the click left the focus behind.
func _hide_tooltip(id: String, by_focus: bool) -> void:
	if _tip_id != id or by_focus != _tip_by_focus:
		return
	_tip_id = ""
	_tooltip.visible = false


## Fill the tooltip from the catalog and put it beside its node. Re-run whenever what it says or
## where it points could have changed: a purchase, or a pan.
func _update_tooltip() -> void:
	if _tip_id.is_empty() or not _nodes.has(_tip_id):
		_tooltip.visible = false
		return
	var node: Button = _nodes[_tip_id]
	var state: int = node.state()
	# The locale's language tag, so the text server shapes the glyphs the locale expects - see
	# main_menu.gd. Read on every raise rather than cached: the settings screen can change the
	# locale while the desktop is up behind it.
	var language := TranslationServer.get_locale().get_slice("_", 0)
	_tip_name.language = language
	_tip_description.language = language
	_tip_price.language = language
	if state == SkillNode.State.LOCKED:
		# Behind an unbought parent: name, effect and price would all say what the node is.
		_tip_name.text = tr(HIDDEN_KEY)
		_tip_description.visible = false
		_tip_price.visible = false
	else:
		_tip_name.text = tr(Catalog.display_name(_tip_id))
		_tip_description.text = tr(Catalog.description(_tip_id))
		_tip_description.visible = not _tip_description.text.is_empty()
		var price := _price_text(_tip_id)
		# A bought skill has nothing left to pay and a free one never had anything, and a price
		# line either way would be a number with no question attached to it.
		_tip_price.visible = not price.is_empty() and state != SkillNode.State.BOUGHT
		_tip_price.text = price
		_tip_price.add_theme_color_override("font_color", _tip_price_color(state))
	# The panel is sized by the text that has just changed under it.
	_tooltip.reset_size()
	_place_tooltip(node)
	_tooltip.visible = true


func _tip_price_color(state: int) -> Color:
	if state == SkillNode.State.BUYABLE:
		return TIP_PRICE_BUYABLE
	return TIP_PRICE_UNBUYABLE if state == SkillNode.State.UNBUYABLE else TIP_PRICE_LOCKED


## Beside the node, kept on the canvas. Its top edge is the node's, so the tooltip does not jump
## as its own height settles, and it flips to the node's left rather than running off the right.
## The window is the same rectangle the tree is clipped to, so a tooltip never covers the taskbar.
func _place_tooltip(node: Control) -> void:
	var anchor := _screen_rect(node)
	var window := _viewport.size
	var size := _tooltip.size
	var at := Vector2(anchor.end.x + TOOLTIP_GAP, anchor.position.y)
	if at.x + size.x > window.x:
		at.x = anchor.position.x - TOOLTIP_GAP - size.x
	at.x = clampf(at.x, 0.0, maxf(0.0, window.x - size.x))
	at.y = clampf(at.y, 0.0, maxf(0.0, window.y - size.y))
	_tooltip.position = at.round()


## Keyboard and gamepad players move between nodes by focus, and focus moves to nodes that are off
## the side of the window as happily as to ones that are on it. This slides the view the least it
## can to bring the focused node back inside, so tabbing through the tree walks the view along
## with it instead of leaving it behind.
func _bring_into_view(id: String) -> void:
	var node: Control = _nodes.get(id)
	if node == null:
		return
	var rect := _screen_rect(node).grow(FOCUS_MARGIN)
	var shift := Vector2(
		_axis_shift(rect.position.x, rect.end.x, _viewport.size.x),
		_axis_shift(rect.position.y, rect.end.y, _viewport.size.y),
	)
	if shift != Vector2.ZERO:
		_set_pan(_pan + shift)


## How far one axis has to move to bring [low, high] inside [0, extent]: 0 when it is already
## there, and for a rect larger than the window the move that puts its near edge on the window's.
static func _axis_shift(low: float, high: float, extent: float) -> float:
	if low < 0.0:
		return -low
	if high > extent:
		return extent - high
	return 0.0


## Every requirement, as a line from the parent's centre into the child's. Drawn on the layer
## under the nodes, so each line disappears under the two cards it joins.
##
## Elbows rather than diagonals - down out of the parent, across, down into the child. On a
## nearest-filtered pixel canvas a diagonal is a staircase that crawls as the tree is panned;
## horizontal and vertical runs stay put.
func _draw_edges() -> void:
	# World positions into the edge layer's own space - see _frame_edges().
	var origin := _edges.position
	for id in _nodes:
		var to: Vector2 = _positions[id] - origin
		for required in Catalog.requires(id):
			if not _positions.has(required):
				# A requirement in no tree, which Catalog.validate() reports at boot. There is
				# nowhere to draw the line from.
				continue
			_draw_edge(_positions[required] - origin, to, _edge_color(required, id))


func _draw_edge(from: Vector2, to: Vector2, color: Color) -> void:
	var turn := (from.y + to.y) * 0.5
	var width := EDGE_WIDTH
	_edges.draw_line(from, Vector2(from.x, turn), color, width)
	if not is_equal_approx(from.x, to.x):
		_edges.draw_line(Vector2(from.x, turn), Vector2(to.x, turn), color, width)
	_edges.draw_line(Vector2(to.x, turn), to, color, width)


func _edge_color(from: String, to: String) -> Color:
	if _skills == null:
		return EDGE_CLOSED
	if _skills.is_unlocked(to):
		return EDGE_TAKEN
	return EDGE_OPEN if _skills.is_unlocked(from) else EDGE_CLOSED
