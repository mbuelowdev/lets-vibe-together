# Add the main menu

## 1. Context & Goal

The game boots straight into the desktop shell: `run/main_scene` is the app-switcher scene, and the
only front end the player has ever seen is a taskbar. This feature gives the game the screen it
opens on — room art, the title, and four buttons — and makes the desktop something you arrive at
rather than something you are dropped into.

This is the roadmap's Horizon 1, tasks 1, 2 and 5 (background art, title art, main menu). Tasks 3
and 4 — the Settings and Credits screens — are **not** in this feature: their buttons exist and do
nothing, so the menu keeps its shape and its click targets when those screens land.

The desktop scene is renamed as part of this. "Main" meant "the main scene" and now points at the
wrong thing; the desktop is one screen among several and is called `game.tscn` / `game.gd`.

## 2. Scope

### In scope

- `main_menu.tscn` / `main_menu.gd` — the new boot scene.
- Rename `main.tscn` → `game.tscn`, `main.gd` → `game.gd`, root node `Main` → `Game`; point
  `run/main_scene` at `res://main_menu.tscn`.
- A `Scrim`: a near-black, full-height column down the middle of the canvas, behind the title and
  buttons, with hard edges.
- Start/Continue as one button, labelled from whether a save file exists.
- Settings and Credits as wired, inert placeholders.
- Quit, which exits without saving.
- Keyboard/gamepad focus through the four buttons.
- Five `MAIN_MENU_*` keys across all 26 locales in `locale/ui.csv`.
- A `save_presence_changed` signal on `GameState`, so the Start/Continue label can react to the
  save file appearing or going away under a menu that is already drawn.
- A `screen` bridge field, registered by both screens, plus the `mainMenu*` fields in §7.
- Menu navigation prepended to every existing check in `.egon/checks/`, which now has to walk
  through the menu to reach the desktop it was written against.

### Out of scope

- The Settings screen and the Credits screen (roadmap Horizon 1, tasks 3 and 4). The three
  dropdowns, "Delete local save" and "Save & Quit" stay on Home exactly as they are.
- Any way back from the desktop to the menu. There is no pause menu yet — that is Horizon 2.
- Any change to `taskbar.tscn` / `taskbar.gd`, `APP_BACKGROUNDS`, or the app screens.
- Project display settings, palette, resolution, stretch mode, or the input map.
- Music, transitions, or animation on the menu.
- Rewriting the shipped SPECs under `docs/features/` that name `main.gd` / `main.tscn`. They
  describe what was built when it was built; this section is the record of the rename.

## 3. Relevant files / existing code

### Files to create

- `main_menu.tscn` / `main_menu.gd` — the menu.
- `.egon/checks/add-main-menu.json`.

### Files to modify

- `main.tscn` → `game.tscn`, `main.gd` → `game.gd` (+ `.uid`), root node renamed, `SCREEN_ID` and
  the `screen` bridge field added.
- `project.godot` — `run/main_scene`.
- `game_state.gd` — `save_presence_changed`.
- `locale/ui.csv` — five new rows.
- `.egon/checks/*.json` — the three-step menu prefix.
- `godot-cli.md`, `docs/godot-cli.md` — the sentence naming what `--quit-after` loads.
- Doc comments in `settings.gd` and `taskbar.gd` that point at `main.gd`.

### Existing patterns / conventions

- Scenes live at the repo root with a same-named script beside them (`taskbar.tscn` / `taskbar.gd`).
- Controls are positioned with explicit anchors and offsets in the `.tscn`, not with containers
  (`main.tscn`, `taskbar.tscn`). Buttons on the existing screen are 176×24 and 4px apart.
- Node references are cached into `_`-prefixed vars in `_ready()`.
- Bridge registration lives in one `_register_bridge_fields()` helper using
  `get_node("/root/EgonBridge")` — never the `EgonBridge` identifier, which is undefined under
  `--check-only`.
