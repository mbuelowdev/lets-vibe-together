extends CanvasLayer
## The fade that Start/Continue walks through: menu into black, a short "Loading" hold, then black
## into the desktop. Lives as an autoload so the shade and the label survive `change_scene_to_file()`,
## which would otherwise free a child of the menu and flash the desktop for a frame.
##
## Screens do not own this. The menu asks `to_scene()` and then forgets it; Settings and Quit do not
## come through here. Autoload identifiers are undefined under `--check-only`, so gameplay scripts
## reach it as `get_node("/root/SceneTransition")`.
##
## The hold is fake. GameState has already read the save before the menu exists, and `game.tscn` is
## a handful of nodes: there is nothing to stream. The black and the dots are the beat between the
## room and the desktop, not a spinner over real work.
##
## Egon runs skip the theatrical timing. Every existing check clicks Start and awaits `screen ==
## "game"`, and five seconds of fade would time them out. When a scenario was requested - the
## `?egon_scenario=` query or `--egon-scenario=` - the same phases still run, just in a handful of
## frames, so a check can still see `loadingVisible` without the suite waiting on a loading screen.

const LOADING_KEY := "LOADING"

## Player-facing lengths. Egon uses the short pair below instead; `_fade_seconds()` /
## `_loading_seconds()` are what the tweens actually run.
const FADE_SECONDS := 1.0
const LOADING_SECONDS := 3.0
const DOT_SECONDS := 0.333

const EGON_FADE_SECONDS := 0.05
const EGON_LOADING_SECONDS := 0.3

const PHASE_IDLE := "idle"
const PHASE_FADE_OUT := "fadeOut"
const PHASE_LOADING := "loading"
const PHASE_FADE_IN := "fadeIn"

var _shade: ColorRect
var _label: Label
var _busy := false
var _phase := PHASE_IDLE
var _dots := 0
var _egon_run := false
var _fade: Tween
var _dot_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = $Root/Shade
	_label = $Root/LoadingLabel
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.color = Color(0, 0, 0, 0)
	_label.visible = false
	_egon_run = _is_egon_run()
	# Autoload _ready order is the [autoload] list; EgonBridge is a sibling, not a parent, so
	# it may not be in the tree yet. Idle is after every autoload has been added.
	call_deferred("_register_bridge_fields")


## True from the Start press until the desktop has finished fading in. game.gd reads this so the
## desktop track can fade in with the picture instead of slamming in over black.
func is_busy() -> bool:
	return _busy


## The fade-in length this run is actually using, so game.gd's play() and the shade stay one
## gesture even when Egon has shortened it.
func fade_in_seconds() -> float:
	return _fade_seconds()


## Fade the current scene out, hold on black with the loading text, switch to `scene_path`, fade
## that in. Re-entrant calls are ignored: a second click on Start while the first is fading would
## otherwise queue another change on top of one already in flight.
func to_scene(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	get_viewport().gui_release_focus()
	get_viewport().gui_disable_input = true
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_music_out()
	_phase = PHASE_FADE_OUT
	await _tween_shade(1.0)
	await _play_loading()
	var tree := get_tree()
	var previous_id := 0 if tree.current_scene == null else tree.current_scene.get_instance_id()
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("scene_transition: could not open %s (error %d)" % [scene_path, error])
		_abort()
		return
	# change_scene_to_file defers the swap. Wait until the desktop is actually the current
	# scene and has run _ready(), so the fade-in is a fade of that, not of the menu.
	var frames := 0
	while tree.current_scene == null or tree.current_scene.get_instance_id() == previous_id:
		await tree.process_frame
		frames += 1
		if frames > 60:
			push_error("scene_transition: timed out waiting for %s" % scene_path)
			_abort()
			return
	_phase = PHASE_FADE_IN
	await _tween_shade(0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_disable_input = false
	_phase = PHASE_IDLE
	_busy = false


func _abort() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	if _dot_tween != null:
		_dot_tween.kill()
		_dot_tween = null
	_label.visible = false
	_shade.color = Color(0, 0, 0, 0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().gui_disable_input = false
	_phase = PHASE_IDLE
	_busy = false


func _tween_shade(target_alpha: float) -> void:
	if _fade != null:
		_fade.kill()
	var seconds := _fade_seconds()
	if seconds <= 0.0:
		_shade.color.a = target_alpha
		return
	_fade = create_tween()
	_fade.tween_property(_shade, "color:a", target_alpha, seconds)
	await _fade.finished
	_fade = null


## Black, the translated word, and a 0..3 dot cycle for LOADING_SECONDS. The fourth tick wraps
## back to none: "Loading" / "Loading." / "Loading.." / "Loading..." / "Loading".
func _play_loading() -> void:
	_phase = PHASE_LOADING
	_dots = 0
	_refresh_loading_label()
	_label.visible = true
	if _dot_tween != null:
		_dot_tween.kill()
	_dot_tween = create_tween()
	_dot_tween.set_loops()
	_dot_tween.tween_callback(_advance_dot).set_delay(DOT_SECONDS)
	await get_tree().create_timer(_loading_seconds(), true).timeout
	if _dot_tween != null:
		_dot_tween.kill()
		_dot_tween = null
	_label.visible = false


func _advance_dot() -> void:
	_dots = (_dots + 1) % 4
	_refresh_loading_label()


func _refresh_loading_label() -> void:
	_label.language = TranslationServer.get_locale().get_slice("_", 0)
	_label.text = tr(LOADING_KEY) + ".".repeat(_dots)


func _fade_music_out() -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	music.fade_out(_fade_seconds())


func _fade_seconds() -> float:
	return EGON_FADE_SECONDS if _egon_run else FADE_SECONDS


func _loading_seconds() -> float:
	return EGON_LOADING_SECONDS if _egon_run else LOADING_SECONDS


## True when this boot was asked to run a scenario. Local play has no query and no user arg, so
## it keeps the full fade; the suite always passes one, so it does not sit on a loading screen.
func _is_egon_run() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--egon-scenario="):
			return true
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval(
			"(new URLSearchParams(window.location.search)).get('egon_scenario') || ''", true
		)
		if typeof(raw) == TYPE_STRING and not String(raw).is_empty():
			return true
	return false


func _register_bridge_fields() -> void:
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	bridge.register_field("transitionPhase", func() -> String: return _phase)
	bridge.register_field("loadingVisible", func() -> bool: return _is_loading_visible())
	bridge.register_field("loadingText", func() -> String: return _loading_text())


func _is_loading_visible() -> bool:
	return _label != null and is_instance_valid(_label) and _label.is_visible_in_tree()


func _loading_text() -> String:
	if not _is_loading_visible():
		return ""
	return _label.text
