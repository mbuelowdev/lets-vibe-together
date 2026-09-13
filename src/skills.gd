extends Node
## What the player's unlocked skills actually do.
##
## Registered as the `Skills` autoload, after `GameState`: this reads the unlocked set from
## there and GameState knows nothing about it, so the dependency only ever points one way.
## Autoload identifiers are undefined under `--check-only`, so reach it as
## `get_node("/root/Skills")` from gameplay scripts rather than the bare `Skills`.
##
## Three kinds of effect, because the skills the trees are being built around are three kinds of
## thing, and each needs a different shape of support from the engine underneath:
##
##   a modifier - "money gains are 5% larger"      multiplier(MOD_MONEY_GAIN), applied on the
##                                                 one path every gain goes through
##   a schedule - "some rubles every 10 seconds"   a clock this node runs, calling a handler the
##                                                 feature registers
##   a feature  - "a new taskbar icon"             a flag the feature's own code asks about
##
## skill_catalog.gd holds the rows; this file holds none of the data and all of the behaviour.
## Adding a *kind* of effect is work here. Adding a skill is not.
##
## ## Rebuilt, never accumulated
##
## Every change to the unlocked set throws the whole runtime away and recomputes it from the set
## - _rebuild(). Applying an unlock incrementally would be less work per unlock and would need a
## matching un-apply for every path that takes a skill back: loading a save over a running game,
## reset(), an egon scenario, a respec later. One recompute has no inverse to get wrong, and the
## sets involved are a handful of rows.
##
## Only the schedules carry anything across a rebuild, and only their clocks; see _rebuild().

## The effect table changed: a skill was unlocked, a save was loaded, progress was reset. UI that
## draws a bonus or a feature's state redraws on this rather than polling.
signal effects_changed

## A schedule came due. Carries the catalog's payload for the key, untouched. Whatever implements
## the key can listen here or register a handler; see register_schedule_handler().
signal schedule_fired(key: StringName, payload: Dictionary)

const Catalog := preload("res://src/skill_catalog.gd")

## Why a skill cannot be unlocked right now, which is also what a locked node in the tree needs
## to draw: dimmed for REQUIREMENTS, priced in red for COST. NONE means unlock() would take it.
enum Lock {
	NONE,
	## No such id in the catalog. A save from a build whose tree has been re-cut can hold one.
	UNKNOWN,
	ALREADY,
	REQUIREMENTS,
	COST,
}

## Most schedule ticks a single frame may pay out. A frame that ran long - a stall, a tab the
## browser stopped rendering - would otherwise pay a whole backlog at once, and a schedule whose
## handler is slow could feed itself. Past this the leftover time is dropped rather than banked:
## a skill that pays every 10 seconds pays for time the player was *playing*.
const MAX_CATCH_UP_TICKS := 4

var _game_state: Node

## Summed modifier amounts, keyed by MOD_*. Absent means nobody modifies it, which reads as 0.0
## and a x1.0 multiplier.
var _modifiers: Dictionary = {}

## Enabled feature keys, as a set.
var _features: Dictionary = {}

## Running schedules, keyed by SCHEDULE_*: {"every": float, "payload": Dictionary, "elapsed":
## float}. Only what is unlocked is in here, so _process is off entirely until a skill starts a
## clock.
var _schedules: Dictionary = {}

## Handlers registered by the features that implement the schedule keys, keyed the same way.
var _handlers: Dictionary = {}

## Schedule keys already complained about, so a key with nothing listening warns once instead of
## every time it comes due.
var _unhandled_warned: Dictionary = {}


func _ready() -> void:
	# A tree that does not hang together is a skill the player can never buy or a bonus nothing
	# applies, neither of which shows up on screen. Warn at boot, where it is one glance.
	for problem in Catalog.validate():
		push_warning("Skills: catalog problem - %s" % problem)
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		push_error("Skills: GameState autoload is missing; no skill effects will apply")
		return
	# GameState's _ready() has already loaded the save - it is declared first in [autoload] - so
	# this first build sees the player's real set rather than an empty one.
	_game_state.unlocked_skills_changed.connect(_on_unlocked_skills_changed)
	_rebuild()


## Buy `id`: spend its cost and record it. True when the player now has it.
##
## The one place an unlock may happen from, so the price is charged exactly once and nothing can
## record a skill whose requirements are not met. The affordability check and the spend are both
## GameState's, and lock_state() runs before either, so a refused purchase leaves the balance
## alone. Recording it emits GameState.unlocked_skills_changed, which lands in _rebuild().
func unlock(id: String) -> bool:
	if lock_state(id) != Lock.NONE:
		return false
	var price := Catalog.cost(id)
	if price > 0 and not _game_state.spend_rubles(price):
		return false
	return _game_state.unlock_skill(id)


