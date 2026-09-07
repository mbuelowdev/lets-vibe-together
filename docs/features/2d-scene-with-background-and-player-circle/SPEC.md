# 2D scene with background and player circle

## 1. Context & Goal

The project is currently an empty `main.tscn` with a single `Node` root and no scripts, no input map, and no art. This feature turns it into a playable 2D world: a visually distinguishable dotted background, a circular player that moves with WASD, a smoothed camera that follows the player, and a colored bounding box marking the spawn point. Everything after this (enemies, pickups, levels) builds on the node layout, input actions, and debug bridge established here, so names and paths below are load-bearing.

## 2. Scope

### In scope

- Replace the `main.tscn` root with a `Node2D` scene containing background, spawn marker, and player.
- Dot-grid background over a fixed world rect, on a solid fill color, so player motion is obviously visible.
- `CharacterBody2D` player drawn in code as a 2-tone ring circle, moving at 320 px/s with WASD, 8-way, normalized diagonals.
- Input actions `move_up` / `move_down` / `move_left` / `move_right` added to `project.godot` (WASD only).
- A per-keypress input latch (see §5) so a single tap produces visible movement.
- `Camera2D` child of the player with position smoothing.
- Spawn bounding box: 128×128 translucent fill + outline, centered on the spawn point at world origin.
- `window.__egon.state()` JavaScriptBridge debug bridge (§6).

### Out of scope

- Collisions, obstacles, physics layers, enemies, pickups, HUD, menus, audio.
- Any imported image asset (the Discord avatar is NOT used; the circle is code-drawn — see §5).
- Autoloads, save/load, scene transitions, export preset or CI changes.
- Touch/gamepad/arrow-key input.

## 3. Relevant files / existing code

### Files to modify

- `main.tscn` — currently `[node name="Main" type="Node"]` only. Rebuild as the scene tree in §4 with root `Main` of type `Node2D`.
- `project.godot` — add `[input]` actions for WASD, and `display/window/stretch/mode="canvas_items"` with `aspect="expand"` so the 1152×648 project viewport renders correctly in the tester's 960×540 browser viewport. Do not change `run/main_scene`, `config/name`, or the rendering section.

### Files to create

- `scripts/main.gd` — root script; wires nothing but the `window.__egon.state()` debug bridge (§6).
- `scripts/player.gd` — `CharacterBody2D` movement, input latch, world clamp, `_draw()` of the circle.
- `scripts/background_grid.gd` — `Node2D` that `_draw()`s the dot grid.
- `scripts/spawn_marker.gd` — `Node2D` that `_draw()`s the spawn bounding box.

### Existing patterns / conventions

- No scripts exist yet; this feature sets the convention: one `.gd` file per node under `res://scripts/`, snake_case filenames matching the node's role, `class_name` omitted, scripts attached in `main.tscn` via `ext_resource`.
- Everything visual is drawn in `_draw()` with Godot primitives — no image/texture imports in this project yet.
- Colors are written as `Color("#RRGGBB")` literals at the top of each script as `const`.

## 4. Interface / Contract

### Scene tree (`main.tscn`)

```
Main (Node2D)                       script: res://scripts/main.gd
├── BackgroundLayer (CanvasLayer)   layer = -100
│   └── BackgroundFill (ColorRect)  anchors full rect, color #1E2233, mouse_filter = Ignore
├── BackgroundGrid (Node2D)         script: res://scripts/background_grid.gd, z_index = -50
├── SpawnMarker (Node2D)            script: res://scripts/spawn_marker.gd, position = (0, 0), z_index = -10
└── Player (CharacterBody2D)        script: res://scripts/player.gd, position = (0, 0), z_index = 0
    ├── CollisionShape2D            CircleShape2D, radius = 24
    └── Camera2D                    position = (0,0), enabled, position_smoothing_enabled = true,
                                    position_smoothing_speed = 8.0
```

### Palette (settled, game-wide)

- Background fill: `#1E2233`
- Player: `#4CC9F0` (disc), `#9BE7FF` (inner ring highlight)
- Spawn box: `#F9C74F`

### `scripts/background_grid.gd`

- `const DOT_SPACING := 96.0`, `const WORLD_HALF_EXTENT := 1536.0`.
- `_draw()`: for every x and y that is a multiple of 96 in `[-1536, 1536]`, draw a dot at that world position.
  - Normal dot: `draw_circle(pos, 3.0, Color("#3A4160"))`.
  - Every 4th dot on both axes (world coords that are multiples of 384): `draw_circle(pos, 7.0, Color("#4A5480"))` instead — coarse reference marks.
- Drawn once (static); no `_process`, no `queue_redraw()` per frame.

### `scripts/spawn_marker.gd`

- `const BOX_SIZE := Vector2(128, 128)`, `const OUTLINE_WIDTH := 4.0`.
- `_draw()`: rect `Rect2(-64, -64, 128, 128)` filled with `Color("#F9C74F", 0.2)`, then the same rect stroked with `Color("#F9C74F")` at width 4 (`draw_rect(..., false, 4.0)`).

### `scripts/player.gd` (`CharacterBody2D`)

