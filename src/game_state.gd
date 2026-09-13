extends Node
## Global game state: the values more than one screen needs to agree on.
##
## Registered as the `GameState` autoload, so it outlives scene changes and every reader sees
## the same numbers. Autoload identifiers are undefined under `--check-only`, so reach it as
## `get_node("/root/GameState")` from gameplay scripts rather than the bare `GameState`.
##
## State is private behind accessors on purpose. A bare `var rubles` would let any caller write
## a negative balance and would give the taskbar nothing to listen to, so every mutation goes
## through a setter that clamps and emits. Add future values the same way: a private var, a
## reader, a mutator that emits a `*_changed` signal.
##
## Persisted to user://save.cfg. There is one save and only one: the player never picks a
## slot, never names a file, and never loads anything but the state the last session left
## behind, so "load" is something that happens in _ready() rather than a screen. Deleting the
## file is the only way back to a fresh start, which clear_save() does for the settings screen's
## "Delete local save" button and for the egon suite.
##
## Preferences live in settings.gd and a separate file. Different lifetimes: wiping progress
## should not cost the player their language, and a save format change should not touch
## settings. See [settings.gd] for the storage story, which is otherwise the same one.
##
## Writes are coalesced rather than immediate. Settings save on every change because they only
## move by hand; a balance is mutated by gameplay - purchases now, income ticks
## later - and writing a file on each ruble would put a disk write inside a loop. Every
## mutation instead marks the state dirty and _process() flushes at most once every
## SAVE_INTERVAL seconds, so a burst of changes costs one write and the player can lose at
## most a second of progress to a crash. Save & Quit and a window close flush immediately.

## Emitted only when the balance actually changes, so listeners can redraw unconditionally.
signal rubles_changed(rubles: int)

## The same contract for the two counts the taskbar draws left of the balance.
signal skins_changed(skins: int)
signal targets_changed(targets: int)

## The profile list changed: one appended, dropped or loaded. See target_profiles().
signal target_profiles_changed

## One skill just became unlocked, for whatever wants to celebrate it - a popup, a sound, the
## tree node lighting up. Carries the id alone; what the skill does is skills.gd's business.
signal skill_unlocked(skill_id: String)

## The unlocked set changed as a whole, for any reason: a purchase, a save being loaded over a
## running game, a reset. Carries the whole set, so a listener that rebuilds from it - Skills
## does exactly that - never has to track what the change was.
##
## Deliberately not named skills_changed: skins_changed above is a different value one letter
## away, and the two must never be confused at a connect() site.
signal unlocked_skills_changed(skill_ids: PackedStringArray)

## A story segment moved between the two sets below - one started, or one was read through. For
## anything drawing off the record rather than off Story's own signals.
signal story_seen_changed(segment_ids: PackedStringArray)
signal story_pending_changed(segment_ids: PackedStringArray)

## Emitted when the answer to save_file_exists() flips, so a screen that draws one thing for a
## fresh start and another for a save in progress - the main menu's Start/Continue button - can
## redraw instead of polling the filesystem every frame.
##
## Nothing a player does at the main menu creates or removes the file, so for them this fires
## once at most, from the load in _ready(). It exists for the paths that change the file out
## from under a screen that is already up: clear_save() behind the settings screen's "Delete local
## save", and the egon scenarios, which are applied on the first frame - after the menu's _ready()
## has already read the file and picked a label.
signal save_presence_changed(exists: bool)

## Rubles are whole units: a float balance would accumulate rounding error across purchases,
## and kopeks are below the resolution of anything this game sells.
const STARTING_RUBLES := 1337

## Wide enough for any plausible balance and narrow enough that the formatted string still
## fits the taskbar. Gains past it are clamped rather than wrapped.
const MAX_RUBLES := 999_999_999

## Skins and targets are counts of things the player holds, not money, and a new game holds none
## of either. Clamped like the balance rather than left to grow without bound; six digits keeps
## the taskbar row well clear of the app icons.
const MAX_COUNT := 999_999

## U+20BD. Of the four faces in res://resources/ui-font.tres only Galmuri11 carries it, so it
## is drawn from the last fallback in the chain while the digits beside it come from Pixelify
## Sans. The two faces do not share a baseline - Galmuri11 reports a 17px line height against
## Pixelify Sans's 16 - so the sign rides high when both are set in one Label. The taskbar
## therefore draws it in its own control, nudged down; see taskbar.tscn's MoneySign node.
const RUBLE_SIGN := "₽"

