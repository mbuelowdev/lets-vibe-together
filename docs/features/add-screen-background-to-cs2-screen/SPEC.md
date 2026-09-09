# Add screen background to the CS2 screen

## 1. Context & Goal

Today every "app" in the desktop shell is just a flat `ColorRect` fill: selecting the cs2 icon
repaints the whole canvas `#6e3a3a` (`main.gd`, `APP_BACKGROUNDS`). That was the placeholder from
`create-main-scene-with-switchable-tabs`. The cs2 screen now has real art (`screen-base-cs2.png`),
so selecting the cs2 app must show that artwork filling the 640×360 canvas instead of the flat
colour, with the taskbar still drawn on top of it. This is the first real app screen and sets the
pattern later app screens (home/steam/chrome) will follow.

## 2. Scope

### In scope

- Copy `screen-base-cs2.png` from the asset library into `res://assets/library/image/` and import it
  with nearest-neighbour filtering (no mipmaps).
- Add a full-canvas `Screen` `TextureRect` to `main.tscn` under `UI`, layered above `Background` and
  below `Taskbar`.
- `main.gd`: map app ids to screen artwork; show the cs2 artwork when `cs2` is selected and hide the
  `Screen` node for every other app (home/steam/chrome keep their flat colours).
- Register the four verification-hook fields in §7.

### Out of scope

- Any change to `taskbar.tscn` / `taskbar.gd` (icons, hover, selection, sizes).
- Changing `APP_BACKGROUNDS` colours or removing the `Background` `ColorRect` — the cs2 colour
  `#6e3a3a` must keep being applied underneath the artwork, because inherited checks read
  `backgroundColor` after selecting cs2.
- Screen artwork for home, steam or chrome.
- Project display settings, palette, resolution, stretch mode, or the input map.
- Any interactive content *inside* the cs2 screen (buttons, menus, HUD) — this is a static backdrop.

## 3. Relevant files / existing code

### Files to modify

- `main.tscn` — insert a `Screen` (`TextureRect`) node under `UI`, between `Background` and
  `Taskbar` in child order.
- `main.gd` — add the app-id → screen-texture mapping, apply it in `_ready()` and in
  `_on_app_selected()`, and register the new bridge fields in `_register_bridge_fields()`.

### Files to create

- `assets/library/image/screen-base-cs2.png` (+ Godot-generated `.import`) — the cs2 screen artwork,
  copied from the asset library.

### Existing patterns / conventions

- `main.gd` holds the app→visual mapping as a `const` `Dictionary` keyed by app id
  (`APP_BACKGROUNDS`); add `APP_SCREEN_TEXTURES` next to it in the same style.
- `main.gd` caches child nodes into `_`-prefixed vars in `_ready()` (`_background`, `_taskbar`);
  cache the new node as `_screen` the same way.
- Bridge registration lives in one `_register_bridge_fields()` helper using
  `get_node("/root/EgonBridge")` — never the `EgonBridge` identifier (see `main.gd:29-40`).
- Pixel-art textures are loaded by `res://assets/library/image/...` path constants and drawn with
  `texture_filter = TEXTURE_FILTER_NEAREST` (see `taskbar.gd:6-7,33`).
- Purely decorative Controls use `mouse_filter = Control.MOUSE_FILTER_IGNORE` so they never eat taskbar
  clicks (`main.tscn` `Background`, `taskbar.tscn` `Base`).

## 4. Assets

- `screen-base-cs2.png` — the cs2 application screen backdrop. Copied to
  `res://assets/library/image/screen-base-cs2.png`, imported with **nearest** filter and mipmaps off.
  It is drawn as the full-canvas backdrop of the cs2 app, anchored at base-space `(0, 0)` and
  covering the whole 640×360 canvas. Its native size is expected to be exactly 640×360, so draw it
  1:1 with no scaling; only if the imported native size differs must the implementer scale it
  uniformly (nearest, no smoothing) so the drawn artwork still covers exactly 640×360.

## 5. Interface / Contract

All coordinates are in the 640×360 base space (project viewport is 640×360, `canvas_items` stretch,
`keep` aspect, `integer` scale — at the 640×360 runner window the scale is exactly 1×, no letterbox).

Scene tree after the change (`main.tscn`):

```
Main (Node2D)                       main.gd
└── UI (CanvasLayer)
    ├── Background (ColorRect)      child 0 — unchanged, full rect (0,0)-(640,360)
    ├── Screen (TextureRect)        child 1 — NEW
    └── Taskbar (instance)          child 2 — unchanged, must stay the LAST child
```

`Screen` (`TextureRect`) properties:

- `anchors_preset = 15` (full rect): `anchor_right = 1.0`, `anchor_bottom = 1.0`,
  `grow_horizontal = 2`, `grow_vertical = 2`, all offsets `0` → rect `(0,0)` size `640×360`.
- `texture = null` in the scene file; assigned at runtime by `main.gd`.
- `visible = false` in the scene file.
- `expand_mode = TextureRect.EXPAND_IGNORE_SIZE` — the Control rect stays 640×360 regardless of the
  texture.
- `stretch_mode = TextureRect.STRETCH_KEEP` when the texture is natively 640×360 (draw 1:1 from the
  top-left); `TextureRect.STRETCH_SCALE` only in the fallback case where the native size is not
  640×360.
- `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`.
- `mouse_filter = Control.MOUSE_FILTER_IGNORE`.

`main.gd` additions:

