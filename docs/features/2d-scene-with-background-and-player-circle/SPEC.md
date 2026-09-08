# 2D scene with background and player circle

## 1. Context & Goal

The project currently boots an empty `Main` Node (`res://main.tscn`) with no world, camera, or player. This feature is the first playable 2D scene: a painterly teal ground large enough to pan, a player circle textured with Egon's portrait, WASD/arrow movement, and a top-down camera that smoothly lags behind so motion against the ground is obvious.

## 2. Scope

### In scope

- Turn `res://main.tscn` into a 2D world with a painterly, high-contrast ground larger than the view
- Add a 64px-diameter player circle that uses the Egon portrait, spawned at the world center
- WASD and arrow keys move the player at 240 px/s when held, with a 48px step on each tap so a key tap always changes position
- `Camera2D` follows the player with position smoothing (lag, not a hard lock)
- Clamp the player to the ground so they cannot walk into empty void
- Register EgonBridge fields listed in §7
- Add the four move input actions to `project.godot`

### Out of scope

- Editing `res://egon/egon_bridge.gd` or its autoload entry
- Changing renderer, window size, stretch mode, or `canvas_resize_policy`
- HUD, menus, combat, collisions with walls/enemies, zoom, rotation
- Pixel-art conversion or recoloring of the portrait
- New library assets beyond `portrait-of-egon.webp`

## 3. Relevant files / existing code

### Files to modify

- `res://main.tscn` — root is currently a bare `Node` named `Main`. Change it to `Node2D`, attach `main.gd`, and instance the world + player
- `res://project.godot` — add `move_left` / `move_right` / `move_up` / `move_down` input actions only. Do not touch `[autoload]`, `[application]`, or `[rendering]`

### Files to create

- `res://main.gd` — wires the scene, clamps the player to world bounds, registers all §7 fields
- `res://player.tscn` — player circle, portrait, outline, `Camera2D`
- `res://player.gd` — tap-step + held movement, `moveCount`, camera smoothing setup
- `res://world.tscn` — painterly ground, accent blobs, ink border
- `res://assets/library/images/portrait-of-egon.webp` — copy of library asset `portrait-of-egon.webp` (import there; do not invent another filename)

### Existing patterns / conventions

- Keep the orchestrator-owned debug bridge (`EgonBridge` autoload → `res://egon/egon_bridge.gd`) untouched; only call `register_field` from gameplay `_ready()`
- Scene/script split: `player.tscn` + `player.gd`, `world.tscn` as data/layout, `main.gd` as the composition root
- Input: there is no input map yet. Add actions in `project.godot`; do not poll raw keycodes in `_process` as the only path (taps must be visible via `is_action_just_pressed` / `_unhandled_input`)

## 4. Assets

- `portrait-of-egon.webp` — the player's face. Copy into `res://assets/library/images/portrait-of-egon.webp` and assign it as the `Sprite2D` texture on the player. Uniformly scale to **cover** a 64×64 px square (scale = `64 / min(texture_width, texture_height)`), centered on the player origin, then clip to a 64px-diameter circle. Overflow is cropped by the clip; do not stretch non-uniformly. Leave the import filter **linear** (not nearest).

## 5. Interface / Contract

### Scene tree

```
Main (Node2D)            [res://main.tscn + main.gd]
├── World (instance world.tscn)
│   └── Background (Node2D)
│       ├── Ground (Polygon2D)
│       ├── Blob1 … Blob10 (Polygon2D)
│       └── Border (Line2D)
└── Player (instance player.tscn)
    ├── Outline (Polygon2D)
    ├── Clip (Node2D)          clip_children = CLIP_CHILDREN_AND_DRAW
    │   ├── Mask (Polygon2D)   32px-radius filled circle
    │   └── Portrait (Sprite2D)
    └── Camera2D
```

Node names above are required (checks and `main.gd` paths depend on them).

### World (`res://world.tscn`)

