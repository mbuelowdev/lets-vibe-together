# Create main scene with switchable tabs

## 1. Context & Goal

`res://main.tscn` in this branch is still an empty `Node` — the game has no screen at all. This feature establishes the game's visual foundation: a 640×360 pixel-art base resolution that is upscaled with nearest-neighbour integer scaling, a bottom-attached taskbar built from the uploaded taskbar art, and four clickable app icons that act as tabs. Exactly one app is selected at a time and each app paints a different (placeholder) full-screen background, so later features can hang real app content off a selection that already works.

## 2. Scope

### In scope

- Project display settings: base viewport 640×360, `canvas_items` stretch, `keep` aspect, integer scale mode, nearest-neighbour default texture filter.
- `main.tscn` rebuilt as the app shell: full-canvas background `ColorRect` + taskbar UI layer.
- A `taskbar.tscn` / `taskbar.gd` component: `taskbar-base.png` spanning the bottom of the canvas, plus four 32×32 app buttons (home, steam, chrome, cs2) left-aligned, no gaps.
- Click-to-select: clicking an app icon swaps that icon to its selected variant, deselects the previously selected one, and changes the background colour.
- One placeholder background colour per app (flat fill, no content).
- `EgonBridge` fields listed in §7.

### Out of scope

- `taskbar-util-icons.png` (microphone / internet / sound / more), a clock, a start button, or any right-hand taskbar area.
- Real app content, windows, window chrome, dragging, or per-app UI beyond the flat colour.
- Keyboard shortcuts for tab switching, hover/pressed animations, sound.
- The player/world/camera feature described in the game map — it is not present in this branch's tree. Do not recreate it, do not reference its scripts or bridge fields.
- `portrait-of-egon.webp` and `font-vt323-regular.ttf`.

## 3. Relevant files / existing code

### Files to modify

- `project.godot` — add the `[display]` section (window size 640×360, stretch mode `canvas_items`, aspect `keep`, scale mode `integer`) and `rendering/textures/canvas_textures/default_texture_filter=0` (nearest). Leave the existing `EgonBridge` autoload entry and `run/main_scene` untouched.
- `main.tscn` — currently `[node name="Main" type="Node"]` with no children. Rebuild as described in §5, keeping the root node named `Main`.

### Files to create

- `main.gd` — script on the `Main` root: owns the background colour, listens to the taskbar's selection signal, registers the bridge fields.
- `taskbar.tscn` — the taskbar Control subtree (base image + four app buttons).
- `taskbar.gd` — script on the taskbar root: builds the atlas regions, tracks the selected index, emits `app_selected`.
- `assets/library/images/taskbar-base.png` and `assets/library/images/taskbar-app-icons.png` (+ their `.import` files) — copied in from the asset library.

### Existing patterns / conventions

- `egon/egon_bridge.gd` is an autoload. Register fields with `get_node("/root/EgonBridge").register_field(...)` — never the bare `EgonBridge` identifier, because `--check-only` does not load autoloads.
- One scene file per component with a same-named script beside it (`taskbar.tscn` / `taskbar.gd`), scenes at the repo root, matching `main.tscn` at the root.
- GDScript: tabs for indentation, typed declarations, `snake_case` members, `SCREAMING_SNAKE` constants.

## 4. Assets

- `taskbar-base.png` — the taskbar background strip. Placed as a `TextureRect` anchored to the bottom of the 640×360 canvas, drawn at its **native height** `H` (do not scale vertically) and stretched horizontally to the full 640 px width (`stretch_mode = STRETCH_SCALE`, `texture_filter = TEXTURE_FILTER_NEAREST`). Its top edge sits at `y = 360 - H`.
- `taskbar-app-icons.png` — the app icon sheet. Treat it as a grid of **4 rows × 2 columns**: rows top-to-bottom are `home`, `steam`, `chrome`, `cs2`; column 0 is the unselected variant, column 1 is the selected variant. Slice it with `AtlasTexture` regions derived from the measured cell size, and draw every icon at exactly **32×32** base pixels (scale the region only if the measured cell is not 32×32), nearest filtering, no mipmaps.

## 5. Interface / Contract

### Display / project settings

```
[display]
window/size/viewport_width=640
window/size/viewport_height=360
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"

[rendering]
textures/canvas_textures/default_texture_filter=0
```

All coordinates below are in the 640×360 base space, origin top-left.

### Scene tree

`main.tscn`

