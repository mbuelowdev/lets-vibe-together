extends Control
## The Chrome app, over its backdrop: one button in the middle of the canvas that sells the
## player's skins for rubles, RUBLES_PER_SKIN each.
##
## Placeholder economics standing in for a marketplace page, and the far end of the chain that
## starts with a CS2 match: cs2_screen.gd pays targets, gaming_community_screen.gd turns those into skins,
## and this turns those into the balance on the taskbar.
##
## One press sells the whole stock, and the button is disabled with nothing to sell - the same
## shape as gaming_community_screen.gd, and for the same reasons.
##
## game.gd shows this only while Chrome is the selected app. Nothing here counts down, so unlike
## cs2_screen.gd it has nothing to carry on doing while it is hidden.

const CONVERT_KEY := "CHROME_TURN_SKINS_INTO_RUBLE"

## What one skin sells for.
const RUBLES_PER_SKIN := 1000

var _convert_button: Button
var _settings: Node
var _game_state: Node


func _ready() -> void:
	_convert_button = $ConvertButton
	_settings = get_node_or_null("/root/Settings")
	_game_state = get_node_or_null("/root/GameState")
	_convert_button.pressed.connect(_on_convert_pressed)
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	# Skins arrive while this screen is hidden - a conversion over on Gaming Community - so the button's
	# state follows the counter rather than being worked out when Chrome comes up.
	if _game_state != null:
		_game_state.skins_changed.connect(_on_skins_changed)
	refresh_labels()
	_refresh_button_state()


## The button's label in the locale in effect, font tag and all - see cs2_screen.gd. game.gd runs
## it again when the settings screen closes, which may have changed the locale.
func refresh_labels() -> void:
	_convert_button.language = TranslationServer.get_locale().get_slice("_", 0)
	_convert_button.text = tr(CONVERT_KEY)


## Settings replaced wholesale from disk. Only an egon scenario does that at runtime.
func _on_settings_loaded() -> void:
	refresh_labels()


func _on_skins_changed(_skins: int) -> void:
	_refresh_button_state()


## Skins on hand, all of which one press sells. 0 is also what disables the button.
func sellable_skins() -> int:
	return 0 if _game_state == null else _game_state.skins()


func _on_convert_pressed() -> void:
	var skins := sellable_skins()
	if skins <= 0:
		return
	_game_state.add_skins(-skins)
	_grant_rubles(skins * RUBLES_PER_SKIN)


## A sale is money the player earned, so it goes through Skills rather than straight onto the
## balance: a money-gain skill scales it on the way, the way a match's payout is scaled. Without
## the autoload - only a scene booted on its own is missing it - the sale still pays, unscaled.
func _grant_rubles(amount: int) -> void:
	var skills := get_node_or_null("/root/Skills")
	if skills != null:
		skills.grant_rubles(amount)
		return
	_game_state.add_rubles(amount)


func _refresh_button_state() -> void:
	_convert_button.disabled = sellable_skins() <= 0