## Russian groups thousands with a space and puts the sign after the amount: "1 000 ₽".
##
## Two spaces, not one. A space is 2px at font size 12 in Pixelify Sans, the same as the
## sidebearing the digits already carry, so a single space renders no visible break at all -
## "1 234 567" reads as "1234 567". Doubling it is the smallest gap this font can draw that
## actually separates the groups. The same separator sits before the sign so the spacing is
## even across the whole string.
const DIGIT_GROUP_SEPARATOR := "  "
const DIGITS_PER_GROUP := 3

## Stamped into every save so a future format change can migrate rather than guess. A file
## carrying an unknown version is left alone and the session starts fresh: a half-understood
## save read with today's keys would be worse than no save at all.
##
## A new key is not a format change. load_game() reads every key with a default, so a file
## written before skins and targets existed loads with none of either. Bump this when an
## existing key changes meaning.
const SAVE_VERSION := 1

const SAVE_PATH := "user://save.cfg"
const SAVE_SECTION := "progress"

## Spelled out rather than "skills": "skins" is a different value in the same section and the
## two are one letter apart in a file a human may end up reading.
const SAVE_KEY_SKILLS := "unlocked_skills"

## The story record, in two keys because a segment has three states and one set cannot hold
## three: read through, started and not finished, or neither. See _seen_story below.
const SAVE_KEY_STORY_SEEN := "seen_story"
const SAVE_KEY_STORY_PENDING := "pending_story"

## Who each target is, oldest first. See _target_profiles below.
const SAVE_KEY_TARGET_PROFILES := "target_profiles"

const TargetProfiles := preload("res://src/target_profiles.gd")

## Seconds between autosaves while the state keeps changing. Short enough that a crash costs
## nothing anyone would notice, long enough that a run of purchases is one write.
const SAVE_INTERVAL := 1.0

var _rubles: int = STARTING_RUBLES
var _skins: int = 0
var _targets: int = 0

## One profile per target, oldest first, always exactly _targets long: a target earned appends a
## made-up profile and a target spent drops the newest. Saved, so a target keeps its name and
## avatar across loads. Only as many as fit are ever drawn, but all are kept.
var _target_profiles: Array[Dictionary] = []

## Which skills the player has bought, as a set: id -> true. A Dictionary rather than an Array
## because nearly every question asked of it is "is this one in there" - a bonus resolving, a
## tree node deciding how to draw itself - and that is a lookup rather than a walk.
##
## Flat, with no hierarchy in it at all, though the skills themselves form trees. Which skill
## sits under which, what it costs and what it does is authored data and lives in
## skill_catalog.gd; what belongs to the player, and so belongs in their file, is one bit per
## skill. Storing the tree here instead would freeze the shape of the tree that shipped with
## this build into the save, so every later rebalance - a node moved, a branch re-cut - would
## become a migration of everyone's file, and reading it back would still have to be flattened
## into exactly this set before anything could be asked of it.
##
## Nothing enforces that the set is *reachable*: prerequisites are the catalog's rule and are
## checked at the one place an unlock happens (Skills.unlock()), not here. A GameState that
## re-derived the tree would be a second copy of it to keep in step, and the only way to reach an
## impossible set is to hand-edit the save, which costs the player their own bonuses and nothing
## else.
var _unlocked_skills: Dictionary = {}

## The story segments the player has read through, and the ones they started and did not finish,
## both as sets: id -> true, for the same reason the skills above are one.
##
## Two sets rather than one flag because a segment has three states, and which one it is in
## decides what happens on the next boot:
##
##   in neither     never shown; plays when whatever triggers it comes due
##   in pending     started and not finished; queued and replayed from its first line
##   in seen        read through; never plays again
##
## So "seen" means read, not merely reached, and a sequence cut short by a quit, a crash or a
## closed browser tab is not lost. There is no line index in here: segments are a handful of
## boxes and a replay starts at the first one, which is a decision story.gd explains.
##
## Opaque ids, like the skills: nothing here checks them against story_catalog.gd, so a save
## holding a segment this build has re-cut keeps it and means something again if it comes back.
var _seen_story: Dictionary = {}
var _pending_story: Dictionary = {}

## Set by every mutation, cleared by a successful write. Also what savePending reports, so a
## check can wait for the flush instead of guessing at it - the suite has no sleep step.
var _dirty := false
var _time_since_save := 0.0

