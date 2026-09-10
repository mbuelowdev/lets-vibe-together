# Taskbar ruble balance and global game state

## 1. Context & Goal

Every value the game has held so far belongs to exactly one screen: the selected app lives in
`taskbar.gd`, the background color in `main.gd`, the window mode in the dropdown that sets it.
Money is the first value that does not — a balance is earned on one screen, spent on another, and
displayed on the taskbar that outlives both. Storing it on any one of those screens would mean the
others read a copy that can drift.

So this feature adds two things at once: a `GameState` autoload that owns cross-screen values, and
the first such value — a ruble balance — drawn at the right end of the taskbar, immediately left of
the divider that already separates the util cluster from the app icons. The balance is a readout
only. Nothing spends it yet; `spend_rubles()` exists so the store screen that eventually does has a
single correct way to.

## 2. Scope

### In scope

- `res://game_state.gd`, registered as the `GameState` autoload, owning the ruble balance behind
  accessors and emitting `rubles_changed` on every change.
- Ruble formatting (`format_amount`, `format_rubles`) on that autoload, so a taskbar balance and a
  future price tag render identically.
- A two-control money readout in `res://taskbar.tscn`'s `Utils` cluster, left of `Divider`.
- `res://taskbar.gd` binding those controls to `rubles_changed` and exposing the §7 accessors.
- The `rich` scenario, establishing a balance far from the boot value.
- The new bridge fields listed in §7, registered from `res://main.gd`.

### Out of scope

- Spending money from any screen. `spend_rubles()` and `can_afford()` ship unused on purpose.
- Persistence. `GameState` is rebuilt at boot and "Save & Quit" in `main.gd` still only quits.
- Earning money: no timers, no rewards, no CS2 or Steam integration.
- A second currency, kopeks, or fractional balances.
- Localizing the amount. The format is Russian regardless of UI language — it is the in-fiction
  desktop's currency, not the player's.
- Making the readout interactive: no click target, no hover, no tooltip, no wallet screen.
- Any change to the app icons, the divider, the volume icon, or the clock.

## 3. Relevant files / existing code

### Files to create

- `res://game_state.gd` — the autoload.
- `res://.egon/scenarios/rich.gd` — the `rich` scenario.
- `res://.egon/checks/add-taskbar-currency.json` — this feature's checks.

### Files to modify

- `res://project.godot` — add `GameState="*res://game_state.gd"` under `[autoload]`, **above** the
  `EgonBridge` line: `EgonBridge` instantiates every scenario script in its own `_ready()`, and a
  scenario that touches `GameState` must find it already registered.
- `res://taskbar.tscn` — add `Money` and `MoneySign` Labels to `Utils`.
- `res://taskbar.gd` — bind both controls to the autoload; add the §7 accessors; add both to
  `_util_controls()`.
- `res://main.gd` — register the §7 bridge fields in the existing `_register_bridge_fields()`.
- `res://.egon/checks/add-taskbar-clock-and-volume-icon.json` — see §6.

### Existing patterns / conventions

- Autoload identifiers are undefined under `--check-only`, so gameplay scripts reach the autoload as
  `get_node("/root/GameState")`, never the bare `GameState` — the same rule `godot-cli.md` states for
  `EgonBridge`. A `RefCounted` scenario has no `get_node()` at all and uses
  `Engine.get_main_loop().root.get_node_or_null("GameState")`.
- Geometry lives in `taskbar.tscn`, not in code (see the amendment in
  `docs/features/add-on-hover-effects/SPEC.md` §6). Both money controls carry their own offsets, and
  the 2px baseline correction in §6 is a scene offset rather than a constant in `taskbar.gd`.
- `main.gd` registers every bridge field at the one `_register_bridge_fields()` call site;
  `taskbar.gd` registers nothing and only exposes accessors for it to call.
- Util cluster members are `mouse_filter = MOUSE_FILTER_IGNORE`, which is what keeps
  `utils_clickable()` false and lets clicks fall through to the taskbar.

## 4. Assets

None. The balance is text in the existing UI font; no sheet, cell, or import is added.

## 5. Interface / Contract

`res://game_state.gd` (extends `Node`, autoloaded as `GameState`):

