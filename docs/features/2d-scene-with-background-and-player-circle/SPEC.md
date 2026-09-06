# 2D scene with background and player circle

## Goal

Turn the empty Godot web game into a playable 2D view: a distinguishable playfield, a circular player textured with a given avatar image, WASD movement, and a visible spawn bounding box.

## Current state

- Godot 4.7 project `lets-vibe-together`; main scene is `res://main.tscn`.
- `main.tscn` is an empty root `Node` named `Main` (no 2D nodes, scripts, or assets).
- Web export is already configured (`export_presets.cfg`, Docker export to nginx).

## Scene

- Root the running scene as 2D (replace or wrap `Main` so a `Node2D` / `CanvasItem` tree is what the player sees).
- Camera: keep the playfield fully visible without extra UI. A static camera that shows the spawn area and nearby movement is enough.
- Do not add menus, HUD, or multiplayer.

## Background

- Fill the visible viewport with a background that is **not** a flat single color matching the player or the spawn box.
- Use a clearly patterned or two-tone field (for example a dark grid, checker, or subtle stripes) so a moving circle is obvious.
- Contrast against both the player sprite and the spawn box color `#00E5FF`.

## Player

- Represent the player as a **circle** (circular sprite / `Sprite2D` with a circular texture or clip).
- Texture the circle with this image (vendor it into the repo; do not load Discord CDN at runtime):

  `https://cdn.discordapp.com/avatars/1422897079751147642/7f0236b31ace88c5587b393575667bd3.webp?size=1024`

- Spawn the player at a fixed, visible position (center of the spawn bounding box).
- The circle must stay visually circular (no stretched ellipse) at the default viewport.

## Movement

- Keyboard only: **W** up, **A** left, **S** down, **D** right.
- Hold-to-move; diagonal WASD combinations should move diagonally.
- Speed: constant, comfortable for a browser window (player crosses a large fraction of the view in a few seconds, not instantly).
- No pointer / click-to-move. Collision with world bounds is optional; if omitted, the player may leave the spawn box and travel across the playfield.

## Spawn bounding box

- At the player spawn, draw a rectangular **bounding box** (outline or filled-with-outline rectangle).
- Color (chosen in Discord): solid **electric cyan** `#00E5FF`.
- Size: larger than the player circle so the circle sits inside the box at spawn and the box remains easy to see.
- The box is a visual marker only (it does not have to block movement).

## Implementation notes

- Keep changes in this Godot project; scripts in GDScript are fine.
- Commit the avatar as a project texture (convert/import as needed; Godot 4.7 accepts webp).
- Do not change Docker/nginx/export wiring unless required for the new assets to appear in the web build.

## Acceptance criteria

1. Open the game in the browser: a 2D playfield is visible with a patterned/two-tone background, a circular player showing the provided avatar image, and an electric cyan (`#00E5FF`) rectangular bounding box around the spawn. The player starts inside that box.
2. Hold **W**, **A**, **S**, and **D** in turn (and a diagonal pair): the circle moves in the matching direction and that motion is clearly visible against the background.
3. Reload the page: the player is again inside the same cyan spawn box, and the avatar is still mapped onto the circle (not a missing-texture placeholder).