## Each value as of the last successful write, or -1 before there has been one. Lets a check
## compare what is on disk against what is in memory without re-reading the file every frame.
var _last_saved_rubles := -1
var _last_saved_skins := -1
var _last_saved_targets := -1

## The unlocked set as of the last write. Empty both before there has been one and when nothing
## is unlocked; _last_saved_rubles being -1 is what tells those two apart.
var _last_saved_skills := PackedStringArray()

## Whether the file was there the last time anything looked. Only save_presence_changed reads
## it; save_file_exists() still asks the filesystem, so a check cannot be fooled by a stale
## flag. Starts false so the load in _ready() announces a save that is already on disk.
var _save_present := false

## Egon scenarios put the game into states a normal session would never reach. Left enabled,
## a scenario that hands the player a million rubles would persist it and every check that
## booted afterwards would inherit the fortune - user:// outlives a page load.
var _autosave_enabled := true


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	if not _dirty or not _autosave_enabled:
		return
	_time_since_save += delta
	if _time_since_save >= SAVE_INTERVAL:
		save_game()


func _notification(what: int) -> void:
	# WM_CLOSE_REQUEST is the desktop exit that does not go through the button; EXIT_TREE
	# catches get_tree().quit() from anywhere else. Neither fires when a browser tab is
	# closed, which is why the flush interval is a second and not a minute.
	#
	# Guarded on the dirty flag rather than writing unconditionally: a scenario that cleared
	# the save would otherwise see the file reappear at shutdown.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _dirty:
			save_game()


## Read the save into memory. Called once, from _ready(), before any scene exists - the
## taskbar reads the balance in its own _ready(), so it never sees the pre-load value.
func load_game() -> void:
	# First, and before any early return: re-syncing with the disk is this function's whole job,
	# and every path out of it - no file, a version we cannot read, a clean load - leaves the
	# answer to save_file_exists() settled.
	_refresh_save_presence()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		# No save on a first run, or one that will not parse. STARTING_RUBLES stands.
		return
	var version := int(config.get_value(SAVE_SECTION, "version", 0))
	if version != SAVE_VERSION:
		# Migrations belong here once there is a second version. Until then an unrecognised
		# file is ignored, not deleted: the next autosave overwrites it, but a player who
		# downgraded by accident still has their file if they go back.
		push_warning("GameState: ignoring save version %d, expected %d" % [version, SAVE_VERSION])
		return
	set_rubles(int(config.get_value(SAVE_SECTION, "rubles", STARTING_RUBLES)))
	set_skins(int(config.get_value(SAVE_SECTION, "skins", 0)))
	_target_profiles.clear()
	for saved in config.get_value(SAVE_SECTION, SAVE_KEY_TARGET_PROFILES, []):
		var profile := TargetProfiles.from_saved(saved)
		if not profile.is_empty():
			_target_profiles.append(profile)
	set_targets(int(config.get_value(SAVE_SECTION, "targets", 0)))
	# A save from before profiles, or one with unreadable entries, gets made-up ones here.
	var profiles_backfilled := _target_profiles.size() < _targets
	_sync_target_profiles()
	_set_unlocked_skills(config.get_value(SAVE_SECTION, SAVE_KEY_SKILLS, PackedStringArray()))
	# Both absent from any save written before the story system, and both read as empty through
	# the same default as every value above - which is why SAVE_VERSION does not move. Story's
	# backfill is what then makes such a file coherent; see story.gd.
	_set_seen_story(config.get_value(SAVE_SECTION, SAVE_KEY_STORY_SEEN, PackedStringArray()))
	_set_pending_story(config.get_value(SAVE_SECTION, SAVE_KEY_STORY_PENDING, PackedStringArray()))
	# The setters marked the state dirty; what came off disk is by definition already on it.
	_mark_clean(true)
	# Except backfilled profiles, which would be rolled again on every load until written.
	if profiles_backfilled:
		_mark_dirty()


