extends Control
## The dialog box: a full-width panel across the bottom of the canvas, a portrait standing on its
## top edge, a speaker's name, and their line revealed a word at a time.
##
## The whole view of the story and none of its bookkeeping. Story (story.gd) decides which segment
## and which line; this shows that line and calls Story.advance() when the player asks for the
## next one. It registers itself with Story on the way in, which is what lets a segment owed from
## a previous session wait through the main menu and play when the desktop comes up.
##
## process_mode is PROCESS_MODE_ALWAYS in the scene, like pause_menu.tscn: Story stops the tree
## while a sequence is up, and a box that froze with it would never finish revealing or take a
## press. Everything under it - the taskbar, the app screens, the skill tree - is pausable and so
## goes inert without anything having to disable it.
##
## Text only. There is no voice track and there will not be one, so the reveal below is the whole
## of "spoken": a word at a time, with a breath after punctuation.

## Grey, for every speaker with no portrait yet. One colour rather than one per character, so a
## placeholder reads as missing art rather than as a design that was chosen.
const PORTRAIT_PLACEHOLDER_TINT := Color("#6b6b6b")

## What a thought is drawn in, against the white the theme gives a Label for a spoken line. A cool
## grey rather than a dimmer white: it sits with the box's #1B2838 fill and #2E4272 border, and
## still carries about 5:1 against that fill, which is a line to be read rather than a hint.
##
## Only this is overridden. A spoken line takes the override back off instead of setting white, so
## a change to the theme's Label colour keeps reaching the boxes.
const THOUGHT_COLOR := Color("#98a0aa")

## Words a second. Read speech is nearer 2.5, which is unbearable to sit through in a box the
## player cannot skip; this is quick enough not to be waited on and slow enough to land word by
## word. 4 to 8 is the range worth trying - it is one number.
const REVEAL_WORDS_PER_SECOND := 6.0

## The breath after a word that ends a sentence or a clause, on top of the word's own time. Nearly
## all of what makes the reveal sound like someone talking rather than a ticker running.
const PAUSE_SENTENCE := 0.18
const PAUSE_CLAUSE := 0.09

## Both in the Latin and the CJK forms, since the line arrives already translated.
const SENTENCE_MARKS := ".!?…。！？"
const CLAUSE_MARKS := ",;:、，；："

## Half-period of the "there is more" blink at the bottom right of the box.
const HINT_BLINK_SECONDS := 0.45

## The portrait's inset from whichever edge it stands at, and its size. The box is 64 tall and the
## portrait sits directly on its top edge, which the scene lays out; this is what flipping sides
## recomputes.
const PORTRAIT_MARGIN := 16.0
const PORTRAIT_SIZE := 64.0

const Catalog := preload("res://src/story_catalog.gd")

var _story: Node
var _scrim: ColorRect
var _portrait: Control
var _portrait_frame: Panel
var _portrait_image: TextureRect
var _box: Panel
var _speaker_name: Label
var _text: Label
var _hint: Control

## Loaded portraits, keyed by path, so flipping between two speakers does not re-read either.
var _portrait_textures: Dictionary = {}

## Where the reveal may stop, as indices into the current line's text: one per word, or one per
## character in a script that does not space its words. Computed once per line.
var _stops: PackedInt32Array = PackedInt32Array()

## How many stops have been revealed, so _stops[_stop_index] is the next one.
var _stop_index := 0

## Seconds until the next stop, counted down in _process.
var _wait := 0.0

var _blink := 0.0

## The frame the box went up on. Input arriving on it is dropped - see _input().
var _opened_frame := -1

## Whether this line's height has been measured yet, and which text keys have already been
## complained about, so an overflowing translation warns once rather than every line.
var _measured := false
var _overflow_warned: Dictionary = {}


func _ready() -> void:
	_scrim = $Scrim
	_portrait = $Portrait
	_portrait_frame = $Portrait/Frame
	_portrait_image = $Portrait/Image
	_box = $Box
	_speaker_name = $Box/SpeakerName
	_text = $Box/Text
	_hint = $Box/Hint
	_tint_placeholder()
	visible = false
	_story = get_node_or_null("/root/Story")
	if _story == null:
		push_error("story_dialog: Story autoload is missing; no story will be drawn")
		return
	_story.segment_started.connect(_on_segment_started)
	_story.line_changed.connect(_on_line_changed)
	_story.segment_finished.connect(_on_segment_finished)
	# Last, and the reason this is a registration rather than game.gd wiring it: Story holds its
	# queue across a scene change and starts it here, so a segment owed from a previous session
	# plays when the desktop appears instead of over the main menu.
	_story.attach_view(self)


