extends Control
## The pause menu: Esc on the desktop, or the taskbar's Home icon, stops the game and puts
## Continue, Settings and Save & Quit over it. Esc again, or Continue, takes it away and lets the
## game run on.
##
## Built the way the front end is - a column of 176x34 buttons on res://resources/theme.tres, 8px
## apart - but it stands over the desktop, not over room art, so the scrim is a flat shade across
## the whole canvas, taskbar included, rather than the menu's column. The desktop stays visible
## under it, dimmed, so it reads as stopped rather than gone. The shade also takes every click
## that misses a button, so nothing on the desktop can be pressed through it.
##
## It sits on its own CanvasLayer in game.tscn, above the desktop's, and that does more than draw
## it on top: a Control whose parent is not a Control is a root for Godot's focus search, so
## neither the geometric neighbour search nor Tab can walk out of this menu - or out of the
## settings screen opened over it - onto the taskbar underneath.
##
## The pause is the SceneTree's. `get_tree().paused` stops every node on the default process
## mode: GameState's autosave interval, the taskbar clock, and every control on the desktop, which
## stops taking input. This node runs always, so it can open itself on Esc and take presses while
## the rest is stopped; the settings screen inherits that from it.
##
## Music runs always too, so the desktop's track plays on under the menu, muffled: open() asks
## Music for the low-pass sweep and _close() takes it off again. The settings screen opened in
## between leaves the music alone, so it stays muffled there.
##
## Save & Quit writes both halves its label promises and returns to the main menu - see
## _on_save_quit_pressed(). It is the button Home's screen used to carry; Home has no screen any
## more, and its taskbar icon opens this menu instead.
##
## Settings is the front end's settings screen, instanced over this menu rather than switched to:
## a scene change would free the desktop, and the player would come back to it with whatever app
## they had open forgotten. The screen draws its own art over the whole canvas, so it looks the
## way it does from the main menu. Its Back - the button, or Esc - comes back here through
## `closed` instead of opening the main menu.

## The settings screen opened from here has closed. It may have changed the locale, and on its way
## out it took the bridge fields it shares with the desktop - `screen`, `focusedControl`,
## `locale`, `rubles` and `saveFileExists` - off along with its own, so game.gd puts its own back.
signal settings_closed

const SETTINGS_SCENE := "res://src/settings_screen.tscn"
const MAIN_MENU_SCENE := "res://src/main_menu.tscn"

const CONTINUE_KEY := "PAUSE_CONTINUE"
## The main menu's key: the same word, already in every language.
const SETTINGS_KEY := "MAIN_MENU_SETTINGS"
## The label Home's screen used to carry, already in every language.
const SAVE_QUIT_KEY := "SAVE_QUIT"

## Pressing any of these with the menu up and nothing focused is the player reaching for it
## without a mouse. Same list as the other screens', and for the same reason.
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
	"paused",
	"pauseMenuVisible",
	"pauseMenuButtons",
	"pauseMenuScrimRect",
]

var _scrim: ColorRect
var _continue_button: Button
var _settings_button: Button
var _save_quit_button: Button

## The three buttons in the order they are drawn, which is also the order focus walks them.
var _buttons: Array[Button] = []

var _settings: Node

## The settings screen while it is open over this menu, otherwise null.
var _settings_screen: Control

## Whatever had focus on the desktop when the menu opened, handed back when it closes so a
## keyboard player carries on from where they were.
var _desktop_focus: Control


func _ready() -> void:
	_scrim = $Scrim
	_continue_button = $ContinueButton
	_settings_button = $SettingsButton
	_save_quit_button = $SaveQuitButton
	_buttons = [_continue_button, _settings_button, _save_quit_button]
	_settings = get_node_or_null("/root/Settings")
	_continue_button.pressed.connect(_close)
	_settings_button.pressed.connect(_on_settings_pressed)
	_save_quit_button.pressed.connect(_on_save_quit_pressed)
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	# Closed until Esc, whatever the editor was last left showing.
	visible = false
	_refresh_labels()
	_wire_focus_navigation()
	_register_bridge_fields()


## Every label, rebuilt in the locale in effect, font tag and all - see main_menu.gd. Runs again
## when the settings screen closes, which may have changed the locale behind the column's back.
func _refresh_labels() -> void:
	var font_language := TranslationServer.get_locale().get_slice("_", 0)
	for button in _buttons:
		button.language = font_language
	_continue_button.text = tr(CONTINUE_KEY)
	_settings_button.text = tr(SETTINGS_KEY)
	_save_quit_button.text = tr(SAVE_QUIT_KEY)


## Settings replaced wholesale from disk. Only an egon scenario does that at runtime.
func _on_settings_loaded() -> void:
	_refresh_labels()


## The main menu's ring: ui_down off Save & Quit comes round to Continue, and ui_up off Continue
## reaches Save & Quit. Left, right and Tab need no wiring: the CanvasLayer already keeps them in.
func _wire_focus_navigation() -> void:
	var count := _buttons.size()
	for i in count:
		var button := _buttons[i]
		button.focus_neighbor_top = button.get_path_to(_buttons[(i + count - 1) % count])
		button.focus_neighbor_bottom = button.get_path_to(_buttons[(i + 1) % count])


