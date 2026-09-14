extends RefCounted
## What a skin is: one unique object the player owns. GameState keeps the collection and saves it;
## this only makes skins up, checks loaded ones and draws their frames and art.
##
## Preloaded like target_profiles.gd. A skin is a read-only Dictionary
## {"id": int, "name": String, "wear_float": float, "image_id": int, "rarity": String}.

## Rarest last, the order the weights below follow.
const RARITIES: PackedStringArray = ["common", "uncommon", "rare", "exotic", "legendary"]
const RARITY_WEIGHTS: PackedFloat32Array = [50.0, 25.0, 15.0, 7.0, 3.0]

const RARITY_COLORS := {
	"legendary": Color("#f2c12e"),
	"exotic": Color("#e0393e"),
	"rare": Color("#ee6fc8"),
	"uncommon": Color("#2e4fbf"),
	"common": Color("#79c7f2"),
}
## How much of the rarity colour shows behind the art; the border draws it at full strength.
const BACKGROUND_ALPHA := 0.3

const MIN_WEAR := 0.01
const MAX_WEAR := 0.99

## Art per image id, once there is any: skin-<id>-32.png and skin-<id>-128.png in IMAGE_DIR. A
## missing file draws as empty art, over the rarity background.
const IMAGE_DIR := "res://assets/images/skins"
const IMAGE_COUNT := 16
const PREVIEW_SIZE := 32
const FULL_SIZE := 128

const WEAPONS: PackedStringArray = [
	"AK-47", "M4A4", "M4A1-S", "AWP", "Desert Eagle", "Glock-18", "USP-S", "P250",
	"MP9", "P90", "FAMAS", "Galil AR", "SSG 08", "Karambit", "Butterfly Knife", "Bayonet",
]
const FINISHES: PackedStringArray = [
	"Neon Dusk", "Rust Bloom", "Cold Borscht", "Night Market", "Paper Tiger", "Static",
	"Copper Veins", "Toxic Sunrise", "Pixel Rot", "Velvet Fang", "Winter Asphalt", "Glass Wolf",
	"Burnt Orange", "Ghost Ledger", "Hot Wire", "Blue Tape",
]


## A new skin with the given id and everything else rolled.
static func random_skin(id: int) -> Dictionary:
	return make_skin(
		id,
		"%s | %s" % [WEAPONS[randi_range(0, WEAPONS.size() - 1)], FINISHES[randi_range(0, FINISHES.size() - 1)]],
		randf_range(MIN_WEAR, MAX_WEAR),
		randi_range(0, IMAGE_COUNT - 1),
		_random_rarity(),
	)


static func make_skin(id: int, name: String, wear_float: float, image_id: int, rarity: String) -> Dictionary:
	var skin := {"id": id, "name": name, "wear_float": wear_float, "image_id": image_id, "rarity": rarity}
	skin.make_read_only()
	return skin


## A skin read back from the save, or an empty Dictionary when it is not one this build can draw.
static func from_saved(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var id: Variant = value.get("id")
	var name: Variant = value.get("name")
	var wear: Variant = value.get("wear_float")
	var image_id: Variant = value.get("image_id")
	var rarity: Variant = value.get("rarity")
	if typeof(id) != TYPE_INT or typeof(name) != TYPE_STRING or typeof(image_id) != TYPE_INT:
		return {}
	if typeof(wear) not in [TYPE_FLOAT, TYPE_INT] or typeof(rarity) != TYPE_STRING or not RARITIES.has(rarity):
		return {}
	return make_skin(id, name, clampf(float(wear), MIN_WEAR, MAX_WEAR), image_id, rarity)


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## The locale key of a rarity's display name, e.g. SKIN_RARITY_LEGENDARY.
static func rarity_key(rarity: String) -> String:
	return "SKIN_RARITY_" + rarity.to_upper()


## The frame behind a skin's art: a full-strength rarity border over a fainter fill of the same
## colour. Art is an object on transparent pixels, so the fill shows around it.
static func frame_style(rarity: String, border_width: int) -> StyleBoxFlat:
	var color := rarity_color(rarity)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, BACKGROUND_ALPHA)
	style.border_color = color
	style.set_border_width_all(border_width)
	return style


static func preview_texture(skin: Dictionary) -> Texture2D:
	return _texture(skin, PREVIEW_SIZE)


static func full_texture(skin: Dictionary) -> Texture2D:
	return _texture(skin, FULL_SIZE)


static func _texture(skin: Dictionary, size: int) -> Texture2D:
	var path := "%s/skin-%d-%d.png" % [IMAGE_DIR, int(skin.get("image_id", -1)), size]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _random_rarity() -> String:
	var total := 0.0
	for weight in RARITY_WEIGHTS:
		total += weight
	var roll := randf() * total
	for i in RARITIES.size():
		roll -= RARITY_WEIGHTS[i]
		if roll < 0.0:
			return RARITIES[i]
	return RARITIES[0]
