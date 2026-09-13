# Skilltree Suggestions

Companion to `SKILLTREE.md`. Three parts:

1. **Mechanics**: what the game has now (in code) and what `STORY.md` / `SKILLTREE.md` say is coming.
2. **Levers**: the numbers and switches each mechanic has, what the current tree already boosts, and what nothing boosts yet.
3. **Skills**: new nodes built on those gaps, sorted by tree, each one written as a purchase.

Requirements are all-of, as in the catalog (no "any of"). Short names are ≤ 10 characters so they fit the 64 px skill card at font size 12. The effect kinds match
`skill_catalog.gd`: **MOD** (modifier bucket), **SCHED** (schedule/clock), **FEAT** (feature switch).
Keys marked *new* don't exist yet. They are listed in the [hook list](#5-modifier-keys-this-would-need)
at the end.

---

## 0. Framing: every skill is a purchase

The player never "learns" anything. They **pay rubles for something**, and that thing does the work.
That fits a broke kid in a tower block who has just found out money solves problems. Every node should
answer **"what did I just buy?"** A skill can be one of six kinds of purchase:

| Purchase type | Examples | Reads as |
| --- | --- | --- |
| **Goods** | books, vodka, keyboard, second monitor, printer paper | "Buy a …" |
| **Services** | intel from forum "friends", Wi-Fi password, captcha solving, proxies | "Pay for …" / "Subscribe to …" |
| **People** | hired help, a foreman, the software guy, a cousin in telecom | "Hire …" |
| **Training** | courses for the workers (the existing "Teach workers …" nodes) | "Pay for a course / tutor so the workers …" |
| **Bribes & favours** | district cop, building caretaker, flea market vendor | "Slip … an envelope" |
| **Accounts & data** | aged profiles, leaked databases, smurf accounts, lookalike domains | "Buy a …" from a forum |

### Presentation ideas for the Skills app

- **Each tree is a shop.** The Skills app becomes a set of seller pages instead of one abstract tree:
  | Tree | Shop framing |
  | --- | --- |
  | General (1st) | *The flea market downstairs*: hand-written price tags, cardboard boxes |
  | Automation (2nd) | *The courtyard / job board*: tear-off flyers ("computer skills? call …") |
  | Shady Software (3rd) | *The software guy's price list*: a forum thread or messenger channel in green-on-black |
  | Scammer 2.0 (4th) | *Black market catalogue*: photocopied, stapled |
  | Office (bonus) | *Real estate & furniture classifieds* |
  | Worker (bonus) | *Night-school course brochure* |
- **Nodes are price tags.** A locked node shows a crossed-out or blurred tag. An affordable node shows a
  plain price tag. A bought node gets a **"SOLD" / "ПРОДАНО"** stamp instead of a lit-up border.
- **Tooltip = listing.** Line 1 is what you're buying (flavour). Line 2 is what it does (numbers). Price on the
  bottom. Example: *"A mechanical keyboard, only a little sticky. Each key press types 2 characters."*
