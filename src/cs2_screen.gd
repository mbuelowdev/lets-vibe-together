extends Control
## The CS2 app, over its backdrop: a Queue for match button in the middle of the canvas, and once
## that is pressed, a match that plays itself out as a run of full-canvas stages.
##
## Every stage is a placeholder for now - a dark canvas with its name across the middle in white -
## standing in for the gif it will become.
##
## game.gd shows this only while CS2 is the selected app, but a hidden Control still processes, so a
## match carries on while the player is on Steam or Chrome and is wherever it has got to when they
## come back. The pause menu does stop it: this runs on the default process mode, so it waits under
## the shade with the taskbar clock and everything else on the desktop.

const QUEUE_KEY := "CS2_QUEUE_FOR_MATCH"

## Seconds after Queue for match was pressed at which each stage comes up, in order. The last one
## holds for LAST_STAGE_HOLD, then the queue button comes back for another match.
const STAGES := [
	[0.0, "PLACEHOLDER: queueing gif (2.0s)"],
	[2.0, "PLACEHOLDER: queue pop gif (3.0s)"],
	[5.0, "PLACEHOLDER: loading gif (3.0s)"],
	[8.0, "PLACEHOLDER: warmup gif (2.0s)"],
	[10.0, "PLACEHOLDER: spinbotting t side gif (10.0s)"],
	[20.0, "PLACEHOLDER: spinbotting ct side gif (10.0s)"],
	[30.0, "PLACEHOLDER: game won gif (2.0s)"],
]

const LAST_STAGE_HOLD := 2.0

var _queue_button: Button
var _stage_panel: ColorRect
var _stage_label: Label
var _settings: Node

## Index into STAGES of the stage on screen, or -1 while the queue button is up.
var _stage: int = -1
var _elapsed: float = 0.0


func _ready() -> void:
	_queue_button = $QueueButton
	_stage_panel = $StagePanel
	_stage_label = $StagePanel/StageLabel
	_settings = get_node_or_null("/root/Settings")
	_queue_button.pressed.connect(_on_queue_pressed)
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	_stage_panel.visible = false
	# Nothing to count until the player queues.
	set_process(false)
	refresh_labels()


## The button's label in the locale in effect, font tag and all - see main_menu.gd. game.gd runs it
## again when the settings screen closes, which may have changed the locale.
func refresh_labels() -> void:
	_queue_button.language = TranslationServer.get_locale().get_slice("_", 0)
	_queue_button.text = tr(QUEUE_KEY)


## Settings replaced wholesale from disk. Only an egon scenario does that at runtime.
func _on_settings_loaded() -> void:
	refresh_labels()


func _on_queue_pressed() -> void:
	_queue_button.visible = false
	_stage_panel.visible = true
	_elapsed = 0.0
	_show_stage(0)
	set_process(true)


## Walks rather than steps, so a long frame that crosses two stage times still lands on the later.
func _process(delta: float) -> void:
	_elapsed += delta
	var stage := _stage
	while stage + 1 < STAGES.size() and _elapsed >= float(STAGES[stage + 1][0]):
		stage += 1
	if stage != _stage:
		_show_stage(stage)
	if _stage == STAGES.size() - 1 and _elapsed >= float(STAGES[_stage][0]) + LAST_STAGE_HOLD:
		_return_to_queue()


func _show_stage(index: int) -> void:
	_stage = index
	_stage_label.text = String(STAGES[index][1])


## Same idle as _ready: the backdrop and Queue for match, nothing counting.
func _return_to_queue() -> void:
	_stage = -1
	_elapsed = 0.0
	_stage_panel.visible = false
	_queue_button.visible = true
	set_process(false)
