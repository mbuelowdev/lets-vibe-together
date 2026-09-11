extends Node
## The music: the menu's track, the desktop's track, and the switch that muffles whichever one is
## playing.
##
## Registered as the `Music` autoload so the player outlives `change_scene_to_file()`. The stream
## used to be a child of main_menu.tscn, which meant Start and Settings both tore it down with
## the screen, and coming back from Settings started the song from the top. Screens do not own
## a player any more: they ask this node to play a track, muffle, or stop. Autoload identifiers
## are undefined under `--check-only`, so reach it as `get_node("/root/Music")` from gameplay
## scripts rather than the bare `Music`.
##
## Does not autoplay. Settings and GameState exist before any scene, and this cannot know which
## screen comes up first: the menu asks for MENU_TRACK and the desktop for GAME_TRACK, so
## `--scene res://src/game.tscn` hears the desktop's song rather than the menu's. The pause menu
## muffles the desktop's track while it is up. The settings screen leaves the music alone.
##
## play() is a no-op while the same track is already going, so Menu → Settings → Back → Settings
## never rewinds. Asking for the other track cuts over to it, from the top. An optional fade-in
## seconds starts the new track at silence and brings it up; the desktop uses that so the song
## arrives with the picture after Start's fade, not over the black. stop() cuts at once and
## also clears muffle, so the next play() is not still in the side-room state. fade_out() is
## the slow stop: it brings the level to nothing over the given seconds and then stop()s, which
## is what the menu→desktop fade asks for. Both mp3s loop because their import settings say so
## (`loop=true`), not because anything here restarts them.
##
## Runs while the tree is paused. The pause menu pauses it, and a pausable AudioStreamPlayer pauses
## its stream along with the tree - the desktop's track would stop dead under the menu instead of
## going behind a door - while the muffle's sweep is a tween bound to this node, which would not
## move.
##
## The player sits on a dedicated Music bus, and the bus's first effect is the muffle. When it is
## a low-pass filter, set_muffled() does not just switch it: it sweeps the cutoff down over
## MUFFLE_SECONDS, and back up the same way, so the track fades in behind a door rather than
## cutting to it. The player's level falls with it, to MUFFLE_VOLUME of TRACK_VOLUME, so the
## closed end is darker and a bit quieter - a 15% darker cutoff alone is too small to hear as
## "more muffled". The filter is bypassed whenever the sweep is all the way open. How far down
## the cutoff goes is the value the bus layout gives the filter, not a number here - retune that
## end without touching the screens. Any other effect is enabled and bypassed, as before.
##
## Bus effects only run in the engine's own mixer. On the web build Godot defaults every player to
## sample playback, which hands the stream to the browser and skips them - the track played but
## never muffled - so project.godot sets audio/general/default_playback_type.web back to Stream.

const MENU_TRACK := preload("res://assets/audio/main-menu-music.mp3")
const GAME_TRACK := preload("res://assets/audio/game-music-1.mp3")
const BUS_NAME := "Music"

## Linear, so 0.1 is 10% (-20 dB): a track's level in the mix. The two tracks are mastered within
## half a decibel of each other, so one level serves both. The player's volume settings scale the
## buses under it, not this: Music volume the Music bus this plays on, and Master volume the
## Master bus that one sends into.
const TRACK_VOLUME := 0.1

## How long the muffle takes to close from clear, or to open from fully closed. Turning back part
## way through takes the matching share of this, not another full second.
const MUFFLE_SECONDS := 1.0

## How far the player's level falls at full muffle, as a fraction of TRACK_VOLUME. 0.75 is 25%
## quieter. Swept with the cutoff so the two stay one gesture, and applied on the player rather
## than the Music bus, so it does not fight the player's Music volume slider.
const MUFFLE_VOLUME := 0.75

## The clear end of the sweep: above anything in the track, so the filter can come in and drop out
## at this end without a step anyone hears.
const OPEN_CUTOFF_HZ := 20000.0

var _player: AudioStreamPlayer
var _muffled := false

## The Music bus's first effect, when it is a low-pass set_muffled() can sweep. Null when the bus
## or the effect is missing or is something else, and set_muffled() falls back to switching it.
var _filter: AudioEffectLowPassFilter

## The cutoff the bus layout gives the filter, taken before the sweep starts rewriting it: the
## closed end of the sweep.
var _muffled_cutoff_hz := 0.0

## Where the sweep is: 0 is clear, 1 is the layout's cutoff.
var _muffle := 0.0

var _sweep: Tween
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_linear = TRACK_VOLUME
	_player.bus = BUS_NAME
	add_child(_player)
	var idx := _music_bus()
	if idx != -1:
		_filter = AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if _filter != null:
		_muffled_cutoff_hz = _filter.cutoff_hz
		_set_muffle(0.0)


