extends RefCounted
## Where every skill sits on the skill tree canvas.
##
## Computed from the graph rather than authored: a row in skill_catalog.gd already says what it
## requires, and that is enough to place it. So adding a skill never means picking pixel
## coordinates, and a rebalance that re-parents a node moves it on screen without anyone editing
## a position. The cost is that the tree is only as pretty as the rule below - a hand-placed tree
## can be prettier. If one ever has to be, the escape hatch is a "pos" key on the catalog row that
## overrides this; there is none today because nothing has needed one.
##
## Preloaded rather than autoloaded, like skill_catalog.gd: it owns no state, and a preloaded
## script parses under `--check-only` where an autoload identifier does not.
##
## Positions are node *centres*, in world pixels. skills_screen.gd works in the same space and
## opens the view centred on start_id().
##
## ## The rule
##
## A skill's row is one below the deepest skill it requires, so a node always sits under every one
## of its parents - the diamond where two branches meet lands below both of them rather than
## beside one. Within a row each node wants the average x of its parents; the row is then swept
## left to right to push overlapping nodes COLUMN_WIDTH apart, and shifted back so it stays
## centred on where its nodes wanted to be rather than drifting right as it spreads.

const Catalog := preload("res://src/skill_catalog.gd")

## Whole canvas pixels between the centres of neighbouring nodes. A node is 40x40 - see
## skill_node.gd - so these are the node plus the gap the edges are drawn through.
const COLUMN_WIDTH := 72.0
const ROW_HEIGHT := 64.0

## Canvas pixels between one tree's right edge and the next tree's left.
const TREE_GAP := 96.0


## Every positioned skill, keyed by id, across every tree in Catalog.TREE_IDS and laid out left to
## right in that order. A skill whose tree is not in TREE_IDS - which Catalog.validate() reports -
## gets no position and is missing here; the screen draws what is in this and nothing else.
static func positions() -> Dictionary:
	var out := {}
	var next_left := 0.0
	var first := true
	for tree in Catalog.TREE_IDS:
		var local := tree_positions(StringName(tree))
		if local.is_empty():
			continue
		var rect := bounds(local)
		# The first tree keeps its own origin, so the start node stays where tree_positions() put
		# it and does not shuffle sideways when a second tree is added to the left of it.
		var shift := 0.0 if first else next_left - rect.position.x
		for id in local:
			out[id] = local[id] + Vector2(shift, 0.0)
		next_left = rect.position.x + shift + rect.size.x + TREE_GAP
		first = false
	return out


## One tree's skills, keyed by id, with its first row centred on x = 0 and its first row at y = 0.
static func tree_positions(tree: StringName) -> Dictionary:
	var depth := depths(tree)
	var rows := {}
	for id in Catalog.ids_in_tree(tree):
		var row := int(depth.get(id, 0))
		if not rows.has(row):
			rows[row] = []
		rows[row].append(id)
	var ordered: Array = rows.keys()
	ordered.sort()
	var out := {}
	for row in ordered:
		# Rows top down, so a row's parents are all placed by the time it asks where they are.
		_place_row(rows[row], float(row) * ROW_HEIGHT, out)
	return out


## How many rows down each skill in the tree sits: one below the deepest skill it requires, and 0
## for a root. Requirements in another tree are ignored - they draw an edge between the two trees
## but say nothing about which row the node belongs in in this one.
static func depths(tree: StringName) -> Dictionary:
	var ids := Catalog.ids_in_tree(tree)
	var depth := {}
	for id in ids:
		depth[id] = 0
	# Relaxed until nothing moves. A chain of n skills settles in at most n passes, and that bound
	# is also what stops a requirement cycle - which Catalog.validate() reports rather than
	# prevents - from spinning here forever.
	for _pass in ids.size():
		var settled := true
		for id in ids:
			var deepest := -1
			for required in Catalog.requires(id):
				if depth.has(required):
					deepest = maxi(deepest, int(depth[required]))
			if deepest + 1 > int(depth[id]):
				depth[id] = deepest + 1
				settled = false
		if settled:
			break
	return depth


## The rectangle the given centres span, zero-sized for a single node and empty for no nodes.
## Centres only: a caller that wants the drawn extent grows it by half a node.
static func bounds(node_positions: Dictionary) -> Rect2:
	var rect := Rect2()
	var first := true
	for id in node_positions:
		var centre: Vector2 = node_positions[id]
		rect = Rect2(centre, Vector2.ZERO) if first else rect.expand(centre)
		first = false
	return rect


## The skill the tree opens on: the first root of the first tree that has one. Empty when no skill
## in the catalog is reachable, which Catalog.validate() reports.
static func start_id() -> String:
	for tree in Catalog.TREE_IDS:
		var roots := Catalog.roots(StringName(tree))
		if not roots.is_empty():
			return roots[0]
	return ""


## One row, written into `placed`. See the rule at the top of the file.
static func _place_row(ids: Array, y: float, placed: Dictionary) -> void:
	var wanted: Array = []
	for id in ids:
		wanted.append([_parent_centre(id, placed), id])
	# By x, then by id: siblings under one parent all want the same x, and falling back to
	# Dictionary order would order them by however the catalog rows happen to be written.
	wanted.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] < b[1] if is_equal_approx(a[0], b[0]) else a[0] < b[0])
	var xs := PackedFloat32Array()
	var x := 0.0
	for i in wanted.size():
		x = float(wanted[i][0]) if i == 0 else maxf(float(wanted[i][0]), x + COLUMN_WIDTH)
		xs.append(x)
	# What the sweep had to add, spread back over the whole row: a row that spread to fit grows
	# out of its middle rather than sliding away from the parents it hangs under.
	var drift := 0.0
	for i in wanted.size():
		drift += xs[i] - float(wanted[i][0])
	if not wanted.is_empty():
		drift /= float(wanted.size())
	for i in wanted.size():
		# Whole pixels: the canvas is 640x360 and a node drawn on a half pixel is a blurred node.
		placed[wanted[i][1]] = Vector2(round(xs[i] - drift), y)


## The average x of the parents already placed above `id`, and 0 for a root - or for a node whose
## every requirement is in another tree, which this tree cannot place it under.
static func _parent_centre(id: String, placed: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for required in Catalog.requires(id):
		if placed.has(required):
			total += float(placed[required].x)
			count += 1
	return 0.0 if count == 0 else total / float(count)
