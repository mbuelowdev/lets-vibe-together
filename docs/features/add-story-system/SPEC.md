# Add story system

A dialog-box story layer over the desktop: a sequence of boxes, each with a speaker portrait and a
line of text revealed word by word, advanced by the player, with the game paused underneath.
Sequences are triggered by unlocking a skill.

Text only - no voice, now or later.

## Scope

**In:** the system. A catalog of speakers and segments, the autoload that queues and tracks them,
the view that draws and paces them, the persistence that stops one replaying, a new translation
file for the lines to live in.

**Out:**

- **Story text.** `SEGMENTS` ships empty. Nothing plays until segments are authored.
- **Skill bindings.** The tree is unfinished, so no segment is wired to a skill id. The binding is
  one optional field per segment (below); filling it in is the authoring pass, not this change.
- **Portrait art.** Every speaker ships with an empty portrait path and draws a flat placeholder.
- **Non-skill triggers.** `docs/STORY.md` ends the story at a million rubles, not at a skill.
  `Story.play()` is public and a segment's skill binding is optional, so that hook is a later
  one-liner - it is not built here.
- **EgonBridge fields, `.egon/checks`, `.egon/scenarios`.** Per CLAUDE.md, not without being asked.
- Skipping a sequence, a text-speed setting, a story log or replay viewer, a main-menu prologue
  shown before the desktop exists.

## Decisions

| Question | Decision |
| --- | --- |
| Where story data lives | `src/story_catalog.gd`, a sibling of `skill_catalog.gd`. Narrative data stays out of the tree's economy data; a skill with no segment simply has none. |
| Text and localisation | A new `locale/story.csv` + `locale/story.*.translation`, registered in `project.godot`. Prose is long and grows; keeping it out of `ui.csv` keeps that file readable. Lines are `tr()` keys like every other string. |
| A skill already unlocked when its segment appears | Marked seen at load, never played. No wall of dialog when an old save meets a new segment. |
| An unfinished segment | Seen is recorded when a segment *finishes*. One that started and did not finish persists as pending and replays from its first line on the next load, so nothing is lost to a quit mid-sequence. |
| Controls | Click, Space or Enter. Mid-reveal it finishes the line; on a finished line it advances. Esc does nothing - a sequence is read through, not skipped. |
| Portraits | Optional path per speaker. Empty draws a flat grey placeholder, so the system runs with no new assets. |
| Layout | Full-width box across the bottom, over the taskbar; portrait standing on the box's top edge. |
| Thoughts | An optional `thought` flag per line, drawn in grey instead of the theme's white. Per line, not per speaker: the same character speaks in one box and thinks in the next. |
| Music | Faded out to silence for the duration, and faded back in after. Not muffled - the pause menu muffles because it is outside the fiction, but a story beat is read in silence, and this game's only voice is its text. |

## New files

### `src/story_catalog.gd`

`extends RefCounted`, static, no state - the shape of `skill_catalog.gd`, and read the same way
(`const Catalog := preload(...)`).

Two tables.

`SPEAKERS`, keyed by `StringName`:

```gdscript
const SPEAKERS := {
    &"self":   {"name": "STORY_SPEAKER_SELF",   "portrait": ""},
    &"mother": {"name": "STORY_SPEAKER_MOTHER", "portrait": ""},
    &"friend": {"name": "STORY_SPEAKER_FRIEND", "portrait": ""},
    &"coder":  {"name": "STORY_SPEAKER_CODER",  "portrait": ""},
}
```

The four characters in `docs/STORY.md`. `name` is a `story.csv` key. `portrait` is a path under
`res://assets/images/` (`portrait-mother.png`, matching the dash-case of the images already there)
and is empty until art exists.

