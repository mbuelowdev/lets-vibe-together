## A settings file already on disk, so a check can prove the dropdowns and the volume sliders
## boot from the file rather than from the OS locale, the live window size and the first-run
## volumes.
##
## The file is written here and then loaded through the same Settings.load_settings() a cold
## boot calls, because the check vocabulary has no page-reload step: seeding user:// and
## reloading the page would be the truer test, but this exercises every line of the load path
## except the one that decides when it runs.
extends RefCounted

const PATH := "user://settings.cfg"
const SECTION := "video"
const AUDIO_SECTION := "audio"

## German because it is nowhere near any plausible OS locale on a test runner, so a passing
## check cannot be the fallback quietly agreeing with the saved value.
const LOCALE := "de"

## 2 -> 1280x720. The browser canvas will not actually resize (canvas_resize_policy=2), which
## is the point: the dropdown has to be reading the file, not measuring the window.
const RESOLUTION_SCALE := 2

## Deliberately the windowed key. A browser refuses fullscreen without a user gesture, so
## seeding one would test the refusal, not the load.
const WINDOW_MODE := "WINDOW_MODE_WINDOWED"

## Anything but 25, which is where a first run has it, so a passing check cannot be the
## default quietly agreeing with the file. A whole percent, matching the slider's 1% step.
const MASTER_VOLUME := 40

## Anything but 100, where a first run has them, and apart from each other and from master, so a
## passing check cannot be a default - or the wrong slider's value - quietly agreeing with the file.
const MUSIC_VOLUME := 60
const SFX_VOLUME := 80


func apply() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "locale", LOCALE)
	config.set_value(SECTION, "resolution_scale", RESOLUTION_SCALE)
	config.set_value(SECTION, "window_mode", WINDOW_MODE)
	config.set_value(AUDIO_SECTION, "master_volume", MASTER_VOLUME)
	config.set_value(AUDIO_SECTION, "music_volume", MUSIC_VOLUME)
	config.set_value(AUDIO_SECTION, "sfx_volume", SFX_VOLUME)
	if config.save(PATH) != OK:
		push_error("saved_settings scenario: could not write %s" % PATH)
		return
	# Engine.get_main_loop() rather than the bare Settings identifier: autoloads are undefined
	# under --check-only, and a RefCounted scenario has no get_node() of its own.
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("Settings")
	if settings == null:
		push_error("saved_settings scenario: Settings autoload is missing")
		return
	settings.load_settings()
