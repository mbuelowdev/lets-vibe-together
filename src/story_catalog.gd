extends RefCounted
## Who speaks and what they say: the speakers the story knows and the segments it can play. Data
## and the queries over it, nothing else - this file never touches the running game.
##
## Preloaded rather than autoloaded (`const Catalog := preload("res://src/story_catalog.gd")`),
## for the reason skill_catalog.gd gives at the top of itself: no state to hold, and a preloaded
## script parses under `--check-only` where an autoload identifier does not.
##
## SEGMENTS is empty. The system is finished and the prose is not: the skill trees are still
## being cut (docs/SKILLTREE.md), and a segment is worth authoring once the skill it hangs off
## exists. Until then nothing plays, story.gd's backfill is a no-op, and validate() has nothing
## to complain about. Authoring one is filling in a row below - see the commented example.
##
## ## Segment ids
##
## SCREAMING_SNAKE, unique, and stable once shipped: the id is what lands in the save file, in
## `seen_story` and `pending_story` (game_state.gd). Renaming a shipped id makes the player's
## record of it meaningless - they would see a segment again, or lose one - so pick the boring
## name now. The id is deliberately *not* the skill id: the tree gets re-cut and the ending beat
## has no skill behind it at all (docs/STORY.md ends the story at a million rubles).

## Which end of the box the portrait stands at. Left unless a line says otherwise, so a
## two-hander reads as a conversation rather than two boxes from the same corner.
const SIDE_LEFT := &"left"
const SIDE_RIGHT := &"right"

const SIDES: Array[StringName] = [SIDE_LEFT, SIDE_RIGHT]

const SkillCatalog := preload("res://src/skill_catalog.gd")

## Everyone the story can put in a box, keyed by the StringName a line names them with.
##
## The four characters in docs/STORY.md. `name` is a locale/story.csv key, like every other
## string on screen. `portrait` is a path under res://assets/images/ - portrait-mother.png, the
## dash-case the images there already use - and is empty until the art exists, which draws the
## grey placeholder in story_dialog.gd instead.
##
## No per-speaker colour. Every missing portrait draws the same flat grey, so a box reads as
## missing its art rather than as a finished design, and nothing has to be re-picked when the
## real portraits land.
const SPEAKERS := {
	&"self": {"name": "STORY_SPEAKER_SELF", "portrait": ""},
	&"mother": {"name": "STORY_SPEAKER_MOTHER", "portrait": ""},
	&"friend": {"name": "STORY_SPEAKER_FRIEND", "portrait": ""},
	&"coder": {"name": "STORY_SPEAKER_CODER", "portrait": ""},
}

## The segments, keyed by segment id, in the order they are declared - which is the order
## story.gd plays two that come due at once, and the order a replay queue is rebuilt in.
##
## `skill` is the skill id whose unlock triggers the segment, and is optional: absent or empty
## means nothing triggers it automatically and only Story.play() reaches it. `lines` is ordered
## and is one dialog box each; a line is `speaker` (a key in SPEAKERS), `text` (a story.csv key),
## an optional `side` (SIDE_LEFT / SIDE_RIGHT, left by default) and an optional `thought`.
##
## `thought` marks a line as something the speaker thinks rather than says, which story_dialog.gd
## draws in grey instead of white. It is the line that changes, not the speaker: the same
## character speaks in some boxes and thinks in others, so this is a flag per line rather than a
## second entry in SPEAKERS.
##
## A line is two lines of the box at font size 12, which is roughly 100 characters each - 200 in
## the box. Nothing can check that here - the row holds a key, and how many lines it takes depends
## on the locale and its font - so story_dialog.gd warns at runtime when a translation overflows.
const SEGMENTS := {
	# "FIRST_SCAM": {
	# 	"skill": "MORE_MONEY_GAIN_1",
	# 	"lines": [
	# 		{"speaker": &"friend", "text": "STORY_FIRST_SCAM_01"},
	# 		{"speaker": &"self", "text": "STORY_FIRST_SCAM_02", "side": SIDE_RIGHT},
	# 		{"speaker": &"self", "text": "STORY_FIRST_SCAM_03", "side": SIDE_RIGHT,
	# 			"thought": true},
	# 	],
	# },
}


static func has(id: String) -> bool:
	return SEGMENTS.has(id)


