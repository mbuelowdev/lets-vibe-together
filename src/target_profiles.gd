extends RefCounted
## Who a target is: a gamer name from names.txt and a cell of the avatar sheet. GameState keeps
## one profile per target and saves them; this only makes profiles up, checks loaded ones and
## draws their avatars.
##
## Preloaded like skill_catalog.gd. The name list is read once and cached.
##
## A profile is a read-only Dictionary {"name": String, "avatar": Vector2i}. The avatar is stored
## as a sheet cell rather than an index so a wider sheet does not change who everyone looks like.

const NAMES_PATH := "res://names.txt"
const FALLBACK_NAME := "Player"
const AVATAR_SHEET := preload("res://assets/images/gamer-community-avatars-sheet.png")
const AVATAR_SIZE := 10

static var _names := PackedStringArray()


static func names() -> PackedStringArray:
	if not _names.is_empty():
		return _names
	var file := FileAccess.open(NAMES_PATH, FileAccess.READ)
	if file != null:
		for line in file.get_as_text().split("\n", false):
			var name := line.strip_edges()
			if not name.is_empty():
				_names.append(name)
	if _names.is_empty():
		push_error("TargetProfiles: no names in %s" % NAMES_PATH)
		_names.append(FALLBACK_NAME)
	return _names


static func avatar_grid() -> Vector2i:
	return Vector2i(AVATAR_SHEET.get_width(), AVATAR_SHEET.get_height()) / AVATAR_SIZE


## A new profile, preferring a name that is not a key of `taken` while any are left.
static func random_profile(taken: Dictionary) -> Dictionary:
	var pool := names()
	if taken.size() < pool.size():
		var free := PackedStringArray()
		for name in pool:
			if not taken.has(name):
				free.append(name)
		if not free.is_empty():
			pool = free
	var grid := avatar_grid()
	return make_profile(
		pool[randi_range(0, pool.size() - 1)],
		Vector2i(randi_range(0, grid.x - 1), randi_range(0, grid.y - 1)),
	)


static func make_profile(name: String, avatar: Vector2i) -> Dictionary:
	var profile := {"name": name, "avatar": avatar}
	profile.make_read_only()
	return profile


## A profile read back from the save, or an empty Dictionary when it is not one this build can draw.
static func from_saved(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var name: Variant = value.get("name")
	var avatar: Variant = value.get("avatar")
	if typeof(name) != TYPE_STRING or typeof(avatar) != TYPE_VECTOR2I:
		return {}
	var grid := avatar_grid()
	if avatar.x < 0 or avatar.y < 0 or avatar.x >= grid.x or avatar.y >= grid.y:
		return {}
	return make_profile(name, avatar)


static func avatar_texture(profile: Dictionary) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = AVATAR_SHEET
	atlas.region = Rect2(Vector2(profile["avatar"]) * AVATAR_SIZE, Vector2.ONE * AVATAR_SIZE)
	return atlas
