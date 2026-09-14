extends Control
## The Chrome app, over its backdrop: a scrollable gallery of the player's skins in a panel in the
## middle of the canvas. Clicking one swaps the gallery for that skin's detail view, whose button
## sells it for RUBLES_PER_SKIN.
##
## Placeholder economics standing in for a marketplace page, and the far end of the chain that
## starts with a CS2 match: cs2_screen.gd pays targets, gaming_community_screen.gd turns those into skins,
## and this turns those into the balance on the taskbar.
##
## game.gd shows this only while Chrome is the selected app. Nothing here counts down, so unlike
## cs2_screen.gd it has nothing to carry on doing while it is hidden.

const SkinItems := preload("res://src/skin_items.gd")

## What one skin sells for.
const RUBLES_PER_SKIN := 1000

## A gallery cell: the preview plus a 1px rarity border, and a margin the hover outline draws in.
const CELL_SIZE := 40
const PREVIEW_BORDER := 1
const DETAIL_BORDER := 2

## A skin the player has not hovered yet pulses a glow around its frame, NEW_GLOW_PERIOD seconds a
## beat, between the two alphas.
const NEW_GLOW_COLOR := Color(1.0, 0.97, 0.82)
const NEW_GLOW_SIZE := 4
const NEW_GLOW_PERIOD := 1.2
const NEW_GLOW_MIN_ALPHA := 0.2
## The "New" badge in the cell's top-right corner, dark on the glow's colour. Never wider than a cell.
const NEW_BADGE_TEXT_COLOR := Color(0.13, 0.13, 0.14)
const NEW_BADGE_PADDING := 1

var _settings: Node
var _game_state: Node

var _gallery: ScrollContainer
var _grid: GridContainer
var _empty: Label
var _detail: Control
var _back_button: Button
var _frame: Panel
var _image: TextureRect
var _name: Label
var _properties: Label
var _sell_button: Button

## The skin the detail view shows, or -1 while the gallery is up.
var _detail_skin_id := -1

var _cell_normal := StyleBoxEmpty.new()
var _cell_hover := StyleBoxFlat.new()
var _cell_pressed := StyleBoxFlat.new()
var _glow_style := StyleBoxFlat.new()
var _badge_style := StyleBoxFlat.new()

## The glow on each new skin's cell: skin id -> Panel. Every glow shares one pulse.
var _glows: Dictionary = {}
## The "New" badge on the same cells: skin id -> Label.
var _badges: Dictionary = {}
var _glow_clock := 0.0


func _ready() -> void:
	_gallery = $Panel/Gallery
	_grid = $Panel/Gallery/Grid
	_empty = $Panel/Empty
	_detail = $Panel/Detail
	_back_button = $Panel/Detail/BackButton
	_frame = $Panel/Detail/Content/Frame
	_image = $Panel/Detail/Content/Frame/Image
	_name = $Panel/Detail/Content/Name
	_properties = $Panel/Detail/Content/Properties
	_sell_button = $Panel/Detail/Content/SellButton
	_settings = get_node_or_null("/root/Settings")
	_game_state = get_node_or_null("/root/GameState")
	_build_cell_styles()
	_back_button.pressed.connect(close_detail)
	_sell_button.pressed.connect(_on_sell_pressed)
	if _settings != null:
		_settings.loaded.connect(_on_settings_loaded)
	# Skins arrive while this screen is hidden - a trade over on Gaming Community - so the gallery
	# follows the collection rather than being rebuilt when Chrome comes up.
	if _game_state != null:
		_game_state.skins_changed.connect(_on_skins_changed)
	refresh_labels()
	_rebuild_gallery()


func _process(delta: float) -> void:
	if _glows.is_empty() or not is_visible_in_tree():
		return
	_glow_clock = fmod(_glow_clock + delta, NEW_GLOW_PERIOD)
	var beat := 0.5 - 0.5 * cos(_glow_clock / NEW_GLOW_PERIOD * TAU)
	var alpha := lerpf(NEW_GLOW_MIN_ALPHA, 1.0, beat)
	for glow in _glows.values():
		glow.modulate.a = alpha


