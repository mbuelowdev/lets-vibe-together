extends TextureRect
## A chat window on the Gaming Community screen, one per target. Dragged by its title bar and kept
## inside drag_bounds so it never covers the taskbar.
##
## The chat runs in rounds until the target declines or accepts:
##
##   TYPING    every key the screen hands to type_next_character() puts one more character of a
##             random opener (later: answer) into the chatbox; the last one sends it to the log
##   WAITING   REPLY_DELAY_MIN..MAX seconds; after TYPING_DELAY_MIN..MAX of them the target's line
##             shows growing dots until the reply replaces them. The target rolls a follow-up
##             question (back to TYPING, and the next roll is less likely to be one), a refusal or a yes
##   TRADE     the target answered yes: the reply, then a trade request to click
##   CLOSING   refused, or the trade was clicked: CLOSE_DELAY seconds, then the window goes
##
## The log shows the last VISIBLE_LINES lines; each new one pushes the oldest out of view.
##
## The window only tells the screen what happened (traded / refused / closed); the screen owns
## GameState and the target list.

signal traded(profile: Dictionary)
signal refused(profile: Dictionary)
signal closed(profile: Dictionary)
## The player clicked the window: the screen decides whether it gets the keys.
signal focus_requested

enum Stage { TYPING, WAITING, TRADE, CLOSING }

const TargetProfiles := preload("res://src/target_profiles.gd")

## Chat lines are keys in locale/chat.csv, named by these counts:
##   CHAT_OPENER_<o>                     an opener
##   CHAT_OPENER_<o>_Q<q>                a follow-up question about that opener
##   CHAT_CURIOUS_<n>, CHAT_SUSPICIOUS_<n>  follow-up questions for any opener
##   <question>_A<a>                     the player's answers to a question
##   CHAT_REPLY_POSITIVE_<n>, CHAT_REPLY_NEGATIVE_<n>  the target's yes / no
## Follow-ups come from the opener's own questions, then CURIOUS_ASKED curious ones, then suspicious
## ones, and never repeat in a chat.
const OPENER_COUNT := 6
const QUESTIONS_PER_OPENER := 2
const CURIOUS_COUNT := 4
const SUSPICIOUS_COUNT := 5
## Curious questions asked before the suspicious ones take over.
const CURIOUS_ASKED := 2
const ANSWERS_PER_QUESTION := 3
const POSITIVE_REPLY_COUNT := 5
const NEGATIVE_REPLY_COUNT := 5
const TRADE_REQUEST_KEY := "CHAT_TRADE_REQUEST"

## Percent chances of the target's first reply. They always add up to 100.
const FOLLOW_UP_CHANCE_START := 90
const DECLINE_CHANCE_START := 10
const ACCEPT_CHANCE_START := 0
## Every follow-up question moves this many points from the follow-up chance...
const FOLLOW_UP_CHANCE_STEP := 10
## ...to decline and accept, this many each.
const OUTCOME_CHANCE_STEP := 5
## Seconds from the player's message to the target's reply.
const REPLY_DELAY_MIN := 10.0
const REPLY_DELAY_MAX := 20.0
## Seconds from the player's message to the target's typing dots.
const TYPING_DELAY_MIN := 2.0
const TYPING_DELAY_MAX := 4.0
## The dots go 1, 2, ... MAX_DOTS, then back to 1, one step every DOT_STEP seconds.
const MAX_DOTS := 3
const DOT_STEP := 0.4
## Seconds between the chat ending and the window going.
const CLOSE_DELAY := 1.0

## Log lines, in log pixels: where the top visible one sits, and how far apart they are.
const LINE_TOP := 6.0
const LINE_STEP := 28.0
const VISIBLE_LINES := 3

## The area of the window that picks it up, in window pixels (0,0 to 149,18 inclusive).
const TITLE_BAR := Rect2(0, 0, 150, 19)

## How much of the scene's shadow an unfocused window keeps; a focused one has all of it.
const UNFOCUSED_SHADOW_STRENGTH := 0.4

## Where the window may be, in its parent's pixels. The window's whole rect stays inside it.
var drag_bounds := Rect2(0, 0, 640, 328)

## The target this window is a chat with. Set before the window enters the tree.
var profile: Dictionary = {}

