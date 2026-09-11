extends Control
## The front end: the screen `run/main_scene` boots into, and the only way to the desktop.
##
## Four buttons over the room art, with the title above them, both standing on a near-black column
## down the middle of the screen. Start, Settings and Credits sit as a group, 8px apart; Quit stays
## at the bottom of the column with a 32px gap above it, so leave is not the fourth destination.
## The column is what makes the text readable: the backdrop is a lit room with posters, a monitor
## and a lot of local contrast, and white-on-busy is unreadable wherever the art happens to be pale.
## It is a `Scrim` TextureRect between the backdrop and everything else - see main_menu.tscn for
## the gradient, which is 90% black across the middle and eases to 70% at its sides, where it
## stops with a hard edge.
##
## Start and Continue are one button, not two, because there is one save and the player never picks
## a slot: the file either exists, in which case the label reads Continue, or it does not, in which
## case it reads Start. Both do exactly the same thing - ask SceneTransition to fade into
## res://src/game.tscn - because GameState has already read the save in its own _ready(), long
## before this screen exists. There is nothing here to load; the "Loading" hold is theatre.
##
## Settings opens settings_screen.tscn - its own room art under a copy of this scrim - whose Back
## button comes straight here again. Credits is wired and inert: it gets its own screen in the
## roadmap's Horizon 1 task 4, and the button is here now so the menu does not change shape when
## that lands.
##
## Nothing here applies a saved setting. The Settings autoload reads the file and puts the saved
## locale into effect before any scene exists, so this screen only has to draw in whatever
## TranslationServer already says.
##
## The menu track lives on the Music autoload, not on this scene, because Start and Settings both
## leave this screen and that would free a child player. This screen is the one that asks for the
## menu track and for muffle off; Settings leaves the music alone; Start's fade asks Music to die
## with the picture, and the desktop plays its own track. play() is a no-op while the same track
## is already going, so Back from Settings does not rewind it.

const GAME_SCENE := "res://src/game.tscn"
const SETTINGS_SCENE := "res://src/settings_screen.tscn"

## What `screen` reports while this scene is up. game.gd registers the same field as "game", so a
## check can tell the two apart without knowing what either one draws.
const SCREEN_ID := "mainMenu"

const START_KEY := "MAIN_MENU_START"
const CONTINUE_KEY := "MAIN_MENU_CONTINUE"
const SETTINGS_KEY := "MAIN_MENU_SETTINGS"
const CREDITS_KEY := "MAIN_MENU_CREDITS"
const QUIT_KEY := "MAIN_MENU_QUIT"

## Pressing any of these with nothing focused is the player reaching for the UI without a mouse.
## Same list as game.gd's, and for the same reason.
const FOCUS_ENTRY_ACTIONS: PackedStringArray = [
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right",
	"ui_accept",
	"ui_focus_next",
	"ui_focus_prev",
]

## Everything _register_bridge_fields() adds, so _exit_tree() can take it all back off again
## without the two lists drifting apart.
const BRIDGE_FIELDS: PackedStringArray = [
	"screen",
	"mainMenuVisible",
	"mainMenuTitleVisible",
	"mainMenuScrimVisible",
	"mainMenuScrimBehindUi",
	"mainMenuScrimRect",
	"mainMenuButtons",
	"mainMenuStartIsContinue",
	"focusedControl",
]

var _background: TextureRect
var _scrim: TextureRect
var _title: TextureRect
var _start_button: Button
var _settings_button: Button
var _credits_button: Button
var _quit_button: Button

## The four buttons in the order they are drawn, which is also the order focus walks them.
var _buttons: Array[Button] = []

var _state: Node
var _settings: Node

## Whether the start button is currently offering to continue a save rather than begin one.
## Cached rather than re-derived: it is what the label was built from, so a check reading it
## cannot disagree with what the player can see.
var _start_is_continue := false