## Every label in the locale in effect, font tag and all - see cs2_screen.gd. game.gd runs it again
## when the settings screen closes, which may have changed the locale.
func refresh_labels() -> void:
	var language := TranslationServer.get_locale().get_slice("_", 0)
	for control in [_empty, _back_button, _name, _properties, _sell_button]:
		control.language = language
	_empty.text = tr("CHROME_SKINS_EMPTY")
	# The settings screen's key: the same word, already in every language.
	_back_button.text = tr("SETTINGS_BACK")
	_sell_button.text = tr("CHROME_SKIN_SELL")
	for badge in _badges.values():
		_place_badge(badge, language)
	_refresh_detail()


## Settings replaced wholesale from disk. Only an egon scenario does that at runtime.
func _on_settings_loaded() -> void:
	refresh_labels()


func _on_skins_changed(_skins: int) -> void:
	_rebuild_gallery()
	# The skin on show may be the one that just went.
	if _detail_skin_id != -1 and _skin(_detail_skin_id).is_empty():
		close_detail()


func open_detail(skin_id: int) -> void:
	if _skin(skin_id).is_empty():
		return
	_detail_skin_id = skin_id
	_refresh_detail()
	_gallery.visible = false
	_empty.visible = false
	_detail.visible = true


func close_detail() -> void:
	_detail_skin_id = -1
	_detail.visible = false
	_gallery.visible = true
	_empty.visible = _grid.get_child_count() == 0


## The id of the skin in the detail view, or -1 while the gallery is up.
func detail_skin_id() -> int:
	return _detail_skin_id


func _skin(skin_id: int) -> Dictionary:
	return {} if _game_state == null else _game_state.skin_item(skin_id)


## Newest first, so a skin just traded for is at the top.
func _rebuild_gallery() -> void:
	for cell in _grid.get_children():
		_grid.remove_child(cell)
		cell.queue_free()
	_glows.clear()
	_badges.clear()
	var skins: Array[Dictionary] = [] if _game_state == null else _game_state.skin_items()
	skins.reverse()
	for skin in skins:
		_grid.add_child(_make_cell(skin))
	# Measured once in the tree, where the badges pick up this screen's theme font.
	var language := TranslationServer.get_locale().get_slice("_", 0)
	for badge in _badges.values():
		_place_badge(badge, language)
	_empty.visible = skins.is_empty() and not _detail.visible


func _make_cell(skin: Dictionary) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.focus_mode = Control.FOCUS_NONE
	for slot in ["normal", "disabled", "focus"]:
		cell.add_theme_stylebox_override(slot, _cell_normal)
	cell.add_theme_stylebox_override("hover", _cell_hover)
	cell.add_theme_stylebox_override("pressed", _cell_pressed)
	cell.add_theme_stylebox_override("hover_pressed", _cell_pressed)
	var frame_size := SkinItems.PREVIEW_SIZE + PREVIEW_BORDER * 2
	var id := int(skin["id"])
	if _game_state.is_skin_new(id):
		var glow := Panel.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.add_theme_stylebox_override("panel", _glow_style)
		glow.position = Vector2.ONE * ((CELL_SIZE - frame_size) / 2 - 1)
		glow.size = Vector2.ONE * (frame_size + 2)
		glow.modulate.a = NEW_GLOW_MIN_ALPHA
		cell.add_child(glow)
		_glows[id] = glow
		cell.mouse_entered.connect(_on_new_cell_hovered.bind(id))
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", SkinItems.frame_style(skin["rarity"], PREVIEW_BORDER))
	frame.position = Vector2.ONE * (CELL_SIZE - frame_size) / 2
	frame.size = Vector2(frame_size, frame_size)
	cell.add_child(frame)
	if _glows.has(id):
		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.clip_text = true
		badge.add_theme_stylebox_override("normal", _badge_style)
		badge.add_theme_color_override("font_color", NEW_BADGE_TEXT_COLOR)
		cell.add_child(badge)
		_badges[id] = badge
	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = SkinItems.preview_texture(skin)
	preview.position = Vector2.ONE * PREVIEW_BORDER
	preview.size = Vector2.ONE * SkinItems.PREVIEW_SIZE
	frame.add_child(preview)
	cell.pressed.connect(open_detail.bind(id))
	return cell


