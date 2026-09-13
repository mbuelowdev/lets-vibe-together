extends Control
## The Credits screen: who made the game, and the notices the software it is built out of asks
## for. The main menu's Credits button switches to it; Back - or ui_cancel from anywhere on it -
## switches to the menu again.
##
## It is a page, not a menu, so nothing on it takes focus by navigation: Back is FOCUS_CLICK and
## every arrow press falls through to _unhandled_input and scrolls. There is no focus-entry press
## to spend the way the menu and the Settings screen spend one, because there is no column to
## enter.
##
## The backdrop is the menu's; the scrim over it is darker than either other front-end screen's -
## 0.88 against the menu's 0.518 and Settings' 0.733 - because they put short labels on a scrim and
## this puts paragraphs on one, over the brightest part of the art. The gradient's eased ends put
## the room back at the screen edges, and the text column stays inside the plateau.
##
## One Label, not a RichTextLabel: the page has no markup, and a license text that happens to
## contain square brackets must not be read as BBCode. It sits in a ScrollContainer with
## horizontal scroll disabled, which is what forces it to the viewport width so autowrap has
## something to wrap against, and behind a MarginContainer, because a visible ScrollContainer bar
## is drawn over the content rather than beside it.
##
## The engine's half of _build_body() is read out of the engine rather than typed here, so it
## cannot go stale across an upgrade; the font notices are typed, because a font's copyright lives
## in its `name` table where no runtime API reaches. Headings and the hint are translated, the
## license texts are not.
##
## The music plays on underneath, untouched, exactly as on the Settings screen.

const MAIN_MENU_SCENE := "res://src/main_menu.tscn"

## The whole of the credit half of this page. One person wrote all of it, so there are no roles to
## list: a role list for a solo dev is the same name five times.
const DEVELOPER := "mbuelowdev"

## The SIL Open Font License 1.1, without the per-font header the three fonts' own copies carry.
## Rendered on the page; the per-font files next to it are what the build ships so the fonts
## travel with their license. Both only leave the project if export_presets.cfg keeps including
## assets/fonts/*.txt - "all_resources" does not cover a .txt.
const OFL_PATH := "res://assets/fonts/OFL-1.1.txt"

const OFL_NAME := "SIL Open Font License 1.1"

const GODOT_URL := "https://godotengine.org"

const TITLE_KEY := "MAIN_MENU_CREDITS"
const BACK_KEY := "SETTINGS_BACK"
const HINT_KEY := "CREDITS_HINT"
const MADE_BY_KEY := "CREDITS_MADE_BY"
const ENGINE_KEY := "CREDITS_ENGINE"
const FONTS_KEY := "CREDITS_FONTS"
const THIRD_PARTY_KEY := "CREDITS_THIRD_PARTY"
const LICENSE_TEXTS_KEY := "CREDITS_LICENSE_TEXTS"

## The faces res://resources/ui-font.tres draws from. Each notice is the one inside that font's own
## `name` table, copied here because nothing at runtime can read it back out. Pixelify Sans is
## marked modified: the build draws from a changed copy of it, and saying so is how a reader knows
## the glyphs are not the author's exactly as shipped. None of the three carries a Reserved Font
## Name, so the modified copy keeps its name and stays under the same license.
const FONTS: Array[Dictionary] = [
	{
		"name": "Pixelify Sans",
		"note": "modified for this game",
		"copyright": "Copyright 2021 The Pixelify Sans Project Authors",
		"url": "https://github.com/eifetx/Pixelify-Sans",
	},
	{
		"name": "Fusion Pixel Font",
		"note": "",
		"copyright": "Copyright (c) 2022 TakWolf",
		"url": "https://github.com/TakWolf/fusion-pixel-font",
	},
	{
		"name": "Galmuri11",
		"note": "",
		"copyright": "Copyright (c) 2019-2025 Lee Minseo (quiple@quiple.dev)",
		"url": "https://quiple.dev",
	},
]