## Why `id` is not buyable, or Lock.NONE if it is. Checked in the order a player reads a node:
## does it exist, do I have it, can I reach it, can I pay for it.
func lock_state(id: String) -> Lock:
	if not Catalog.has(id):
		return Lock.UNKNOWN
	if is_unlocked(id):
		return Lock.ALREADY
	if not requirements_met(id):
		return Lock.REQUIREMENTS
	if _game_state == null or not _game_state.can_afford(Catalog.cost(id)):
		return Lock.COST
	return Lock.NONE


func can_unlock(id: String) -> bool:
	return lock_state(id) == Lock.NONE


func is_unlocked(id: String) -> bool:
	return _game_state != null and _game_state.is_skill_unlocked(id)


## All of a skill's requirements, not any: a node with two parents needs both. A skill with none
## is a root and is always reachable.
func requirements_met(id: String) -> bool:
	for required in Catalog.requires(id):
		if not is_unlocked(required):
			return false
	return true


## The buyable frontier: not unlocked, requirements met, affordable or not. What a tree screen
## lights up, and what "affordable or not" costs it is one lock_state() call per node to tell
## the two apart.
func available_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in Catalog.ids():
		if not is_unlocked(id) and requirements_met(id):
			out.append(id)
	return out


## The player's set, sorted, straight from GameState - including ids this build's catalog no
## longer carries. unlocked_catalog_ids() is the same list with those dropped.
func unlocked_ids() -> PackedStringArray:
	return PackedStringArray() if _game_state == null else _game_state.unlocked_skills()


func unlocked_catalog_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in unlocked_ids():
		if Catalog.has(id):
			out.append(id)
	return out


## Summed bonus for a modifier bucket: 0.0 when no unlocked skill touches it.
func modifier_bonus(key: StringName) -> float:
	return float(_modifiers.get(key, 0.0))


## The bucket as the factor to multiply by. Ranks stack additively - two skills worth +0.05 each
## make x1.10, not x1.1025 - because a tree of ten ranks compounds into a number nobody can price
## against, and "+5% per rank" is what the node will say on screen.
func multiplier(key: StringName) -> float:
	return 1.0 + modifier_bonus(key)


## `amount` scaled by a bucket, rounded to whole units. The currency is whole rubles, so a bonus
## smaller than half a ruble rounds away: +5% pays nothing on a 1-ruble gain and 1 on a 10-ruble
## one. That is the cost of an integer currency, and it is why income is worth granting in
## meaningful lumps rather than a ruble at a time.
func apply_multiplier(key: StringName, amount: int) -> int:
	return int(round(float(amount) * multiplier(key)))


## Income. Every ruble the player *earns* should come through here rather than through
## GameState.add_rubles(), which is the raw mutator and applies no bonus - a match payout, a
## scheduled stipend, a sale. Returns what was actually paid, bonus included, so a caller that
## wants to tell the player what they got does not have to redo the arithmetic.
##
## Refunds, corrections and fines are not income and belong on add_rubles(): a 5% money bonus
## should not quietly inflate a refund.
func grant_rubles(amount: int) -> int:
	if amount <= 0 or _game_state == null:
		return 0
	var granted := apply_multiplier(Catalog.MOD_MONEY_GAIN, amount)
	_game_state.add_rubles(granted)
	return granted


func feature_enabled(key: StringName) -> bool:
	return _features.has(key)


## Every enabled feature key, sorted. Strings rather than StringNames: this is what the egon
## bridge reports, and it has to be JSON-safe.
func enabled_features() -> PackedStringArray:
	var out: Array = []
	for key in _features:
		out.append(String(key))
	out.sort()
	return PackedStringArray(out)


## Point a schedule key at the code that implements it. The runtime owns the clock and knows
## nothing about what the key does; the feature owns the behaviour and knows nothing about which
## skill turned it on.
##
## Safe to call before any skill has started that schedule - registration and unlocking are
## independent, and a handler for a key nobody has unlocked simply never fires. One handler per
## key: registering a second replaces the first, which is what a reload of the feature's scene
## wants.
func register_schedule_handler(key: StringName, handler: Callable) -> void:
	_handlers[key] = handler
	_unhandled_warned.erase(key)


func unregister_schedule_handler(key: StringName) -> void:
	_handlers.erase(key)


## The schedules currently running, sorted. JSON-safe, like enabled_features().
func active_schedules() -> PackedStringArray:
	var out: Array = []
	for key in _schedules:
		out.append(String(key))
	out.sort()
	return PackedStringArray(out)