var _stage := Stage.TYPING
## The opener or answer being typed, in the locale in effect when its round started.
var _message := ""
## Follow-up question pools, in the order they are asked from; asked questions are removed.
var _questions: Array[PackedStringArray] = []
## How many more questions each pool may ask before the next pool takes over.
var _question_turns: Array[int] = []
var _typed_count := 0
var _follow_up_chance := FOLLOW_UP_CHANCE_START
var _decline_chance := DECLINE_CHANCE_START
var _accept_chance := ACCEPT_CHANCE_START
## The lines in the log, oldest first. Lines pushed out of view are freed.
var _lines: Array[Control] = []
var _dragging := false
## The mouse's offset from the window's top-left corner when it was picked up.
var _grab_offset := Vector2.ZERO

var _chat_box: Control
var _typed: Label
var _log: Control
## Hidden templates the log lines are copied from.
var _player_line: Control
var _target_line: Control
var _trade_line: Control
var _shadow_style: StyleBoxFlat
var _focused_shadow_color: Color


func _ready() -> void:
	_chat_box = $ChatBox
	_typed = $ChatBox/Typed
	_log = $Log
	_player_line = $Log/PlayerLine
	_target_line = $Log/TargetLine
	_trade_line = $Log/TradeLine
	# The scene's style is shared by every window; this one's shadow strength is its own.
	var shadow := $Shadow as Panel
	_shadow_style = shadow.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_focused_shadow_color = _shadow_style.shadow_color
	shadow.add_theme_stylebox_override("panel", _shadow_style)
	set_focused(false)
	var avatar := TargetProfiles.avatar_texture(profile)
	($TitleAvatar as TextureRect).texture = avatar
	(_target_line.get_node("Content/Avatar") as TextureRect).texture = avatar
	(_trade_line.get_node("Content/Avatar") as TextureRect).texture = avatar
	(_trade_line.get_node("Content/TradeRequest") as Button).text = tr(TRADE_REQUEST_KEY)
	var opener := randi_range(1, OPENER_COUNT)
	_questions = [
		_numbered("CHAT_OPENER_%d_Q" % opener, QUESTIONS_PER_OPENER),
		_numbered("CHAT_CURIOUS_", CURIOUS_COUNT),
		_numbered("CHAT_SUSPICIOUS_", SUSPICIOUS_COUNT),
	]
	_question_turns = [QUESTIONS_PER_OPENER, CURIOUS_ASKED, SUSPICIOUS_COUNT]
	_start_typing(tr("CHAT_OPENER_%d" % opener))


## Every chat line key, for checking locale/chat.csv.
static func line_keys() -> PackedStringArray:
	var keys := _numbered("CHAT_REPLY_POSITIVE_", POSITIVE_REPLY_COUNT)
	keys.append_array(_numbered("CHAT_REPLY_NEGATIVE_", NEGATIVE_REPLY_COUNT))
	var questions := _numbered("CHAT_CURIOUS_", CURIOUS_COUNT)
	questions.append_array(_numbered("CHAT_SUSPICIOUS_", SUSPICIOUS_COUNT))
	for opener in range(1, OPENER_COUNT + 1):
		keys.append("CHAT_OPENER_%d" % opener)
		questions.append_array(_numbered("CHAT_OPENER_%d_Q" % opener, QUESTIONS_PER_OPENER))
	for question in questions:
		keys.append(question)
		keys.append_array(_numbered(question + "_A", ANSWERS_PER_QUESTION))
	return keys


func is_typing() -> bool:
	return _stage == Stage.TYPING


## The screen's say on whether keys type into this window. An unfocused window's shadow is weaker.
func set_focused(focused: bool) -> void:
	_shadow_style.shadow_color = _focused_shadow_color
	if not focused:
		_shadow_style.shadow_color.a *= UNFOCUSED_SHADOW_STRENGTH


## One key press worth of typing. Sends the message once the last character is in.
func type_next_character() -> void:
	if _stage != Stage.TYPING:
		return
	_typed_count = mini(_typed_count + 1, _message.length())
	_show_typed()
	if _typed_count >= _message.length():
		_send()


func place_randomly() -> void:
	var free := (drag_bounds.size - size).max(Vector2.ZERO)
	_move_to(drag_bounds.position + Vector2(randi_range(0, int(free.x)), randi_range(0, int(free.y))))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			move_to_front()
			focus_requested.emit()
			_dragging = TITLE_BAR.has_point(button.position)
			_grab_offset = button.position
		else:
			_dragging = false
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_move_to(position + motion.position - _grab_offset)
		accept_event()


func _move_to(target: Vector2) -> void:
	var max_position := (drag_bounds.end - size).max(drag_bounds.position)
	position = target.round().clamp(drag_bounds.position, max_position)


## The typed part of the message, right-aligned against the chatbox once it is wider than the box,
## so the newest character is always in view.
func _show_typed() -> void:
	_typed.text = _message.left(_typed_count)
	_typed.size.x = 0
	_typed.position.x = minf(0, _chat_box.size.x - _typed.get_minimum_size().x)