## Dashes under every heading. 96 of them is 384px at 12px - a rule across most of the 406px the
## text wraps at, and short enough that it can never be the line that wraps.
const RULE := 96

## A line at least this long was wrapped by whoever wrote the file rather than ended on purpose -
## see _reflow().
const REFLOW_MIN := 60

## Seconds a direction has to be held before the page starts gliding on its own. The press itself
## is an event and the glide is polled, which is two mechanisms on purpose - see _process().
const HOLD_DELAY := 0.3

## Canvas pixels per second the page glides at while a direction is held.
const GLIDE_SPEED := 180.0

var _title: Label
var _page: ScrollContainer
var _body: Label
var _back_button: Button
var _hint: Label

## How long the held direction has been held, or 0 while none is.
var _held := 0.0

## Sub-pixel remainder of the glide. The page only ever moves whole pixels, like everything else
## on the 640x360 canvas.
var _glide_remainder := 0.0

var _settings: Node


func _ready() -> void:
	_title = $Title
	_page = $Page
	_body = $Page/Margin/Body
	_back_button = $BackButton
	_hint = $Hint
	_back_button.focus_mode = Control.FOCUS_CLICK
	_back_button.pressed.connect(_on_back_pressed)
	_settings = get_node_or_null("/root/Settings")
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	_style_scrollbar()
	_refresh_labels()


## Text server language tag: the same slice main_menu.gd takes off a locale, so Japanese draws
## from the ja face rather than whichever font in the chain owns the glyph first.
func _font_language() -> String:
	return TranslationServer.get_locale().get_slice("_", 0)


## Every piece of text the screen draws, rebuilt from scratch - the body included, because its
## five headings are translated too. One function rather than one per label: a locale change has
## to end with the whole page agreeing about which language it is in.
func _refresh_labels() -> void:
	var font_language := _font_language()
	for control: Control in [_title, _back_button, _hint, _body]:
		control.language = font_language
	_title.text = tr(TITLE_KEY)
	_back_button.text = tr(BACK_KEY)
	_hint.text = tr(HINT_KEY)
	_body.text = _build_body()


## Settings replaced wholesale from disk, which can carry a different locale than the one in
## effect. Nothing on this screen changes the locale - only an egon scenario reaches this at
## runtime - but the page is translated, so it redraws when one does.
func _on_settings_loaded() -> void:
	_refresh_labels()


## The whole page, top to bottom. Sections are separated by a heading between two rules; anything
## under a heading that is not a copyright line or a license text is indented four spaces.
func _build_body() -> String:
	var lines := PackedStringArray()
	_append_heading(lines, MADE_BY_KEY)
	lines.append(DEVELOPER)
	_append_engine(lines)
	_append_fonts(lines)
	_append_third_party(lines)
	_append_license_texts(lines)
	lines.append("")
	return "\n".join(lines)


func _append_heading(lines: PackedStringArray, key: String) -> void:
	var heading := tr(key)
	if not lines.is_empty():
		lines.append("")
		lines.append("")
	var rule := "-".repeat(RULE)
	lines.append(rule)
	lines.append(heading)
	lines.append(rule)
	lines.append("")


## The engine, named and dated by the engine itself. Its copyright lines are the first entry of
## get_copyright_info(), which is Godot's own; taking them from there rather than typing them here
## is what keeps this right across an upgrade.
func _append_engine(lines: PackedStringArray) -> void:
	_append_heading(lines, ENGINE_KEY)
	var version := String(Engine.get_version_info().get("string", ""))
	lines.append("Godot Engine %s" % version if version != "" else "Godot Engine")
	var components := Engine.get_copyright_info()
	if not components.is_empty():
		_append_copyright_lines(lines, components[0])
	lines.append("    %s" % GODOT_URL)