- World rectangle: origin `(0, 0)`, size **2880×1620** px (3× the 960×540 runner view).
- `Ground`: axis-aligned `Polygon2D` quad `(0,0) → (2880,0) → (2880,1620) → (0,1620)`, color `#1F7A6C` (teal), alpha 1.0, `z_index` 0.
- Accent blobs: `Polygon2D` regular **16-gons** (circle stand-ins), `z_index` 1, **alpha 0.85** so overlaps mix (painterly). Exact centers, radii, and colors:

  | node    | center     | radius | color     |
  |---------|------------|--------|-----------|
  | Blob1   | (1200, 700) | 160 | `#155E54` dark teal |
  | Blob2   | (1650, 680) | 140 | `#3D9B8C` light teal |
  | Blob3   | (1500, 920) | 80  | `#F3E6D0` cream |
  | Blob4   | (1320, 860) | 64  | `#E07A5F` coral |
  | Blob5   | (2300, 810) | 200 | `#E07A5F` coral (east, off the opening view) |
  | Blob6   | (1440, 1400)| 180 | `#F3E6D0` cream (south, off the opening view) |
  | Blob7   | (600, 810)  | 180 | `#3D9B8C` light teal (west) |
  | Blob8   | (1440, 280) | 150 | `#155E54` dark teal (north) |
  | Blob9   | (1800, 1200)| 120 | `#E07A5F` coral (southeast) |
  | Blob10  | (1000, 500) | 100 | `#F3E6D0` cream (northwest) |

- `Border`: closed `Line2D` `(0,0) → (2880,0) → (2880,1620) → (0,1620) → (0,0)`, width **8**, color `#1A2332` (dark ink), `z_index` 2.
- No `Camera2D` on the world. No `CanvasLayer`. Everything is in world space so panning reveals new blobs.

### Player (`res://player.tscn` + `player.gd`)

- Root `Node2D` named `Player`, `z_index` 10.
- Spawn (set by `main.gd` on ready, before the first frame of movement): **`(1440, 810)`** — center of the 2880×1620 ground.
- `Outline`: 16-gon, radius **34** px, color `#1A2332`, drawn behind the clipped portrait (ink ring around the 64px body).
- `Clip/Mask`: 16-gon, radius **32** px, opaque white (color is irrelevant; it is the clip mask).
- `Clip/Portrait`: `Sprite2D`, texture = the imported portrait, centered at `(0, 0)`, scaled to cover 64×64 as in §4.
- Diameter of the visible circle: **64** px.

`player.gd` constants (do not diverge):

- `MOVE_SPEED := 240.0` (px/s while a move action is held)
- `MOVE_STEP := 48.0` (px applied once per tap)
- `CAMERA_SMOOTHING_SPEED := 8.0`

Signals: none. Exported properties: none required.

### Camera2D

- Child of `Player`, `make_current()` in `player.gd` `_ready()`.
- `position` `(0, 0)` (camera origin is the player origin).
- `zoom` `(1, 1)`.
- `position_smoothing_enabled = true`.
- `position_smoothing_speed = 8.0`.
- `drag_horizontal_enabled = false`, `drag_vertical_enabled = false`.
- No limits (`limit_*` left at Godot defaults so the camera may show the ink border when the player is near an edge).

After a discrete player step, the view center **lags**, then catches up. Bridge field `cameraLagPx` must go to `0` once smoothing finishes.

### Input actions (`project.godot`)

Deadzone `0.5` on each. Keyboard events only:

| action      | keys                                      |
|-------------|-------------------------------------------|
| `move_left` | `A` (`KEY_A`), `Left` (`KEY_LEFT`)        |
| `move_right`| `D` (`KEY_D`), `Right` (`KEY_RIGHT`)      |
| `move_up`   | `W` (`KEY_W`), `Up` (`KEY_UP`)            |
| `move_down` | `S` (`KEY_S`), `Down` (`KEY_DOWN`)        |

Diagonals: `Input.get_vector("move_left", "move_right", "move_up", "move_down")` is normalized so held diagonal speed stays 240 px/s, not 240√2.

### Movement behavior

Two cooperating paths (both required):

1. **Tap (testable, also a responsive nudge).** In `_unhandled_input`, for each of the four actions, if `event.is_action_pressed(action)` and `not event.is_echo()`: add `MOVE_STEP` px on that axis (left −x, right +x, up −y, down +y), increment `moveCount` by 1, and set a one-frame flag so path 2 does not also move on this frame. Godot Y increases downward, so `move_down` increases `playerY`.
2. **Hold (human play).** In `_process(delta)`, if the skip flag is clear: `position += Input.get_vector(...) * MOVE_SPEED * delta`. Clear the skip flag at the end of the frame.