- `const MOVE_SPEED := 320.0` (px/s), `const RADIUS := 24.0`, `const LATCH_TIME := 0.12` (s), `const WORLD_LIMIT := 1416.0`.
- `_unhandled_input(event)` / `_process`: maintain a per-action latch timer dictionary for `move_up`, `move_down`, `move_left`, `move_right`. On an action's `pressed` event, set that action's latch timer to `LATCH_TIME`. Each frame decrement latch timers by `delta`.
- An action counts as active if `Input.is_action_pressed(action)` OR its latch timer > 0.
- `_physics_process(delta)`: build `dir` from active actions, `dir = dir.normalized()` when non-zero, `velocity = dir * MOVE_SPEED`, `move_and_slide()`, then clamp `position.x` and `position.y` to `[-WORLD_LIMIT, WORLD_LIMIT]`.
- `_draw()`: `draw_circle(Vector2.ZERO, 24.0, Color("#4CC9F0"))` then `draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 48, Color("#9BE7FF"), 5.0, true)`.

### Input actions (`project.godot`)

- `move_up` → `W` (physical keycode)
- `move_down` → `S`
- `move_left` → `A`
- `move_right` → `D`
- Deadzone 0.5, no other events bound.

### `scripts/main.gd`

- `@onready var player := $Player`, `@onready var camera := $Player/Camera2D`, `@onready var spawn := $SpawnMarker`.
- Registers the debug bridge in `_ready()` (§6). No gameplay logic.

## 5. Implementation notes / constraints

- **No image asset.** Discord chose the code-drawn 2-tone ring circle over the linked avatar image; do not add, import, or reference any `.webp`/`.png`.
- **Input latch is required, not optional.** The browser tester's `browser_press_key` fires keydown+keyup in one burst, which can land inside a single frame and produce zero movement. The 0.12 s latch guarantees ≥ 38 px of travel per tap while feeling identical for held keys.
- Use *physical* keycodes for WASD so non-QWERTY layouts still work.
- The camera has no limits set; the player clamp at ±1416 keeps the player inside the 3072×3072 dot field, so the solid `#1E2233` fill is always behind the visible area.
- `BackgroundFill` lives on a `CanvasLayer` at `layer = -100` so it never scrolls; the dot grid is a world-space `Node2D` so it *does* scroll and makes movement readable.
- Web export: the debug bridge must be guarded with `if OS.has_feature("web")` (or `JavaScriptBridge` availability) so desktop runs do not error. Keep the `JavaScriptCallback` reference in a member variable — Godot frees it otherwise and `window.__egon.state()` throws.
- Report positions as plain floats rounded to 2 decimals in the bridge payload to avoid float noise in comparisons.
- No `class_name`, no autoloads, no addons, no new dependencies.

## 6. Verification hooks

- Mechanism: Godot `JavaScriptBridge` registers `window.__egon.state` from `scripts/main.gd` in `_ready()`. Create the `window.__egon` object if absent (`JavaScriptBridge.eval("window.__egon = window.__egon || {};", true)`), then attach the callback created with `JavaScriptBridge.create_callback(...)` and stored in a member variable.
- Call: `window.__egon.state()` returns a JSON **string** that the §7 expressions parse with `JSON.parse(...)`.
- Fields the §7 JS expressions will read, with type and meaning:
  - `ready` (`boolean`) — true once `Main._ready()` has finished and the player node exists.
  - `playerX` (`number`) — player global position x in world pixels, 2 decimals.
  - `playerY` (`number`) — player global position y in world pixels, 2 decimals.
  - `spawnX` (`number`) — spawn marker global position x (constant 0).
  - `spawnY` (`number`) — spawn marker global position y (constant 0).
  - `cameraFollowError` (`number`) — distance in pixels between the camera's current screen-center target (`Camera2D.get_screen_center_position()`) and the player's global position, 2 decimals.
  - `moveSpeed` (`number`) — configured player speed, 320.
  - `spawnBoxSize` (`number`) — spawn bounding box edge length, 128.

## 7. Acceptance criteria

1. Keys: none. Click: none. JS: `` () => JSON.parse(window.__egon.state()) ``. Then: object with `ready` === true, `playerX` === 0, `playerY` === 0, `spawnX` === 0, `spawnY` === 0, `moveSpeed` === 320, `spawnBoxSize` === 128.
2. Keys: `KeyD` ×6, then `KeyS` ×6. Click: none. JS: `` () => { const s = JSON.parse(window.__egon.state()); return [s.playerX, s.playerY]; } ``. Then: first element ≥ 100 and ≤ 1416; second element ≥ 100 and ≤ 1416.
3. Keys: none (run after criterion 2's movement). Click: none. JS: `` () => JSON.parse(window.__egon.state()).cameraFollowError ``. Then: return is ≤ 24.

## 8. Explicitly NOT this task

- Do not download, embed, or reference the Discord avatar image.
- Do not add arrow-key, gamepad, or touch bindings; WASD only.
- Do not add collision layers, obstacle bodies, or a TileMap.
- Do not change `export_presets.cfg`, `Dockerfile`, `nginx.conf`, or the GitHub workflow.
- Do not invent a debug global other than `window.__egon.state`.
