# 2D scene with background and player circle

## 1. Context & Goal

The project currently boots `res://main.tscn`, a bare `Node` with nothing in it — no world, no camera, no player. This feature is the first playable screen: a painterly teal ground large enough to pan around, a player circle that shows the Egon portrait, WASD movement with a short acceleration ramp, and a top-down camera that smoothly lags behind the player. It establishes the art direction (painterly illustrated 2D, teal ground with coral/cream accents and dark ink lines) and the movement feel every later feature builds on.

## 2. Scope

### In scope

- A world scene (`world.tscn`): large teal ground rectangle, ten painterly coral/cream blobs, dark ink border outline.
- A player scene (`player.tscn`): dark ink outlined circle whose fill is the Egon portrait, clipped to the circle.
- Top-down movement on WASD (and arrow keys) with acceleration and deceleration, clamped inside the world.
- A `Camera2D` on the player with position smoothing (visible lag) and limits set to the world bounds.
- Input map actions `move_left`, `move_right`, `move_up`, `move_down` in `project.godot`.
- `main.tscn` / `main.gd` composing world + player and registering the debug bridge fields in §7.

### Out of scope

- Collision bodies, physics layers, obstacles, enemies, pickups, HUD, menus, audio.
- Sprint/dash, diagonal speed tuning beyond normalizing the input vector.
- Any change to `egon/egon_bridge.gd`, the autoload entry, or the renderer settings.
- Window/stretch settings: leave `project.godot` display config untouched (stretch stays disabled).

## 3. Relevant files / existing code

### Files to modify

- `project.godot` — add an `[input]` section with the four move actions (WASD + arrow keys). Do not touch `[autoload]`, `[rendering]`, or `[application]`.
- `main.tscn` — change root from `Node` to `Node2D` named `Main`, attach `main.gd`, instance `World` and `Player`.

### Files to create

- `main.gd` — scene composition + `EgonBridge` field registration.
- `world.tscn` — background: ground, blobs, border.
- `player.tscn` — outline circle, clipped portrait, `Camera2D`.
- `player.gd` — movement, acceleration, world clamping, `move_count`.

### Existing patterns / conventions

- `egon/egon_bridge.gd` is orchestrator-owned; register through `get_node("/root/EgonBridge").register_field(...)` from `main.gd`'s `_ready()`. Never reference the `EgonBridge` identifier directly (`--check-only` does not load autoloads).
- One script per scene root, script file next to its scene at the repo root (`player.tscn` ↔ `player.gd`), matching how `main.tscn` ↔ `main.gd` will pair.
- No addons; plain Godot 4.7 nodes only.

## 4. Assets

- `portrait-of-egon.webp` — the fill of the player circle. Copy into `assets/library/images/portrait-of-egon.webp` and import as a normal 2D texture (filter on, mipmaps on). Used as the `Portrait` `Sprite2D` texture, `centered = true` at the circle's origin, uniformly scaled by the implementer so the image's **shorter** side covers at least the 96 px circle diameter (i.e. `scale = 96.0 / min(texture_width, texture_height)` on both axes), then clipped to the circle by the `Mask` polygon. Do not distort the aspect ratio.

## 5. Interface / Contract

### Constants (in `main.gd`)

```gdscript
const WORLD_WIDTH := 3456
const WORLD_HEIGHT := 1944
const PLAYER_START := Vector2(1728, 972)  # world center
```

### `world.tscn`

```
World (Node2D)
└─ Background (Node2D)
   ├─ Ground (Polygon2D)      # rect (0,0)-(3456,1944), color #1F6F6B
   ├─ Blob1..Blob10 (Polygon2D)
   └─ Border (Line2D)
```

- `Ground`: polygon `[(0,0), (3456,0), (3456,1944), (0,1944)]`, `color = Color("1f6f6b")`.
- `Blob1..Blob10`: irregular painterly blobs, each a closed 12-point polygon built from a radius of 140–320 px jittered by ±25% per point, so no two look alike. Colors alternate: odd-numbered blobs `Color("f2e3c8")` (cream) at `modulate.a = 0.85`, even-numbered `Color("e2725b")` (coral) at `modulate.a = 0.55`. Spread their centers across the full world so movement is always visibly against a landmark — put one near each of the four quadrant centers, one at roughly (1728, 500), (1728, 1500), (600, 972), (2900, 972), (2400, 1600), (900, 400). Blobs must not be centered exactly on `PLAYER_START`.
- `Border`: closed `Line2D` tracing the world rect inset by 6 px, `width = 10`, `default_color = Color("12211f")` (dark ink), `closed = true`.
- `z_index`: `Background` stays at default 0; the player is added after the world in `main.tscn` so it draws on top.

### `player.tscn` / `player.gd`

```
Player (Node2D)            → player.gd
├─ Outline (Polygon2D)     # 48-point circle, radius 54, color #12211f
└─ Mask (Polygon2D)        # 48-point circle, radius 48, clip_children = CLIP_CHILDREN_ONLY
   └─ Portrait (Sprite2D)  # portrait-of-egon.webp, centered, scaled per §4
```

`player.gd`:

```gdscript
extends Node2D

const MAX_SPEED := 420.0        # px/s
const ACCELERATION := 1200.0    # px/s^2, ramp-up feel
const FRICTION := 1400.0        # px/s^2, ramp-down
const TAP_IMPULSE := 240.0      # px/s added on each movement key press
const RADIUS := 54.0

var velocity := Vector2.ZERO
var move_count := 0
var bounds := Rect2(Vector2.ZERO, Vector2(3456, 1944))  # set by main.gd

func _unhandled_input(event: InputEvent) -> void   # counts presses, applies impulse
func _physics_process(delta: float) -> void        # accelerate / decelerate, move, clamp
```