- **Receipt popup** on purchase (reuses `value_change_popup.gd`'s idea): `-4 500 ₽ … KEYBOARD (USED)`.
- **Ranked nodes are restocks.** Rank II/III is "a better one" or "more of it", never "level 2": *Vodka →
  More vodka → A whole crate*.
- **Story hooks.** Buying something visible (a monitor, a crate of vodka, an office) is a natural trigger for a
  one-line comment from Mother or the Old Friend through `story_catalog.gd`'s `"skill"` field.

---

## 1. Mechanics

### 1a. In the game now

| # | Mechanic | Where | How it works today |
| --- | --- | --- | --- |
| M1 | **CS2 match** | `cs2_screen.gd` | Press *Queue*. 7 stages play out over 32 s plus a 2 s hold, then the button comes back (**manual re-queue**). Keeps running while hidden. |
| M2 | **Target payout** | `cs2_screen.gd` `TARGET_CHANCES` | One roll per match: 1 target (75%), 2 (20%), 3 (4%), 4 (1%). |
| M3 | **Target feed** | `gaming_community_screen.gd`, `target_profiles.gd` | One card per target with a name and avatar, only as many as fit. The only thing a target has is its name and avatar. |
| M4 | **Chat: typing** | `gaming_community_chat_window.gd` | **One key press = one character** of a random opener. The message sends when it's fully typed. Only the frontmost typing window receives keys. Several windows can be open at once. |
| M5 | **Chat: reply** | same | The target answers after 1–3 s. **50%** positive (`POSITIVE_CHANCE`), otherwise a refusal. Either way the target is used up. |
| M6 | **Trade** | same + screen `TRADE_SKINS` | On a positive reply you click the trade request, get **+1 skin**, and the window closes after 1 s. |
| M7 | **Selling skins** | `chrome_screen.gd` | One button sells **all** skins at **1000 ₽ each** through `Skills.grant_rubles()`. |
| M8 | **Rubles** | `game_state.gd`, `skills.gd` | Start with 1337 ₽. `MOD_MONEY_GAIN` scales every ruble earned. Rubles are the only thing you spend. |
| M9 | **Skill runtime** | `skills.gd` | Modifiers (additive fractions → multiplier), schedules (clock + handler), features (on/off). Requirements can cross trees. |
| M10 | **Story beats** | `story.gd`, `story_catalog.gd` | Dialogue segments triggered by unlocking a skill. |

### 1b. Planned (STORY.md / SKILLTREE.md / placeholder apps)

| # | Mechanic | Source | Implied numbers |
| --- | --- | --- | --- |
| P1 | **Workers**: headcount, trigger speed, success chance, what they can do (find / scam / sell) | Trees 2, Worker, Office | worker count, cycle time, success %, skins or rubles per cycle |
| P2 | **Scammer software**: API scraper finds targets, ChatAutomate scams them | Tree 3, `scammer_screen` | targets/min, attempts/min, success % |
| P3 | **Own marketplace**: sell price, sell speed, ads income, promotion | Tree 3 | ₽/skin, skins/min, ₽/min |
| P4 | **Telephone scams** (player, then workers) | Tree 4, `telephone_screen` | calls/min, yield/call |
| P5 | **Fake bills (writing/printing)** (player, then workers) | Tree 4 | bills/min, value/bill |
| P6 | **Office & floorplanner**: worker slots, hardware, amenities, "no meetings" | Office tree, `office_screen`, `floorplanner_screen` | slots, efficiency % |
| P7 | **Languages**: success chance per language | Worker tree | means targets need a **country/language**, which doesn't exist yet |
| P8 | **Rent / household**: "pay his part of the rent this month" | STORY.md part 1 | an early money goal, possibly a recurring cost |
| P9 | **Ending**: reach 1 000 000 ₽ and the government calls | STORY.md | the global goal |

---

## 2. Levers: what each mechanic can be boosted by

✅ = boosted by an existing `SKILLTREE.md` node, ❌ = nothing touches it yet (these are the gaps the
suggestions target).

| Mechanic | Lever | Kind | Covered? |
| --- | --- | --- | --- |
| M1 CS2 match | Match length (stage timings) | MOD | ❌ |
| | Auto re-queue | FEAT | ❌ |
| | Parallel matches (second account) | FEAT | ❌ |
| M2 Target payout | Better roll table / +flat targets | MOD | ✅ vodka, intel |
| | Guaranteed minimum raised | MOD | ❌ |
| | Targets without playing (schedule) | SCHED | ✅ (tree 3 scraper, for software only) |
| M3 Target feed | Feed capacity / visible cards | MOD | ❌ |
| | Target "value" (rich targets trade more skins) | FEAT | ❌ |
| M4 Chat typing | Characters per key press | MOD | ❌ |
| | One key types into several windows | FEAT | ❌ |
| | Opener length | MOD | ❌ |
| M5 Chat reply | Success chance | MOD | ✅ scam book, English, tragedy |
| | Reply delay | MOD | ❌ |
| | Refusal doesn't use up the target (second try) | FEAT | ❌ |
| M6 Trade | Skins per trade / chance of a bonus skin | MOD | ❌ |
| | Trade auto-accepted (no click) | FEAT | ❌ |
| | Window close delay | MOD | ❌ (tiny, not worth a node alone) |
| M7 Selling | ₽ per skin | MOD | ✅ pro account, expensive skins, market manipulation |
| | Auto-sell | FEAT/SCHED | ✅ for workers only, not the player |
| | Bulk-sale bonus | MOD | ❌ |
| M8 Rubles | Passive income | SCHED | ✅ marketplace ads (tree 3 only) |
| | Skill price discount | MOD | ❌ |
| P1 Workers | Count / speed / success | MOD | ✅ lots |
| | Workers pick up the player's leftover targets | FEAT | ❌ |
| | Scaling bonus per worker (foreman) | MOD | ❌ |
| | Offline / night-shift production | FEAT | ❌ |
| P2 Software | Scraper speed, chat speed, chat success | MOD | ✅ |
| | Parallel bot conversations | MOD | ❌ |
| | Recover failed bot chats | FEAT | ❌ |
| P3 Marketplace | Price, speed, ads, promote | MOD/SCHED | ✅ |
| | Reputation / fake reviews | MOD | ❌ |
| P4 Telephone | Yield, speed | MOD | ✅ |
| | Lead supply (who do you call?) | SCHED/FEAT | ❌ |
| | Success chance | MOD | ❌ |
| P5 Printing | Yield, speed | MOD | ✅ |
| | Getting bills into circulation (use them to buy skins) | FEAT | ❌ |
| P6 Office | Slots, speed, efficiency | MOD | ✅ |
| Cross-mechanic | One loop feeding another (refused chat → phone lead, fake bills → skins) | FEAT | ❌ |

**Main gaps:** the player's **hands-on actions** (typing, re-queueing, clicking trades), **cutting
waiting time** (match length, reply delay), **links between loops**, and **spending less** (discounts).
The existing tree is almost all "more %" on success and price.

---

## 3. Suggested skills

Columns: **Card** (≤ 10 chars) · **What you buy** (tooltip flavour) · **Effect** · **Kind / key** ·
**Ranks** · **Requires**. Suggested effect amounts are starting points for balancing, not final values.

### 3.1 General tree (1st, starter): additions

Everything here applies to the player. It fills the typing / waiting / clicking gaps so the manual loop
gets faster, not just more profitable.

#### CS2 (finding targets)

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Energy Drk | *A crate of off-brand energy drinks. Your aim doesn't improve, but your reflexes do.* | Matches play 10% faster per rank | MOD `match_speed` *new* | 3 | root |
| Headset | *A headset with a mic that mostly works. Now you can hear who brags about their inventory.* | +1 guaranteed target every 4th match (or: the 2-target row goes from 25% → 35%) | MOD `target_roll` *new* | 1 | Energy Drk I |
| Spinbot | *A monthly subscription to a "legit" forum cheat. The match stages already say you use it.* | The two spinbotting stages are 50% shorter | MOD `match_speed` *new* | 1 | Headset |
| Macro Key | *A second-hand macro keyboard with the queue button bound to it.* | **Auto re-queue:** a new match starts after the hold | FEAT `cs2_auto_queue` *new* | 1 | Spinbot |
| Smurf Acc | *A Prime smurf account bought from a guy in a stairwell.* | A second CS2 match runs in parallel (both pay) | FEAT `cs2_second_match` *new* | 1 | Macro Key + Vodka |

#### Gaming Community (chatting)

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Keyboard | *A mechanical keyboard, only a little sticky.* | Each key press types 2 / 3 / 4 characters | MOD `typing_speed` *new* | 3 | Scam book |
| Wi-Fi Pass | *The neighbour's Wi-Fi password, for 300 ₽ a month.* | Targets reply 20% sooner per rank (1–3 s → 0.6–1.8 s at rank II) | MOD `reply_speed` *new* | 2 | Scam book |
| +Rep | *Pay school kids 20 ₽ each to spam "+rep trusted trader" on your profile.* | +5% chat success per rank | MOD `chat_success` *new* | 3 | English book |
| 2nd Screen | *A second monitor from the flea market. One corner is purple.* | Each key press types into the **two** frontmost chat windows | FEAT `chat_dual_typing` *new* | 1 | Keyboard II |
| Old Acc | *An aged, level-40 Gaming Community account with badges.* | A refusal has a 25% chance to become "hmm… ok, send trade" instead of using up the target | FEAT `chat_second_chance` *new* | 1 | +Rep II |
| Fake Link | *A lookalike trade-site domain, one letter off.* | 20% chance that a trade pays 2 skins | MOD `bonus_skin_chance` *new* | 2 | Tragedy book II |
| Autoclick | *A cheap autoclicker .exe. Probably a virus.* | Trade requests are accepted automatically | FEAT `chat_auto_trade` *new* | 1 | 2nd Screen |

#### Chrome (selling) and money

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Price Ext | *A price-tracker browser extension. You sell at the daily peak.* | +5% ₽ per skin per rank | MOD `skin_price` *new* | 2 | Pro account |
| Bulk Badge | *A "Verified Bulk Seller" badge for the skin site.* | Selling 10+ skins in one go pays +15% | MOD `bulk_sale_bonus` *new* | 1 | Price Ext I |
| Loyalty Crd | *A flea market loyalty card. Spend money to spend less money.* | Skills cost 5% less per rank | MOD `skill_cost` *new* | 2 | root |
| Empties | *A plastic crate for vodka bottle deposits.* | +50 ₽ every 30 s | SCHED `bottle_deposit` *new* | 1 | Vodka |
| Rent Paid | *Your share of this month's rent, paid in full. Mother is almost impressed.* | No effect on its own. **Story node** for STORY.md part 1 ("pay his part of the rent"); required by Hired help | none (story trigger) | 1 | Vodka + Pro account + Scam book |

> **Why Rent Paid:** STORY.md has the first story milestone as "get enough money to pay the rent". A
> zero-effect node that plays the beat and gates *Hired help* puts that milestone in the tree without a new
> system.

---

### 3.2 Automation tree (2nd): additions

Theme: you're **hiring and equipping people** from the courtyard.

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Contacts | *A school notebook to hand over your target list.* | Workers chat to targets that have sat in **your** feed for more than 60 s | FEAT `workers_take_leftovers` *new* | 1 | Teach scam directly |
| Prime Accs | *Cheap Prime accounts for everyone.* | Workers play CS2 and find targets on their own | FEAT/SCHED `worker_targets` *new* | 1 | Identify targets I |
| Foreman | *Hire your cousin Dima as foreman. He yells a lot.* | +2% worker speed **per worker** | MOD `worker_speed_per_head` *new* | 1 | Managing people book |
| Seeds | *A sack of sunflower seeds for the break room.* | +5% worker speed | MOD `worker_speed` | 1 | root (cheap filler) |
| Trade-ups | *A course on trade-up contracts.* | Every 10 skins workers collect become 11 | MOD `worker_skin_yield` *new* | 2 | Market manipulation I |
| Flyers | *Tear-off job flyers for every stairwell in the district.* | Hiring workers costs 10% less per rank | MOD `hire_cost` *new* | 2 | Hire from street I |
| Cot | *Folding cots. The night shift sleeps where it works.* | Workers produce at 25% rate while the game is closed (capped at 8 h) | FEAT `offline_production` *new* (needs a new system) | 1 | Foreman |
| Software Guy | *The Old Friend knows a guy.* | Bridge node that unlocks tree 3 and triggers the story beat | FEAT `unlock_tree_software` | 1 | Contacts + Foreman |

---

### 3.3 Shady Software tree (3rd): additions

Theme: **the software guy's price list.** Everything is a subscription, license, or "service".

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Proxies | *A list of 500 residential proxies. Don't ask whose.* | ChatAutomate runs +1 parallel conversation per rank | MOD `bot_parallel_chats` *new* | 3 | ChatAutomate |
| Captcha | *A captcha-solving service, paid per 1000.* | API scraper +15% speed | MOD `scraper_speed` | 2 | API scraper |
| Aged Bots | *A bundle of aged bot accounts with real-looking inventories.* | +10% ChatAutomate success | MOD `bot_success` | 1 | Proxies I |
| Phish Page | *A clone of the trade site's login page.* | 15% of refused bot chats still pay a skin | FEAT `bot_phish_recovery` *new* | 1 | Aged Bots |
| Giveaway | *A fake "free knife giveaway" bot for community servers.* | A burst of +5 targets every 2 min | SCHED `giveaway_targets` *new* | 1 | API scraper II |
| Reviews | *300 five-star reviews for your marketplace.* | Marketplace sells 20% faster | MOD `market_speed` | 2 | Marketplace |
| Crypto GW | *A crypto payment gateway. Buyers from abroad.* | +10% marketplace price | MOD `market_price` | 1 | Promote Marketplace |
| Server | *A rented rack in a basement "data centre".* | +10% speed for **all** software | MOD `software_speed` *new* | 2 | API scraper + ChatAutomate |
| Telecom Kid | *The software guy's cousin works at a phone company.* | Bridge node that unlocks tree 4 and triggers the story beat | FEAT `unlock_tree_scam2` | 1 | Server I |

---

### 3.4 New Scammer 2.0 tree (4th): additions

Existing nodes cover yield and speed. The gaps are **leads**, **success chance**, and **links to the old
loops**.

#### Telephone

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Leak DB | *A leaked customer database on a USB stick.* | More phone leads: +1 lead every N s per rank | SCHED `phone_leads` *new* | 3 | Telephone software |
| Spoofing | *Caller-ID spoofing. The screen says "Bank".* | +10% phone success | MOD `phone_success` *new* | 2 | Leak DB I |
| Voice Mod | *A voice changer that makes you sound 45 and tired.* | +10% phone success | MOD `phone_success` *new* | 1 | Spoofing I |
| Headsets | *Call-centre headsets, bulk pack of 20.* | Worker calls +15% speed | MOD `worker_phone_speed` | 1 | Teach workers telephone |
| Cross-sell | *A form where refused chat targets "verify" their phone number.* | Every refused chat (player, worker or bot) adds a phone lead | FEAT `refusal_to_phone_lead` *new* | 1 | Leak DB I + ChatAutomate |

#### Printing / fake bills

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Paper | *Cotton paper with a watermark that looks right if you squint.* | +10% value per bill per rank | MOD `print_yield` | 3 | Printing software |
| Laser | *A laser printer "fallen off a truck".* | +20% printing speed | MOD `print_speed` | 1 | Paper I |
| Toner | *Toner cartridges by the pallet.* | Printing never stalls / −10% print cycle | MOD `print_speed` | 1 | Laser |
| Skin Wash | *A vendor who takes cash for skins, no questions.* | Fake bills turn into skins automatically, which you can sell as usual | FEAT `bills_to_skins` *new* | 1 | Paper II + Pro account |
| Letterhead | *Official-looking letterhead templates.* | Letter scams (printer + phone) +10% yield | MOD `print_yield` + `phone_yield` | 1 | Spoofing I + Paper I |

---

### 3.5 Worker tree (bonus): additions

The language nodes need targets to have a **country** (see [open questions](#4-gaps--open-questions)).
With that in place:

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Phrasebook | *A dog-eared tourist phrasebook, 12 languages.* | +3% success on every foreign target | MOD `chat_success` (all) | 1 | root |
| Translator | *A translation-app subscription.* | Language penalty halved for languages not yet taught | MOD `language_penalty` *new* | 1 | English + Spanish |
| Accent Crs | *Accent coaching from a failed actor.* | Phone success +10% for taught languages | MOD `phone_success` | 1 | Telephone software + English |

---

### 3.6 Office tree (bonus): additions

| Card | What you buy | Effect | Kind / key | Ranks | Requires |
| --- | --- | --- | --- | --- | --- |
| Posters | *"TEAMWORK" motivational posters with eagles on them.* | +3% worker efficiency | MOD `worker_speed` | 1 | Shabby office (cheap) |
| Open Plan | *Tear down the walls. Literally.* | +2 worker slots, −5% efficiency | MOD `office_slots` + `worker_speed` | 1 | Expand office I |
| AC | *An air conditioner that drips on one desk.* | +10% efficiency in summer (or: always) | MOD `worker_speed` | 1 | Expand office II |
| Timeclock | *A punch clock. Nobody knows how to use it.* | Workers trigger 10% faster | MOD `worker_speed` | 1 | Disallow meetings |
| Caretaker | *Pay the building caretaker to "not see anything".* | No effect unless raids exist; otherwise −50% raid chance | FEAT `raid_protection` *new* (optional) | 1 | Shabby office |

---

### 3.7 New tree ideas

These go beyond `SKILLTREE.md` and would need some new systems.

#### Krysha (protection) tree: only if a *heat/risk* mechanic is added

The scam grows, so the attention grows. A **Heat** meter fills with every scam and resets or costs money
at the top (a raid, a ban wave, a lost account). Skills are bribes and precautions:

| Card | What you buy | Effect |
| --- | --- | --- |
| VPN | *A VPN subscription* | −10% heat per chat scam |
| Burners | *A box of burner SIMs* | −15% heat per phone scam |
| Cop Envlp | *A monthly envelope for the district police officer* | Heat decays 20% faster |
| Lawyer | *A lawyer who used to be a prosecutor* | A raid costs half |
| Krysha | *Protection from someone with a nicer car* | Raids impossible, but −5% of all income (the "cut") |

This gives the "bought skill" framing a moral-cost twist: some purchases are **ongoing cuts**.

#### Connections tree: the lead-up to the ending

Unlocks around 500 000 ₽ (story beat: someone "important" starts noticing). Global, expensive
multipliers that prepare the government phone call:

| Card | What you buy | Effect |
| --- | --- | --- |
| Suit | *A real suit. Mother cries.* | +5% all income (story beat) |
| Restaurant | *Dinner for a deputy's assistant* | Skills −10% cost |
| Donation | *A "donation" to a patriotic youth club* | +10% success on western European targets |
| Phone Line | *A second, official phone line* | Last node. Unlocks the ending call once 1 000 000 ₽ is reached |

---

## 4. Gaps & open questions

Things in `SKILLTREE.md` / `STORY.md` that the suggestions ran into:

1. **Languages have nothing to act on.** The Worker tree's six language nodes need targets to carry a
   country/language (`target_profiles.gd` has only name and avatar). Suggestion: give each profile a country
   flag on the card, with a success penalty for untaught languages. This also sets up the ending (western
   European targets).
2. **Duplicate lines.** Tree 3 lists "Upgrade ChatAutomate software 1/2/3" twice (chance and speed), and
   Marketplace likewise ("faster selling prices" probably means *faster selling*). Tree 2 has two separate
   "workers trigger faster" books. Consider making one of them success or yield so the nodes feel different.
3. **"Teach workers how to succeed scam directly"** reads unclear. Maybe *"Teach workers to scam on
   their own (workers now generate skins)"*.
4. **Tree unlock order.** STORY.md places the office between trees 2 and 3 ("room planner software?"),
   while SKILLTREE.md calls Office a bonus tree. The suggestions assume Office unlocks from *Hire from
   street II* and Worker from *Teach workers scam directly*.
5. **The rent milestone** exists only in the story. See *Rent Paid* in 3.1.
6. **The ending threshold** (1 000 000 ₽) should be checked against total tree cost. If the trees add up
   to about 1M, the player can reach the ending with nothing left to buy, which is fine. If they add up to
   much more, the ending cuts the trees off.
7. **Cost bands (rough proposal).** Early income is about 1 skin per ~70 s (one ~34 s match, 50%
   success, 1000 ₽/skin), so:
   | Tree | Node cost band |
   | --- | --- |
   | General | 500 – 15 000 ₽ |
   | Automation | 10 000 – 80 000 ₽ |
   | Shady Software | 50 000 – 250 000 ₽ |
   | Scammer 2.0 | 150 000 – 600 000 ₽ |
   | Worker / Office | scale with the tree that unlocks them |

---

## 5. Modifier keys this would need

Where each *new* key would be read in the current code, so `skill_catalog.gd`'s rule ("a key is declared
when the code that reads it exists") can be followed one key at a time.

| Key | Kind | Reads in | Applies as |
| --- | --- | --- | --- |
| `match_speed` | MOD | `cs2_screen.gd` `STAGES` / `LAST_STAGE_HOLD` | stage time ÷ multiplier |
| `target_roll` | MOD | `cs2_screen.gd` `TARGET_CHANCES` / `targets_for_roll()` | scale the non-certain rows |
| `cs2_auto_queue` | FEAT | `cs2_screen.gd` `_return_to_queue()` | call `_on_queue_pressed()` instead of showing the button |
| `cs2_second_match` | FEAT | `cs2_screen.gd` | second match state (larger change) |
| `typing_speed` | MOD | `gaming_community_chat_window.gd` `type_next_character()` | characters per press = round(multiplier) |
| `chat_dual_typing` | FEAT | `gaming_community_screen.gd` key routing | route the key to the two frontmost typing windows |
| `reply_speed` | MOD | `gaming_community_chat_window.gd` `REPLY_DELAY_MIN/MAX` | delay ÷ multiplier |
| `chat_success` | MOD | `gaming_community_chat_window.gd` `POSITIVE_CHANCE` | `0.5 × multiplier`, clamped (also where the existing scam/English/tragedy books would plug in) |
| `chat_second_chance` | FEAT | `gaming_community_chat_window.gd` `_send()` | re-roll once on refusal |
| `chat_auto_trade` | FEAT | `gaming_community_chat_window.gd` `_send()` | call `_on_trade_request_pressed()` straight away |
| `bonus_skin_chance` | MOD | `gaming_community_screen.gd` `TRADE_SKINS` | chance of +1 skin |
| `skin_price` | MOD | `chrome_screen.gd` `RUBLES_PER_SKIN` | kept separate from `money_gain` so "per skin" and "all income" stay distinct (they multiply together) |
| `bulk_sale_bonus` | MOD | `chrome_screen.gd` `_on_convert_pressed()` | applied if skins ≥ 10 |
| `skill_cost` | MOD | `skills.gd` `unlock()` / `lock_state()` and the tooltip price | cost ÷ multiplier |
| `bottle_deposit` | SCHED | handler adds rubles through `Skills.grant_rubles()` | every 30 s |

Note: "faster" levers (`match_speed`, `reply_speed`, `skill_cost`) **divide** by the multiplier so stacked
ranks never reach zero or go negative (x1.3 → 77% of the time, not 70%).