```
Main (Node2D)                       → main.gd
└── UI (CanvasLayer)
    ├── Background (ColorRect)      anchors full rect (0,0)-(640,360), mouse_filter = IGNORE
    └── Taskbar (instance of taskbar.tscn)
```

`taskbar.tscn`

```
Taskbar (Control)                   → taskbar.gd
                                    anchors: bottom-wide (left 0, right 0, bottom 0),
                                    offset_top = -32 (static; see the §6 amendment),
                                    mouse_filter = IGNORE
├── Base (TextureRect)              texture = taskbar-base.png, full-rect of Taskbar,
│                                   stretch_mode = STRETCH_SCALE, mouse_filter = IGNORE
└── Apps (Control)                  full-rect of the canvas bottom row (see button layout)
    ├── AppHome   (TextureButton)
    ├── AppSteam  (TextureButton)
    ├── AppChrome (TextureButton)
    └── AppCs2    (TextureButton)
```

### App button layout (base pixels)

Each button is exactly 32×32 with `stretch_mode = STRETCH_SCALE`, `ignore_texture_size = true`, `texture_filter = TEXTURE_FILTER_NEAREST`, and **bottom edge at `y = 360`** (top edge `y = 328`), regardless of the taskbar art's native height. No gaps between cells:

| Button | app_id | left x | rect (base px) | centre (base px) |
| --- | --- | --- | --- | --- |
| AppHome | `home` | 0 | (0,328)–(32,360) | (16,344) |
| AppSteam | `steam` | 32 | (32,328)–(64,360) | (48,344) |
| AppChrome | `chrome` | 64 | (64,328)–(96,360) | (80,344) |
| AppCs2 | `cs2` | 96 | (96,328)–(128,360) | (112,344) |

The taskbar rect is a static 32 px tall and `Base` scales `taskbar-base.png` to fill it, so the icons always sit flush inside the bar.

### Colours

| app_id | background colour |
| --- | --- |
| `home` | `#2e4272` |
| `steam` | `#1b2838` |
| `chrome` | `#3f6b3a` |
| `cs2` | `#6e3a3a` |

### Scripts

`taskbar.gd`

```gdscript
extends Control

signal app_selected(app_id: String)

const APP_IDS: PackedStringArray = ["home", "steam", "chrome", "cs2"]

func select_app(index: int) -> void      # clamps, no-op if already selected, emits app_selected
func selected_index() -> int
func selected_app_id() -> String
func selected_icon_count() -> int        # buttons currently showing their column-1 texture
```

`main.gd`

```gdscript
extends Node2D

const APP_BACKGROUNDS := {
	"home": Color("#2e4272"),
	"steam": Color("#1b2838"),
	"chrome": Color("#3f6b3a"),
	"cs2": Color("#6e3a3a"),
}

func _on_app_selected(app_id: String) -> void   # sets Background.color, increments _app_switch_count
```

### Behaviour

- On boot, index 0 (`home`) is selected: `AppHome` shows its selected variant, the other three show unselected, and `Background.color` is `#2e4272`.
- Clicking an app button selects it, sets every other button back to its unselected texture, and repaints the background. Exactly one button is ever in the selected state.
- Clicking the already-selected button is a no-op: no signal, no switch-count increment, no colour change.
- The switch counter starts at `0` on boot (the initial `home` selection does not count) and increments by one per actual selection change.

## 6. Implementation notes / constraints

- The game map describes a merged tree with `world.tscn`/`player.tscn` and `main.gd` bridge fields (`playerX`, `moveCount`, …). None of those files exist in this branch; `main.tscn` is a bare `Node`. Write `main.gd` fresh and do not register or reference those fields.
- Changing the viewport from the Godot default (1152×648, stretch `disabled`) to 640×360 `canvas_items`/`keep`/`integer` is intentional and now the project-wide art-style baseline: 640×360 pixel-art canvas, nearest-neighbour, integer upscale.
- At the runner's 640×360 window the integer scale is exactly 1× with no letterboxing, so base pixel `(x, y)` maps to window pixel `(x, y)`.
- Import both PNGs with `filter=false` / nearest and mipmaps off so the upscale stays crisp; if the editor default re-enables filtering, set it per-texture in the `.import` file.
- Derive the icon atlas regions from the sheet's measured dimensions (`texture.get_width() / 2`, `texture.get_height() / 4`) instead of hard-coding pixel offsets, so a differently sized sheet still slices into 4 rows × 2 columns. This still governs the selection/hover atlases `taskbar.gd` builds at runtime; the resting textures baked into `taskbar.tscn` do hard-code their regions (see the §6 amendment).
- Use `TextureButton` so clicks come through the normal GUI path; keep `Taskbar`, `Base` and `Background` at `MOUSE_FILTER_IGNORE` so only the four buttons consume input.
- Wire selection through the `app_selected` signal — `main.gd` must not reach into the buttons directly.
- Set the taskbar height statically in `taskbar.tscn` as `offset_top = -32.0` — see the amendment below; this line originally required deriving it from `base_texture.get_height()` at `_ready()`.
- No new addons, no third-party dependencies, no shaders.