## The placeholder's grey, set here rather than in the scene so the one constant above is the only
## place it is written. The border colour stays the scene's, which is why this replaces the fill on
## a copy of the stylebox instead of modulating the whole panel.
func _tint_placeholder() -> void:
	var style := _portrait_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var tinted := style.duplicate() as StyleBoxFlat
	tinted.bg_color = PORTRAIT_PLACEHOLDER_TINT
	_portrait_frame.add_theme_stylebox_override("panel", tinted)


## Story is an autoload and outlives this scene, so it has to be told the box is gone: it puts the
## segment back at the head of its queue and lets the tree run again.
func _exit_tree() -> void:
	if _story != null:
		_story.detach_view(self)


## _input rather than _unhandled_input, so this sits ahead of the pause menu's ui_cancel handler
## (pause_menu.gd:141) without depending on which of two PROCESS_MODE_ALWAYS layers Godot walks
## first.
func _input(event: InputEvent) -> void:
	if not visible or _story == null:
		return
	# The press that bought the skill cannot actually reach here - a Button emits `pressed` during
	# GUI delivery, after _input has already run for that event - but this box opens from inside
	# that handler, which is close enough to the edge to be worth one line.
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed("ui_cancel"):
		# Swallowed, and that is the point: left alone it reaches the pause menu, which would
		# open over the sequence. A story segment is read through, not escaped.
		get_viewport().set_input_as_handled()
		return
	if not _is_advance(event):
		return
	get_viewport().set_input_as_handled()
	if _revealing():
		_finish_reveal()
		return
	_story.advance()


