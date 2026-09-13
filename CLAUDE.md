# lets-vibe-together

Godot **4.7** GDScript game (working title *Loveless Child Simulator*). Pixel-art **640×360** desktop sim: a fake Windows shell (Gaming Community, Chrome, CS2, Skills) plus a main-menu front end. Progress is rubles / skins / targets; CS2 is a self-playing match that pays targets. Code in `src/`, theme/fonts in `resources/`, art/audio in `assets/`, strings in `locale/ui.csv`.

Autoloads: `Settings` (`user://settings.cfg`), `GameState` (`user://save.cfg`), `Skills` + `skill_catalog.gd`, `Music`, `SceneTransition`. Always reach them as `get_node("/root/Name")` — bare identifiers fail `--check-only`.

## Egon (not for you)

`.egon/` is the **Egon coding bot** (planner/implementer/check runner), not local agents. `EgonBridge` autoload exposes `window.__egon.state()` for that bot's JSON checks in `.egon/checks/` and scenario scripts in `.egon/scenarios/`. Do not read, edit, or extend `.egon/` (including `egon_bridge.gd` and bridge `register_field` calls) unless explicitly asked. Do not create SPECs or `.egon/checks` unless explicitly instructed. Do not read `docs/features/**/SPEC.md` unless the user points at one.

## Scenes

| Scene | Role |
| --- | --- |
| `main_menu.tscn` | Boot scene. Start/Continue → `game.tscn` (via `SceneTransition`), Settings, Credits, Quit. |
| `settings_screen.tscn` | Volume / locale / resolution / window / delete save. Scene-swap from menu; overlay from pause. |
| `credits_screen.tscn` | Scrollable credits/licenses. Back → menu. |
| `game.tscn` | In-game desktop. Taskbar apps: Home opens pause (not a screen); Gaming Community, Chrome, CS2, Skills and the four placeholders are child screens. |
| `taskbar.tscn` | Bottom bar: app icons, skins/targets/rubles, volume (deco), clock (click toggles the debug menu). |
| `debug_menu.tscn` | Flyout above the clock: Give money (+10000), Give targets (+10), Give skins (+10); the clock closes it too. Grants go straight to `GameState`. |
| `gaming_community_screen.tscn` | Gaming Community app (formerly Steam): backdrop, wheel-scrolled feed, one card per target (as many as fit). Card → chat window: keys type an opener, target shows growing typing dots after 2–4 s and replies after 10–20 s: follow-up question (player types an answer, next round), refusal, or trade request (click = +1 skin); starts 90/10/0 %, each follow-up moves 10 points to refusal/trade (5 each); log keeps the last 3 lines; target spent via `GameState.remove_target_profile()`, window closes 1 s later, cards slide up. Names/avatars: `target_profiles.gd` + `names.txt`; chat lines in `locale/chat.csv` (English only; paired questions/answers by key name, wear-swap scam theme; `--script res://src/check_chat_lines.gd` checks they exist and fit 2 lines). |
| `chrome_screen.tscn` | Chrome app: one button selling every skin at 1 skin = 1000 rubles, via `Skills.grant_rubles()`. |
| `cs2_screen.tscn` | CS2 app: queue → staged fake match → targets. Keeps running while hidden. |
| `skills_screen.tscn` | Skills app placeholder; real trees not designed yet. Buy via `Skills.unlock()`. |
| `scammer_screen.tscn`, `telephone_screen.tscn`, `office_screen.tscn`, `floorplanner_screen.tscn` | Empty placeholder apps: Chrome's taskbar icon, a flat `#232323` backdrop, nothing on them yet. |
| `pause_menu.tscn` | Esc or Home. Continue / Settings overlay / Save & Quit → menu. Pauses the tree. |
| `scene_transition.tscn` | Autoload fade used only for Start/Continue. |

## Token hygiene

- Do not read `ROADMAP.md`, `docs/**`, `.egon/**`, `locale/**`, `*.import`, `*.uid`, `.godot/`, binaries, or Godot logs (`cat`/`Read` of logs is forbidden; `rg` with a cap if debugging a run).
- Scripts are comment-heavy. **Grep / offset-read** the function you need. Do not ingest a whole `.gd` "for context".
- Edit `.gd` for behaviour. Open a `.tscn` only when the node tree, layout, or exported props must change — they are verbose.
- Do not add essay comments, SPECs, checks, extra docs, or new files unless asked.
- Match local style: tabs, typed GDScript, `snake_case` / `SCREAMING_SNAKE`. UI strings go through `tr("KEY")` + `locale/ui.csv`, never hardcoded (except licenses).
- After `.gd` edits: `godot --headless --path . --script res://src/foo.gd --check-only`. After scene/`project.godot` edits: `--quit-after 60` and grep the log for `SCRIPT ERROR`. Skip Web export unless asked.
- One save, no slots. Settings ≠ progress. Do not invent Gaming Community/Chrome content or a skills tree unless tasked.