A single tap that `_process` never observes as held still moves the player by exactly 48 px and increments `moveCount`.

### Clamp

After movement, clamp `Player.global_position` so the 64px circle stays on the ground: `x ∈ [32, 2848]`, `y ∈ [32, 1588]`.

## 6. Implementation notes / constraints

- Runtime viewport for checks is **960×540** (stretch **disabled**). Editor `1152×648` in `project.godot` is design size only; do not position the player using 1152×648.
- `ColorRect` is allowed but `Polygon2D` + `Line2D` stay in 2D world space without Control layout quirks — use those.
- 16-gon construction: for `i in 0 .. 15`, vertex `center + (radius * cos(i * TAU/16), radius * sin(i * TAU/16))`.
- Do not parent the ground to the camera or a `CanvasLayer`; if the background is screen-space, panning is invisible.
- Do not use `Input.is_action_pressed` as the **only** move trigger: a runner tap can fall inside one frame and `_process` will miss it. The 48px `_unhandled_input` step is the contract that makes WASD checks pass.
- Do not edit `egon/egon_bridge.gd`. Register fields from `main.gd` `_ready()` (player/world are in the tree by then).
- Web export: `webp` import is fine; no extra compression settings required beyond project defaults.
- Painterly style here means overlapping semi-transparent color blobs on a teal field, not a hand-painted texture (none exists in the library).

## 7. Verification hooks

- Mechanism: the `EgonBridge` autoload, already in the project. The implementer registers each field below from `main.gd` `_ready()`, for example `EgonBridge.register_field("playerX", func(): return round(player.global_position.x))` and `EgonBridge.register_field("hasBackground", func(): return world != null)`. Do not ask for a hand-rolled `JavaScriptBridge` and do not reassign `window.__egon`.
- Call: `window.__egon.state()` returns a JSON object of every registered field — this feature's and every earlier feature's.
- Fields this feature registers, with type and meaning:
  - `playerX` (`number`) — `round(Player.global_position.x)` at spawn 1440; +x is right
  - `playerY` (`number`) — `round(Player.global_position.y)` at spawn 810; +y is down
  - `cameraX` (`number`) — `round(Camera2D.get_screen_center_position().x)` (view center, not the Camera2D node's local offset)
  - `cameraY` (`number`) — `round(Camera2D.get_screen_center_position().y)`
  - `cameraLagPx` (`number`) — `round` of `Vector2(cameraX, cameraY).distance_to(Vector2(playerX, playerY))` using those rounded components; `0` when the smoothed camera has caught up
  - `cameraSmoothingEnabled` (`boolean`) — `true` when the active `Camera2D.position_smoothing_enabled` is on
  - `moveCount` (`number`) — integer, starts at `0`, +1 per move-action tap (`just_pressed` / `_unhandled_input` path). Never decrement
  - `hasBackground` (`boolean`) — `true` when the `World` instance exists in the tree
  - `worldWidth` (`number`) — `2880`
- Existing fields this feature reuses, from the GAME_MAP "Debug bridge" table, or `None.`:
  - None.

## 8. Test scenarios

- Scenarios this feature verifies against:
  - `default` (existing) — normal boot of `res://main.tscn`: player at `(1440, 810)`, camera current with smoothing, full painterly ground. Every check is reachable from a cold boot; no extra scenario script.

Machine-executable checks: `egon/checks/2d-scene-with-background-and-player-circle.json`.

## 9. Acceptance criteria

1. The game boots into a top-down 2D view of a teal ground with cream and coral patches, and the player is Egon’s portrait clipped to a circle at the center of that ground.
2. WASD and the arrow keys both move the player across the ground; a single tap is enough to change position.
3. The camera smoothly lags behind the player and the ground is larger than the view, so you can see the circle travel over changing colors.

## 10. Explicitly NOT this task

- Do not modify `res://egon/egon_bridge.gd` or the autoload line
- Do not add physics layers, `CharacterBody2D` collision, or a tilemap
- Do not add a HUD, title screen, or zoom/rotate controls
- Do not switch stretch mode or the renderer
- Do not replace the portrait with a primitive circle-only placeholder unless the import fails — the portrait is in scope