### Amendment — 2026-09-09: the taskbar layout is static

The taskbar's geometry was originally computed in `taskbar.gd`'s `_ready()`. Godot does not run
non-`@tool` scripts in the editor, so the scene as saved was a 640×0 rect and the taskbar was
invisible in the editor preview. Layout now lives in `taskbar.tscn`:

- `Taskbar` carries `offset_top = -32.0`; `Base` carries `stretch_mode = STRETCH_SCALE`; each app
  button carries its own offsets, `custom_minimum_size` and a resting `AtlasTexture` sub-resource.
- The `_ready()` prologue that set `offset_top`, the `Base` texture and the mouse filters is gone,
  as is `_configure_button()`. `ICON_DRAW_SIZE` and `BASE_TEXTURE_PATH` went with them.
- `taskbar.gd` still owns the selection/hover swap and still measures the sheet to build those
  atlases; only the resting state is baked.

Hard-coding 32 does not affect upscaling. Under `canvas_items`/`keep`/`integer` the layout space is
permanently 640×360, so 32 is 32 *base units* and renders as 32 × N physical pixels at every window
size (32/64/96/384 px at 1×/2×/3×/12×). The accepted tradeoff: a `taskbar-base.png` of a different
native height is now scaled to fill the 32 px bar rather than resizing it.

## 7. Verification hooks

- Mechanism: the `EgonBridge` autoload, already in the project (`res://egon/egon_bridge.gd`). The implementer calls `get_node("/root/EgonBridge").register_field("selectedApp", func(): return taskbar.selected_app_id())` — one such call per field listed below, in `main.gd`'s `_ready()`. Do not use the bare `EgonBridge` identifier — `--check-only` does not load autoloads. Do not hand-roll `JavaScriptBridge` and do not reassign `window.__egon`.
- Call: `window.__egon.state()` returns a JSON object of every registered field.
- Fields this feature registers, with type and meaning:
  - `selectedApp` (`string`) — app id of the currently selected tab: `"home"`, `"steam"`, `"chrome"` or `"cs2"`.
  - `selectedAppIndex` (`number`) — index of the selected tab, `0`–`3` in the order home, steam, chrome, cs2.
  - `appSwitchCount` (`number`) — cumulative count of actual selection changes since boot; starts at `0`.
  - `backgroundColor` (`string`) — the `Background` ColorRect's current colour as a lowercase `#rrggbb` string (e.g. `"#2e4272"`).
  - `appIconCount` (`number`) — number of app buttons in the taskbar; `4`.
  - `selectedIconCount` (`number`) — how many app buttons are currently drawing their selected variant; must always be `1`.
  - `taskbarVisible` (`boolean`) — true when the taskbar node exists, is visible, and its base texture is loaded.
- Existing fields this feature reuses, from the GAME_MAP "Debug bridge" table: `None.` (none of those scripts exist in this branch).

## 8. Test scenarios

- Scenarios this feature verifies against:
  - `default` (existing) — the game as it normally boots. The taskbar, the four app icons and the initial `home` selection are all present on a cold boot, and switching is driven by clicks the runner can perform, so no extra scenario is needed.

## 9. Acceptance criteria

1. The game boots into a 640×360 pixel-art screen that upscales with crisp nearest-neighbour pixels, showing a bottom-attached taskbar drawn from the taskbar base art with four app icons in a row at its left edge.
2. Clicking an app icon selects it: that icon switches to its selected variant, every other icon returns to its unselected variant, and never more than one app is selected.
3. Each of the four apps shows its own distinct full-screen background colour, and the background changes as soon as a different app is selected.

## 10. Explicitly NOT this task

- Do not add the utility icons, a clock, or a start menu to the taskbar.
- Do not add input map actions or keyboard shortcuts.
- Do not add addons, plugins, or new autoloads, and do not edit `egon/egon_bridge.gd`.
- Do not create a scenario script; `default` covers this feature.