func _start_typing(message: String) -> void:
	_stage = Stage.TYPING
	_message = message
	_typed_count = 0
	_show_typed()


func _send() -> void:
	_stage = Stage.WAITING
	_typed.text = ""
	_add_line(_player_line, _message)
	var reply_delay := randf_range(REPLY_DELAY_MIN, REPLY_DELAY_MAX)
	var typing_delay := randf_range(TYPING_DELAY_MIN, TYPING_DELAY_MAX)
	await _wait(typing_delay)
	var reply := _add_line(_target_line, "").get_node("Content/Text") as Label
	var dots := _animate_dots(reply)
	await _wait(reply_delay - typing_delay)
	dots.queue_free()
	var roll := randi_range(0, 99)
	if roll < _follow_up_chance:
		var question := _next_question()
		reply.text = tr(question)
		_follow_up_chance -= FOLLOW_UP_CHANCE_STEP
		_decline_chance += OUTCOME_CHANCE_STEP
		_accept_chance += OUTCOME_CHANCE_STEP
		_start_typing(_pick(_numbered(question + "_A", ANSWERS_PER_QUESTION)))
	elif roll < _follow_up_chance + _decline_chance:
		reply.text = _pick(_numbered("CHAT_REPLY_NEGATIVE_", NEGATIVE_REPLY_COUNT))
		refused.emit(profile)
		_close()
	else:
		_stage = Stage.TRADE
		reply.text = _pick(_numbered("CHAT_REPLY_POSITIVE_", POSITIVE_REPLY_COUNT))
		var trade_line := _add_line(_trade_line, "")
		var trade_request := trade_line.get_node("Content/TradeRequest") as Button
		trade_request.pressed.connect(_on_trade_request_pressed.bind(trade_request))
		trade_request.button_down.connect(focus_requested.emit)


## Cycle `label` through 1..MAX_DOTS dots until the returned Timer is freed.
func _animate_dots(label: Label) -> Timer:
	label.text = "."
	var timer := Timer.new()
	timer.wait_time = DOT_STEP
	timer.timeout.connect(func() -> void: label.text = ".".repeat(label.text.length() % MAX_DOTS + 1))
	add_child(timer)
	timer.start()
	return timer


func _pick(keys: PackedStringArray) -> String:
	return tr(keys[randi_range(0, keys.size() - 1)])


## A random unasked question from the first pool with turns and questions left, or, once every
## pool's turns are used, from the first pool with questions left. There are more questions than
## follow-ups a chat can roll, so the pools never run dry.
func _next_question() -> String:
	var index := -1
	for i in _questions.size():
		if not _questions[i].is_empty() and (_question_turns[i] > 0 or index < 0):
			index = i
			if _question_turns[i] > 0:
				break
	_question_turns[index] -= 1
	# Packed arrays are copied on assignment, so the shrunk pool is written back.
	var pool := _questions[index]
	var question := pool[randi_range(0, pool.size() - 1)]
	pool.remove_at(pool.find(question))
	_questions[index] = pool
	return question


## `prefix` followed by 1..count.
static func _numbered(prefix: String, count: int) -> PackedStringArray:
	var keys := PackedStringArray()
	for i in range(1, count + 1):
		keys.append(prefix + str(i))
	return keys


## Append a copy of `template` to the log, its Text label (if any) showing `text`, and scroll the
## log so the newest VISIBLE_LINES lines are in view.
func _add_line(template: Control, text: String) -> Control:
	var line := template.duplicate() as Control
	line.get_node("Content").visible = true
	var label := line.get_node_or_null("Content/Text") as Label
	if label != null:
		label.text = text
	_log.add_child(line)
	_lines.append(line)
	while _lines.size() > VISIBLE_LINES:
		_lines.pop_front().queue_free()
	for i in _lines.size():
		_lines[i].position.y = LINE_TOP + LINE_STEP * i
	return line


func _on_trade_request_pressed(trade_request: Button) -> void:
	if _stage != Stage.TRADE:
		return
	trade_request.disabled = true
	traded.emit(profile)
	_close()


func _close() -> void:
	_stage = Stage.CLOSING
	await _wait(CLOSE_DELAY)
	closed.emit(profile)
	queue_free()


## A Timer of the window's own rather than a SceneTreeTimer: it stops with the pause, and if the
## window is freed first the wait simply never ends instead of resuming on a freed instance.
func _wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(seconds)
	await timer.timeout
	timer.queue_free()