```gdscript
signal rubles_changed(rubles: int)

const STARTING_RUBLES := 1337
const MAX_RUBLES := 999_999_999
const RUBLE_SIGN := "₽"
const DIGIT_GROUP_SEPARATOR := "  "
const DIGITS_PER_GROUP := 3

func rubles() -> int
func set_rubles(amount: int) -> void      # clamps to [0, MAX_RUBLES]; emits only on a real change
func add_rubles(amount: int) -> void      # negative deducts with no affordability check
func can_afford(cost: int) -> bool        # false for a negative cost
func spend_rubles(cost: int) -> bool      # false and no mutation when unaffordable
func reset() -> void

static func format_amount(amount: int) -> String   # grouped digits, no sign: "1  337"
static func format_rubles(amount: int) -> String   # amount and sign: "1  337  ₽"
```

`res://taskbar.gd` additions:

```gdscript
func money_text() -> String        # the whole readout, recomposed across both controls
func money_matches_state() -> bool # money_text() == GameState.format_rubles(GameState.rubles())
func money_sign_drop() -> int      # px the sign's box centre sits below the amount's; 2
```

Behavior contract:

- State is private behind accessors. A bare `var rubles` would let a caller write a negative balance
  and would give the taskbar nothing to bind to. Future cross-screen values follow the same shape: a
  private var, a reader, a mutator that clamps and emits a `*_changed` signal.
- `set_rubles()` emits only when the clamped value differs from the current one, so listeners may
  redraw unconditionally without a feedback loop.
- `spend_rubles(cost)` is the only way to spend. It returns whether the purchase went through and
  leaves the balance untouched when it did not, so a caller branches on one call rather than checking
  and then deducting.
- `taskbar.gd` binds `rubles_changed` in `_ready()` and writes only `Money.text`. The balance moves
  when the player earns or buys something, never on a clock, so it is pushed on change and never
  polled in `_process`.
- `MoneySign.text` is static scene text and is never written from code — see §6.
- Both controls join `_util_controls()`, so `utils_visible()` returns 5 and `utils_order()` returns
  `["money", "moneysign", "divider", "volume", "clock"]`. `utils_right_margin()` stays 4 and
  `utils_clickable()` stays false: the readout is left of the cluster's right edge and takes no input.

## 6. Implementation notes / constraints

**The ruble sign is not in the primary UI font.** Of the four faces in `res://resources/ui-font.tres`,
only Galmuri11 — last in the fallback chain, and there for Korean and Vietnamese — carries U+20BD.
The sign therefore renders through a different face than the digits beside it. It does render
correctly at font size 12, but this is load-bearing: dropping Galmuri11 from the chain turns the
balance into tofu. Verify against a rendered frame, not a headless run, when touching the font.

**The two faces do not share a vertical metric.** Galmuri11 reports a 17px line height against
Pixelify Sans's 16, and the sign's glyph is 11px of ink against the digits' 7. Set in one Label the
sign is baseline-aligned but sits 4px taller than the digits *entirely upward*, which reads as the
sign floating above the number. The fix is to give the sign its own control and translate it down
2px, splitting the overhang evenly above and below (measured: digits ink y341-347, sign y339-349,
both centred on y344). Consequences the implementer must preserve:

- `MoneySign` is a separate node whose only job is to carry that offset. Folding the sign back into
  the amount string reintroduces the problem, which is why `_update_money()` writes
  `format_amount()` and not `format_rubles()`.
- The offset is `offset_top = -30.0` / `offset_bottom = 2.0` — the same 32px box as every other
  cluster member, translated, not resized.
- The 4px gap between `Money`'s right edge (-92) and `MoneySign`'s left edge (-88) reproduces
  `DIGIT_GROUP_SEPARATOR` exactly, so the split is invisible in the drawn result and
  `money_text()` can recompose the readout with that separator.

**The thousands separator is two spaces, not one.** A space is 2px at font size 12 in Pixelify Sans —
the same as the sidebearing the digits already carry — so a single space draws no visible break at
all and `"1 234 567"` reads as `1234 567`, with the first group break lost. Two spaces is the
smallest gap this font can draw that actually separates the groups. Do not "correct" it to one.

**Slot widths are derived from the widest string `MAX_RUBLES` allows.** `"999  999  999"` measures
73px, so `Money` is an 80px slot (-172 to -92); the sign is 10px, so `MoneySign` is 12px (-88 to
-76). Neither Label clips, so an unexpectedly long string grows leftward into empty taskbar rather
than being cut — but raising `MAX_RUBLES` past 9 digits means re-measuring both.

**Rubles are whole units.** A float balance would accumulate rounding error across purchases, and
kopeks are below the resolution of anything this game will sell. `_group_digits()` still handles a
leading minus, for price deltas — the balance itself cannot go negative.

