extends Control

## Cheat flyout over the taskbar clock. Grants go straight to GameState, past any skill bonus.

const MONEY_GRANT := 10000
const TARGETS_GRANT := 10
const SKINS_GRANT := 10

var _give_money_button: Button
var _give_targets_button: Button
var _give_skins_button: Button


func _ready() -> void:
	_give_money_button = $Panel/Grants/GiveMoneyButton as Button
	_give_targets_button = $Panel/Grants/GiveTargetsButton as Button
	_give_skins_button = $Panel/Grants/GiveSkinsButton as Button
	_give_money_button.pressed.connect(_on_give_money_pressed)
	_give_targets_button.pressed.connect(_on_give_targets_pressed)
	_give_skins_button.pressed.connect(_on_give_skins_pressed)
	visible = false


## Rebuilt on every open: the locale may have changed in settings since the last one.
func _refresh_labels() -> void:
	var font_language := TranslationServer.get_locale().get_slice("_", 0)
	for button in [_give_money_button, _give_targets_button, _give_skins_button]:
		button.language = font_language
	_give_money_button.text = tr("DEBUG_GIVE_MONEY")
	_give_targets_button.text = tr("DEBUG_GIVE_TARGETS")
	_give_skins_button.text = tr("DEBUG_GIVE_SKINS")


func toggle() -> void:
	if visible:
		visible = false
	else:
		_refresh_labels()
		visible = true


func _on_give_money_pressed() -> void:
	get_node("/root/GameState").add_rubles(MONEY_GRANT)


func _on_give_targets_pressed() -> void:
	get_node("/root/GameState").add_targets(TARGETS_GRANT)


func _on_give_skins_pressed() -> void:
	get_node("/root/GameState").add_skins(SKINS_GRANT)
