# Taskbar app icon hover effects

## 1. Context & Goal

The taskbar in `res://taskbar.tscn` already swaps each app icon between an unselected and a selected
variant, but the icons give no feedback when the mouse is over them, so the taskbar feels dead until
you actually click. The updated `taskbar-app-icons.png` sheet now ships two extra columns (an
unselected-hover and a selected-hover variant per app), so this feature wires mouse hover on each
taskbar app button to the matching hover column of the sheet. It is the first piece of "this is a
desktop OS you can point at" polish, so hover must be a pure visual swap — it must never change which
app is selected or which background color is showing.

## 2. Scope

### In scope

- Re-copy the updated `taskbar-app-icons.png` (now 4 columns × 4 rows) from the asset library into
  `res://assets/library/image/taskbar-app-icons.png`.
- Extend `res://taskbar.gd` to build hover atlas textures for columns 2 (unselected hover) and 3
  (selected hover) alongside the existing columns 0 and 1.
- Track which app button the mouse is currently over and drive that button's `texture_normal` to the
  correct hover variant, restoring the non-hover variant on mouse exit.
- Keep the hover variant correct when selection changes while the mouse is still on an icon
  (e.g. clicking an unselected icon under the cursor moves it from column 2 to column 3).
- Register the new debug bridge fields listed in §7 from `res://main.gd`.

### Out of scope

- Pressed / focus / disabled visual states (`texture_pressed`, `texture_focused`, `texture_disabled`).
- Tooltips, hover sounds, icon nudge/scale animation, or any tween — hover is an instant swap only.
- The taskbar util icons (`taskbar-util-icons.png`), a clock, or a start menu.
- Anything about background colors, app switching logic, or `main.tscn` layout beyond bridge fields.
- Changing the 320×180 base resolution, stretch mode, or palette.

## 3. Relevant files / existing code

### Files to modify

- `res://taskbar.gd` — build hover atlas texture arrays, track the hovered button index, expose
  `hovered_index()`, `hovered_app_id()`, `hover_enter_count()`, `hovered_icon_column()`; connect each
  `TextureButton`'s `mouse_entered` / `mouse_exited`.
- `res://main.gd` — register the three new bridge fields in `_register_bridge_fields()`.
- `res://assets/library/image/taskbar-app-icons.png` — replace with the updated 4-column sheet from the
  asset library (plus its regenerated `.import`).

### Files to create

- None.

### Existing patterns / conventions

- `taskbar.gd` builds the selection and hover textures in code from a single sheet via
  `_make_atlas(sheet, col, row, cell_w, cell_h)` returning an `AtlasTexture` with `filter_clip = true`;
  keep that helper and keep column/row indices as its arguments rather than hard-coded `Rect2`s. The
  resting textures are separate baked sub-resources in `taskbar.tscn` (see the §6 amendment).
- Icon geometry lives in `taskbar.tscn`: each button carries its own offsets and a 32×32
  `custom_minimum_size`. Do not move it back into code. This line originally read that geometry was
  code-driven from `ICON_DRAW_SIZE = 32` in `_configure_button()`; both are gone.
- `main.gd` registers every bridge field in one `_register_bridge_fields()` call site using
  `get_node("/root/EgonBridge")` — follow that exactly; `taskbar.gd` itself registers nothing.
- Textures use `texture_filter = TEXTURE_FILTER_NEAREST` everywhere for the pixel-art look; the hover
  textures must too (they inherit it from the button, which already sets it).

## 4. Assets

- `taskbar-app-icons.png` — the taskbar app icon sheet, re-copied because it now has **4 columns × 4
  rows**. Rows top-to-bottom are `home`, `steam`, `chrome`, `cs2`, matching `APP_IDS`. Columns
  left-to-right are: `0` unselected, `1` selected, `2` unselected-hover, `3` selected-hover. Cells are
  square and equal-sized: derive `cell_w = sheet.get_width() / 4.0` and `cell_h = sheet.get_height() / 4.0`
  rather than hard-coding pixel numbers. Each cell is drawn into a 32×32 button rect
  (sized in `taskbar.tscn`) with `ignore_texture_size = true` and `STRETCH_SCALE`, so the implementer does not
  need to rescale the image itself. Import settings: nearest/lossless, mipmaps off, same as the
  currently imported sheet.

## 5. Interface / Contract

`res://taskbar.gd` (extends `Control`), additions and changes:

```gdscript
const ICON_SHEET_COLUMNS := 4
const COL_UNSELECTED := 0
const COL_SELECTED := 1
const COL_UNSELECTED_HOVER := 2
const COL_SELECTED_HOVER := 3

var _hovered_index: int = -1
var _hover_enter_count: int = 0
var _hover_textures: Array[AtlasTexture] = []          # column 2, one per app row
var _selected_hover_textures: Array[AtlasTexture] = [] # column 3, one per app row

func hovered_index() -> int          # -1 when the mouse is over no app icon
func hovered_app_id() -> String      # "" when hovered_index() == -1, else APP_IDS[hovered_index()]
func hover_enter_count() -> int      # cumulative count of mouse_entered on any app icon
func hovered_icon_column() -> int    # atlas column currently shown by the hovered button; -1 when none
```

Behavior contract:

- `_build_atlas_textures()` fills all four arrays: for each row `r` in `APP_IDS.size()`, column 0 →
  `_normal_textures[r]`, 1 → `_selected_textures[r]`, 2 → `_hover_textures[r]`, 3 →
  `_selected_hover_textures[r]`.
- `_refresh_icon_textures()` chooses each button's `texture_normal` from a 2×2 decision:
  | | not hovered | hovered |
  | --- | --- | --- |
  | not selected | column 0 | column 2 |
  | selected | column 1 | column 3 |
- In `_ready()`, for each button `i`: `button.mouse_entered.connect(_on_app_mouse_entered.bind(i))` and
  `button.mouse_exited.connect(_on_app_mouse_exited.bind(i))`.
- `_on_app_mouse_entered(index)`: if `_hovered_index == index` return; set `_hovered_index = index`,
  increment `_hover_enter_count`, call `_refresh_icon_textures()`.
- `_on_app_mouse_exited(index)`: only clear if `_hovered_index == index`; set `_hovered_index = -1`,
  call `_refresh_icon_textures()`.
- `select_app(index)` keeps its existing early-return and signal behavior; because it already calls
  `_refresh_icon_textures()`, clicking the hovered icon moves it from column 2 to column 3 with no
  extra code.
- `selected_icon_count()` must keep returning `1` at all times: it currently compares
  `texture_normal == _selected_textures[i]`, so it must be widened to count a button whose
  `texture_normal` is either `_selected_textures[i]` **or** `_selected_hover_textures[i]`.
- `hovered_icon_column()` returns `-1` when `_hovered_index == -1`; otherwise `COL_SELECTED_HOVER` when
  `_hovered_index == _selected_index`, else `COL_UNSELECTED_HOVER`. Compute it from the button's actual
  `texture_normal` identity (compare against the four arrays) so the field can never disagree with what
  is drawn.
- No new input actions, no new signals, no exported properties, no scene-file node changes.

## 6. Implementation notes / constraints

- Defensive sheet handling: read `cell_w = sheet.get_width() / 4.0`. If the copied sheet turns out to
  have fewer than 4 columns (width/height ratio implies < 4), log `push_warning` once and fall back to
  reusing column 0 for unselected-hover and column 1 for selected-hover so nothing crashes and no atlas
  region falls outside the texture. The check for column indices will fail in that case, which is the
  intended signal that the wrong sheet was copied.
- Hover feedback is an instant texture swap only — no tween, no tooltip, no offset change (settled on
  Discord). Do not set `Control.mouse_default_cursor_shape`.
- `mouse_entered` / `mouse_exited` are reliable in the web export because each `TextureButton` already
  has `mouse_filter = MOUSE_FILTER_STOP` and the parent `Apps`/`Taskbar` controls are `MOUSE_FILTER_IGNORE`;
  do not switch to polling `get_global_mouse_position()` in `_process`.
- Edge case: moving the pointer directly from one icon to its neighbour can deliver `mouse_entered` for
  the new button before `mouse_exited` for the old one. The guard in `_on_app_mouse_exited` (only clear
  when the index matches) is what makes that ordering safe — do not remove it.
- Edge case: `_hover_enter_count` never decrements and is not reset by `select_app`.
- Because a hovered icon can hold the selected-hover texture, any other code that identifies "the
  selected icon" by texture identity must consider both selected columns — `selected_icon_count()` is
  the only such place today.
- Keep `filter_clip = true` on the new atlases so neighbouring sheet columns never bleed in at nearest
  filtering.