## The three faces the UI font chain draws from, each with the notice out of its own name table.
func _append_fonts(lines: PackedStringArray) -> void:
	_append_heading(lines, FONTS_KEY)
	for i in FONTS.size():
		var font := FONTS[i]
		if i > 0:
			lines.append("")
		var note := String(font["note"])
		lines.append(String(font["name"]) if note == "" else "%s (%s)" % [font["name"], note])
		lines.append("    %s" % font["copyright"])
		lines.append("    %s" % font["url"])
		lines.append("    %s" % OFL_NAME)


## Everything the engine is built out of, read out of the engine: 102 components, each with the
## copyright lines and the license id its authors ask to be carried. This is the section that
## keeps FreeType, Brotli and the rest satisfied, and it is the reason the page is long.
func _append_third_party(lines: PackedStringArray) -> void:
	_append_heading(lines, THIRD_PARTY_KEY)
	var components := Engine.get_copyright_info()
	for i in components.size():
		if i > 0:
			lines.append("")
		lines.append(String(components[i].get("name", "")))
		_append_copyright_lines(lines, components[i])


## One component's parts: every copyright line it claims, and the license each part is under.
func _append_copyright_lines(lines: PackedStringArray, component: Dictionary) -> void:
	for part: Dictionary in component.get("parts", []):
		for holder: String in part.get("copyright", []):
			lines.append("    Copyright (c) %s" % holder)
		var license := String(part.get("license", ""))
		if license != "":
			lines.append("    %s" % license)


## Every license in full: the font one off disk, then the 19 the engine reports, by name. Sorted
## rather than in whatever order the engine hands them over, so the page reads the same twice.
func _append_license_texts(lines: PackedStringArray) -> void:
	_append_heading(lines, LICENSE_TEXTS_KEY)
	lines.append(OFL_NAME)
	lines.append("")
	lines.append(_ofl_text())
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name: String in names:
		lines.append("")
		lines.append("")
		lines.append(name)
		lines.append("")
		lines.append(_reflow(String(licenses[name]).strip_edges(false, true)))


## The license the three fonts are under. It is a file rather than a constant so the copy the page
## shows is the copy the build ships. A build that dropped it from the export would otherwise show
## an empty section and say nothing about it; say it loudly instead, and leave creditsBodyLength
## short enough for a check to notice.
func _ofl_text() -> String:
	var text := FileAccess.get_file_as_string(OFL_PATH)
	if text.strip_edges() != "":
		return _reflow(text.strip_edges(false, true))
	push_error("credits_screen: %s is missing from this build" % OFL_PATH)
	return "This build is missing its copy of %s (%s)." % [OFL_NAME, OFL_PATH]


## Licenses arrive hard-wrapped at about 78 characters and this page wraps at about 65, so every
## line of one would spill a short orphan onto the next and the whole section would read as ragged
## as a torn edge. This takes the hard wraps back out: a line long enough to have been wrapped by
## whoever typed the file keeps the line after it, and anything else - blank lines, headings,
## numbered items, and rules drawn out of one repeated character - stays exactly where it was.
## Not a word changes, only where the lines break, which is the reader's business rather than the
## license's.
func _reflow(text: String) -> String:
	var out := PackedStringArray()
	var wrapped := false
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if wrapped and stripped != "" and not out.is_empty():
			out[out.size() - 1] = "%s %s" % [out[out.size() - 1], stripped]
		else:
			out.append(line)
		wrapped = stripped.length() >= REFLOW_MIN and not _is_rule(stripped)
	return "\n".join(out)


## A row of one repeated character - "====", "----" - which is a drawn line rather than a sentence
## that ran long, and must not swallow the heading under it.
func _is_rule(stripped: String) -> bool:
	for i in stripped.length():
		if stripped[i] != stripped[0]:
			return false
	return stripped != ""