## Seconds between ticks of a running schedule, or 0.0 when it is not running.
func schedule_interval(key: StringName) -> float:
	if not _schedules.has(key):
		return 0.0
	return float(_schedules[key]["every"])


## Seconds until the next tick, or -1.0 when the schedule is not running. For a UI that counts
## down to the next payout, and for a check that wants to wait for one.
func seconds_until(key: StringName) -> float:
	if not _schedules.has(key):
		return -1.0
	var entry: Dictionary = _schedules[key]
	return maxf(0.0, float(entry["every"]) - float(entry["elapsed"]))


## Runs only while something is scheduled; _rebuild() switches it off again when nothing is.
##
## Clocks are advanced for every schedule first and the due ones fired afterwards, because a
## handler may unlock a skill - which rebuilds _schedules out from under this loop.
func _process(delta: float) -> void:
	var due: Array[StringName] = []
	for key in _schedules:
		var entry: Dictionary = _schedules[key]
		var every := float(entry["every"])
		if every <= 0.0:
			continue
		var elapsed := float(entry["elapsed"]) + delta
		var ticks := 0
		while elapsed >= every and ticks < MAX_CATCH_UP_TICKS:
			elapsed -= every
			ticks += 1
			due.append(key)
		if ticks == MAX_CATCH_UP_TICKS:
			# Dropped, not banked: see MAX_CATCH_UP_TICKS.
			elapsed = fmod(elapsed, every)
		entry["elapsed"] = elapsed
	for key in due:
		# A handler fired earlier this frame may have rebuilt the table.
		if _schedules.has(key):
			_fire_schedule(key)


func _fire_schedule(key: StringName) -> void:
	var payload: Dictionary = _schedules[key].get("payload", {})
	var handler: Callable = _handlers.get(key, Callable())
	if handler.is_valid():
		handler.call(payload)
	elif schedule_fired.get_connections().is_empty() and not _unhandled_warned.has(key):
		# The skill is unlocked and its clock is running, but nothing is listening, so the
		# player bought something that does nothing. Once per key, not once per tick.
		_unhandled_warned[key] = true
		push_warning("Skills: schedule '%s' fired with no handler registered" % key)
	schedule_fired.emit(key, payload)


func _on_unlocked_skills_changed(_skill_ids: PackedStringArray) -> void:
	_rebuild()


## The whole effect table, recomputed from the unlocked set. See the note at the top of the file
## for why this is a rebuild rather than an incremental apply.
##
## Unknown ids - in the save, not in this build's catalog - contribute nothing and are skipped in
## silence. GameState keeps them so a downgrade or a restored tree gets them back.
func _rebuild() -> void:
	_modifiers.clear()
	_features.clear()
	var schedules: Dictionary = {}
	for id in unlocked_catalog_ids():
		for effect in Catalog.effects(id):
			if typeof(effect) != TYPE_DICTIONARY:
				continue
			_apply_effect(id, effect, schedules)
	_carry_schedule_clocks(schedules)
	_schedules = schedules
	set_process(not _schedules.is_empty())
	effects_changed.emit()


func _apply_effect(id: String, effect: Dictionary, schedules: Dictionary) -> void:
	var kind := StringName(effect.get("kind", &""))
	var key := StringName(effect.get("key", &""))
	match kind:
		Catalog.EFFECT_MODIFIER:
			_modifiers[key] = modifier_bonus(key) + float(effect.get("amount", 0.0))
		Catalog.EFFECT_FEATURE:
			_features[key] = true
		Catalog.EFFECT_SCHEDULE:
			var every := float(effect.get("every", 0.0))
			if every <= 0.0:
				return
			# Two skills on one key is the upgrade shape - a later rank shortening the cadence -
			# so the shortest interval wins, and brings its own payload with it.
			if schedules.has(key) and float(schedules[key]["every"]) <= every:
				return
			schedules[key] = {
				"every": every,
				"payload": effect.get("payload", {}),
				"elapsed": 0.0,
			}
		_:
			push_warning("Skills: %s has an effect of unknown kind '%s'" % [id, kind])


## A schedule that survives a rebuild keeps the time it has already served, so unlocking an
## unrelated skill does not restart every clock on the desktop. The carried time is capped at the
## new interval: a rank that shortens the cadence pays at once rather than paying a backlog.
func _carry_schedule_clocks(schedules: Dictionary) -> void:
	for key in schedules:
		if not _schedules.has(key):
			continue
		var every := float(schedules[key]["every"])
		schedules[key]["elapsed"] = minf(float(_schedules[key]["elapsed"]), every)
