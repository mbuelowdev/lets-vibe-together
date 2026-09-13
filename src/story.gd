extends Node
## The story, as a queue: what is owed, what is playing, what has been read. Autoloaded as
## `Story`, reached as `get_node("/root/Story")`.
##
## Knows nothing about how a dialog box looks. It decides which segment is up and which line of
## it, stops the game and fades the music out while one is on screen, and records the result;
## story_dialog.gd draws it and calls advance(). Nothing else in the game talks to this - segments
## come due on their own, off GameState.skill_unlocked.
##
## ## Two records, three states
##
## A segment is never shown, started-but-unfinished, or finished, and two sets in the player's
## save hold that (game_state.gd):
##
##   never shown        in neither
##   started            in `pending_story`
##   finished           in `seen_story`
##
## Starting one marks it pending; reading it through moves it to seen. So a sequence interrupted
## by a quit, a crash or a closed browser tab is still pending on the next boot, gets queued, and
## plays again from its first line - "seen" means read through, not merely reached.
##
## Replaying from the start rather than from the interrupted line is the whole reason there is no
## line index in the save: segments are a handful of boxes, and a half-revealed line would have to
## un-reveal itself to be resumed. Pending is never abandoned - leaving the desktop mid-sequence
## puts the segment back at the head of the queue (see _on_view_exiting) - so the only way out of
## pending is reading it.
##
## ## Why a view has to attach
##
## This is an autoload, so _ready() runs before any scene exists and the scene that follows it is
## main_menu.tscn. A pending segment that started itself there would stop the tree and try to draw
## a box over the main menu with no dialog node in it. So a segment is queued at boot and only
## *starts* once a view calls attach_view(), which story_dialog.gd does from its own _ready() -
## the queue simply waits through the menu and plays when the desktop comes up.

## A segment just went up, with its first line already selected. The view shows itself on this.
signal segment_started(segment_id: String)

## The line being shown changed - a new segment's first line, or an advance within one. Carries
## the index into the segment's `lines`, so a listener need not track it.
signal line_changed(segment_id: String, index: int)

## A segment was read through and is now seen. Another may start in the same frame, which is why
## a listener deciding whether to hide itself should ask is_playing() rather than assume.
signal segment_finished(segment_id: String)

const Catalog := preload("res://src/story_catalog.gd")

var _game_state: Node

## The node drawing the boxes, or null between scenes. Nothing starts without one; see the note
## on attaching at the top of this file.
var _view: Node = null

## Segments owed, in the order they will play. The one currently on screen is not in here - it is
## _current - so the queue is what is left after it.
var _queue: PackedStringArray = PackedStringArray()

var _current := ""
var _line_index := -1

## Whether *this* set get_tree().paused. The pause menu owns the same flag (pause_menu.gd:167),
## so clearing it unconditionally would resume a game the player had paused themselves.
var _paused_by_story := false


func _ready() -> void:
	# A segment nobody can read, or a line naming a speaker who does not exist, draws as a wrong
	# box rather than as an error. Warn at boot, where it is one glance - skills.gd does the same
	# for the skill tree.
	for problem in Catalog.validate():
		push_warning("Story: catalog problem - %s" % problem)
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		push_error("Story: GameState autoload is missing; no story will play")
		return
	# skill_unlocked, not unlocked_skills_changed: the second also fires for a save being read
	# back and for a reset, and neither of those is a story beat. (load_game() goes through
	# _set_unlocked_skills(), which emits only the second, so a load cannot trigger a segment
	# even before the seen set is consulted.)
	_game_state.skill_unlocked.connect(_on_skill_unlocked)
	# GameState's _ready() has already loaded the save - it is declared first in [autoload] - so
	# both of these see the player's real record rather than an empty one.
	_queue_pending()
	_backfill_seen()


## Line a segment up. True when it was queued.
##
## Refused for an id nobody authored, for one with no lines, for one already queued or on screen,
## and for one already seen unless `force` - which is how a segment is re-watched while it is
## being written. A *pending* segment is not refused: that is the replay.
func play(segment_id: String, force: bool = false) -> bool:
	if not Catalog.has(segment_id) or Catalog.line_count(segment_id) == 0:
		return false
	if segment_id == _current or _queue.has(segment_id):
		return false
	if not force and _game_state != null and _game_state.is_story_segment_seen(segment_id):
		return false
	_queue.append(segment_id)
	_start_next()
	return true


## Next line, or the end of the segment. The view's one call.
func advance() -> void:
	if _current.is_empty():
		return
	if _line_index + 1 < Catalog.line_count(_current):
		_line_index += 1
		line_changed.emit(_current, _line_index)
		return
	_finish_current()


func is_playing() -> bool:
	return not _current.is_empty()


