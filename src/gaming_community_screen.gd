extends Control
## The Gaming Community app, over its backdrop (game.gd's APP_SCREEN_TEXTURES): a list of the
## player's targets on the left, a feed scrolled with the mouse wheel, and a chat window per
## target opened from the list.
##
## The feed is clipped by its FeedClip parent, so scrolling it up slides it under the backdrop's
## header instead of over it.
##
## Typing: while the screen is up, every key press except Esc types into the focused chat window,
## if it is still being typed in. Clicking a window (or its target's card) focuses it; clicking
## anywhere else leaves no window focused. A chat that ends in a trade pays TRADE_SKINS; either way the
## target is spent, and its card stays until its window closes, then the cards below slide up.
##
## game.gd shows this only while Gaming Community is the selected app. Open chat windows are
## children of this screen, so they hide with it, and their chats carry on while hidden.

const CHAT_WINDOW_SCENE := preload("res://src/gaming_community_chat_window.tscn")
const TARGET_CARD_SCENE := preload("res://src/gaming_community_target_card.tscn")

const RECENTLY_PLAYED_WITH_KEY := "GAMING_COMMUNITY_RECENTLY_PLAYED_WITH"

## Where the feed art's top-left corner rests before any scrolling, in screen pixels.
const FEED_ORIGIN := Vector2(210, 60)

## Screen rows the feed is visible in: below the header (y <= 36 stays backdrop) and down to the
## taskbar, which draws over the rest anyway.
const FEED_TOP := 37
const TASKBAR_TOP := 328

## Pixels one wheel notch scrolls the feed.
const FEED_SCROLL_STEP := 16
## Pixels the feed may scroll past the point where its bottom edge meets the taskbar.
const FEED_SCROLL_EXTRA := 4

## Card height as laid out in gaming_community_target_card.tscn, and the gap below each card.
const TARGET_CARD_HEIGHT := 18
const TARGET_CARD_GAP := 2
const CARD_SLIDE_SECONDS := 0.2

## Skins one accepted trade request pays.
const TRADE_SKINS := 1

var _recently_played_with_label: Label
var _target_list: Control
var _feed_clip: Control
var _feed: TextureRect
var _chat_windows: Control
## The chat window keys type into, or null: none gets them.
var _focused_window: Control = null
var _game_state: Node
## How far the feed is scrolled up, 0 at rest.
var _feed_scroll: int = 0
## Profiles already spent in GameState whose chat window has not closed yet. Their cards stay put
## until it does.
var _closing_profiles: Array[Dictionary] = []


func _ready() -> void:
	_recently_played_with_label = $RecentlyPlayedWithLabel
	_target_list = $TargetList
	_feed_clip = $FeedClip
	_feed = $FeedClip/Feed
	_chat_windows = $ChatWindows
	_game_state = get_node_or_null("/root/GameState")
	_feed_clip.position = Vector2(FEED_ORIGIN.x, FEED_TOP)
	_feed_clip.size = Vector2(_feed.texture.get_width(), TASKBAR_TOP - FEED_TOP)
	_feed_clip.gui_input.connect(_on_feed_gui_input)
	_apply_feed_scroll()
	# Targets arrive while this screen is hidden - a match finishing on CS2 - so the list follows
	# the profiles as they change rather than being built when the screen comes up.
	if _game_state != null:
		_game_state.target_profiles_changed.connect(_refresh_target_list)
	_refresh_target_list()
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.loaded.connect(refresh_labels)
	refresh_labels()


func refresh_labels() -> void:
	_recently_played_with_label.language = TranslationServer.get_locale().get_slice("_", 0)
	_recently_played_with_label.text = tr(RECENTLY_PLAYED_WITH_KEY)


func _on_feed_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_feed_scroll += FEED_SCROLL_STEP
	elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_feed_scroll -= FEED_SCROLL_STEP
	else:
		return
	_apply_feed_scroll()
	_feed_clip.accept_event()


## Scrolled all the way down, the feed's bottom edge sits FEED_SCROLL_EXTRA pixels above the taskbar.
func max_feed_scroll() -> int:
	return maxi(0, int(FEED_ORIGIN.y) + _feed.texture.get_height() - TASKBAR_TOP + FEED_SCROLL_EXTRA)


func _apply_feed_scroll() -> void:
	_feed_scroll = clampi(_feed_scroll, 0, max_feed_scroll())
	_feed.position = Vector2(0, FEED_ORIGIN.y - FEED_TOP - _feed_scroll)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Any click drops the focus; the GUI pass that follows hands it to the window clicked, if any.
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_focus_chat_window(null)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.is_action("ui_cancel"):
		return
	if _focused_window != null and _focused_window.is_typing():
		_focused_window.type_next_character()
		get_viewport().set_input_as_handled()


