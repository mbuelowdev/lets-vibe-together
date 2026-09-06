# Shoot projectile from player to mouse cursor

## Context

The working tree is a Godot 4.7 web project (`lets-vibe-together`) using the Forward Plus 3D renderer. `main.tscn` is a bare `Node` named `Main`. There is no player, camera, input handling, or gameplay script yet.

This feature adds the first playable loop: a visible player in the 3D scene, and a left-click that spawns a simple sphere projectile flying from that player toward the mouse cursor.

## Behavior

- The main scene must show a 3D play view: a `Camera3D` that can see the player, plus a simple visible player mesh (for example a capsule or distinct colored body) standing on a readable ground plane so height and motion are obvious in the browser.
- Left mouse button down (click) on the game canvas creates one new sphere mesh (the projectile) at the player's position.
- That sphere immediately flies in a straight line from the player toward the 3D world point under the mouse cursor at the moment of the click.
- Convert the cursor to a world aim point by intersecting a camera ray through the mouse position with the ground plane (or the horizontal plane at the player's feet). Do not aim at a random direction or only in screen space.
- Flight is continuous and visibly fast (constant speed). The projectile keeps going along that aim line after passing the cursor point; it does not need to stop on the cursor.
- Each additional left click spawns another sphere. Existing projectiles keep flying.
- Projectiles may despawn after leaving a reasonable play area or after a few seconds so they do not accumulate forever.

## Implementation notes

- Ground work in `res://main.tscn` (the `run/main_scene` in `project.godot`) and new GDScript as needed. Keep the Web export preset working; this is a browser game.
- Use Godot 3D nodes (`MeshInstance3D` / `SphereMesh` for the projectile). Do not switch the project to 2D.
- Capture mouse clicks on the game viewport (`InputEventMouseButton`, left button). Ignore UI-only handling that would miss canvas clicks.
- If the cursor ray does not hit the ground (for example the sky), skip spawning or aim along the last valid ground hit so a click never fires in an undefined direction.

## Out of scope

- Damage, enemies, ammo, cooldowns, sound, particles, or aiming reticles.
- Player movement or camera controls beyond a fixed camera that keeps the player and nearby ground in view.
- Right-click or keyboard shooting.

## Acceptance criteria

1. Open the exported game in a browser. A 3D player mesh is visible on a ground plane (not a blank or empty viewport).
2. Move the mouse to a spot on the ground away from the player, then click the left mouse button. A sphere appears at the player and travels across the ground toward that cursor location, not sideways or away from it.
3. Click the left mouse button a second time at a different ground location. A second sphere appears at the player and flies toward the new cursor location while the first sphere continues independently.
