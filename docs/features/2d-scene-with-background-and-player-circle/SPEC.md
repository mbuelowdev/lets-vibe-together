# 2D scene with background and player circle

## Goal

Turn the current empty Godot web game into a playable 2D view: a visible player circle that moves with WASD, a spatially varied background so motion is obvious, and a camera that stays on the circle.

## Current state

- Godot 4.7 project `lets-vibe-together`; main scene is `res://main.tscn`.
- `main.tscn` is a root `Node` named `Main` with no children, scripts, or drawn content.
- Web export is already configured (`export_presets.cfg` → `build/web/index.html`; canvas focuses on start).
- There is no `Camera2D`, player, input map, or 2D world yet.

## Requirements

### Scene

- `run/main_scene` stays `res://main.tscn` (or is updated only if the 2D scene is that same entry point).
- The running scene is 2D (`Node2D` / `Camera2D` / 2D draw nodes). Do not use a 3D camera or 3D mesh as the player.

### Player

- A filled circle is the player. It must stay visually distinct from the background (high contrast fill and/or outline).
- The player starts on-screen at load.

### Movement

- Hold **W** / **A** / **S** / **D** to move up / left / down / right in world space.
- Diagonal WASD combinations move diagonally.
- Movement is continuous while keys are held, at a speed that is easy to see in a browser (roughly a few hundred pixels per second).
- No other movement scheme is required (no mouse, no click-to-move).

### Background

- The world behind the player is **not** a flat gray (or any other uniform solid color) fill.
- Use a repeating pattern, grid, tiles, or scattered landmarks that change with world position, so camera motion is readable.
- The decorated area is large enough that the player can travel for several seconds without running out of visible variation.

### Camera

- A `Camera2D` (or equivalent 2D camera) is current and follows the player circle.
- As the circle moves, it stays in the viewport (centered or near-centered). The background, not the circle, should appear to scroll.

## Out of scope

- Combat, collision, bounds clamping, UI, audio, multiplayer.
- Remapping keys or on-screen buttons.

## Acceptance criteria

1. Open the game in a browser. A 2D view loads with a player circle on a background that is not a single flat color (grid, tiles, pattern, or landmarks are visible).
2. Click the game canvas if needed, then hold **W**, **A**, **S**, and **D** in turn. The circle moves in the matching direction, and the background pattern shifts so the motion is obvious.
3. Keep holding a movement key for a couple of seconds. The circle remains in view (centered or near-centered) while the background continues to scroll — the camera is following the player.