- `_unhandled_input`: for each of the four move actions, when `event.is_action_pressed(action)` and not `event.is_echo()`, increment `move_count` by 1 and add `TAP_IMPULSE * dir` to `velocity` (`dir` = `Vector2.LEFT/RIGHT/UP/DOWN`), then `velocity = velocity.limit_length(MAX_SPEED)`. This makes a single keydown+keyup tap produce real, durable displacement.
- `_physics_process`: `var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")`. If `input != Vector2.ZERO`, `velocity = velocity.move_toward(input.normalized() * MAX_SPEED, ACCELERATION * delta)`; else `velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)`. Then `global_position += velocity * delta` and clamp `global_position` to `bounds` inset by `RADIUS` on every side, zeroing the velocity component on any axis that hits the clamp.

### Camera

`Camera2D` is a child of `Player` in `player.tscn`, at local `(0,0)`:

- `enabled = true`, `position_smoothing_enabled = true`, `position_smoothing_speed = 3.0` (deliberately laggy).
- `limit_left = 0`, `limit_top = 0`, `limit_right = 3456`, `limit_bottom = 1944`, `limit_smoothed = true`.
- Drag margins disabled (`drag_horizontal_enabled = false`, `drag_vertical_enabled = false`).

### `main.gd`

- `_ready()`: sets `player.global_position = PLAYER_START`, `player.bounds = Rect2(Vector2.ZERO, Vector2(WORLD_WIDTH, WORLD_HEIGHT))`, caches `world`, `player`, `camera` (`player.get_node("Camera2D")`), then registers the fields in §7.

### Input map (`project.godot`)

| Action | Keys |
| --- | --- |
| `move_left` | A, Left |
| `move_right` | D, Right |
| `move_up` | W, Up |
| `move_down` | S, Down |

## 6. Implementation notes / constraints

- Clipping: `Mask` (a `Polygon2D` circle) is the parent and sets `clip_children = CanvasItem.CLIP_CHILDREN_ONLY`; `Portrait` is its child so only the circular area of the portrait renders. `Outline` is a slightly larger circle drawn **before** `Mask` in the tree so a 6 px dark ink ring shows around the portrait.
- Build the circle polygons in the scene file or in `_ready()` from 48 evenly spaced points; do not use a `TextureRect` or a shader.
- Movement is `Node2D` + manual integration, not `CharacterBody2D` — there are no collisions in this feature.
- The runner cannot hold a key: the `TAP_IMPULSE` path in `_unhandled_input` is what makes taps observable. Do not remove it in favour of polling-only movement.
- `move_count` counts key presses (not frames) and never resets.
- Stretch is `disabled`, so the running root viewport equals the browser window; do not add camera zoom compensation.
- Keep the blobs as `Polygon2D` nodes — no `TileMap`, no imported textures beyond the portrait.
- Web export: no per-frame allocations in `_physics_process`; reuse the cached `Vector2`s.

## 7. Verification hooks

- Mechanism: the `EgonBridge` autoload, already in the project. `main.gd` calls `get_node("/root/EgonBridge").register_field("name", func(): return …)` once per field in `_ready()`. Do not use the `EgonBridge` identifier, do not hand-roll a `JavaScriptBridge` bridge, do not reassign `window.__egon`.
- Call: `window.__egon.state()` returns a JSON object of every registered field.
- Fields this feature registers:
  - `playerX` (`number`) — `round(player.global_position.x)`.
  - `playerY` (`number`) — `round(player.global_position.y)`.
  - `moveCount` (`number`) — cumulative count of movement key presses (`player.move_count`).
  - `cameraX` (`number`) — `round(camera.get_screen_center_position().x)`.
  - `cameraY` (`number`) — `round(camera.get_screen_center_position().y)`.
  - `cameraSmoothingEnabled` (`boolean`) — `camera.position_smoothing_enabled`.
  - `hasBackground` (`boolean`) — the world instance exists in the tree (`world != null`).
  - `worldWidth` (`number`) — `WORLD_WIDTH`.
- Existing fields this feature reuses, from the GAME_MAP "Debug bridge" table: all of the above names are the established spellings — register them exactly as written, no near-duplicates.

## 8. Test scenarios

- Scenarios this feature verifies against:
  - `default` (existing) — the game as it normally boots: `main.tscn` with the world and the player at world center. Everything this feature does is reachable from a cold boot, so no new scenario is needed.

## 9. Acceptance criteria

1. Booting the game shows a large painterly teal world with coral/cream blobs and a dark ink border, with the Egon portrait visible inside a dark-outlined player circle at the center of the world.
2. Pressing W/A/S/D (or the arrow keys) moves the player circle in that direction with a short acceleration ramp and a glide to a stop, and the player can never leave the world rectangle.
3. The camera stays on the player but visibly trails behind while moving, catching up once the player stops.

## 10. Explicitly NOT this task

- Do not edit `egon/egon_bridge.gd` or the `[autoload]` section.
- Do not add collision shapes, `CharacterBody2D`, physics layers, or a `TileMap`.
- Do not change the window size, stretch mode, or renderer.
- Do not add any asset beyond `portrait-of-egon.webp`.