**Amendment to an earlier feature's checks.** `.egon/checks/add-taskbar-clock-and-volume-icon.json`
asserted `taskbarUtilsVisible == 3` and an exact `taskbarUtilsOrder` of `"divider,volume,clock"`.
Both are now false — the cluster has five members. That check is about the trio's reading order at
the right end, so it is relaxed to `at_least: 3` and `contains: "divider,volume,clock"`, which
preserves its intent and survives further additions to the left of the divider. Its
`taskbarUtilsRightMargin == 4` and `volumeIconColumn == 2` assertions are untouched and still pass.

## 7. Verification hooks

- Mechanism: the `EgonBridge` autoload. `res://main.gd` calls
  `get_node("/root/EgonBridge").register_field("name", func(): return …)` once per field inside the
  existing `_register_bridge_fields()`. Do not use the bare `EgonBridge` identifier.
- Call: `window.__egon.state()` returns a JSON object of every registered field.
- Fields this feature registers:
  - `rubles` (`number`) — the balance held by `GameState`, read straight off the autoload rather than
    off the label, so a check can compare the two and catch a display that has drifted from the state
    it is meant to show. Provider: `func() -> int: return _game_state_rubles()`.
  - `moneyText` (`string`) — the whole readout as the player reads it, recomposed from both controls:
    `"1  337  ₽"` at boot. Provider: `func() -> String: return _taskbar.money_text()`.
  - `moneyMatchesState` (`bool`) — whether the drawn readout equals
    `format_rubles(rubles())`. Read live, so a label left stale by a missed signal reports false
    instead of quietly disagreeing. Provider: `func() -> bool: return _taskbar.money_matches_state()`.
  - `moneySignDrop` (`number`) — pixels the sign's box centre sits below the amount's; `2`. Measured
    between vertical centres so it stays honest if either box is resized. Nothing else on screen
    would show this drifting. Provider: `func() -> int: return _taskbar.money_sign_drop()`.
- Existing fields this feature reuses: `taskbarVisible`, `taskbarUtilsVisible`, `taskbarUtilsOrder`,
  `taskbarUtilsRightMargin`, `taskbarUtilsClickable`, `selectedApp`, `appSwitchCount`, `hoveredApp`,
  `hoveredIconColumn`.

## 8. Test scenarios

- `default` (existing) — the game as it normally boots: the taskbar reads `1  337  ₽`.
- `rich` (new) — sets the balance to 1 234 567 through `GameState.set_rubles()`. It exists because
  every string a `default` check can assert is also the placeholder text baked into `taskbar.tscn`,
  so `default` alone cannot tell a live readout from a scene file that happens to say the right
  thing. `rich` can.

Coordinate note: the base viewport is 640×360 and the runner's space is 1:1 with Godot coordinates.
The money readout spans x468-564 at y328-360; `(545, 344)` is over the drawn text. Taskbar app icon
centers are `(16, 344)` home, `(48, 344)` steam, `(80, 344)` chrome, `(112, 344)` cs2.

The machine-executable checks live in `.egon/checks/add-taskbar-currency.json`.

## 9. Acceptance criteria

1. The taskbar draws the balance at the right end, between the app icons and the divider, in reading
   order money → divider → volume → clock, with the cluster still 4px off the taskbar's right edge.
2. The balance shown is `GameState`'s, not a string baked into the scene: the `rich` scenario boots
   reading `1  234  567  ₽`, and any later `set_rubles()` is on screen the same frame.
3. The balance survives app switching — it is owned by the autoload, not by a screen.
4. The ruble sign renders as a ruble sign, not tofu, and sits 2px below the amount's box centre.
5. The readout is inert: pointing at it or clicking it changes no selection, no background, and no
   balance, and `utils_clickable()` stays false.
6. `spend_rubles()` refuses a purchase the balance cannot cover and leaves the balance untouched;
   the balance never goes below 0 or above `MAX_RUBLES`.

## 10. Explicitly NOT this task

- Do not persist `GameState` or wire it into "Save & Quit".
- Do not add a way to earn or spend rubles from any screen.
- Do not make the readout clickable, hoverable, or focusable, and do not give it a tooltip.
- Do not fold the ruble sign back into the amount string, and do not write `MoneySign.text` from code.
- Do not reduce the thousands separator to a single space.
- Do not localize or reformat the amount per UI language.
- Do not rename or remove any existing bridge field, and do not register fields from `taskbar.gd`.
- Do not add addons or dependencies.