## Write now, regardless of the interval. For Save & Quit, a window close, and anywhere the
## game reaches a point worth not losing.
func save_game() -> void:
	if not _autosave_enabled:
		return
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, "version", SAVE_VERSION)
	config.set_value(SAVE_SECTION, "rubles", _rubles)
	config.set_value(SAVE_SECTION, "skins", _skins)
	config.set_value(SAVE_SECTION, "targets", _targets)
	config.set_value(SAVE_SECTION, SAVE_KEY_TARGET_PROFILES, _target_profiles)
	config.set_value(SAVE_SECTION, SAVE_KEY_SKILLS, unlocked_skills())
	config.set_value(SAVE_SECTION, SAVE_KEY_STORY_SEEN, seen_story_segments())
	config.set_value(SAVE_SECTION, SAVE_KEY_STORY_PENDING, pending_story_segments())
	var error := config.save(SAVE_PATH)
	if error != OK:
		# Keep playing on a read-only or full user://. Retried at the next interval, since
		# the dirty flag is only cleared by a write that worked.
		push_warning("GameState: could not write %s (error %d)" % [SAVE_PATH, error])
		_time_since_save = 0.0
		return
	_mark_clean(true)
	_refresh_save_presence()


## Back to a fresh game: starting balance, no skins or targets, no file. The only route to one,
## since the player has no new-game button - the settings screen's "Delete local save" and the
## egon scenario that has to undo what an earlier check persisted both come through here.
##
## _mark_clean(false) is what makes the deletion stick: it drops the dirty flag set by
## reset() just above, so neither the next _process() tick nor the flush at shutdown
## writes the file back out from under the player.
func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	reset()
	_mark_clean(false)
	_refresh_save_presence()


## Stop persisting for the rest of the session. One way on purpose: a scenario that turns
## saving off should not be able to turn it back on and flush the state it fabricated.
func disable_autosave() -> void:
	_autosave_enabled = false
	_dirty = false


func autosave_enabled() -> bool:
	return _autosave_enabled


## True while a change is waiting to be written.
func save_pending() -> bool:
	return _dirty


func last_saved_rubles() -> int:
	return _last_saved_rubles


func last_saved_skins() -> int:
	return _last_saved_skins


func last_saved_targets() -> int:
	return _last_saved_targets


func last_saved_unlocked_skills() -> PackedStringArray:
	return _last_saved_skills.duplicate()


func save_file_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Emit save_presence_changed only when the file actually appeared or went away, so a listener
## can rebuild its UI unconditionally the way the rubles_changed listeners do.
func _refresh_save_presence() -> void:
	var exists := save_file_exists()
	if exists == _save_present:
		return
	_save_present = exists
	save_presence_changed.emit(exists)


func _mark_dirty() -> void:
	if not _autosave_enabled:
		return
	_dirty = true


## `on_disk` says whether memory now matches the file: true after a load or a write, false once
## clear_save() has taken the file away.
func _mark_clean(on_disk: bool) -> void:
	_dirty = false
	_time_since_save = 0.0
	_last_saved_rubles = _rubles if on_disk else -1
	_last_saved_skins = _skins if on_disk else -1
	_last_saved_targets = _targets if on_disk else -1
	_last_saved_skills = unlocked_skills() if on_disk else PackedStringArray()


func rubles() -> int:
	return _rubles


## Clamped to [0, MAX_RUBLES]: a balance is never negative, and spending routes through
## spend_rubles(), which refuses the purchase instead of overdrawing.
func set_rubles(amount: int) -> void:
	var clamped := clampi(amount, 0, MAX_RUBLES)
	if clamped == _rubles:
		return
	_rubles = clamped
	_mark_dirty()
	rubles_changed.emit(_rubles)


## Positive to earn, negative to deduct without an affordability check (a fine, a refund
## reversal). Use spend_rubles() for anything the player could fail to afford.
##
## Raw: no skill bonus is applied here, because a bonus on "money gained" should not inflate a
## refund or soften a fine. Income the player earns goes through Skills.grant_rubles(), which
## scales it and then calls this.
func add_rubles(amount: int) -> void:
	set_rubles(_rubles + amount)


func can_afford(cost: int) -> bool:
	return cost >= 0 and _rubles >= cost


## True when the purchase went through. Returns false and leaves the balance untouched when
## it did not, so callers can branch on one call rather than checking and then deducting.
func spend_rubles(cost: int) -> bool:
	if not can_afford(cost):
		return false
	set_rubles(_rubles - cost)
	return true


func skins() -> int:
	return _skins


## Clamped to [0, MAX_COUNT] and emits only on a real change, like set_rubles(). Nothing awards
## or spends skins yet.
func set_skins(amount: int) -> void:
	var clamped := clampi(amount, 0, MAX_COUNT)
	if clamped == _skins:
		return
	_skins = clamped
	_mark_dirty()
	skins_changed.emit(_skins)


