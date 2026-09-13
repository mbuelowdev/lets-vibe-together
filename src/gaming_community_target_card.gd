extends Button
## One target in the Gaming Community list: its avatar, then its name. The whole card is the
## button, so hovering anywhere on it lights it up (the styleboxes in the scene).

const TargetProfiles := preload("res://src/target_profiles.gd")

## The profile this card draws, as GameState.target_profiles() handed it over.
var profile: Dictionary = {}


func show_profile(new_profile: Dictionary) -> void:
	if is_same(new_profile, profile):
		return
	profile = new_profile
	($Avatar as TextureRect).texture = TargetProfiles.avatar_texture(profile)
	($Name as Label).text = profile["name"]
