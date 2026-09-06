# Feature: 2D scene with a gray-ish background and a moving green circle

## Summary

The shipped web game currently loads `res://main.tscn` as its only scene. That scene is an empty `Node` named `Main` (`project.godot` `run/main_scene`). After this feature, opening the game in a browser must show a 2D playfield: a gray-ish background with visible landmarks, a green circle the player steers with WASD, and a camera that stays on that circle so movement is obvious.

## Current state

- Engine: Godot 4.7, Forward Plus, web export (`export_presets.cfg` → `build/web/index.html`).
- Application name: `lets-vibe-together`.
- Main scene: `[node name="Main" type="Node"]` with no children, no scripts, no 2D nodes.
- Web export focuses the canvas on start (`html/focus_canvas_on_start=true`), so keyboard input should work after the page loads without an extra click in the common case.

## Goals

1. The main scene is a 2D view (the existing `Main` root may become a `Node2D`, or it may own a 2D child that fills the viewport).
2. The background is clearly gray-ish (not black, not white, not a saturated color).
3. The background has fixed visual features so camera motion is readable.
4. A distinct green circle is the player avatar.
5. Holding **W / A / S / D** moves the circle on the playfield.
6. The camera follows the circle so it stays on screen while the world scrolls.

## Non-goals

- No menu, HUD, score, or instructions overlay.
- No enemies, collectibles, collisions, or win/lose state.
- No mouse, gamepad, or arrow-key controls (WASD only).
- No world-edge walls or wrap-around. A large (or unbounded) playfield is enough.
- No audio.

## Spec decisions

These defaults keep the first scene simple. Do not invent extra systems.

| Topic | Decision |
| --- | --- |
| Player shape | Solid filled circle, clearly green (e.g. lime / mid green). Radius large enough to see immediately on a desktop viewport (about 24–48 px at default zoom). |
| Background color | Mid gray (roughly `#5a5a5a`–`#8a8a8a`). |
| Landmarks | At least four non-moving, contrasting marks spread around the start area (darker/lighter gray shapes, a grid, rocks, or similar). They must not all sit under the circle at spawn. |
| Spawn | Circle starts near the center of the landmark cluster so features are visible in every direction. |
| Movement | Continuous while a key is held. W up, S down, A left, D right. Diagonals when two keys are held. Speed high enough that a 1-second hold is obvious. |
| Camera | Follows the circle and keeps it in view (centered or near-centered). Instant or lightly smoothed follow are both fine. |
| Controls | WASD only. Do not require a visible UI to explain this. |

## Implementation notes (grounding)

- Keep `run/main_scene` as `res://main.tscn` so the web export still boots this view.
- Prefer a `Camera2D` parented to (or tracking) the circle so follow behavior is native.
- Input should use Godot’s physical WASD keys (or mapped `ui`/custom actions bound to those keys) so the browser build responds after canvas focus.
- Landmarks must be in world space, not on a canvas layer that moves with the camera. If they are children of the camera or a screen-space `CanvasLayer`, movement will not be visible.

## Acceptance criteria

Numbered checks a reviewer can perform in a browser against the exported web game.

1. Open the game in a browser. The viewport shows a 2D scene (not a blank/black empty window) with a gray-ish background.
2. A solid green circle is visible on that scene without interacting.
3. At least four distinct, non-green background features are visible at the same time as the circle (different positions and/or shapes so the playfield is not a flat wash of one gray).
4. Click the game canvas if needed so it has keyboard focus. Hold **W**: the circle moves up relative to the world. Background features slide downward (or otherwise reveal that the camera followed the circle). The circle stays on screen.
5. Hold **S**: the circle moves down relative to the world. Background features slide upward. The circle stays on screen.
6. Hold **A**: the circle moves left relative to the world. Background features slide right. The circle stays on screen.
7. Hold **D**: the circle moves right relative to the world. Background features slide left. The circle stays on screen.
8. Hold **W** and **D** together: the circle moves diagonally up-right, and the camera still keeps it in view.
9. Release all keys: the circle stops. It does not keep drifting.
10. After moving away from the spawn point, at least one landmark that was on screen at start is no longer under the circle (or has left the viewport), proving the world moved independently of the avatar.
11. Reload the page: the same gray-ish scene, green circle, and landmarks appear again at the starting arrangement.