## Start `track` unless it is already the one playing: from the top when nothing is, or cut over
## from the other one. Does not clear muffle: the screen that wants the song clear calls
## set_muffled(false) itself. `fade_seconds` above zero starts the track silent and tweens the
## player up to TRACK_VOLUME (times whatever muffle is already doing), so a scene that is itself
## fading in can bring the song with it.
func play(track: AudioStream, fade_seconds: float = 0.0) -> void:
	if _player.playing and _player.stream == track:
		return
	_kill_fade()
	_player.stream = track
	var target := _clear_volume()
	if fade_seconds > 0.0:
		_player.volume_linear = 0.0
		_player.play()
		_fade = create_tween()
		_fade.tween_property(_player, "volume_linear", target, fade_seconds)
		return
	_player.volume_linear = target
	_player.play()


## Bring the playing track down to silence over `seconds`, then stop(). Used by the menu→desktop
## fade so the song dies with the picture instead of cutting when the scene does. A zero or
## negative length is stop() itself. Idempotent on silence: nothing playing means there is
## nothing to fade.
func fade_out(seconds: float) -> void:
	if not _player.playing:
		return
	if seconds <= 0.0:
		stop()
		return
	_kill_fade()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_linear", 0.0, seconds)
	_fade.tween_callback(stop)


## Also clears muffle, at once rather than over MUFFLE_SECONDS: there is nothing playing to hear a
## sweep, and the next play() should not start in the tail of one.
func stop() -> void:
	_kill_fade()
	if _player.playing:
		_player.stop()
	_muffled = false
	if _sweep != null:
		_sweep.kill()
	var idx := _music_bus()
	if _filter != null:
		_set_muffle(0.0)
	else:
		_player.volume_linear = TRACK_VOLUME
	if idx == -1:
		return
	AudioServer.set_bus_effect_enabled(idx, 0, false)


## Start closing or opening the muffle. Idempotent: asking for the state we are already in, or
## already sweeping towards, does nothing, including when the bus or the effect is missing, so a
## screen can declare the state it wants without caring who called first. The pause menu closes
## it when it opens and opens it again when it closes, and the sweep runs while the tree is
## paused, because this node does.
##
## Turning round mid-sweep starts from wherever the cutoff is now, so Continue inside the first
## second opens up again from part way down instead of jumping.
func set_muffled(muffled: bool) -> void:
	if _muffled == muffled:
		return
	_muffled = muffled
	var idx := _music_bus()
	if idx == -1:
		return
	if _filter == null:
		AudioServer.set_bus_effect_enabled(idx, 0, muffled)
		_player.volume_linear = TRACK_VOLUME * (MUFFLE_VOLUME if muffled else 1.0)
		return
	if _sweep != null:
		_sweep.kill()
	var target := 1.0 if muffled else 0.0
	if muffled:
		AudioServer.set_bus_effect_enabled(idx, 0, true)
	_sweep = create_tween()
	_sweep.tween_method(_set_muffle, _muffle, target, MUFFLE_SECONDS * absf(target - _muffle))
	if not muffled:
		_sweep.tween_callback(AudioServer.set_bus_effect_enabled.bind(idx, 0, false))


## The resource path of the track playing, or "" when nothing is, so the desktop's bridge fields
## can tell its song from the menu's.
func track_path() -> String:
	if _player.stream == null or not _player.playing:
		return ""
	return _player.stream.resource_path


## The state the screens asked for, not where the sweep has got to.
func is_muffled() -> bool:
	return _muffled


## TRACK_VOLUME with the current muffle applied, which is TRACK_VOLUME itself while the filter
## is open. play()'s fade-in aims here rather than at the constant, so a track that starts
## muffled (it should not, but the two tweens then stay one level) does not pop up and get
## pulled back down.
func _clear_volume() -> float:
	return TRACK_VOLUME * lerpf(1.0, MUFFLE_VOLUME, _muffle)


func _kill_fade() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null


## Put the cutoff `amount` of the way from open to the layout's cutoff, evenly in octaves rather
## than hertz, and the player's level the same amount of the way from TRACK_VOLUME to
## TRACK_VOLUME * MUFFLE_VOLUME. Pitch is heard as ratios, so a straight line from 20 kHz to
## 700 Hz would spend most of the second changing nothing audible and then fall off a cliff at
## the end. Level is a short drop, so linear in amplitude is enough.
func _set_muffle(amount: float) -> void:
	_muffle = amount
	_filter.cutoff_hz = OPEN_CUTOFF_HZ * pow(_muffled_cutoff_hz / OPEN_CUTOFF_HZ, amount)
	_player.volume_linear = TRACK_VOLUME * lerpf(1.0, MUFFLE_VOLUME, amount)


## The Music bus's index, or -1 when the bus or its first effect is missing.
func _music_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1 or AudioServer.get_bus_effect_count(idx) < 1:
		return -1
	return idx