## Godot's default scrollbar is a rounded grey slab, and the theme has nothing to say about
## VScrollBar because nothing else in the game scrolls. The bar is an internal child, so it cannot
## be styled in the scene file: it is styled here, 6px wide and flat, out of the palette in
## docs/GAME_DECISIONS.md.
func _style_scrollbar() -> void:
	var bar := _page.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(6, 0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.105882354, 0.15686275, 0.21960784, 0.78431374)
	# The content margins are a minimum height: a 2,350-line page would otherwise give the grabber
	# a couple of pixels and nothing to see.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.18039216, 0.25882354, 0.44705883, 1)
	grabber.content_margin_top = 6.0
	grabber.content_margin_bottom = 6.0
	var grabber_lit := StyleBoxFlat.new()
	grabber_lit.bg_color = Color(0.65882355, 0.72156864, 0.84705883, 1)
	grabber_lit.content_margin_top = 6.0
	grabber_lit.content_margin_bottom = 6.0
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_lit)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_lit)


## ui_cancel is Back from anywhere on the page - Esc, or B on a gamepad - the way it is on the
## Settings screen. Everything else here moves the page: a press is one line, a page key is a
## viewport less one line so the eye keeps a line it has already read, and Home / End are the two
## ends. Every step is clamped, so Home and End are "as far as it goes" in either direction.
##
## These are events rather than polling because a press has to land even when it is over inside
## one frame - which is exactly what a synthetic press from the check suite is. The glide in
## _process() is the other half, and the two must not double up: echoes are refused here, so key
## repeat never adds a step to a page that is already gliding.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Before the scene change, which takes this node out of the tree and its viewport with it.
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return
	var step := 0
	if event.is_action_pressed("ui_down"):
		step = _line_step()
	elif event.is_action_pressed("ui_up"):
		step = -_line_step()
	elif event.is_action_pressed("ui_page_down"):
		step = _page_step()
	elif event.is_action_pressed("ui_page_up"):
		step = -_page_step()
	elif event.is_action_pressed("ui_end"):
		step = _scroll_max()
	elif event.is_action_pressed("ui_home"):
		step = -_scroll_max()
	if step == 0:
		return
	_scroll_by(step)
	get_viewport().set_input_as_handled()


## A held direction, once it has been held long enough to mean "keep going" rather than "one
## line". Polled rather than driven by key repeat because a gamepad's d-pad does not repeat, and
## started late rather than at once because the press itself has already moved the page a line.
func _process(delta: float) -> void:
	var direction := Input.get_axis("ui_up", "ui_down")
	if is_zero_approx(direction):
		_held = 0.0
		_glide_remainder = 0.0
		return
	_held += delta
	if _held < HOLD_DELAY:
		return
	_glide_remainder += direction * GLIDE_SPEED * delta
	var whole := int(_glide_remainder)
	if whole == 0:
		return
	_glide_remainder -= whole
	_scroll_by(whole)


func _scroll_by(pixels: int) -> void:
	_page.scroll_vertical = clampi(_page.scroll_vertical + pixels, 0, _scroll_max())


## How far the page can go: everything below the viewport. 0 on a page that fits, which is what
## makes every step above a no-op rather than a jump to nowhere.
func _scroll_max() -> int:
	var bar := _page.get_v_scroll_bar()
	return maxi(0, int(bar.max_value - bar.page))


## One viewport, less a line the reader keeps.
func _page_step() -> int:
	var line := _line_step()
	return maxi(line, int(_page.get_v_scroll_bar().page) - line)


## What one press of ui_up / ui_down moves the page: one line as the Label draws it, which is the
## 12px font plus the negative line spacing the page is set in, not the font size.
func _line_step() -> int:
	return maxi(1, _body.get_line_height())


## Nothing to save on the way out: the screen only ever read. Nothing to fall back to either, so a
## scene that will not open is said loudly and the player is left on a screen that still works
## rather than a half-torn-down one.
func _on_back_pressed() -> void:
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("credits_screen: could not open %s (error %d)" % [MAIN_MENU_SCENE, error])
