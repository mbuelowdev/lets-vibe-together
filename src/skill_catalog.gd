extends RefCounted
## What skills exist: the tree each one hangs in, what it costs, what it requires, and what it
## does. Data and the queries over it, nothing else - this file never touches the running game.
##
## Preloaded rather than autoloaded (`const Catalog := preload("res://src/skill_catalog.gd")`):
## it owns no state, so there is nothing for a singleton to hold, and a preloaded script parses
## under `--check-only`, where an autoload identifier does not.
##
## The rows at the bottom are placeholder content: five nodes shaped so the skills screen has one
## of every state to draw against the 1337 rubles a new save starts with - a free root, a child
## that can be afforded, a sibling that cannot, a grandchild behind an unbought parent, and a
## capstone behind two branches at once. What is real about them is that shape, not their names or
## their prices; replace them when the trees are designed.
##
## Adding a skill is filling in a row here rather than writing code: pick an id, name it, name its
## tree, list what must already be unlocked, price it, and describe its effects. Where it lands on
## screen is not a decision - skill_tree_layout.gd reads it off the requirements. validate() says
## whether the result hangs together.
##
## ## Why the hierarchy lives here and not in the save
##
## A skill is two separate things, with two separate lifetimes. Its *shape* - where it sits in a
## tree, what it costs, what it unlocks next - is authored, ships in the build, and changes with
## the game. Whether the player has *bought* it is a single bit, theirs, and has to survive an
## update that moves the node somewhere else in the tree.
##
## So the tree is static data here, and GameState stores only the flat set of unlocked ids. A
## save that mirrored the hierarchy would freeze last patch's tree into the player's file and
## make every rebalance a migration; a flat set costs one line of save and re-reads its meaning
## from this file on every boot. See game_state.gd's note above _unlocked_skills.
##
## ## Skill ids
##
## SCREAMING_SNAKE, one per skill, unique across every tree, and stable once shipped - the id is
## what lands in the save file. Rank suffixes for a repeated bonus: MORE_MONEY_GAIN_1,
## MORE_MONEY_GAIN_2. Renaming a shipped id is a save migration (see SAVE_VERSION), so pick the
## boring name now.

## The trees, in the order the skills screen draws them. Every skill names one of these.
##
## One for now, holding every placeholder row below. A second tree is a name here plus rows naming
## it: skill_tree_layout.gd lays each tree out on its own and sets them side by side in this
## order, and a requirement that crosses from one to the other draws an edge between them.
const TREE_IDS: PackedStringArray = ["economy"]

## The three kinds of thing a skill can do, which is what the effects below are shaped around:
##
##   EFFECT_MODIFIER  a standing multiplier on some number - "money gains are 5% larger".
##                    {"kind": EFFECT_MODIFIER, "key": MOD_*, "amount": 0.05}
##                    `amount` is a fraction added to a bucket that starts at 0.0; two ranks of
##                    +0.05 make a x1.10 multiplier. See Skills.multiplier().
##
##   EFFECT_SCHEDULE  something that happens on a clock - "some rubles every 10 seconds".
##                    {"kind": EFFECT_SCHEDULE, "key": SCHEDULE_*, "every": 10.0,
##                     "payload": {...}}
##                    `payload` is optional and is handed to whatever implements the key; the
##                    runtime only keeps the clock. See Skills.register_schedule_handler().
##
##   EFFECT_FEATURE   a switch that turns a feature on for good - "a new taskbar icon".
##                    {"kind": EFFECT_FEATURE, "key": FEATURE_*}
##                    The feature's own code asks Skills.feature_enabled(key); nothing here
##                    knows what it turns on.
##
## A skill may carry any number of effects, of any mix of kinds: "MORE_MONEY_GAIN_1" is one
## modifier, but a capstone that pays a stipend *and* opens an app is a schedule and a feature
## on one row.
const EFFECT_MODIFIER := &"modifier"
const EFFECT_SCHEDULE := &"schedule"
const EFFECT_FEATURE := &"feature"

const EFFECT_KINDS: Array[StringName] = [EFFECT_MODIFIER, EFFECT_SCHEDULE, EFFECT_FEATURE]

## Modifier buckets. A key is declared here when the code that reads it exists, so validate()
## can catch a skill that modifies something nothing applies.
##
## MOD_MONEY_GAIN scales every ruble the player earns; Skills.grant_rubles() is the one path it
## is applied on.
const MOD_MONEY_GAIN := &"money_gain"

const MODIFIER_KEYS: Array[StringName] = [MOD_MONEY_GAIN]

## Schedule keys, declared by whichever script registers a handler for them, and feature keys,
## declared by whichever feature reads them. Both empty until the first skill needs one.
const SCHEDULE_KEYS: Array[StringName] = []
const FEATURE_KEYS: Array[StringName] = []