func _ready() -> void:
	_background = $Background
	_scrim = $Scrim
	_title = $Title
	_start_button = $StartButton
	_settings_button = $SettingsButton
	_credits_button = $CreditsButton
	_quit_button = $QuitButton
	_buttons = [_start_button, _settings_button, _credits_button, _quit_button]
	_state = get_node_or_null("/root/GameState")
	_settings = get_node_or_null("/root/Settings")
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	if _state != null:
		_state.save_presence_changed.connect(_on_save_presence_changed)
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	_refresh_labels()
	_wire_focus_navigation()
	_enter_music()
	_register_bridge_fields()


## Text server language tag: the same slice game.gd takes off a locale. Without it the first font
## in res://resources/ui-font.tres's chain that owns the glyph wins, which sends Japanese to the
## zh_hans face; with it, ja draws from the ja face and Korean from Galmuri.
func _font_language() -> String:
	return TranslationServer.get_locale().get_slice("_", 0)


## Every label the screen draws, rebuilt from scratch. One function rather than a "set the start
## text" and a "set the rest": a locale change and a save appearing both have to end with all four
## buttons agreeing about which language they are in.
func _refresh_labels() -> void:
	_start_is_continue = _save_exists()
	var font_language := _font_language()
	for button in _buttons:
		button.language = font_language
	_start_button.text = tr(CONTINUE_KEY if _start_is_continue else START_KEY)
	_settings_button.text = tr(SETTINGS_KEY)
	_credits_button.text = tr(CREDITS_KEY)
	_quit_button.text = tr(QUIT_KEY)


func _save_exists() -> bool:
	return false if _state == null else bool(_state.save_file_exists())


## The save appeared or went away underneath a menu that is already drawn. No player reaches this
## - nothing on this screen writes or deletes the file - but the egon scenarios do: they are
## applied on the first frame, after _ready() has already picked a label off an empty user://.
func _on_save_presence_changed(_exists: bool) -> void:
	_refresh_labels()


## Settings replaced wholesale from disk, which can carry a different locale than the one in
## effect at boot. Settings has already applied it by the time this fires, so all that is left is
## to redraw. Only an egon scenario does this at runtime; a real player's file is read once, in
## the autoload's _ready(), before this scene exists.
func _on_settings_loaded() -> void:
	_refresh_labels()


## Godot's geometric neighbour search already walks a single column of siblings, but it dead-ends
## at both ends. Wiring the column by hand is what makes it a ring: ui_down off Quit comes back to
## Start, and ui_up off Start reaches Quit, so no press ever does nothing.
func _wire_focus_navigation() -> void:
	var count := _buttons.size()
	for i in count:
		var button := _buttons[i]
		button.focus_neighbor_top = button.get_path_to(_buttons[(i + count - 1) % count])
		button.focus_neighbor_bottom = button.get_path_to(_buttons[(i + 1) % count])


## Clear any muffle and start the menu track if it is not already going. Cold boot starts it;
## Back from Settings leaves the playhead alone.
func _enter_music() -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	music.set_muffled(false)
	music.play(music.MENU_TRACK)


## Godot routes ui_* navigation through the focused Control and drops it when there is none, so
## from a cold boot the first key or button press does nothing at all and the menu reads as frozen
## to anyone not using the mouse. This spends that press on entering the menu instead.
##
## That includes ui_accept, which is the point: the first Enter or A lands on Start rather than
## pressing it, so nobody starts a game with the press they meant as "wake up".
func _unhandled_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action in FOCUS_ENTRY_ACTIONS:
		if not event.is_action_pressed(action):
			continue
		_start_button.grab_focus()
		get_viewport().set_input_as_handled()
		return


func _on_start_pressed() -> void:
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null:
		transition.to_scene(GAME_SCENE)
		return
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.stop()
	_open(GAME_SCENE)


func _on_settings_pressed() -> void:
	_open(SETTINGS_SCENE)