## Positive to award, negative to take away.
func add_skins(amount: int) -> void:
	set_skins(_skins + amount)


func targets() -> int:
	return _targets


## Clamped to [0, MAX_COUNT] like set_skins(). A finished CS2 match awards them; see
## cs2_screen.gd for the roll.
func set_targets(amount: int) -> void:
	var clamped := clampi(amount, 0, MAX_COUNT)
	if clamped == _targets:
		return
	_targets = clamped
	_sync_target_profiles()
	_mark_dirty()
	targets_changed.emit(_targets)


func add_targets(amount: int) -> void:
	set_targets(_targets + amount)


## Spend one particular target: its profile goes and the count drops by one. False when the profile
## is not one of the player's, e.g. already spent. set_targets() lowering the count drops the newest
## instead; this is for when the player picked which one.
func remove_target_profile(profile: Dictionary) -> bool:
	for i in _target_profiles.size():
		if is_same(_target_profiles[i], profile):
			_target_profiles.remove_at(i)
			_targets -= 1
			_mark_dirty()
			target_profiles_changed.emit()
			targets_changed.emit(_targets)
			return true
	return false


## Oldest first, one per target. A new Array holding the same read-only profiles, so a caller can
## tell two profiles apart with is_same() but cannot change one.
func target_profiles() -> Array[Dictionary]:
	return _target_profiles.duplicate()


func _sync_target_profiles() -> void:
	if _target_profiles.size() == _targets:
		return
	if _target_profiles.size() > _targets:
		_target_profiles.resize(_targets)
	var taken := {}
	for profile in _target_profiles:
		taken[profile["name"]] = true
	while _target_profiles.size() < _targets:
		var profile := TargetProfiles.random_profile(taken)
		taken[profile["name"]] = true
		_target_profiles.append(profile)
	target_profiles_changed.emit()


## The unlocked ids, sorted, as a copy: the set is private so nothing outside can unlock a skill
## by writing to it. Sorted rather than in unlock order so the save file, the bridge and any
## comparison of two sets all read the same way.
##
## May contain ids this build's catalog no longer carries; see unlock_skill().
func unlocked_skills() -> PackedStringArray:
	return _sorted_ids(_unlocked_skills)


func is_skill_unlocked(skill_id: String) -> bool:
	return _unlocked_skills.has(skill_id)


## Record a skill as bought. True when the set actually changed, so a caller can branch on one
## call the way it does on spend_rubles().
##
## Records, and nothing more: no cost is charged and no prerequisite is checked here. Both are
## the catalog's rules and both happen in Skills.unlock(), which is the only path gameplay
## should call - this one is for it, for the save being read back, and for egon scenarios that
## need the player to already have something.
##
## The id is not checked against the catalog either. A save written by a build whose tree has
## since been re-cut holds ids that no longer exist, and dropping them here would quietly cost a
## player their progress when the tree was only being reorganised; they are kept, contribute
## nothing while they are unknown (see skills.gd), and mean something again if the skill comes
## back. A rename is a save migration, which is what SAVE_VERSION is for.
func unlock_skill(skill_id: String) -> bool:
	if skill_id.is_empty() or _unlocked_skills.has(skill_id):
		return false
	_unlocked_skills[skill_id] = true
	_mark_dirty()
	skill_unlocked.emit(skill_id)
	unlocked_skills_changed.emit(unlocked_skills())
	return true


## Take a skill back. Nothing in the game does yet; a respec would, and the egon scenarios need
## it to undo what an earlier check bought. Does not refund, and does not touch the skills that
## required this one - a respec that has to decide what happens to the branch below is a design
## question, not a storage one.
func relock_skill(skill_id: String) -> bool:
	if not _unlocked_skills.erase(skill_id):
		return false
	_mark_dirty()
	unlocked_skills_changed.emit(unlocked_skills())
	return true


func clear_skills() -> void:
	if _unlocked_skills.is_empty():
		return
	_unlocked_skills.clear()
	_mark_dirty()
	unlocked_skills_changed.emit(unlocked_skills())


func seen_story_segments() -> PackedStringArray:
	return _sorted_ids(_seen_story)


func pending_story_segments() -> PackedStringArray:
	return _sorted_ids(_pending_story)