func _focus_chat_window(window: Control) -> void:
	if window == _focused_window:
		return
	if _focused_window != null:
		_focused_window.set_focused(false)
	_focused_window = window
	if window != null:
		window.set_focused(true)


## Cards that fit in TargetList, top to bottom.
func target_card_capacity() -> int:
	return (int(_target_list.size.y) + TARGET_CARD_GAP) / (TARGET_CARD_HEIGHT + TARGET_CARD_GAP)


## One card per target, oldest at the top, for as many as fit; the rest are not drawn. A card
## belongs to its profile for life: a spent target's card is freed and the cards below it slide
## up, with the next undrawn target sliding in at the bottom.
func _refresh_target_list() -> void:
	var live: Array[Dictionary] = []
	if _game_state != null:
		live = _game_state.target_profiles()
	var capacity := target_card_capacity()
	# Profiles only ever join at the end, so the cards already up, in slot order, followed by
	# whatever comes next in GameState's list is the list in order.
	var cards := _target_list.get_children()
	cards.sort_custom(func(a: Control, b: Control) -> bool: return a.position.y < b.position.y)
	var head := live.slice(0, capacity + _closing_profiles.size())
	var shown: Array[Dictionary] = []
	for card in cards:
		if _has_profile(head, card.profile) or _has_profile(_closing_profiles, card.profile):
			shown.append(card.profile)
	for profile in head:
		if not _has_profile(shown, profile):
			shown.append(profile)
	if shown.size() > capacity:
		shown.resize(capacity)
	var removed_any := false
	for card in cards:
		if not _has_profile(shown, card.profile):
			_target_list.remove_child(card)
			card.queue_free()
			removed_any = true
	var pitch := TARGET_CARD_HEIGHT + TARGET_CARD_GAP
	for i in shown.size():
		var card := _card_for(shown[i])
		var slot_y := float(i * pitch)
		if card == null:
			card = _add_target_card(shown[i])
			# Filling the gap a spent target left: come up from below with the rest.
			card.position.y = slot_y + pitch if removed_any else slot_y
		if card.has_meta("slide"):
			(card.get_meta("slide") as Tween).kill()
			card.remove_meta("slide")
		if card.position.y != slot_y:
			var tween := card.create_tween()
			# Whole pixels only, so the names stay crisp on the way.
			tween.tween_method(func(y: float) -> void: card.position.y = roundf(y), card.position.y, slot_y, CARD_SLIDE_SECONDS)
			card.set_meta("slide", tween)
	_close_orphaned_chat_windows(live)


func _card_for(profile: Dictionary) -> Button:
	for card in _target_list.get_children():
		if is_same(card.profile, profile):
			return card
	return null


func _add_target_card(profile: Dictionary) -> Button:
	var card: Button = TARGET_CARD_SCENE.instantiate()
	_target_list.add_child(card)
	card.show_profile(profile)
	card.pressed.connect(func() -> void: _open_chat(card.profile))
	return card


static func _has_profile(profiles: Array[Dictionary], profile: Dictionary) -> bool:
	for candidate in profiles:
		if is_same(candidate, profile):
			return true
	return false


## The target's window to the front, or a new one for it if it has none.
func _open_chat(profile: Dictionary) -> void:
	for window in _chat_windows.get_children():
		if is_same(window.profile, profile):
			window.move_to_front()
			_focus_chat_window(window)
			return
	if _has_profile(_closing_profiles, profile):
		return
	var window: Control = CHAT_WINDOW_SCENE.instantiate()
	window.profile = profile
	window.traded.connect(_on_chat_traded)
	window.refused.connect(_spend_target)
	window.closed.connect(_on_chat_closed)
	window.focus_requested.connect(_focus_chat_window.bind(window))
	window.tree_exiting.connect(func() -> void:
		if _focused_window == window:
			_focused_window = null)
	_chat_windows.add_child(window)
	window.drag_bounds = Rect2(0, 0, size.x, TASKBAR_TOP)
	window.place_randomly()
	_focus_chat_window(window)


func _on_chat_traded(profile: Dictionary) -> void:
	if _game_state != null:
		_game_state.add_skins(TRADE_SKINS)
	_spend_target(profile)


## The target's count drops now; its card waits for the window to close.
func _spend_target(profile: Dictionary) -> void:
	_closing_profiles.append(profile)
	if _game_state != null:
		_game_state.remove_target_profile(profile)


func _on_chat_closed(profile: Dictionary) -> void:
	for i in _closing_profiles.size():
		if is_same(_closing_profiles[i], profile):
			_closing_profiles.remove_at(i)
			break
	_refresh_target_list()


## A window whose target the player no longer has goes with it, unless it is closing on its own.
func _close_orphaned_chat_windows(live: Array[Dictionary]) -> void:
	for window in _chat_windows.get_children():
		if not _has_profile(live, window.profile) and not _has_profile(_closing_profiles, window.profile):
			window.queue_free()
