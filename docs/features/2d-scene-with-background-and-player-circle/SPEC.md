# 2D scene with background and player circle

## Context

`lets-vibe-together` is a Godot **4.7** web export. `res://main.tscn` is the run/main scene and is currently an empty `Node`. There is no 2D world, player, input, or artwork yet. The existing Web export preset and Docker/nginx pipeline must keep working.

## Goal

Show a 2D playfield with a clearly patterned world background, a circular player whose fill is a given avatar image, WASD movement, and a **lime-green** rectangle marking the spawn area.

## Decisions

- **Player texture:** the Discord avatar at
  `https://cdn.discordapp.com/avatars/1422897079751147642/7f0236b31ace88c5587b393575667bd3.webp?size=1024`
  is the fill of the **player circle** (not the world background). Vendor it into the repo (e.g. `res://assets/player_circle.webp` or `.png`) and load it as a local Godot texture. Do not fetch Discord CDN at runtime.
- **Spawn box color:** solid **lime green** `#32CD32` (chosen in Discord: option 3).
- **Camera:** static. The playfield is larger than the view. The player moves in world space; the world background does not scroll with the player. Movement is judged by the circle traveling across the patterned ground and out of the spawn box.
- **Input:** W/A/S/D only (up / left / down / right). Hold to move; release to stop. No pointer, gamepad, or arrow-key requirement.

## Requirements

### World

- Convert gameplay to 2D (`Node2D` root or a 2D scene under `Main`).
- Fill the visible view (and enough space around spawn to walk away) with a **non-uniform** background: a repeating checker, grid, or striped pattern using at least two contrasting colors that are **not** lime green `#32CD32` and not a close match to the avatar. A flat single-color fill is not enough — a moving circle must be easy to see.
- Keep the background behind the spawn box and the player.

### Player

- One circular player sprite, using the vendored avatar as its texture/fill, clipped or masked to a circle (square image with transparent corners is fine).
- Spawn the player at the center of the spawn bounding box, which itself is centered in the initial camera view.
- Move in the four cardinal directions while the matching WASD key is held, at a constant speed that is obvious in a browser (about 250–400 px/s).
- The player is not required to collide with the spawn box or world edges for this feature.

### Spawn bounding box

- Draw a visible axis-aligned rectangle around the spawn point (outline or translucent fill plus outline).
- Color: solid lime green `#32CD32` only (no extra accent colors).
- Size: clearly larger than the player circle (roughly 2–3× the circle diameter) so the player starts fully inside it and can walk out.
- The box is a **fixed world marker**. It does not follow the player.

## Out of scope

Camera follow, collisions, enemies, UI, audio, multiplayer, arrow keys, and runtime loading from Discord.

## Acceptance criteria

1. Open the game in a browser. A 2D view is visible: a patterned (not flat) world background, a circular player filled with the vendored avatar image, and a lime-green (`#32CD32`) rectangle around the starting position with the player fully inside that rectangle.
2. Click the game canvas to focus it. Hold **W**, then **A**, then **S**, then **D**. The circle moves up, left, down, and right respectively; the world background and the lime-green box stay put so travel across the pattern is obvious.
3. Walk the player out of the lime-green rectangle. The rectangle remains at the original spawn location; the circle is then outside the box and still fully visible against the patterned background.