## Every skill in the game, keyed by id. A row looks like this:
##
##     "MORE_MONEY_GAIN_2": {
##         "name": "Money II",
##         "description": "Another 5% on every ruble you earn.",
##         "tree": &"economy",
##         "requires": ["MORE_MONEY_GAIN_1"],
##         "cost": 500,
##         "effects": [{"kind": EFFECT_MODIFIER, "key": MOD_MONEY_GAIN, "amount": 0.05}],
##     },
##
## `name` is what the skills screen draws under the node's art. It is the one field the player
## reads and nothing stores, so unlike an id it may be reworded freely. It is drawn into a 64px
## card at font size 12 - about ten characters - and a longer one is clipped rather than shrunk.
## The placeholder names below are plain text; a real one becomes a SKILL_* key in locale/ui.csv
## like every other string on screen, which the screen already runs through tr().
##
## `description` is the sentence the tree shows in the tooltip when the node is hovered, under
## the name and over the price. It is the only place a skill says what it does, so write what the
## effect is worth rather than restating the name. Both it and `name` are player-facing text with
## nothing stored against them, so both may be reworded freely.
##
## `requires` is every id that must already be unlocked, so a node with two parents is a list of
## two; an empty list is a root the player can buy first. Requirements may cross trees - that is
## how a tree gets gated behind another one - as long as the graph stays acyclic. `cost` is in
## rubles and may be 0 for a node that only exists to branch. Both keys, and `effects`, are
## optional: a missing one reads as empty, and an empty-effects skill is legal - it is a
## signpost on the way to its children.
const SKILLS := {
	# The root, and free: a tree has to start somewhere the player can reach without a balance.
	"START": {
		"name": "Start",
		"description": "Where the tree begins. Free, and opens everything below it.",
		"tree": &"economy",
		"cost": 0,
	},
	# Affordable from the first boot, so the tree has a node to demonstrate a purchase on.
	"MORE_MONEY_GAIN_1": {
		"name": "Money I",
		"description": "Every ruble you earn is 5% larger.",
		"tree": &"economy",
		"requires": ["START"],
		"cost": 250,
		"effects": [{"kind": EFFECT_MODIFIER, "key": MOD_MONEY_GAIN, "amount": 0.05}],
	},
	# Behind its rank 1, so it draws locked until that one is bought: the hierarchy, on screen.
	"MORE_MONEY_GAIN_2": {
		"name": "Money II",
		"description": "Another 5% on every ruble you earn.",
		"tree": &"economy",
		"requires": ["MORE_MONEY_GAIN_1"],
		"cost": 500,
		"effects": [{"kind": EFFECT_MODIFIER, "key": MOD_MONEY_GAIN, "amount": 0.05}],
	},
	# Reachable at once but priced above the starting balance, so the tree has a node drawing the
	# difference between "not yet" and "not affordable". No effects: a branch is a signpost.
	"PLACEHOLDER_BRANCH": {
		"name": "Branch",
		"description": "A placeholder. Does nothing on its own - it only opens the way on.",
		"tree": &"economy",
		"requires": ["START"],
		"cost": 2000,
	},
	# Two parents, one down each branch, so the layout and the all-not-any requirement rule both
	# have something to prove themselves on.
	"PLACEHOLDER_CAPSTONE": {
		"name": "Capstone",
		"description": "Needs both branches. Every ruble you earn is 10% larger.",
		"tree": &"economy",
		"requires": ["MORE_MONEY_GAIN_2", "PLACEHOLDER_BRANCH"],
		"cost": 1000,
		"effects": [{"kind": EFFECT_MODIFIER, "key": MOD_MONEY_GAIN, "amount": 0.1}],
	},
}


static func has(id: String) -> bool:
	return SKILLS.has(id)


## Every id in the catalog, sorted, so a screen or a check that walks the catalog gets the same
## order every run - Dictionary iteration order is insertion order, which is whatever the rows
## above happen to be in.
static func ids() -> PackedStringArray:
	var out: Array = SKILLS.keys()
	out.sort()
	return PackedStringArray(out)


## The whole row, or an empty Dictionary for an id the catalog does not carry - a save written
## by a build whose tree has since been re-cut. Callers read the row through the accessors
## below rather than indexing it, so a shape change lands in one place.
static func entry(id: String) -> Dictionary:
	return SKILLS.get(id, {})


## What the skills screen draws under the node, falling back to the id - which is legible, if
## ugly - for a row that forgot to name itself. validate() reports the one that did.
static func display_name(id: String) -> String:
	return String(entry(id).get("name", id))


## The sentence the tooltip shows. Empty for a row without one, which the tooltip simply leaves
## out rather than drawing a blank line for.
static func description(id: String) -> String:
	return String(entry(id).get("description", ""))