### Amendment — 2026-09-09: icon geometry and resting textures moved into the scene

`taskbar.tscn` was a 640×0 rect as saved, because `taskbar.gd` built the layout in `_ready()` and the
editor does not run non-`@tool` scripts — so the taskbar did not appear in the editor preview. Button
offsets, `custom_minimum_size`, and each button's resting `texture_normal` (an `AtlasTexture`
sub-resource; `AppHome` uses column 1, matching the boot selection) are now baked into the scene, and
`_configure_button()` and `ICON_DRAW_SIZE` are gone. See the matching amendment in
`docs/features/create-main-scene-with-switchable-tabs/SPEC.md` §6.

What this section describes is otherwise unchanged: `_build_atlas_textures()` still measures the sheet
and `_refresh_icon_textures()` still drives every state swap, so `hovered_icon_column()` and
`selected_icon_count()` keep reporting from live `texture_normal` identity. One behavioural change:
`_refresh_icon_textures()` now returns early when `_normal_textures` is empty. Previously a missing or
unreadable sheet made `_build_atlas_textures()` bail and the next line index an empty array, crashing
at boot; the baked resting textures are now the fallback instead.

## 7. Verification hooks

- Mechanism: the `EgonBridge` autoload, already in the project. `res://main.gd` calls
  `get_node("/root/EgonBridge").register_field("name", func(): return …)` once per field inside the
  existing `_register_bridge_fields()`, called from `_ready()`. Do not use the bare `EgonBridge`
  identifier — `--check-only` does not load autoloads. Do not hand-roll a `JavaScriptBridge` and do not
  reassign `window.__egon`.
- Call: `window.__egon.state()` returns a JSON object of every registered field — this feature's and
  every earlier feature's.
- Fields this feature registers, with type and meaning:
  - `hoveredApp` (`string`) — app id of the taskbar icon the mouse is currently over (`"home"`,
    `"steam"`, `"chrome"`, `"cs2"`), or `""` when the mouse is over none.
    Provider: `func() -> String: return _taskbar.hovered_app_id()`.
  - `hoverEnterCount` (`number`) — cumulative count of mouse-enter events on any taskbar app icon since
    boot; never decrements. Provider: `func() -> int: return _taskbar.hover_enter_count()`.
  - `hoveredIconColumn` (`number`) — atlas sheet column currently drawn by the hovered icon: `2` for
    unselected-hover, `3` for selected-hover, `-1` when nothing is hovered.
    Provider: `func() -> int: return _taskbar.hovered_icon_column()`.
- Existing fields this feature reuses, from the GAME_MAP "Debug bridge" table:
  - `selectedApp`
  - `selectedIconCount`

Every check expression is a deterministic read of this object. Nothing infers pass/fail from pixels,
colors, or "the screenshot looks right."

## 8. Test scenarios

- Scenarios this feature verifies against:
  - `default` (existing) — the game as it normally boots: taskbar visible along the bottom with `home`
    selected and no icon hovered. Hover is driven entirely by pointer position, which the runner can
    produce from a cold boot, so no new scenario is needed.

Coordinate note for the implementer: base viewport is 320×180 with `canvas_items` stretch at 16:9, so
the runner's 640×360 space is exactly 2× Godot coordinates. Icon centers are at
`(32, 328)` home, `(96, 328)` steam, `(160, 328)` chrome, `(224, 328)` cs2; `(500, 100)` is empty
background above the taskbar.

The machine-executable checks live in `.egon/checks/add-on-hover-effects.json`.

## 9. Acceptance criteria

1. Moving the mouse onto a taskbar app icon immediately swaps that icon to its hover artwork, and
   moving the mouse off restores the non-hover artwork, for every one of the four apps.
2. The hover artwork respects selection: the currently selected app shows the selected-hover variant
   while hovered, every other app shows the unselected-hover variant, and hovering never changes which
   app is selected or the background color.
3. Exactly one taskbar icon reads as selected at all times, including while an icon is hovered.

## 10. Explicitly NOT this task

- Do not add pressed, focused, or disabled button textures.
- Do not add tweens, tooltips, sounds, or position offsets to the hover state.
- Do not edit node positions, anchors, or offsets in `taskbar.tscn` — geometry stays code-driven in
  `taskbar.gd`.
- Do not rename or remove any existing bridge field, and do not register these fields from
  `taskbar.gd`.
- Do not add addons or dependencies.