func current_segment() -> String:
	return _current


func current_line_index() -> int:
	return _line_index


## The line on screen, or an empty dictionary when nothing is playing.
func current_line() -> Dictionary:
	if _current.is_empty():
		return {}
	return Catalog.line(_current, _line_index)


## Segments owed after the one on screen.
func queued_count() -> int:
	return _queue.size()


func seen_ids() -> PackedStringArray:
	if _game_state == null:
		return PackedStringArray()
	return _game_state.seen_story_segments()


func pending_ids() -> PackedStringArray:
	if _game_state == null:
		return PackedStringArray()
	return _game_state.pending_story_segments()


## Register the node that draws the boxes. Called by story_dialog.gd from its own _ready(), which
## is what lets a segment queued at boot wait for the desktop instead of stopping the main menu.
##
## One view at a time. The pair is called rather than watched for - a tree_exiting connection
## would have to be bound to the node to know which view left, and the view already has an
## _exit_tree() to call detach_view() from.
func attach_view(view: Node) -> void:
	if view == null or view == _view:
		return
	_view = view
	_start_next()


func view_attached() -> bool:
	return _view != null


## Segments the save says were started and never finished, queued in declaration order rather than
## in whatever order the save happened to list them - two owed segments should replay in the order
## they were written.
func _queue_pending() -> void:
	for id in Catalog.segment_ids():
		if _game_state.is_story_segment_pending(id):
			_queue.append(id)


## Write off every segment whose skill the player already bought before the segment existed. That
## is what stops a beat added after a save from ambushing the player with dialog they have long
## since earned.
##
## Pending wins: a segment the player was part-way through must replay, not be marked read. Which
## is why this runs after _queue_pending() and skips anything in either set.
func _backfill_seen() -> void:
	for id in Catalog.segment_ids():
		if _game_state.is_story_segment_seen(id) or _game_state.is_story_segment_pending(id):
			continue
		var skill := Catalog.skill_of(id)
		if not skill.is_empty() and _game_state.is_skill_unlocked(skill):
			_game_state.mark_story_segment_seen(id)


func _on_skill_unlocked(skill_id: String) -> void:
	for id in Catalog.segments_for_skill(skill_id):
		play(id)


## Take the head of the queue, if there is one and there is anything to draw it. A no-op while a
## segment is already on screen - advance() is what moves past that one.
func _start_next() -> void:
	if not _current.is_empty() or _queue.is_empty() or _view == null:
		return
	var id := _queue[0]
	_queue.remove_at(0)
	_current = id
	_line_index = 0
	_game_state.mark_story_segment_pending(id)
	_set_paused(true)
	_set_music_silenced(true)
	segment_started.emit(id)
	line_changed.emit(id, 0)


## Read through: out of pending, into seen, and straight on to whatever is queued behind it - the
## game must not flicker back to life between two segments, so the unpause only happens once the
## queue really is empty.
func _finish_current() -> void:
	var finished := _current
	_current = ""
	_line_index = -1
	_game_state.mark_story_segment_seen(finished)
	segment_finished.emit(finished)
	_start_next()
	if _current.is_empty():
		_set_paused(false)
		_set_music_silenced(false)


## The view is leaving the tree: Save & Quit, a transition back to the menu, the game closing.
## The segment goes back to the head of the queue and stays pending on disk, so it replays whole
## the next time a desktop comes up.
##
## Clearing the pause is the part that cannot be skipped - left set, it would freeze whatever
## scene loaded next.
##
## Guarded on identity so a view that has already been replaced cannot take the current one's
## segment down with it, whatever order a scene change frees things in.
func detach_view(view: Node) -> void:
	if view != _view:
		return
	_view = null
	if not _current.is_empty():
		var interrupted := _current
		_current = ""
		_line_index = -1
		var rest := _queue
		_queue = PackedStringArray([interrupted])
		_queue.append_array(rest)
	_set_paused(false)
	_set_music_silenced(false)


## Fade the music out for a segment, or back in after one. The boxes are read in silence: this
## game's only voice is its text, and a song under someone speaking is what a muffle is for, not a
## line of dialog.
##
## Called on every segment start rather than only the first, and Music ignores a state it is
## already in, so two segments back to back do not bounce the track up in the gap between them.
func _set_music_silenced(silenced: bool) -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	music.set_silenced(silenced)


## Stop or resume the game, without ever taking the flag off its owner. A segment starting over a
## tree the pause menu already stopped draws over it and leaves the flag alone - that menu is
## unreachable from a sequence, so this is the belt on the braces.
func _set_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if paused:
		if tree.paused:
			return
		tree.paused = true
		_paused_by_story = true
		return
	if not _paused_by_story:
		return
	_paused_by_story = false
	tree.paused = false