## Nothing to fall back to when a scene will not open, so say so loudly and leave the player on a
## screen that still works rather than a half-torn-down one.
func _open(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("main_menu: could not open %s (error %d)" % [scene_path, error])


## Placeholder for the roadmap's Horizon 1 task 4, which gives Credits its own screen the way
## Settings got one. Wired and inert rather than absent so the menu keeps its shape - and its
## button positions, which the egon checks click - when that lands.
func _on_credits_pressed() -> void:
	pass


## No save on the way out, unlike the pause menu's Save & Quit. Nothing reachable from this screen
## changes anything worth writing: preferences already write themselves as they change, and the
## balance has only ever been read from disk here. There is nothing to flush that is not already
## flushed. On the web export quit stops the main loop rather than closing the tab.
func _on_quit_pressed() -> void:
	get_tree().quit()


func _register_bridge_fields() -> void:
	# The egon bot's bridge: there in repo runs and its debug exports, dropped from release builds.
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	bridge.register_field("screen", func() -> String: return SCREEN_ID)
	bridge.register_field("mainMenuVisible", func() -> bool: return is_visible_in_tree())
	bridge.register_field("mainMenuTitleVisible", func() -> bool: return _is_title_visible())
	bridge.register_field("mainMenuScrimVisible", func() -> bool: return _is_scrim_visible())
	bridge.register_field("mainMenuScrimBehindUi", func() -> bool: return _is_scrim_behind_ui())
	bridge.register_field("mainMenuScrimRect", func() -> String: return _scrim_rect())
	bridge.register_field("mainMenuButtons", func() -> Array: return _button_texts())
	bridge.register_field("mainMenuStartIsContinue", func() -> bool: return _start_is_continue)
	bridge.register_field("focusedControl", func() -> String: return _focused_control_name())


## Providers close over nodes this scene is about to free, and Start and Settings both take the
## player off the screen, so anything left registered would hand every check that runs afterwards
## a menu that is not there. `screen` and `focusedControl` are registered by game.gd and
## settings_screen.gd too: SceneTree tears the old scene down and readies the new one inside a
## single deferred call, so the next screen re-registers both before the bridge next pushes a
## snapshot and neither blinks out of `window.__egon.state()`.
func _exit_tree() -> void:
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	for field in BRIDGE_FIELDS:
		bridge.unregister_field(field)


func _is_title_visible() -> bool:
	if _title == null or not is_instance_valid(_title):
		return false
	return _title.is_visible_in_tree() and _title.texture != null


## Where the column actually landed, as "x,y,WxH". It is meant to span the full canvas height, and
## the one thing that can quietly take that away is an anchor: `anchors_preset` is applied at load,
## preset 14 is VCENTER_WIDE rather than HCENTER_WIDE, and an unwritten anchor_top inherits the 0.5
## it sets - which leaves a column down the bottom half only, still visible, still behind the UI,
## and wrong. Neither of the two booleans can see that; a rect can.
func _scrim_rect() -> String:
	if _scrim == null or not is_instance_valid(_scrim):
		return ""
	var rect := _scrim.get_rect()
	return "%d,%d,%dx%d" % [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]


func _is_scrim_visible() -> bool:
	if _scrim == null or not is_instance_valid(_scrim):
		return false
	return _scrim.is_visible_in_tree() and _scrim.texture != null


## The column only does its job from between the two: over the backdrop it is darkening, under the
## title and every button it is not covering. Child order is the whole of that, so this reads it
## back rather than trusting the scene file to have stayed in the order it was written in.
func _is_scrim_behind_ui() -> bool:
	if not _is_scrim_visible():
		return false
	if _background == null or not is_instance_valid(_background):
		return false
	if _title == null or not is_instance_valid(_title):
		return false
	if _scrim.get_index() <= _background.get_index():
		return false
	if _scrim.get_index() >= _title.get_index():
		return false
	for button in _buttons:
		if button == null or not is_instance_valid(button):
			return false
		if _scrim.get_index() >= button.get_index():
			return false
	return true


## The labels as drawn, top to bottom, so a check can prove both the order and that the text
## followed a locale change rather than keeping the English baked into main_menu.tscn.
func _button_texts() -> Array:
	var out: Array = []
	for button in _buttons:
		if button == null or not is_instance_valid(button):
			continue
		out.append(button.text)
	return out


func _focused_control_name() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return "" if focused == null else String(focused.name)