- Purely decorative Controls use `mouse_filter = Control.MOUSE_FILTER_IGNORE`.
- Button text is baked into the `.tscn` in English and overwritten from `tr()` at runtime; the
  text server language tag is set per-Control so the font chain picks the right face
  (`game.gd`'s `_apply_language`).
- The first press with nothing focused enters the UI instead of activating it
  (`game.gd`'s `FOCUS_ENTRY_ACTIONS` / `_unhandled_input`).

## 4. Assets

Both are 1:1, nearest, no mipmaps, drawn in the 640×360 base space.

- `assets/images/main-menu-screen.png` — 640×360 room backdrop, the full canvas at `(0, 0)`.
  Shared with the Settings and Credits screens when those land, so it is a `TextureRect` on the
  menu rather than anything menu-specific.
- `assets/images/main-menu-title-text.png` — 256×100, drawn top-centred at `(192, 8)`. The opaque
  artwork sits at `x 28..229`, `y 13..92` inside it, so drawing the whole texture centred puts the
  visible title within half a pixel of the canvas centre and leaves a 21px top margin. Menu only —
  not on Settings or Credits.

## 5. Interface / Contract

All coordinates are in the 640×360 base space.

```
MainMenu (Control)                  main_menu.gd — full rect, mouse_filter IGNORE
├── Background (TextureRect)        full rect, main-menu-screen.png, STRETCH_KEEP, IGNORE
├── Scrim (TextureRect)             (112,0)-(528,360), gradient below, STRETCH_SCALE, IGNORE
├── Title (TextureRect)             (192,8)-(448,108), main-menu-title-text.png, STRETCH_KEEP, IGNORE
├── StartButton (Button)            (232,204)-(408,228)
├── SettingsButton (Button)         (232,232)-(408,256)
├── CreditsButton (Button)          (232,260)-(408,284)
└── QuitButton (Button)             (232,288)-(408,312)
```

`Scrim` is a `GradientTexture2D`, 416×1, filled linearly along x, stretched to 416×360 — the full
canvas height. Black throughout; the alpha holds `0.9` across the middle 292px — 70% of the column,
`x 174..466` — and eases to `0.7` over the outer 62px on each side, where the column stops with a
hard edge. Gradient offsets are those widths over 416: `0, 0.1490385, 0.8509615, 1`.

Write all four of its anchors in the scene file, `anchor_top = 0.0` included even though `0.0` is
the property default. `anchors_preset` **is** applied when the scene loads, and preset 14 is
`VCENTER_WIDE`, not `HCENTER_WIDE`: it sets `anchor_top` to `0.5`, which an unwritten `anchor_top`
then inherits, leaving a column down the bottom half of the screen only. The correct preset for a
full-height vertical band is 13.

The 292px core is what the UI stands on: it clears the title's opaque artwork (`x 220..421`) by
about 45px on each side and the buttons (`x 232..408`) by 58px, so both read as sitting on a bar
rather than being exactly as wide as one. The hard edge is deliberate: the column is meant to read
as a bar the menu rests on, not as a vignette that fades into the room. One texture row rather than 360 identical ones: the ramp only varies along x, and a 1px-tall texture
has nothing for the project's nearest filter to round when it is scaled down the screen.

Every button is 176×24, horizontally centred (`anchor_left = anchor_right = 0.5`,
`offset_left = -88`, `offset_right = 88`), 4px apart, on `res://resources/theme.tres` at font size
12. The stack of buttons sits below the desk edge on purpose: centred vertically it would cover the
monitor, which is the one part of the backdrop worth looking at.

`main_menu.gd`:

```gdscript
const GAME_SCENE := "res://game.tscn"
const SCREEN_ID := "mainMenu"
const START_KEY := "MAIN_MENU_START"
const CONTINUE_KEY := "MAIN_MENU_CONTINUE"
const SETTINGS_KEY := "MAIN_MENU_SETTINGS"
const CREDITS_KEY := "MAIN_MENU_CREDITS"
const QUIT_KEY := "MAIN_MENU_QUIT"

func _refresh_labels() -> void      # start/continue decision + all four tr() labels + font tag
func _apply_saved_locale() -> void  # Settings.locale() -> TranslationServer, "" left alone
```

`game_state.gd`:

```gdscript
signal save_presence_changed(exists: bool)  # emitted only when save_file_exists() flips
```

Behaviour contract:

- A cold boot shows the menu. Nothing draws the desktop first, at any window size or locale.
- `StartButton` reads `MAIN_MENU_CONTINUE` when `GameState.save_file_exists()`, `MAIN_MENU_START`
  otherwise. It is one button either way: there is one save, the player never picks a slot, and
  both labels lead to the same scene.
- Pressing it changes the scene to `res://game.tscn`, which boots exactly as it does today — home
  selected, the balance `GameState` already read at startup.
- `SettingsButton` and `CreditsButton` are enabled and do nothing.
- `QuitButton` calls `get_tree().quit()` with no save first, unlike Home's "Save & Quit". Nothing
  reachable from the menu changes anything worth writing: preferences write themselves as they
  change, and the balance has only been read here.
- With nothing focused, the first `ui_up` / `ui_down` / `ui_left` / `ui_right` / `ui_accept` /
  `ui_focus_next` / `ui_focus_prev` focuses `StartButton` and is consumed — including `ui_accept`,
  so no one starts a game with the press they meant as "wake up". Focus then walks the column and
  wraps at both ends.
- The menu draws in the saved locale. `GameState` and `Settings` are autoloads and have both read
  their files before the menu's `_ready()`.
- No new input actions, exported properties, or animations.

## 6. Implementation notes / constraints

- The saved locale used to be applied by `main.gd`, because it ran first. It does not any more, so
  `main_menu.gd` applies `Settings.locale()` itself. It deliberately does **not** copy `game.gd`'s
  `LANGUAGES` table: an unset locale is left on the OS default, which is where `game.gd`'s own
  fallback lands anyway. When Horizon 1 task 3 moves settings onto their own screen, the table and
  this boot-time apply belong together wherever that ends up — not duplicated in two scripts.
- The Start/Continue label cannot be decided once in `_ready()` and left alone. Egon scenarios are
  applied on the *first frame*, after `_ready()` has already looked at an empty `user://`, so
  `saved_progress` would leave the menu offering to start a game it has a save for. Hence
  `save_presence_changed`: `GameState` emits when the answer to `save_file_exists()` actually
  flips, and the menu rebuilds its labels. Polling the filesystem every frame would be the other
  way, and this codebase already coalesces its writes rather than putting I/O in `_process`.
- `save_file_exists()` keeps asking the filesystem. The cached flag behind the signal exists only
  to suppress repeat emissions; a check reading the field can never be fooled by it going stale.
- `main_menu.gd` unregisters its bridge fields in `_exit_tree()`. Start is the only way off the
  screen, so anything left registered would hand every check that runs afterwards a menu that is
  not there — and the providers close over nodes that are about to be freed. `screen` and
  `focusedControl` are `game.gd`'s fields too; `SceneTree` tears the old scene down and readies the
  new one inside one deferred call, so `game.gd` re-registers both before the bridge next pushes a
  snapshot.
- Root is a plain `Control`, not `Node2D` + `CanvasLayer`. The layer on `game.tscn` is there to put
  UI above `Node2D` content; the menu has none.
- Do not add addons or dependencies.

## 7. Verification hooks

Registered from `main_menu.gd`'s `_register_bridge_fields()`, called from `_ready()`, via
`get_node("/root/EgonBridge")`.

- `screen` (`string`) — `"mainMenu"` while the menu is up, `"game"` once the desktop is. Registered
  by both scenes, so a check can tell them apart without knowing what either draws. **`game.gd`
  registers this too.**
- `mainMenuVisible` (`boolean`) — the menu root is visible in the tree.
- `mainMenuTitleVisible` (`boolean`) — the `Title` `TextureRect` is visible and has a texture.
- `mainMenuScrimVisible` (`boolean`) — the `Scrim` `TextureRect` is visible and has a texture.
- `mainMenuScrimBehindUi` (`boolean`) — the scrim's child index is above `Background` and below
  `Title` and all four buttons, i.e. it darkens the backdrop without covering anything. Child order
  is the whole of that layering, so this reads it back rather than trusting the scene file to have
  stayed in the order it was written in.
- `mainMenuScrimRect` (`string`) — where the column actually landed, as `"x,y,WxH"`; `"112,0,416x360"`.
  The two booleans above are both still true of a scrim covering half the screen — an anchor is all
  it takes, see §5 — so the rect is the field that can see it.
- `mainMenuButtons` (`Array` of `string`) — the four labels as drawn, top to bottom. Proves both
  the order and that the text followed the locale rather than keeping the English in the scene file.
- `mainMenuStartIsContinue` (`boolean`) — the first button is offering to continue a save. Read off
  the same value the label was built from, so it cannot disagree with what the player sees.
- `focusedControl` (`string`) — name of the focused Control, or `""`. Same field and meaning
  `game.gd` registers.

Existing fields this feature reuses: `saveFileExists`, `rubles`, `taskbarVisible`, `selectedApp`.

## 8. Test scenarios

No new scenario. The menu is reachable from a cold boot, and the two states of its first button are
exactly what `no_save` and `saved_progress` already establish.

Every pre-existing check in `.egon/checks/` gains the same three steps at the front, because the
desktop they were written against is now three steps away:

```json
{ "await": "window.__egon.state().screen", "equals": "mainMenu" },
{ "click": [320, 216] },
{ "await": "window.__egon.state().screen", "equals": "game" }
```

`[320, 216]` is the centre of `StartButton`. Clicking rather than switching scenario keeps the
prefix working under every scenario, including the `no_save` / `saved_progress` / `rich` /
`earned` / `saved_settings` ones that a check cannot combine with a second scenario.

Quit has no check. Exiting the runner is not something the suite can assert and then continue from.

## 9. Acceptance criteria

1. A cold boot shows the room backdrop with the title top-centred and four centred buttons below
   it, standing on a near-black column that spans the full canvas height; the desktop is never
   drawn first.
2. The first button reads "Continue Game" when a save exists and "Start Game" when it does not, and
   opens the desktop either way, with the saved balance intact.
3. Settings and Credits leave the player on the menu; Quit exits without writing a save.
4. The menu is fully operable by keyboard or gamepad, and the first press does not start a game.
5. All four labels are translated in the 26 locales, in the language the player last chose.
6. The whole existing check suite still passes.

## 10. Explicitly NOT this task

- Do not build the Settings or Credits screens, and do not move the dropdowns off Home.
- Do not add a way back to the menu from the desktop — that is Horizon 2's pause menu.
- Do not edit `taskbar.tscn` or `taskbar.gd`.
- Do not change project display/stretch/resolution settings or the input map.
- Do not rename or re-register existing bridge fields.
- Do not make Quit save. Home's "Save & Quit" is a different button with a different promise.
