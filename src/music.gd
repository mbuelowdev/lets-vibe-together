extends Node
## The menu track, and the switch that muffles it on the front-end side rooms.
##
## Registered as the `Music` autoload so the player outlives `change_scene_to_file()`. The stream
## used to be a child of main_menu.tscn, which meant Start and Settings both tore it down with
## the screen, and coming back from Settings started the song from the top. Screens do not own
## a player any more: they ask this node to play, muffle, or stop. Autoload identifiers are
## undefined under `--check-only`, so reach it as `get_node("/root/Music")` from gameplay
## scripts rather than the bare `Music`.
##
## Does not autoplay. Settings and GameState exist before any scene; if this started the track
## in its own `_ready()`, `--scene res://src/game.tscn` would hear the menu song on the desktop.
## The menu is the only screen that asks for play. Settings (and Credits, when that screen
## lands) only flip muffle. The desktop asks for stop, so any path onto it is silent.
##
## play() is a no-op while the track is already going, so Menu → Settings → Back → Settings
## never rewinds. stop() also clears muffle, so the next play() is not still in the side-room
## state. The mp3 loops because its import settings say so (`loop=true`), not because anything
## here restarts it.
##
## The player sits on a dedicated Music bus, and the bus's first effect is the muffle. When it is
## a low-pass filter, set_muffled() does not just switch it: it sweeps the cutoff down over
## MUFFLE_SECONDS, and back up the same way, so a side room fades in behind a door rather than
## cutting to it. The filter is bypassed whenever the sweep is all the way open. How far down it
## goes is the cutoff the bus layout gives the filter, not a number here - retune the muffle
## without touching the screens. Any other effect is enabled and bypassed, as before.
##
## Bus effects only run in the engine's own mixer. On the web build Godot defaults every player to
## sample playback, which hands the stream to the browser and skips them - the track played but
## Settings never muffled it - so project.godot sets audio/general/default_playback_type.web back
## to Stream.

const MENU_STREAM := preload("res://assets/audio/main-menu-music.mp3")
const BUS_NAME := "Music"

## Linear, so 0.1 is 10% (-20 dB): the track's level in the mix. The player's Master volume
## setting scales the Master bus this sends into, not this.
const MENU_VOLUME := 0.1

## How long the muffle takes to close from clear, or to open from fully closed. Turning back part
## way through takes the matching share of this, not another full second.
const MUFFLE_SECONDS := 1.0

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


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = MENU_STREAM
	_player.volume_linear = MENU_VOLUME
	_player.bus = BUS_NAME
	add_child(_player)
	var idx := _music_bus()
	if idx != -1:
		_filter = AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if _filter != null:
		_muffled_cutoff_hz = _filter.cutoff_hz
		_set_muffle(0.0)


## Start the menu track if it is not already playing. Does not rewind a playing stream, and
## does not clear muffle: the screen that wants the song clear calls set_muffled(false) itself.
func play() -> void:
	if _player.playing:
		return
	_player.play()


## Also clears muffle, at once rather than over MUFFLE_SECONDS: there is nothing playing to hear a
## sweep, and the next play() should not start in the tail of one.
func stop() -> void:
	if _player.playing:
		_player.stop()
	_muffled = false
	if _sweep != null:
		_sweep.kill()
	var idx := _music_bus()
	if idx == -1:
		return
	if _filter != null:
		_set_muffle(0.0)
	AudioServer.set_bus_effect_enabled(idx, 0, false)


## Start closing or opening the muffle. Idempotent: asking for the state we are already in, or
## already sweeping towards, does nothing, including when the bus or the effect is missing, so a
## screen can declare "I am a side room" every `_ready()` without caring who called first. The
## menu asks on its way into Settings and Settings asks again; the sweep the first call started
## carries on through the scene change, because this node outlives it.
##
## Turning round mid-sweep starts from wherever the cutoff is now, so Back inside the second
## opens up again from part way down instead of jumping.
func set_muffled(muffled: bool) -> void:
	if _muffled == muffled:
		return
	_muffled = muffled
	var idx := _music_bus()
	if idx == -1:
		return
	if _filter == null:
		AudioServer.set_bus_effect_enabled(idx, 0, muffled)
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


## Put the cutoff `amount` of the way from open to the layout's cutoff, evenly in octaves rather
## than hertz. Pitch is heard as ratios, so a straight line from 20 kHz to 700 Hz would spend most
## of the second changing nothing audible and then fall off a cliff at the end.
func _set_muffle(amount: float) -> void:
	_muffle = amount
	_filter.cutoff_hz = OPEN_CUTOFF_HZ * pow(_muffled_cutoff_hz / OPEN_CUTOFF_HZ, amount)


## The Music bus's index, or -1 when the bus or its first effect is missing.
func _music_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1 or AudioServer.get_bus_effect_count(idx) < 1:
		return -1
	return idx
