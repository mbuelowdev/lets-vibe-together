# Roadmap

A working plan, not a pitch. Horizons are the futures you can play. Tasks are the ordered work that has to exist before that future is true.

Keep this file thin. A task that needs a contract gets a SPEC under `docs/features/<slug>/SPEC.md`. Settled global choices go in `docs/GAME_DECISIONS.md`. Egon checks prove the SPEC, they do not replace it.

Name: LФVELESS CЧILD SIMVLДTOP

## How to use this

**Horizon, not backlog.** A horizon is one player-visible sentence ("the game opens on a main menu"). It is done when that sentence is true in a running build, not when a list of tickets is empty.

**Prerequisites are ordered.** Numbered tasks under a horizon are a sequence. Do not start 3 because 1 looks boring. If two tasks are truly independent, say so on the line.

**One Now.** The Now box is the only place you look when sitting down to work. When a horizon ships, check it off, promote the next one, and rewrite Now.

**SPEC-sized tasks.** Each task should be one feature you can specify, implement, and check in a single pass — the same grain as the existing `docs/features/` folders. "Front end" is a horizon. "Move the three settings dropdowns onto a settings screen" is a task.

**Do not duplicate.** The roadmap names the work and the order. The SPEC owns layout, fields, and acceptance. If they disagree, the SPEC is what gets built; then fix the roadmap.

**No dates unless you mean them.** Status is `done` / `now` / `next` / `later` / `parked`.

**Parked is a junk drawer.** Ideas that are not sequenced live at the bottom so they do not pretend to be a plan.

When you add a horizon: write the player sentence, then the tasks that unlock it, in the order a later task would actually need. When you finish a task: check it off here. When you finish a horizon: mark it `done` and move it into Shipped.

---

## Now

**Horizon 1 — Front end.** The game boots into the main menu, but Settings and Credits are still
buttons that do nothing, and the dropdowns still live on Home.

Start with task 3: the Settings screen.

---

## Horizons

| # | Horizon | Player can… | Status |
| --- | --- | --- | --- |
| 0 | Desktop shell | Switch four apps on a 640×360 desktop, with settings, a clock, and a ruble readout | done |
| 1 | Front end | Boot into a main menu; open Settings and Credits from it; Start/Continue into the desktop | now |
| 2 | Pause and Home | Open a pause menu with Esc in-game, and either give Home a job or remove it | next |
| 3 | Steam and Chrome screens | Open Steam and Chrome onto their own backdrop art, the way CS2 already does | later |
| 4 | Game loop concept | Know what the player does after they hit Start | later |

Horizon 3 does not depend on 1 or 2; it can jump the queue if you would rather paint than build menus. Horizon 4 should land before you invent a *gameplay* use for Home — if Home is only "open pause" or "delete the tab", you can finish Horizon 2 without it.

---

## Horizon 0 — Desktop shell

Status: **done**

Player can: boot a 640×360 pixel-art desktop, switch Home / Steam / Chrome / CS2, change language / resolution / window mode, and quit with the balance and settings still there next launch.

Shipped (do not re-plan):

- [x] Main scene, taskbar, four switchable apps — `docs/features/create-main-scene-with-switchable-tabs/SPEC.md`
- [x] App-icon hover — `docs/features/add-on-hover-effects/SPEC.md`
- [x] CS2 full-canvas backdrop — `docs/features/add-screen-background-to-cs2-screen/SPEC.md`
- [x] Clock and volume icon (volume is decoration) — `.egon/checks/add-taskbar-clock-and-volume-icon.json`
- [x] Ruble readout + `GameState` — `docs/features/add-taskbar-currency/SPEC.md`
- [x] Persist settings — `.egon/checks/save-and-load-settings.json`
- [x] Persist progress — `.egon/checks/save-and-load-progress.json`
- [x] Language, resolution, window-mode, Save & Quit on Home; 26 locales in `locale/ui.csv`
- [x] Keyboard / gamepad focus through settings and the taskbar

---

## Horizon 1 — Front end

Status: **now**

Player can: launch the game into a main menu (background + title), press Start/Continue to reach the desktop, and open Settings and Credits from that menu. Settings no longer live on Home.

Done when: a cold boot never shows the desktop first; the three Home dropdowns and Save & Quit are gone from the desktop; Settings and Credits are their own screens on the same menu background.