No per-speaker colour. Every missing portrait draws the same flat grey
(`story_dialog.gd`'s `PORTRAIT_PLACEHOLDER_TINT`), so a placeholder reads as *missing art* rather
than as a design choice, and nothing has to be re-picked when the real portraits land.

`SEGMENTS`, keyed by segment id, **empty on delivery**:

```gdscript
const SEGMENTS := {
    # "FIRST_SCAM": {
    #     "skill": "MORE_MONEY_GAIN_1",
    #     "lines": [
    #         {"speaker": &"friend", "text": "STORY_FIRST_SCAM_01"},
    #         {"speaker": &"self",   "text": "STORY_FIRST_SCAM_02"},
    #     ],
    # },
}
```

Keyed by its own id rather than by skill id: the id is what persists in the save, so it must not
have to change when the tree is re-cut, and the ending beat has no skill behind it at all. `skill`
is optional - absent or empty means nothing triggers the segment automatically and only
`Story.play()` reaches it. `lines` is ordered and is one box each. A line's optional `side`
(`SIDE_LEFT` / `SIDE_RIGHT`, left default) is which end of the box the portrait stands at, so a
two-hander reads as a conversation, and its optional `thought` marks it as something the speaker
thinks rather than says.

Accessors, all static, all total - a missing key reads as empty, never an error:

`has(id)`, `segment_ids()`, `segment(id)`, `lines(id)`, `line(id, index)`, `line_count(id)`,
`line_speaker(line)`, `line_text_key(line)`, `line_side(line)`, `line_is_thought(line)`,
`skill_of(id)`, `segments_for_skill(id)` (declaration order), `has_speaker(key)`, `speaker(key)`,
`speaker_name_key(key)`, `speaker_portrait(key)`, and `validate()`.

`validate() -> PackedStringArray` mirrors `skill_catalog.validate()` and returns one string per
problem:

- a segment with no `lines`, or an empty one
- a line with an empty `text`
- a line whose `speaker` is not in `SPEAKERS`
- a line whose `side` is neither constant
- a line whose `thought` is not a boolean - caught rather than coerced, since `"thought": "yes"`
  is truthy and a typo would silently grey every such line with nothing saying why
- a non-empty `skill` that `skill_catalog.has()` does not know

That last one is a **warning, not a failure**: while the tree is being cut, a segment pointing at
a skill that does not exist yet is a work-in-progress, not a broken build.

### `src/story.gd` - `Story` autoload

Owns the queue, the seen set and the pause. Knows nothing about how a box is drawn.

```gdscript
signal segment_started(segment_id: String)
signal line_changed(segment_id: String, index: int)
signal segment_finished(segment_id: String)
```

```gdscript
func play(segment_id: String, force: bool = false) -> bool
func advance() -> void
func is_playing() -> bool
func current_segment() -> String
func current_line() -> Dictionary
func queued_count() -> int
func seen_ids() -> PackedStringArray
func pending_ids() -> PackedStringArray
func attach_view(view: Node) -> void
```

`play()` appends to the queue and returns whether it did: refused for an unknown id, and for one
already seen unless `force` (which is how a segment is re-watched during authoring). A segment
already pending is not refused - that is the replay. Starting the first segment of an empty queue
pauses the tree; `advance()` past the last line of the last segment unpauses it.

`advance()` moves to the next line, or finishes the segment and starts the next queued one with no
gap - the game must not flicker back to life between two segments.

**Pause ownership.** `get_tree().paused` already has an owner in `pause_menu.gd:167`. The two can
never be up at once - the taskbar's Home icon and the skill tree are both pausable, so neither can
act while the other is paused, and Esc is swallowed while a sequence is up - but the flag is shared
state, so Story records whether *it* was the one that set it and only clears it if so. A `play()`
call arriving while the tree is already paused by someone else queues the segment and leaves the
flag alone; it starts on the next `advance()`.

**Trigger.** `_ready()` gets `/root/GameState` and connects `skill_unlocked`, then queues every
unseen segment bound to that skill. `skill_unlocked` and not `unlocked_skills_changed`: the second
also fires for a save being read back and for a reset, and neither is a story beat. (`load_game()`
goes through `_set_unlocked_skills()`, which emits only the second - so a load cannot trigger a
sequence even before the seen set is consulted.)

### Two records: seen and pending

A segment is in one of three states, and two persisted sets in `GameState` hold them:

| State | In `pending_story` | In `seen_story` |
| --- | --- | --- |
| Never shown | no | no |
| Started, not finished | **yes** | no |
| Finished | no | yes |

- **Starting** a segment adds it to pending.
- **Finishing** it - `advance()` past its last line - takes it out of pending and puts it in seen.
- **Loading** a save queues every pending id, in `SEGMENTS` declaration order, and plays each from
  its **first** line.

So seen means *read through*, and a sequence interrupted by a quit, a crash or a closed browser tab
comes back whole on the next load rather than being lost. Segments are a handful of lines, so
replaying from the start is cheaper than persisting a line index and much easier to reason about -
a partially replayed line would also have to un-reveal itself.

Pending is never abandoned: leaving the desktop scene mid-sequence does not clear it (see **View
gating** below), so the only way out of pending is reading the segment through.

**Backfill.** Also in `_ready()`, after `GameState` is up and its save is loaded: every segment
that is **neither pending nor seen** and whose bound skill is already unlocked is marked seen. That
is what stops a segment added after a player already bought its skill from ambushing them. Pending
wins over the backfill - a segment the player was part-way through must replay, not be written off
as already read. A no-op while `SEGMENTS` is empty.

### View gating

A segment only *starts* once a view has called `attach_view()`; `play()` with no view attached
queues and waits. This is not optional plumbing - `Story` is an autoload, so its `_ready()` runs
before any scene exists and the boot scene is `main_menu.tscn`. Without the gate, a pending
segment would pause the tree and try to draw a box over the main menu, with no dialog node in the
scene to draw it.

`story_dialog.gd` calls `attach_view(self)` from its own `_ready()`, and `Story` then starts the
queue if anything is in it. Because the autoload outlives the scene change, a segment queued at
boot simply waits through the menu and plays when `game.tscn` comes up.

On **detach** - `story_dialog.gd` calling `Story.detach_view(self)` from its `_exit_tree()`, which
is Save & Quit, a transition back to the menu, or the game closing - `Story` drops the in-flight
segment back to the front of the queue and clears `get_tree().paused` if it was the one that set
it. Called rather than watched for: a `tree_exiting` connection would have to be bound to the node
to know which view left, and the view has an `_exit_tree()` to call from anyway. The call is
guarded on identity, so a view already replaced cannot take the current one's segment down with
it. Leaving the flag set would freeze whatever scene
came next; leaving the segment in flight with no view to draw it would strand the queue. The
segment stays pending on disk, so it replays.

`_ready()` also runs `Catalog.validate()` and `push_warning`s each problem, exactly as
`skills.gd:80` does for the tree.

### `src/story_dialog.gd` + `src/story_dialog.tscn`

The view. `process_mode = PROCESS_MODE_ALWAYS` (`3`), like `pause_menu.tscn`, so it keeps
processing and receiving input while the tree it paused is stopped. Hidden until a segment starts.

Node tree, at 640x360:

```
StoryDialog (Control, full rect, PROCESS_MODE_ALWAYS)
├── Scrim      ColorRect, full rect, black at 0.45, mouse_filter = STOP
├── Portrait   Control, 64x64, y 224..288
│   ├── Frame      Panel, the grey placeholder
│   └── Image      TextureRect, the portrait when there is one
├── Box        Panel, x 0..640, y 288..360
│   ├── SpeakerName  Label, x 16..624, y 296, h 12
│   ├── Text         Label, x 16..624, y 312, h 40
│   └── Hint         Control, 5x3, bottom-right, blinking
```

- **Box** is the full 640 wide and **72 tall**, so it covers the 32px taskbar entirely: 8px of
  padding, the 12px name, a 4px gap, 40px of text, 8px of padding. Its fill is `#1B2838` from
  `docs/GAME_DECISIONS.md`'s palette at **full opacity** - translucent, the taskbar's icons and
  counters read straight through it - with a 1px `#2E4272` border on the **top edge only**, since
  the other three sit on the edges of the screen. A `StyleBoxFlat` in the scene: the theme's
  styleboxes are all button art and none of them is a dialog panel.
- **Portrait** is 64x64 sitting on the box's top edge (y 224..288), inset 16px from the left or the
  right per the line's `side`, flipped in anchors rather than absolute x so it survives a viewport
  that is not 640 wide. `texture_filter = NEAREST` and `STRETCH_KEEP_CENTERED`, like every other
  sprite here. With no texture the `Image` hides and `Frame` shows instead:
  `PORTRAIT_PLACEHOLDER_TINT`, a flat mid-grey (`Color("#6b6b6b")`), behind the same 1px border -
  the same grey for every speaker, so the box is legibly missing its art rather than looking
  finished. The grey is applied to a duplicate of the scene's stylebox at runtime, so the constant
  in the script is the only place it is written.
- **Text** is 608x40 - two lines at font size 12 - with `autowrap_mode = AUTOWRAP_WORD_SMART` and
  `clip_text`. **40, not 32:** the font is 16px tall and the theme adds `line_spacing` of 3, so a
  line advances 19px and two need 38. At 32 the second line was silently clipped. Two lines of 608
  hold roughly 200 characters, about 100 each, and that is the authoring budget. It cannot be
  checked statically (the row holds a `tr()` key, and the answer depends on the locale and its
  font), so the view compares `get_line_count()` against `get_visible_line_count()` once per line
  and `push_warning`s once per string when a translation overflows.
- **Thoughts.** A line with `thought` set gets `THOUGHT_COLOR` (`Color("#98a0aa")`) as a
  `font_color` override on the text label - a cool grey that sits with the box's `#1B2838` fill
  and `#2E4272` border and still carries about 5:1 against that fill, since it is a line to be
  read rather than a hint. A spoken line **removes** the override rather than setting white, so a
  later change to the theme's Label colour still reaches the boxes. Applied per line, so the
  speaker name, the portrait and the reveal are all unaffected by it.
- **Hint** shows only on a fully revealed line, so the box says plainly whether it is still talking
  or waiting. Three stacked `ColorRect`s, 5px wide then 3 then 1, rather than a `▼`: nothing
  guarantees that glyph in the font chain (`resources/ui-font.tres`), and a missing one would draw
  a replacement box in whichever locale fell through. Whole pixels by construction, too.
- **Scrim** takes the mouse everywhere, which both dims the scene and makes the whole screen the
  click target. That is a superset of clicking the box, and the box is the only thing there is to
  aim at anyway.

**Word reveal.** `visible_characters` on the `Text` label, with
`visible_characters_behavior = TextServer.VISIBLE_CHARS_AFTER_SHAPING`, so wrapping is computed
once from the whole line and the text never reflows as it appears.

On each new line the script computes the reveal stops once, into a `PackedInt32Array`:

- one stop per word, at the index just past it, when the line contains a space
- one stop per character when it does not - `zh_Hans`, `zh_Hant` and `ja` do not space their words,
  and a whole line appearing at once is not a reveal

`_process` walks the stops on a clock:

- `REVEAL_WORDS_PER_SECOND := 6.0`, one constant, sensible range 4-8
- an extra `PAUSE_SENTENCE := 0.18` after a word ending `.`, `!`, `?` or `…`, and
  `PAUSE_CLAUSE := 0.09` after `,` or `;`. This is nearly all of what makes a reveal sound like
  speech rather than a ticker, and it is a dictionary lookup on the last character of a word.

**Input**, in `_input()` rather than `_unhandled_input()`, so it sits ahead of the pause menu's
`ui_cancel` handler (`pause_menu.gd:141`) without depending on node order between two
`PROCESS_MODE_ALWAYS` layers:

- returns immediately when not visible
- `ui_accept` - already Space, Enter and KP-Enter in `project.godot`, so **no new input action is
  needed** - or a left mouse press: finish the reveal if it is running, otherwise `Story.advance()`
- `ui_cancel`: consumed and ignored. Consumed is the point - unconsumed it reaches the pause menu,
  which would open over the sequence.
- everything else falls through
- each of those calls `set_input_as_handled()`
- a guard drops any input arriving on the frame the dialog opened. The press that bought the skill
  cannot actually reach here (a `Button` emits `pressed` during GUI delivery, after `_input` has
  already run for that event), but the dialog opening inside a click handler is close enough to
  that edge to be worth one line.

**Focus**, mirroring `pause_menu.gd:167`/`:179`: the focus owner is remembered and released on
open, and handed back on close. Without it the just-bought skill node keeps focus under the box and
the arrow keys walk a tree the player cannot see.

### `locale/story.csv`

Same header as `ui.csv` - `keys` plus the same 26 locale columns - so the existing translation
workflow applies unchanged.

Ships with four rows and nothing else: `STORY_SPEAKER_SELF`, `STORY_SPEAKER_MOTHER`,
`STORY_SPEAKER_FRIEND`, `STORY_SPEAKER_CODER`, English filled, the other 25 columns blank and
waiting for translators. These are labels, not story - no line of dialog is added.

**Only `story.en.translation` is generated.** Godot's `csv_translation` importer emits a
`.translation` per column that has content and nothing for an empty one, so the 25 blank columns
produce no files - and `locale/translations` in `project.godot` may only name files that exist or
every boot is 25 missing resources. So one entry is registered now, and a locale joins that list
when its column is filled. Until then `tr()` on a story key falls through to English, which reads
better than the bare key a registered-but-empty translation would have given.

## Changed files

### `project.godot`

- `Story="*res://src/story.gd"` in `[autoload]`, **after** `Skills`. `GameState` must be up and
  loaded first (the backfill reads the save); ordering after `Skills` means an unlock rebuilds
  effects and repaints the tree before the box covers it.
- `res://locale/story.en.translation` appended to `locale/translations` - only the one, for the
  reason under `locale/story.csv` above.

### `game.tscn`

A `StoryLayer` `CanvasLayer` at `layer = 3` as the **last** child of `Game`, holding a
`story_dialog.tscn` instance. Above `PauseLayer`'s `layer = 2`, which is what "overlays the game
scene" means here.

### `game.gd` - unchanged

Listed because the instinct is to wire the layer the way the taskbar and pause menu are wired, and
it turns out there is nothing to wire: `story_dialog.gd` reaches `/root/Story` and calls
`attach_view()` from its own `_ready()`, which it has to do anyway for the gating above to work
from any scene. No new bridge fields either, so this file is untouched.

### `music.gd`

A silence fade to sit alongside the muffle sweep: `set_silenced(bool)`, `is_silenced()`, and
`SILENCE_SECONDS := 0.6` - shorter than `MUFFLE_SECONDS`, because the muffle is a room going quiet
behind a menu and can take its time, while this is the game getting out of the way of someone
speaking. Idempotent and reversible mid-fade, exactly like `set_muffled()`.

**The level, not the player.** `fade_out()` already exists and is not what this wants: it ends in
`stop()`, so the track would restart from its beginning after every segment. So playback runs on
inaudibly underneath and comes back where it got to.

The muffle and the silence are two factors multiplied into one level, and `_clear_volume()` becomes
the single place it is worked out - `TRACK_VOLUME * lerpf(1.0, MUFFLE_VOLUME, _muffle) * (1.0 -
_silence)`. `_set_muffle()`, the new `_set_silence()` and `play()`'s fade-in all ask it for the
answer rather than computing their own, so they cannot disagree about the level when two of them
overlap. `set_silenced()` kills a running `play()` fade-in for the same reason: that tween aims at
the level as it was when it started and would otherwise pull against this one, and this fade is
headed to the same place anyway. `stop()` clears both factors.

### `game_state.gd`

Two sets, both mirroring how the unlocked-skills set is already stored - opaque ids, never
validated against a catalog, for the reason given at `unlock_skill()`:

- `const SAVE_KEY_STORY_SEEN := "seen_story"` and
  `const SAVE_KEY_STORY_PENDING := "pending_story"`
- `var _seen_story: Dictionary = {}` and `var _pending_story: Dictionary = {}`
- `signal story_seen_changed(segment_ids: PackedStringArray)` and
  `signal story_pending_changed(segment_ids: PackedStringArray)`
- `seen_story_segments()`, `is_story_segment_seen(id)`, `mark_story_segment_seen(id)`,
  `clear_story_segments()`, `_set_seen_story(ids)`
- `pending_story_segments()`, `is_story_segment_pending(id)`, `mark_story_segment_pending(id)`,
  `clear_story_segment_pending(id)`, `_set_pending_story(ids)`
- both read in `load_game()`, both written in `save_game()`, both cleared by `reset()`

`mark_story_segment_seen()` also drops the id from pending, so the two sets cannot both hold it -
finishing a segment is one call, not two that could drift apart.

Two private helpers fall out of having three id sets instead of one, and `unlocked_skills()` and
`_set_unlocked_skills()` are re-pointed at them rather than keeping their own copy of the same
five lines: `_sorted_ids(set)` reads a set out as a sorted list, and `_replace_id_set(set, ids)`
replaces one wholesale from what came off disk - dropping blanks and duplicates, marking dirty,
and returning whether anything actually changed so a load over an identical state does not make
every listener rebuild.

**No `SAVE_VERSION` bump.** An existing version-1 save has neither key, both read as an empty array
through the same default-value path as `rubles` and `skins`, and `Story`'s backfill then makes it
coherent. Bumping it would make every current save unreadable for nothing.

**Autosave covers the pending write.** `_mark_dirty()` from `mark_story_segment_pending()` puts the
file on the 1-second `SAVE_INTERVAL`, and `_notification()` flushes a dirty state on
`WM_CLOSE_REQUEST` / `EXIT_TREE`. The gap is the browser tab closed inside the first second of a
segment - the same gap every other value in the save already has, and the outcome there is the
segment simply not replaying, not a corrupt file.

No `last_saved_*` mirrors for either set: that family exists for bridge fields, and this change
adds none.

## Behaviour, end to end

1. The player buys a skill in the tree. `Skills.unlock()` charges it and
   `GameState.unlock_skill()` records it and emits `skill_unlocked`.
2. `Story` queues each unseen segment bound to that skill, marks it **pending**, pauses the tree,
   fades the music out over `SILENCE_SECONDS`, and emits `segment_started`.
3. The dialog takes focus off the desktop, shows itself, draws the first line's speaker name and
   portrait (or placeholder), and starts revealing words.
4. Click, Space or Enter finishes the current line's reveal. The next one moves to the next box.
5. Past the last line, the segment moves from pending to **seen**. The last line of the last queued
   segment unpauses the tree, fades the music back in, hides the dialog and hands focus back. The
   taskbar, the tree and CS2's match resume where they stopped, and the track picks up where it
   got to rather than restarting.

The music is silenced on every segment start, not only the first, and `Music` ignores a state it
is already in - so two segments back to back do not bounce the track up in the gap between them.
Leaving the desktop mid-sequence fades it back in along with clearing the pause.

Esc does nothing at any point in 3-5. The taskbar, the app screens and the skill tree are all
pausable, so they are inert under the box without anything having to disable them.

Quit at step 3 or 4 and the segment is still pending on disk. On the next load `Story` queues it,
waits through the main menu for the desktop's dialog to attach, and plays it again from its first
line. The skill stays bought - only the sequence repeats.

## Verification

Nothing plays on delivery - `SEGMENTS` is empty - so the change is verified in four parts.

**Static:**

```
godot --headless --path . --script res://src/story_catalog.gd --check-only
godot --headless --path . --script res://src/story.gd --check-only
godot --headless --path . --script res://src/story_dialog.gd --check-only
godot --headless --path . --script res://src/game_state.gd --check-only
godot --headless --path . --script res://src/game.gd --check-only
```

**Import** - the new CSV has no `.translation` files until it is imported, and a headless run with
a translation path that does not resolve fails at boot:

```
godot --headless --path . --import
```

**Runtime:**

```
godot --headless --path . --quit-after 60
```

and grep the log for `SCRIPT ERROR` - `Story`'s `_ready()`, the validate pass and the backfill all
run at boot, with or without a scene, and the boot scene is the main menu, so this run also proves
that a `Story` with nothing attached neither pauses nor draws. Both this and `res://src/game.tscn`
boot clean; the two `ObjectDB instances were leaked` / `resources still in use` lines at exit are
there on an unmodified checkout too, confirmed by stashing the change and booting again.

**On screen and in the record**, driven by a throwaway `PROBE_SEGMENT` in `SEGMENTS`, two probe
strings in `story.csv` and a temporary `StoryProbe` autoload pushing real key events at the window
with `get_window().push_input()` - all four removed before the change landed. 54 assertions, all
passing:

- queued at the main menu, the box is not drawn, the tree is not paused and no view is attached;
  the segment starts only once `game.tscn` brings a dialog up
- the box is 640x72 and covers the taskbar, the placeholder shows and the portrait image does not,
  the speaker name resolves through `story.csv`, and the portrait's anchor flips left to right on a
  line that asks for the other side
- words appear in order (7 of 98 characters two frames in), the hint stays hidden while revealing,
  Space mid-line reveals the rest **without** advancing, and the next Space advances
- Escape changes nothing: the pause menu stays closed and the sequence stays up
- read through: seen, not pending, unpaused, hidden - and a second `play()` of it is refused
- **interrupted**: forced to replay, then `change_scene_to_file` back to the menu mid-sequence -
  the tree unpauses, the view detaches, the segment is back in the queue and still pending, and
  returning to the desktop replays it from line 0
- a line with no spaces (`もしもし、聞こえているか。`) reveals one character at a time, and a line's
  wrapped line count does not move while it reveals
- a 60-word line trips the overflow warning (`wants 6 lines and the box shows 2`), which is also
  what caught the 32px text rect showing only one line of two

A third pass drove a spoken / thought / spoken segment: the text label carries no `font_color`
override on the spoken lines and resolves to the theme's white, carries `#98a0aa` on the thought
line, and has the override taken back off again on the spoken line after it - so the flag toggles
both ways rather than latching. `line_is_thought()` reads a missing key as false, and `validate()`
stays clean on a segment using the flag. A screenshot of the thought line next to the spoken one
confirmed it reads as clearly muted and still legible.

A second probe pass sampled `Music`'s player directly across a sequence - 26 more assertions, all
passing: the level leaves `TRACK_VOLUME` within two frames of a segment starting and does not jump
(0.0969 of 0.1), reaches exactly zero inside `SILENCE_SECONDS`, stays at zero across the boundary
between two queued segments, leaves zero gradually when the last one ends (0.0046 two frames in)
and returns to `TRACK_VOLUME`. `playing` stays true throughout and the playback position advances
across the segment (0.003 to 1.952), which is what proves the track was faded rather than stopped
and restarted. The pause menu still muffles rather than silences, and its level came out at exactly
`TRACK_VOLUME * MUFFLE_VOLUME`, so folding both factors into `_clear_volume()` left the muffle
unchanged.

Screenshots at 1280x720 of both portrait sides confirmed the layout, and caught two things the
assertions could not: the box's fill was translucent enough to read the taskbar through it, and its
side and bottom borders were drawing along the edges of the screen.

No `.egon/checks` or `.egon/scenarios` entry was added.