```gdscript
const APP_SCREEN_TEXTURES := {
    "cs2": "res://assets/library/image/screen-base-cs2.png",
}

var _screen: TextureRect

func _apply_app_screen(app_id: String) -> void
    # loads and shows APP_SCREEN_TEXTURES[app_id] on _screen when present,
    # otherwise clears _screen.texture and sets _screen.visible = false
```

Behaviour contract:

- On boot (`home` selected) `Screen` is hidden and has no texture; the canvas is the flat `#2e4272`
  `Background`.
- Selecting `cs2` (icon click or `Taskbar.select_app(3)`) shows `Screen` with the
  `screen-base-cs2.png` texture covering the full 640×360 canvas. `Background.color` is still set to
  `#6e3a3a` underneath by the existing `APP_BACKGROUNDS` code path.
- Selecting `home`, `steam` or `chrome` again hides `Screen` and clears its texture; those apps look
  exactly as they do today.
- The taskbar (bottom strip and its four 32×32 icons at x `0-32`, `32-64`, `64-96`, `96-128`, y
  `328-360`) is drawn over the artwork and stays fully clickable.
- No new signals, exported properties, input actions, or animations.

## 6. Implementation notes / constraints

- Layering is child order inside the single `UI` `CanvasLayer`: `Background` → `Screen` → `Taskbar`.
  Do not add a second `CanvasLayer` and do not touch the taskbar's `z_index`; just insert `Screen`
  before `Taskbar` in `main.tscn`.
- Keep `APP_BACKGROUNDS` and its assignment in `_on_app_selected()` exactly as they are. The flat
  colour is now a backdrop behind the artwork; removing it breaks the inherited
  `create-main-scene-with-switchable-tabs` checks that read `backgroundColor == "#6e3a3a"` after
  selecting cs2.
- `_ready()` must call `_apply_app_screen(_taskbar.selected_app_id())` after wiring the signal, so the
  initial state is derived from the same code path as a switch (no duplicated boot logic).
- Load the texture with `load()` on the path constant (mirrors `taskbar.gd`); cache it in a var so
  repeated switching does not reload. If the load fails, `push_error` and leave `Screen` hidden — do
  not crash.
- `Screen` must never intercept mouse input (`MOUSE_FILTER_IGNORE`), otherwise the hover feedback in
  `taskbar.gd` stops firing for icons it overlaps.
- Web export: the file is a plain PNG under `assets/library/image/`, same as the existing taskbar art;
  no extra export-preset work.
- Edge case: selecting cs2 twice in a row is a no-op (`taskbar.select_app` early-returns when the
  index is unchanged, so `app_selected` is not re-emitted) — nothing to special-case.
- Do not add addons or dependencies.

## 7. Verification hooks

- Mechanism: the `EgonBridge` autoload, already in the project. The implementer calls
  `get_node("/root/EgonBridge").register_field("name", func(): return …)` once per field, inside
  `main.gd`'s existing `_register_bridge_fields()` called from `_ready()`. Do not use the
  `EgonBridge` identifier (`--check-only` does not load autoloads), do not hand-roll
  `JavaScriptBridge`, do not reassign `window.__egon`.
- Call: `window.__egon.state()` returns a JSON object of every registered field — this feature's and
  every earlier feature's.
- Fields this feature registers, with type and meaning:
  - `screenVisible` (`boolean`) — `true` when the `Screen` `TextureRect` is visible in the tree and
    has a non-null texture; `false` otherwise.
  - `screenTexture` (`string`) — `res://` resource path of the texture currently assigned to `Screen`,
    or `""` when it has none.
  - `screenTextureSize` (`string`) — the artwork's drawn size in base pixels as `"WxH"` (e.g.
    `"640x360"`): the texture's native size when `stretch_mode` is `STRETCH_KEEP`, or the `Screen`
    rect size when it is `STRETCH_SCALE`. `""` when there is no texture.
  - `taskbarAboveScreen` (`boolean`) — `true` when `Screen` and `Taskbar` share the same parent and
    `Taskbar.get_index() > Screen.get_index()`, i.e. the taskbar draws over the screen art.
- Existing fields this feature reuses, from the GAME_MAP "Debug bridge" table:
  - `selectedApp`
  - `backgroundColor`
  - `taskbarVisible`

## 8. Test scenarios

- Scenarios this feature verifies against:
  - `default` (existing) — a normal boot shows `home` with no screen artwork, and the cs2 screen is
    reachable from there by clicking the cs2 taskbar icon at base-space `(112, 344)`, exactly as the
    inherited `create-main-scene-with-switchable-tabs` check already does. No new scenario is needed.

## 9. Acceptance criteria

1. Selecting the cs2 app shows the `screen-base-cs2.png` artwork filling the whole 640×360 canvas at
   its native pixel scale, with crisp nearest-neighbour pixels.
2. The taskbar strip and its icons remain drawn on top of the cs2 artwork and stay clickable and
   hoverable.
3. Switching back to home, steam or chrome hides the artwork and restores that app's flat background
   colour exactly as before.

## 10. Explicitly NOT this task

- Do not remove or recolour the `Background` `ColorRect`, and do not change `APP_BACKGROUNDS`.
- Do not edit `taskbar.tscn` or `taskbar.gd`.
- Do not change project display/stretch/resolution settings.
- Do not rename or re-register existing bridge fields.
- Do not add screen art for home, steam or chrome "while you're in there".