## Esc - ui_cancel, so B on a gamepad too - opens the menu from the desktop and closes it again.
##
## While the settings screen is up every press belongs to it: it is deeper in the tree, so it
## hears them first, and it takes Esc as its own Back.
##
## Otherwise the front end's first-press rule: with the menu up and nothing focused, the press
## only enters the column, at Continue, and is spent doing that.
func _unhandled_input(event: InputEvent) -> void:
	if _settings_screen != null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if visible:
			_close()
		else:
			open()
		return
	if not visible or get_viewport().gui_get_focus_owner() != null:
		return
	for action in FOCUS_ENTRY_ACTIONS:
		if not event.is_action_pressed(action):
			continue
		_continue_button.grab_focus()
		get_viewport().set_input_as_handled()
		return


## Stop the game, muffle its music and put the menu up: on Esc, and from the taskbar's Home icon,
## which game.gd routes here. A no-op while the menu is already up.
##
## Focus comes off the desktop on the way: left on a taskbar icon under the shade, the arrow keys
## would go on walking controls the player cannot see, and the first press would never reach this
## menu. _close() hands it back, so Home pressed from the keyboard ends up on Home again.
func open() -> void:
	if visible:
		return
	_desktop_focus = get_viewport().gui_get_focus_owner()
	get_viewport().gui_release_focus()
	visible = true
	get_tree().paused = true
	_muffle_music(true)


## Take the menu away and let the game run on, its music clear again and focus back where it was
## on the desktop - or nowhere, for a player on the mouse.
func _close() -> void:
	visible = false
	get_tree().paused = false
	_muffle_music(false)
	if is_instance_valid(_desktop_focus) and _desktop_focus.is_visible_in_tree():
		_desktop_focus.grab_focus()
	_desktop_focus = null


func _muffle_music(muffled: bool) -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	music.set_muffled(muffled)


## Over this menu rather than instead of it - see the top of this file. The column is hidden, not
## just covered, while the screen is up: the screen lets the pointer through everywhere its own
## controls are not, and a hidden button can neither take that click nor keep focus - so a
## keyboard player enters the screen from cold, the way they do from the main menu.
func _on_settings_pressed() -> void:
	var scene := load(SETTINGS_SCENE) as PackedScene
	if scene == null:
		push_error("pause_menu: could not load %s" % SETTINGS_SCENE)
		return
	_settings_screen = scene.instantiate()
	_settings_screen.opened_in_game = true
	# Deferred: Back fires from inside the screen's own input handling, which is no moment to
	# take it out of the tree.
	_settings_screen.closed.connect(_on_settings_closed, CONNECT_DEFERRED)
	_set_column_visible(false)
	add_child(_settings_screen)


## remove_child() rather than only queue_free(), so the screen's _exit_tree() - which takes its
## bridge fields off - runs now, before game.gd puts its own back, not at the end of the frame
## after it.
func _on_settings_closed() -> void:
	if _settings_screen == null:
		return
	remove_child(_settings_screen)
	_settings_screen.queue_free()
	_settings_screen = null
	_refresh_labels()
	_set_column_visible(true)
	# Back on the button that opened it, the way the delete question hands focus back to Delete.
	_settings_button.grab_focus()
	settings_closed.emit()


func _set_column_visible(shown: bool) -> void:
	for button in _buttons:
		button.visible = shown


## Both halves the label promises. Neither flush is the only thing standing between the player
## and data loss - settings write as they change, progress autosaves on an interval - because
## closing a browser tab never reaches this handler. Saving here is what makes the button honest
## for the player who does use it.
##
## The exit is the main menu, not off the process: that is where the player came from. Instant,
## the way Settings' Back is - Start's fade is the beat into the desktop, not out of it.
## The tree is unpaused first; change_scene_to_file() would otherwise leave it paused and the
## menu would come up frozen. _exit_tree() would catch that too, but not until the old scene
## is already on its way out.
func _on_save_quit_pressed() -> void:
	if _settings != null:
		_settings.save_settings()
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.save_game()
	get_tree().paused = false
	_muffle_music(false)
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("pause_menu: could not open %s (error %d)" % [MAIN_MENU_SCENE, error])


func _register_bridge_fields() -> void:
	# The egon bot's bridge: there in repo runs and its debug exports, dropped from release builds.
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	# The tree's own flag rather than this menu's visibility, so a check can catch the two
	# disagreeing.
	bridge.register_field("paused", func() -> bool: return get_tree().paused)
	bridge.register_field("pauseMenuVisible", func() -> bool: return _is_column_visible())
	bridge.register_field("pauseMenuButtons", func() -> Array: return _button_texts())
	bridge.register_field("pauseMenuScrimRect", func() -> String: return _scrim_rect())


## Save & Quit takes this node out of the tree. The handler already unpaused; clearing the
## flag here is the last line of defence so the menu does not come up frozen if it forgot to.
func _exit_tree() -> void:
	if visible:
		get_tree().paused = false
	var bridge := get_node_or_null("/root/EgonBridge")
	if bridge == null:
		return
	for field in BRIDGE_FIELDS:
		bridge.unregister_field(field)


## The column on screen: the menu is open and the settings screen is not over it.
func _is_column_visible() -> bool:
	if _continue_button == null or not is_instance_valid(_continue_button):
		return false
	return _continue_button.is_visible_in_tree()


## Where the shade landed, as "x,y,WxH" - main_menu.gd's format. It is meant to be the whole
## canvas, taskbar included.
func _scrim_rect() -> String:
	if _scrim == null or not is_instance_valid(_scrim):
		return ""
	var rect := _scrim.get_rect()
	return "%d,%d,%dx%d" % [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]


## The labels as drawn, top to bottom, so a check can prove both the order and the language.
func _button_texts() -> Array:
	var out: Array = []
	for button in _buttons:
		if button == null or not is_instance_valid(button):
			continue
		out.append(button.text)
	return out