Work, in order:

1. [x] **Main-menu background art.** `assets/images/main-menu-screen.png` — full-canvas 640×360, nearest. Shared by Settings and Credits when they land.
2. [x] **Title art.** `assets/images/main-menu-title-text.png`, 256×100, top-centred on the menu only.
3. [ ] **Settings screen.** Same background as the menu. Move language, resolution, and window mode here from Home. Save & Quit does not belong here (quit is a menu problem; progress already autosaves). SPEC, then implement. Home is empty of settings when this ships.
4. [ ] **Credits screen.** Same background. SPEC, then implement. Copy can be a placeholder list.
5. [x] **Main menu.** `main_menu.tscn` / `main_menu.gd` — `docs/features/add-main-menu/SPEC.md`. Four buttons, not three: Start/Continue Game, Settings, Credits, Quit. Continue vs Start is one control, labelled off `GameState.save_file_exists()`. `run/main_scene` boots here. Settings and Credits are wired and inert until tasks 3–4 land; wiring them to return here is part of those tasks, not this one.

The desktop scene was renamed with this task: `main.tscn` / `main.gd` are now `game.tscn` / `game.gd`, root node `Game`. "Main" meant "the main scene" and stopped being true. The shipped SPECs under `docs/features/` still say `main.gd`; they are records of what was built then, and `add-main-menu/SPEC.md` §2 carries the rename.

---

## Horizon 2 — Pause and Home

Status: **next** — after Horizon 1, because "in-game" means "past the main menu"

Player can: press Esc on the desktop and get a pause menu. The Home taskbar icon either does something useful, opens that pause menu, or is gone.

Done when: Esc while in-game opens pause and Esc/Resume closes it; Home is no longer a dead settings graveyard.

Work, in order:

1. [ ] **Pause menu.** Esc toggles it while the desktop is up. It does not show on the front-end screens. Minimum: Resume, Settings (the Horizon 1 screen), Quit to main menu. SPEC, then implement.
2. [ ] **Decide Home.** One of: give it a real use, make the icon open pause, or delete the tab. Write the choice in `docs/GAME_DECISIONS.md`. If the use is gameplay, do Horizon 4 before locking this. If the use is "open pause" or "delete it", decide now.
3. [ ] **Implement that Home choice.** If you delete the tab, the remaining icons stay left-aligned and every `APP_IDS` / check that assumes four apps gets updated.

---

## Horizon 3 — Steam and Chrome screens

Status: **later** (independent of 1–2)

Player can: select Steam or Chrome and see backdrop art filling the 640×360 canvas, with the taskbar on top, matching CS2.

Done when: neither app is only an `APP_BACKGROUNDS` colour fill.

Work, in order — independent of each other:

1. [ ] **Steam backdrop.** Art, then the same `APP_SCREEN_TEXTURES` pattern as CS2. No shop UI.
2. [ ] **Chrome backdrop.** Same as Steam. No pages.

Reuse `docs/features/add-screen-background-to-cs2-screen/SPEC.md` as the template.

---

## Horizon 4 — Game loop concept

Status: **later**

Player can: (nothing yet — this horizon is a document, not a build)

Done when: `docs/GAME_DECISIONS.md` (or a short design note it points at) answers what the player does after Start, what the four apps are for, and what the next implementation horizon is. Then replace this section with that horizon.

Work, in order:

1. [ ] **Write the loop.** One sitting: the verb, what Steam/Chrome/CS2/Home (if it survives) each do, how rubles move, what a session looks like. No SPEC, no code.
2. [ ] **Rewrite the roadmap.** Turn the concept into the next numbered horizon(s) with ordered tasks. Park everything the concept does not need.

---

## Parked

Not sequenced. Steal from here into a horizon when something earns a player sentence; do not work these from Now.

- Pressed / disabled taskbar-icon states (hover already covers "pointing at")
- Start menu (Windows-style; the pause menu is Horizon 2)
- Tooltips
- Volume that actually mutes; first sounds
- Shared control chrome from `ui-button` / `ui-chrome`
- Second currency or kopeks
- Earn / spend / shop / browser-page features — wait for Horizon 4
- Anything that needs a real browser, a real Steam API, or a real CS2 client
