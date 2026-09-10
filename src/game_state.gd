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
const SAVE_VERSION := 1

const SAVE_PATH := "user://save.cfg"
const SAVE_SECTION := "progress"

## Seconds between autosaves while the state keeps changing. Short enough that a crash costs
## nothing anyone would notice, long enough that a run of purchases is one write.
const SAVE_INTERVAL := 1.0

var _rubles: int = STARTING_RUBLES

## Set by every mutation, cleared by a successful write. Also what savePending reports, so a
## check can wait for the flush instead of guessing at it - the suite has no sleep step.
var _dirty := false
var _time_since_save := 0.0

## The balance as of the last successful write, or -1 before there has been one. Lets a check
## compare what is on disk against what is in memory without re-reading the file every frame.
var _last_saved_rubles := -1

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
	# set_rubles() marked the state dirty; what came off disk is by definition already on it.
	_mark_clean(_rubles)


## Write now, regardless of the interval. For Save & Quit, a window close, and anywhere the
## game reaches a point worth not losing.
func save_game() -> void:
	if not _autosave_enabled:
		return
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, "version", SAVE_VERSION)
	config.set_value(SAVE_SECTION, "rubles", _rubles)
	var error := config.save(SAVE_PATH)
	if error != OK:
		# Keep playing on a read-only or full user://. Retried at the next interval, since
		# the dirty flag is only cleared by a write that worked.
		push_warning("GameState: could not write %s (error %d)" % [SAVE_PATH, error])
		_time_since_save = 0.0
		return
	_mark_clean(_rubles)
	_refresh_save_presence()


## Back to a fresh game: starting balance, no file. The only route to one, since the player
## has no new-game button - the settings screen's "Delete local save" and the egon scenario that
## has to undo what an earlier check persisted both come through here.
##
## _mark_clean(-1) is what makes the deletion stick: it drops the dirty flag set by
## set_rubles() just above, so neither the next _process() tick nor the flush at shutdown
## writes the file back out from under the player.
func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	set_rubles(STARTING_RUBLES)
	_mark_clean(-1)
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


func _mark_clean(saved_rubles: int) -> void:
	_dirty = false
	_time_since_save = 0.0
	_last_saved_rubles = saved_rubles


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


func reset() -> void:
	set_rubles(STARTING_RUBLES)


## The grouped amount with no sign, for callers that draw the sign themselves - the taskbar
## splits the two across separate controls to correct the Galmuri11 baseline.
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