static func tree_of(id: String) -> StringName:
	return StringName(entry(id).get("tree", &""))


## The tree's skills, sorted like ids().
static func ids_in_tree(tree: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids():
		if tree_of(id) == tree:
			out.append(id)
	return out


## What must be unlocked before `id` can be. All of them, not any.
static func requires(id: String) -> PackedStringArray:
	return PackedStringArray(entry(id).get("requires", []))


## The other way down the edge: the skills that name `id` among their requirements, which is the
## set a screen draws lines to. Sorted, and computed rather than stored so the catalog only ever
## states an edge once.
static func unlocks(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for candidate in ids():
		if requires(candidate).has(id):
			out.append(candidate)
	return out


## The tree's entry points: its skills that require nothing. A tree with no roots is unreachable,
## which validate() reports.
static func roots(tree: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids_in_tree(tree):
		if requires(id).is_empty():
			out.append(id)
	return out


static func cost(id: String) -> int:
	return int(entry(id).get("cost", 0))


static func effects(id: String) -> Array:
	return entry(id).get("effects", [])


## Everything wrong with the catalog, one line each, empty when it hangs together. Cheap enough
## to run at boot - Skills does, and pushes each line as a warning - because a typo in a
## requirement id is otherwise a skill the player can simply never buy.
static func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for id in ids():
		var tree := tree_of(id)
		if tree == &"":
			problems.append("%s: no tree" % id)
		elif not TREE_IDS.has(String(tree)):
			problems.append("%s: unknown tree '%s'" % [id, tree])
		if String(entry(id).get("name", "")).is_empty():
			problems.append("%s: no name, so the tree draws its id" % id)
		if description(id).is_empty():
			problems.append("%s: no description, so its tooltip says nothing about it" % id)
		if cost(id) < 0:
			problems.append("%s: negative cost %d" % [id, cost(id)])
		for required in requires(id):
			if required == id:
				problems.append("%s: requires itself" % id)
			elif not has(required):
				problems.append("%s: requires unknown skill '%s'" % [id, required])
		problems.append_array(_effect_problems(id))
	problems.append_array(_cycle_problems())
	for tree in TREE_IDS:
		if not ids_in_tree(StringName(tree)).is_empty() and roots(StringName(tree)).is_empty():
			problems.append("tree '%s': no skill in it is reachable (every one has a requirement)" % tree)
	return problems


static func _effect_problems(id: String) -> PackedStringArray:
	var problems := PackedStringArray()
	for effect in effects(id):
		if typeof(effect) != TYPE_DICTIONARY:
			problems.append("%s: effect is not a dictionary" % id)
			continue
		var kind := StringName(effect.get("kind", &""))
		if not EFFECT_KINDS.has(kind):
			problems.append("%s: unknown effect kind '%s'" % [id, kind])
			continue
		var key := StringName(effect.get("key", &""))
		match kind:
			EFFECT_MODIFIER:
				if not MODIFIER_KEYS.has(key):
					problems.append("%s: nothing applies modifier '%s'" % [id, key])
				if not effect.has("amount"):
					problems.append("%s: modifier '%s' has no amount" % [id, key])
			EFFECT_SCHEDULE:
				if not SCHEDULE_KEYS.has(key):
					problems.append("%s: nothing handles schedule '%s'" % [id, key])
				if float(effect.get("every", 0.0)) <= 0.0:
					problems.append("%s: schedule '%s' needs a positive 'every'" % [id, key])
			EFFECT_FEATURE:
				if not FEATURE_KEYS.has(key):
					problems.append("%s: nothing reads feature '%s'" % [id, key])
	return problems


## Requirements point backwards through the tree, so following them from any skill has to end.
## A cycle would make every skill on it permanently unbuyable - each waiting on the next - which
## is invisible until someone tries to buy one.
##
## Iterative depth-first walk with three states per node: unvisited, on the current path (grey),
## and finished (black). An edge back onto the current path is the cycle.
static func _cycle_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	var finished := {}
	for start in ids():
		if finished.has(start):
			continue
		var on_path := {}
		# Each frame is [id, index of the next requirement to walk].
		var stack: Array = [[start, 0]]
		on_path[start] = true
		while not stack.is_empty():
			var frame: Array = stack[-1]
			var id: String = frame[0]
			var required := requires(id)
			if frame[1] >= required.size():
				stack.pop_back()
				on_path.erase(id)
				finished[id] = true
				continue
			var next: String = required[frame[1]]
			frame[1] += 1
			if not has(next) or finished.has(next):
				continue
			if on_path.has(next):
				problems.append("%s: requirement cycle through '%s'" % [id, next])
				finished[next] = true
				continue
			on_path[next] = true
			stack.append([next, 0])
	return problems