## Every segment id, in declaration order. Dictionary keys keep the order they were written in,
## which is why the rows above can be read as a running order.
static func segment_ids() -> PackedStringArray:
	return PackedStringArray(SEGMENTS.keys())


## Total, like every accessor here: an id nobody authored reads as an empty segment rather than
## an error, so a save holding an id this build no longer has costs nothing.
static func segment(id: String) -> Dictionary:
	return SEGMENTS.get(id, {}) as Dictionary


static func lines(id: String) -> Array:
	return segment(id).get("lines", []) as Array


static func line_count(id: String) -> int:
	return lines(id).size()


## One line of a segment, or an empty dictionary when the index is off either end - story.gd
## walks an index that a re-cut segment can outlive.
static func line(id: String, index: int) -> Dictionary:
	var all := lines(id)
	if index < 0 or index >= all.size():
		return {}
	return all[index] as Dictionary


static func line_speaker(line_data: Dictionary) -> StringName:
	return line_data.get("speaker", &"") as StringName


static func line_text_key(line_data: Dictionary) -> String:
	return String(line_data.get("text", ""))


## Whether the line is thought rather than spoken. Absent reads as spoken, so only the boxes that
## are thoughts say anything about it.
static func line_is_thought(line_data: Dictionary) -> bool:
	return bool(line_data.get("thought", false))


static func line_side(line_data: Dictionary) -> StringName:
	var side := line_data.get("side", SIDE_LEFT) as StringName
	return side if SIDES.has(side) else SIDE_LEFT


## The skill whose unlock plays `id`, or "" for a segment with no trigger.
static func skill_of(id: String) -> String:
	return String(segment(id).get("skill", ""))


## Every segment `skill_id` triggers, in declaration order. A list rather than one id: two beats
## on one skill is a legal way to author, and the order they play in should be readable off the
## rows above rather than off whichever one a lookup happened to find.
static func segments_for_skill(skill_id: String) -> PackedStringArray:
	var found := PackedStringArray()
	if skill_id.is_empty():
		return found
	for id in SEGMENTS:
		if skill_of(id) == skill_id:
			found.append(id)
	return found


static func has_speaker(key: StringName) -> bool:
	return SPEAKERS.has(key)


static func speaker(key: StringName) -> Dictionary:
	return SPEAKERS.get(key, {}) as Dictionary


static func speaker_name_key(key: StringName) -> String:
	return String(speaker(key).get("name", ""))


static func speaker_portrait(key: StringName) -> String:
	return String(speaker(key).get("portrait", ""))


## Everything wrong with the tables above, one string per problem, empty when they hang together.
## story.gd runs this at boot and warns each line, the way skills.gd does for the skill tree: a
## segment nobody can read or a line naming a speaker who does not exist never shows up on screen
## as an error, only as a box that draws wrong.
##
## A `skill` naming a skill the catalog does not have is reported like the rest but is expected
## while the trees are being cut - a segment written ahead of its node is work in progress, not a
## broken build, so this warns and the game plays on.
static func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for id in SEGMENTS:
		var skill := skill_of(id)
		if not skill.is_empty() and not SkillCatalog.has(skill):
			problems.append("segment %s triggers on unknown skill %s" % [id, skill])
		var all := lines(id)
		if all.is_empty():
			problems.append("segment %s has no lines" % id)
			continue
		for index in all.size():
			problems.append_array(_line_problems(id, index, all[index]))
	return problems


static func _line_problems(id: String, index: int, line_data: Variant) -> PackedStringArray:
	var problems := PackedStringArray()
	var where := "segment %s line %d" % [id, index]
	if typeof(line_data) != TYPE_DICTIONARY:
		problems.append("%s is not a dictionary" % where)
		return problems
	var data := line_data as Dictionary
	if String(data.get("text", "")).is_empty():
		problems.append("%s has no text key" % where)
	var speaker_key := data.get("speaker", &"") as StringName
	if not has_speaker(speaker_key):
		problems.append("%s names unknown speaker %s" % [where, speaker_key])
	if data.has("side") and not SIDES.has(data["side"] as StringName):
		problems.append("%s has side %s, expected left or right" % [where, data["side"]])
	# Caught rather than coerced: `"thought": "yes"` is truthy, so a typo here would silently draw
	# every such line grey with nothing saying why.
	if data.has("thought") and typeof(data["thought"]) != TYPE_BOOL:
		problems.append("%s has a non-boolean thought flag: %s" % [where, data["thought"]])
	return problems