## Click anywhere, Space, Enter or the keypad's Enter - the last three are already ui_accept in
## project.godot, so the story needs no input action of its own. A touch counts too: the web build
## runs on phones, where there is no key to press.
func _is_advance(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	var button := event as InputEventMouseButton
	if button != null:
		return button.pressed and button.button_index == MOUSE_BUTTON_LEFT
	var touch := event as InputEventScreenTouch
	return touch != null and touch.pressed


func _process(delta: float) -> void:
	if not visible:
		return
	_advance_reveal(delta)
	_measure_once()
	_blink_hint(delta)


func _on_segment_started(_segment_id: String) -> void:
	visible = true
	_opened_frame = Engine.get_process_frames()


func _on_line_changed(segment_id: String, index: int) -> void:
	_draw_line(Catalog.line(segment_id, index))


## Hidden only when nothing is playing: _finish_current() starts the next queued segment in the
## same call, and the game must not flicker back to life between two of them.
func _on_segment_finished(_segment_id: String) -> void:
	if _story != null and _story.is_playing():
		return
	visible = false
	_text.text = ""
	_stops = PackedInt32Array()
	_stop_index = 0


func _draw_line(line_data: Dictionary) -> void:
	var speaker := Catalog.line_speaker(line_data)
	_apply_speaker(speaker)
	_apply_side(Catalog.line_side(line_data))
	# The language tag picks the regional glyph shapes out of the font chain - see the note in
	# resources/ui-font.tres, and cs2_screen.gd for the same two lines on a button.
	var language := TranslationServer.get_locale().get_slice("_", 0)
	_speaker_name.language = language
	_speaker_name.text = tr(Catalog.speaker_name_key(speaker))
	_text.language = language
	_text.text = tr(Catalog.line_text_key(line_data))
	_apply_thought(Catalog.line_is_thought(line_data))
	_text.visible_characters = 0
	_stops = _reveal_stops(_text.text)
	_stop_index = 0
	# 0, not one word's worth: an empty box for the first eighth of a second reads as a stall.
	_wait = 0.0
	_measured = false
	_hint.visible = false


## Thought lines grey, spoken lines back to whatever the theme says. Set per line rather than per
## segment: the same character speaks in one box and thinks in the next.
func _apply_thought(thought: bool) -> void:
	if thought:
		_text.add_theme_color_override("font_color", THOUGHT_COLOR)
		return
	_text.remove_theme_color_override("font_color")


func _apply_speaker(speaker: StringName) -> void:
	var path := Catalog.speaker_portrait(speaker)
	var texture := _portrait_texture(path) if not path.is_empty() else null
	_portrait_image.texture = texture
	_portrait_image.visible = texture != null
	# The grey square, for every speaker whose art does not exist yet.
	_portrait_frame.visible = texture == null


func _portrait_texture(path: String) -> Texture2D:
	if _portrait_textures.has(path):
		return _portrait_textures[path]
	var texture: Texture2D = load(path)
	if texture == null:
		push_error("story_dialog: missing portrait at %s" % path)
	# Cached either way, so a path that is not there is complained about once rather than on
	# every line the speaker has.
	_portrait_textures[path] = texture
	return texture


## Stand the portrait at one end of the box or the other. Done in anchors rather than in absolute
## x so it survives a viewport that is not 640 wide.
func _apply_side(side: StringName) -> void:
	if side == Catalog.SIDE_RIGHT:
		_portrait.anchor_left = 1.0
		_portrait.anchor_right = 1.0
		_portrait.offset_left = -(PORTRAIT_MARGIN + PORTRAIT_SIZE)
		_portrait.offset_right = -PORTRAIT_MARGIN
		return
	_portrait.anchor_left = 0.0
	_portrait.anchor_right = 0.0
	_portrait.offset_left = PORTRAIT_MARGIN
	_portrait.offset_right = PORTRAIT_MARGIN + PORTRAIT_SIZE


func _revealing() -> bool:
	return _stop_index < _stops.size()


## Every index the reveal may stop at, in order, the last one being the end of the line.
##
## A word at a time where the language has words to count - the index just past each one, since
## the spaces between them carry no glyph and revealing one is not a step the player can see. A
## character at a time where it does not: zh_Hans, zh_Hant and ja do not space their words, and a
## whole line appearing at once is not a reveal.
func _reveal_stops(text: String) -> PackedInt32Array:
	var stops := PackedInt32Array()
	var length := text.length()
	if length == 0:
		return stops
	if text.find(" ") == -1 and text.find("　") == -1:
		for index in range(1, length + 1):
			stops.append(index)
		return stops
	var at := 0
	while at < length:
		while at < length and _is_space(text[at]):
			at += 1
		if at >= length:
			break
		while at < length and not _is_space(text[at]):
			at += 1
		stops.append(at)
	return stops


static func _is_space(character: String) -> bool:
	return character == " " or character == "　" or character == "\n" or character == "\t"


func _advance_reveal(delta: float) -> void:
	if not _revealing():
		return
	_wait -= delta
	while _wait <= 0.0 and _revealing():
		_text.visible_characters = _stops[_stop_index]
		_stop_index += 1
		if not _revealing():
			return
		_wait += _delay_before(_stop_index)


## Time between the stop before `index` and that one: a word's worth, plus a breath if the word
## just revealed ended a sentence or a clause.
func _delay_before(index: int) -> float:
	var delay := 1.0 / REVEAL_WORDS_PER_SECOND
	var previous := _stops[index - 1]
	if previous <= 0 or previous > _text.text.length():
		return delay
	var last := _text.text[previous - 1]
	if SENTENCE_MARKS.contains(last):
		return delay + PAUSE_SENTENCE
	if CLAUSE_MARKS.contains(last):
		return delay + PAUSE_CLAUSE
	return delay


## The whole line at once, on the press that arrives mid-reveal.
func _finish_reveal() -> void:
	_text.visible_characters = -1
	_stop_index = _stops.size()


## The blinking mark at the bottom right, shown only once the line is out: the box says plainly
## whether it is still talking or waiting for the player.
func _blink_hint(delta: float) -> void:
	if _revealing():
		_hint.visible = false
		_blink = 0.0
		return
	_blink += delta
	_hint.visible = fmod(_blink, HINT_BLINK_SECONDS * 2.0) < HINT_BLINK_SECONDS


## Whether this line fits the two lines the box has for it. Cannot be answered before the label
## has wrapped the text, and cannot be answered at all in story_catalog.gd - the row there holds a
## key, and how many lines it takes depends on the locale and its font. So it is measured once per
## line, here, and warned about once per string: a translation that overflows is a string to
## shorten, and clip_text means nothing on screen would otherwise say so.
func _measure_once() -> void:
	if _measured:
		return
	_measured = true
	var line_text := _text.text
	if line_text.is_empty() or _overflow_warned.has(line_text):
		return
	var wanted := _text.get_line_count()
	var shown := _text.get_visible_line_count()
	if wanted <= shown:
		return
	_overflow_warned[line_text] = true
	push_warning("story_dialog: line wants %d lines and the box shows %d - %s" % [
		wanted, shown, line_text,
	])