## The badge's label in the locale in effect, sized to it and pinned to the cell's top-right corner.
func _place_badge(badge: Label, language: String) -> void:
	badge.language = language
	badge.text = tr("CHROME_SKIN_NEW")
	var font := badge.get_theme_font("font")
	var font_size := badge.get_theme_font_size("font_size")
	var text_width := font.get_string_size(badge.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := minf(ceilf(text_width) + NEW_BADGE_PADDING * 2, CELL_SIZE)
	badge.size = Vector2(width, badge.get_minimum_size().y)
	badge.position = Vector2(CELL_SIZE - width, 0)


## The first hover is the player noticing the skin: its glow and badge go, for good.
func _on_new_cell_hovered(skin_id: int) -> void:
	var glow: Panel = _glows.get(skin_id)
	if glow == null:
		return
	_glows.erase(skin_id)
	glow.queue_free()
	var badge: Label = _badges.get(skin_id)
	_badges.erase(skin_id)
	if badge != null:
		badge.queue_free()
	_game_state.mark_skin_seen(skin_id)


## Whether the gallery is drawing a glow on this skin.
func skin_glowing(skin_id: int) -> bool:
	return _glows.has(skin_id)


## A hovered cell lifts out of the panel with a light outline and wash; a pressed one dims it again.
func _build_cell_styles() -> void:
	_cell_hover.bg_color = Color(1, 1, 1, 0.14)
	_cell_hover.border_color = Color(1, 1, 1, 0.9)
	_cell_hover.set_border_width_all(1)
	_cell_pressed.bg_color = Color(1, 1, 1, 0.06)
	_cell_pressed.border_color = Color(1, 1, 1, 0.5)
	_cell_pressed.set_border_width_all(1)
	_glow_style.draw_center = false
	_glow_style.border_color = NEW_GLOW_COLOR
	_glow_style.set_border_width_all(1)
	_glow_style.shadow_color = Color(NEW_GLOW_COLOR, 0.8)
	_glow_style.shadow_size = NEW_GLOW_SIZE
	_badge_style.bg_color = NEW_GLOW_COLOR
	_badge_style.content_margin_left = NEW_BADGE_PADDING
	_badge_style.content_margin_right = NEW_BADGE_PADDING


func _refresh_detail() -> void:
	var skin := _skin(_detail_skin_id)
	if skin.is_empty():
		return
	_frame.add_theme_stylebox_override("panel", SkinItems.frame_style(skin["rarity"], DETAIL_BORDER))
	_image.texture = SkinItems.full_texture(skin)
	_name.text = skin["name"]
	_properties.text = "%s\n%s\n%s" % [
		tr("CHROME_SKIN_RARITY") % tr(SkinItems.rarity_key(skin["rarity"])),
		tr("CHROME_SKIN_WEAR") % ("%.4f" % skin["wear_float"]),
		tr("CHROME_SKIN_ID") % skin["id"],
	]


func _on_sell_pressed() -> void:
	if _game_state == null or not _game_state.remove_skin(_detail_skin_id):
		return
	_grant_rubles(RUBLES_PER_SKIN)


## A sale is money the player earned, so it goes through Skills rather than straight onto the
## balance: a money-gain skill scales it on the way, the way a match's payout is scaled. Without
## the autoload - only a scene booted on its own is missing it - the sale still pays, unscaled.
func _grant_rubles(amount: int) -> void:
	var skills := get_node_or_null("/root/Skills")
	if skills != null:
		skills.grant_rubles(amount)
		return
	_game_state.add_rubles(amount)