func is_story_segment_seen(segment_id: String) -> bool:
	return _seen_story.has(segment_id)


func is_story_segment_pending(segment_id: String) -> bool:
	return _pending_story.has(segment_id)


## A segment just went up on screen. True when the record changed, so a replay of something
## already pending is not a write.
func mark_story_segment_pending(segment_id: String) -> bool:
	if segment_id.is_empty() or _pending_story.has(segment_id):
		return false
	_pending_story[segment_id] = true
	_mark_dirty()
	story_pending_changed.emit(pending_story_segments())
	return true


## A segment was read through: out of pending and into seen, in one call rather than two that
## could drift apart and leave a segment in both sets at once.
func mark_story_segment_seen(segment_id: String) -> bool:
	if segment_id.is_empty():
		return false
	var was_pending := _pending_story.erase(segment_id)
	if _seen_story.has(segment_id):
		if was_pending:
			_mark_dirty()
			story_pending_changed.emit(pending_story_segments())
		return was_pending
	_seen_story[segment_id] = true
	_mark_dirty()
	if was_pending:
		story_pending_changed.emit(pending_story_segments())
	story_seen_changed.emit(seen_story_segments())
	return true


## Forget the whole story record, for reset(). A fresh game has the story ahead of it.
func clear_story_segments() -> void:
	if _seen_story.is_empty() and _pending_story.is_empty():
		return
	var had_pending := not _pending_story.is_empty()
	var had_seen := not _seen_story.is_empty()
	_seen_story.clear()
	_pending_story.clear()
	_mark_dirty()
	if had_pending:
		story_pending_changed.emit(pending_story_segments())
	if had_seen:
		story_seen_changed.emit(seen_story_segments())


func _set_seen_story(segment_ids) -> void:
	if _replace_id_set(_seen_story, segment_ids):
		story_seen_changed.emit(seen_story_segments())


func _set_pending_story(segment_ids) -> void:
	if _replace_id_set(_pending_story, segment_ids):
		story_pending_changed.emit(pending_story_segments())


## Replace the whole set, for the load in load_game(). Emits once, and only when the set really
## differs, so loading a save over an identical state does not make every listener rebuild.
func _set_unlocked_skills(skill_ids) -> void:
	if _replace_id_set(_unlocked_skills, skill_ids):
		unlocked_skills_changed.emit(unlocked_skills())


## An id set as a sorted list. Sorted rather than in insertion order so the value written to the
## save, and the one a listener compares against, does not depend on the order things happened in.
func _sorted_ids(id_set: Dictionary) -> PackedStringArray:
	var ids: Array = id_set.keys()
	ids.sort()
	return PackedStringArray(ids)


## Replace a whole id set with what came off disk, dropping blanks and duplicates. True when the
## set really changed, which is what keeps a load over an identical state from making every
## listener rebuild - and which is why marking dirty lives in here rather than at the call site.
func _replace_id_set(id_set: Dictionary, ids) -> bool:
	var incoming: Array = []
	for value in ids:
		var id := String(value)
		if not id.is_empty() and not incoming.has(id):
			incoming.append(id)
	incoming.sort()
	if PackedStringArray(incoming) == _sorted_ids(id_set):
		return false
	id_set.clear()
	for id in incoming:
		id_set[id] = true
	_mark_dirty()
	return true


func reset() -> void:
	set_rubles(STARTING_RUBLES)
	set_skins(0)
	set_targets(0)
	clear_skills()
	clear_story_segments()


## The grouped amount with no sign, for callers that draw the sign themselves - the taskbar
## splits the two across separate controls to correct the Galmuri11 baseline. The taskbar's skin
## and target counts use it too, so every number on it groups its digits the same way.
static func format_amount(amount: int) -> String:
	return _group_digits(amount)


## Amount and sign as one string, for anywhere a single Label is enough (store price tags).
## Formatting lives here rather than at each call site so every readout matches. Static
## because it reads no state — call it for arbitrary amounts, not just the current balance.
static func format_rubles(amount: int) -> String:
	return "%s%s%s" % [format_amount(amount), DIGIT_GROUP_SEPARATOR, RUBLE_SIGN]


## Sign handling is here for prices and deltas; the balance itself can never be negative.
static func _group_digits(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % DIGITS_PER_GROUP == 0:
			out += DIGIT_GROUP_SEPARATOR
		out += digits[i]
	return "-%s" % out if amount < 0 else out
