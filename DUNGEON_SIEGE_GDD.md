# Project "Siege-like" — Game Design Document & Build Guide
### A party-based dungeon-extraction action-RPG with shopkeeping, in Godot 4

> **Audience:** Future Claude sessions building this game one feature at a time.
> **How to use this file:** Read Sections 0–3 every session. Then jump to the single feature you are implementing in Section 6. Update Section 8 (Progress Tracker) when done.

---

## 0. Session Protocol (READ FIRST, EVERY SESSION)

1. Read Sections 0–3 and the **Progress Tracker (Section 8)**.
2. Pick the **first unchecked feature** whose dependencies are all checked, unless the user names a feature.
3. Read that feature's spec in Section 6. Do not implement anything outside its **Scope**.
4. Implement it following the conventions in Section 3.
5. Verify every **Acceptance Criterion**. Where possible, write an automated test (GUT) or a headless smoke test (`godot --headless --quit-after 5`). Where not possible, add a short manual test script to `docs/manual_tests/<feature_id>.md`.
6. Update Section 8: tick the feature, add a one-line note (files added, known gaps).
7. Append any new design decisions to Section 9 (Decision Log). Never silently deviate from this doc; if a spec is wrong or impractical, change the doc and log why.
8. Commit with message `F-XXX: <feature name>`.

**Rules of thumb**
- One feature per session/PR. Keep the game runnable at the end of every session.
- Data-driven always: stats, items, classes, abilities, monsters, NPC types, decor, economy numbers live in `Resource` (`.tres`) files, never hard-coded in scripts.
- Prefer composition (child nodes/components) over deep inheritance.
- Use placeholder art (primitive meshes, CSG, free CC0 assets). Do not reproduce assets from the games that inspired this one (see Section 1.4).
- Economy and haggling math are **pure functions** in `core/` so they can be unit-tested without scenes.

---

## 1. Vision

### 1.1 Pitch
You are **the Shopkeeper**, saddled with a crushing debt, running a curio shop in a frontier town built on top of **the Hollow Deep**, a vast, multi-level dungeon. You don't fight. You hire a **guild of adventurers**, send a party of up to six into the Deep, and command them in real-time, party-based combat. Each run is an **extraction**: fight downward, fill your packs, and make it back to one of the exits scattered through the dungeon. If the party is wiped out, everything they found is lost and the survivors spend days recovering. Back on the surface, you **stock your shelves, decorate your shop, and haggle** with the townsfolk who come to buy your wares or sell you theirs. Every week the debt collector comes, and so do your adventurers' salaries.

### 1.2 Design Pillars
1. **Extraction with real stakes.** Loot found in a run only counts once you extract. A wipe loses it all and benches the party for days.
2. **One deep, learnable dungeon.** A single fixed, hand-authored, vertically stacked dungeon streamed seamlessly with **no loading screens**. Players learn its routes; exits they discover become future start points.
3. **Party, not hero.** Command up to six adventurers in real time with formations, AI stances, a **tactical pause**, and hotkeyed class abilities.
4. **Loot is merchandise.** Every drop is judged by what it's worth on a shelf as much as what it does in a fight.
5. **Shopkeeping is half the game.** Display, decorate, attract the right customers, and haggle.
6. **The calendar bites.** Each day is either a run or a town day. Debt and salaries are due weekly; injuries cost days.

### 1.3 Target
- Engine: **Godot 4.3+** (4.x stable), **GDScript**, 3D with fixed-angle rotatable camera (dungeon and town).
- Platform: PC (Windows/Linux/macOS). Keyboard + mouse only.
- Scope target: a **vertical slice** (Milestones M0–M9), then content expansion.
- Single-player first. Multiplayer is out of scope until M12.

### 1.4 Legal / IP
This is a **mechanical homage** to *Dungeon Siege* (party combat, seamless streaming), *Recettear* (shopkeeping, haggling, debt), and extraction shooters (run stakes). Use original names, story, art and audio. Do **not** use names, characters, places, assets, music or text from any of those games. Working names (rename freely): the protagonist **the Shopkeeper**, the town **Marchgate**, the dungeon **the Hollow Deep**, the creditor **the Lantern Bank**.

---

## 2. Core Gameplay Spec (summary reference)

### 2.1 Controls (default)
**Dungeon**
| Action | Input |
|---|---|
| Move party / leader | Left-click ground |
| Attack target | Left-click enemy |
| Pick up item | Left-click item on ground |
| Interact (extraction point, chest, door) | Left-click interactable |
| Select character | Click portrait or `F1`–`F6` |
| Select all | `Ctrl+A` or `Home` |
| Add to selection | `Shift+click` portrait |
| Box-select | Left-drag |
| **Tactical pause** | `Space` |
| Class abilities (selected character) | `1`–`6` |
| Quick health / mana potion (selected) | `Z` / `X` |
| Camera rotate | Hold `Middle Mouse` + drag, or `Q`/`E` |
| Camera zoom | Mouse wheel |
| Camera pan | Edge scroll or `WASD` (when unfollowed) |
| Camera follow leader | `V` toggle |
| Inventory | `I` |
| Character sheet | `C` |
| Abilities list | `K` |
| Dungeon map | `M` |
| Stance cycle | `T` |
| Formation cycle | `F` |
| Show item labels | Hold `Alt` |
| Menu | `Esc` |

**Town & Shop**
| Action | Input |
|---|---|
| Move shopkeeper | Left-click ground |
| Interact (door, NPC, display stand) | Left-click |
| Shop build/decor mode (shop closed) | `B` |
| Rotate decor piece | `R` |
| Haggle: adjust offer | Mouse wheel / `↑`/`↓` (±1%), `Shift` for ±10% |
| Haggle: confirm offer | `Enter` or click Offer |
| Haggle: refuse / end | `Esc` |
| Storage (shop stash) | `I` (in shop) |
| Calendar / ledger | `L` |

Commands may be issued **while tactically paused**. Pause is unlimited and is allowed only in the dungeon; the shop runs in real time.

### 2.2 Core Loop & Calendar
- The game runs on **days**. Each day is **either**:
  - **Run day:** in the morning, assemble a party at the Dungeon Gate, pick a start point, and run. The run uses up the whole day; when it ends (extraction or wipe), the day advances to the next morning.
  - **Town day:** split into **3 phases** (Morning, Afternoon, Evening). Each phase is spent on **one activity**:
    - **Open Shop:** real-time selling/buying session in the shop (~150 s real time per phase, tunable).
    - **Visit a location:** entering the Market, Guild Hall, Healer, or Bank to do business uses up the phase when you leave. Walking the streets is free.
  - Arranging display stands and decorating while the shop is closed is **free** (no phase cost).
  - At any point on a town day you may **end the day early**.
- **Weekly settlement** at the end of every 7th day:
  1. The **debt payment** is due (amount per week from `EconomyData.debt_schedule`). Unable to pay means **game over** (bad ending).
  2. **Salaries** for every roster member (active, benched, or injured) are deducted. Any member you can't pay **leaves the guild**; their equipped gear returns to shop storage.
- Paying off the full debt schedule triggers the **good ending**. Free play continues after it.

### 2.3 Guild Roster & Party
- The **Roster** is every adventurer and mule you employ (soft cap from guild hall upgrades, start 6). Recruit at the **Guild Hall** from a rotating list of candidates; dismiss any time.
- The **Party** is the subset deployed on a run: **max 6, pack mules included**. One designated **leader** (camera follows). Others follow in formation.
- Each roster member has a **weekly salary** = `class.base_salary + level × class.salary_per_level` (mules use a flat cheap salary).
- **Injury:** after a **wipe**, every deployed member (mules included) is **injured for a random 1–4 days** (`EconomyData.injury_days_range`) and can't be deployed. The Healer can cut injury days for gold.
- **Pack mules** have a large grid inventory, can't fight, flee from enemies, take no XP, and can die.
- **Gold** is a single shared wallet (the shop's purse).

### 2.4 Classes & Progression
- Every recruit has a **class** (v1: Fighter, Ranger, Mage, Cleric, Rogue). `ClassData` defines base stats, **fixed per-level stat growth**, weapon/armor proficiencies, and an **ability unlock table** (ability X at level N). Level-ups involve **no player choices**.
- Recruits vary: each candidate rolls small **starting stat variance** and 0–2 **traits** (`TraitData`, e.g. "Sturdy: +10% HP", "Greedy: +15% salary, +5% loot find").
- **Primary stats:** **Strength** (HP, melee damage, gear reqs), **Dexterity** (attack speed, ranged accuracy/damage, dodge, gear reqs), **Intelligence** (mana, ability power, mana regen, gear reqs).
- **XP:** kills grant XP to **every deployed non-mule member, including dead ones**. Amount = `monster.xp_value × level_factor(monster_level − member_level)`. Each member gets the full amount by default (`ProgressionData.xp_share_mode = full | split`). Level cap 50 (tunable). The XP curve and level factor live in `ProgressionData`.
- A member's **level** drives stats, ability unlocks, gear requirements, and salary.

### 2.5 Combat
- Real time with **tactical pause** (2.1). Each actor has `Health`, `Mana`, and an attack loop.
- **Auto-engage:** party members with an enemy in aggro range (per stance) attack automatically with basic attacks.
- **Class abilities** are triggered by the player (hotkeys `1`–`6` for the selected character, with targeting cursors). AI uses an ability only if that ability's **auto-cast toggle** is on (2.6).
- **Melee:** approach to weapon range, swing, apply damage at hit-frame. **Ranged:** projectile with travel time. **Abilities:** cast time, mana cost, cooldown; target ground/enemy/ally/self; effects are composable (damage, projectile, AoE, heal, buff/debuff, DoT, summon, revive).
- **Damage formula (baseline, tunable):**
  ```
  raw    = weapon_damage_roll * (1 + stat_scaling) * (1 + damage_mods)
  armor  = target.armor_total
  dmg    = max(1, raw * 100 / (100 + armor))   # armor diminishing returns
  crit   = chance from DEX/items; crit mult 1.5
  ```
- **Hit/dodge:** `hit_chance = clamp(0.5 + (attacker_accuracy - defender_dodge)*0.01, 0.1, 0.95)`.
- **Individual death:** the character collapses; the run continues. Dead members can be revived in the dungeon (revive consumable or Cleric ability). Members still dead at extraction are revived automatically on returning to town, with **no lasting penalty**, and keep their inventory.
- **Wipe:** all deployed members dead. The run ends (2.10).

### 2.6 AI Stances (per character)
- **Defensive/Hold:** only fights what attacks it or is explicitly targeted; stays within leash of leader.
- **Balanced (default):** attacks enemies in a medium aggro radius, returns to formation after.
- **Aggressive:** large aggro radius, chases further.
- **Auto toggles:** per-ability *auto-cast*, *auto-heal allies below X%*, *auto-use potions below X%*, *mana reserve %*.

### 2.7 Formations
Named layouts relative to the leader (*Line, Wedge, Column, Box, Circle, Scatter*), up to 6 slots. Each member's offset = formation slot; mules default to the rearmost slot. The formation rotates with leader facing and degrades to Column in corridors. Movement uses `NavigationAgent3D` with a soft leash.

### 2.8 Items
- **Slots:** head, chest, hands, feet, amulet, ring×2, main hand, off hand (shield/offhand/quiver).
- **Item types:** 1H melee, 2H melee, bow, staff/wand, armor (light/medium/heavy), shield, jewelry, consumable, scroll, **material** (ore, hides, reagents) and **curio** (gems, relics, art objects with no use, worth money only), quest/key.
- **Requirements:** min level and/or STR/DEX/INT; optional `allowed_classes`.
- **Rarity & modifiers:** Normal, Magic (1–2 affixes), Rare (3–4), Unique (handmade). Names are built as `[Prefix] Base [of Suffix]`.
- **Value:** `ItemFactory` computes `value = base_value × rarity_mult × Π(affix value mults)`. This **value is the 100% reference price in haggling**. Market trends (2.14) adjust what customers think it's worth.
- **Shop tags:** every `ItemData` has `shop_tags` (e.g. `martial`, `arcane`, `rustic`, `luxury`, `occult`, `practical`) and a `category`. Customers and trends key off these.
- **Run-found flag:** an item picked up during a run is flagged `found_this_run` until extraction (2.10).
- **Inventory:** grid-based per character (e.g. 8×5). Mules get a large grid (e.g. 12×10). Items have grid sizes. Consumables auto-stack. Drag/drop.
- **Equipment** shows on the 3D model (placeholder: color swap or attached meshes).

### 2.9 The Hollow Deep (Dungeon)
- **One fixed, hand-authored dungeon** of several vertically stacked **levels** (v1: 3). Levels connect through stairs, ramps, shafts and chasms. All of it is one seamlessly streamed **graph of chunks** (scenes with named **sockets**). Chunks near the party load on a background thread and far ones unload. No loading screens, including between levels.
- **Per-run reset:** each run respawns all monsters and re-rolls all containers and ground loot. The layout never changes.
- **Persistent across runs:** the explored map (fog of war), discovered extraction points, and boss first-kill flags.
- **Depth scaling:** each chunk has an `area_level` that sets monster level and item level (ilvl). Deeper means more danger and more valuable loot.
- **Bosses** guard key areas, respawn every run, and award a one-time **first-kill bonus** (unique item / gold / guild hall upgrade).
- **Extraction points** are fixed locations (portals, rope lifts, old mine elevators) that are **always open**. They are **discovered** when the party comes within their radius, and discovery persists even if the party later wipes. Every discovered point can be chosen as a **start point** for later runs, at no cost. The dungeon entrance is always both an extraction point and a start point.

### 2.10 Runs & Extraction
- **Run lifecycle:** `PREP` (Dungeon Gate: choose party ≤6, choose start point, check gear) → `ACTIVE` → `EXTRACTED` | `WIPED` | `ABANDONED` → `SUMMARY` → next day.
- **No in-run timer.** Pressure comes from inventory space, consumables, and risk.
- **Extracting:** the leader interacts with a discovered extraction point and a **channel** starts (default 3 s, `RunConfig.extract_channel_s`). The channel cancels if any living member leaves the point's radius. On completion, the entire deployed party (alive and dead) returns to town.
- **On extraction:** clear `found_this_run` on all items, bank the run gold, revive the dead, and show the run summary (loot value, XP, kills). Members keep their inventories; unload loot to shop storage from the summary or later in the shop.
- **On wipe:** every `found_this_run` item is removed from all deployed members' inventories and equipment (including mule cargo), and **run gold is lost**. Items **brought from town are kept**, as is equipment worn into the run, even if it was unequipped mid-run. Every deployed member is injured (2.3). Then the summary screen, then the next day.
- **Abandoned run** (quit to menu or crash mid-run): on next load it resolves as a **wipe** (saves exist only in town, 2.15).
- **Gold** found in the dungeon goes to a per-run `run_gold` pool and is credited only on extraction.

### 2.11 Town (Marchgate)
- A **walkable 3D town**. The Shopkeeper (non-combatant) walks between locations:
  - **Shop**: your storefront and storage (2.12).
  - **Guild Hall**: roster, recruitment, dismissals, mule hiring. Upgrades raise the roster cap. (Party assembly happens at the Dungeon Gate.)
  - **Market**: wholesale buying (2.14).
  - **Healer**: shorten injuries for gold; sells consumables at fixed prices.
  - **Lantern Bank**: debt status and early payments.
  - **Dungeon Gate**: party assembly and start-point selection; begins a run (only in the Morning phase of a fresh day).
- Visiting a location (Market, Guild Hall, Healer, Bank) uses up the current phase when you leave (2.2).

### 2.12 Shop & Haggling
- **Shop scene:** a 3D interior with a **build grid**. It contains display stands, decor, a counter, and the Shopkeeper. **Shop storage** (stash) is a large grid inventory that holds unsold stock; extracted loot and market purchases go here.
- **Stocking:** while closed, place items from storage onto **display stands** (each stand holds 1–4 items depending on type). Display count is capped by merchant level.
- **Open Shop phase:** customers arrive (2.13), browse stands, and pick an item. Their **intent** is one of:
  - **Buy:** wants a displayed item → comes to the counter → **haggle (sell)**.
  - **Sell:** brings an item from their own loot table → **reverse haggle (buy)**.
  - **Request:** asks for a category/tag ("a sturdy shield?"). You pick an item from storage or the display, then haggle.
- **Haggle model** (pure logic, `core/economy/haggle.gd`):
  - Prices are shown as **% of item value** (2.8), starting at a default (e.g. 120% when selling, 70% when buying).
  - Each NPC rolls a hidden **acceptance threshold** from its type's range (e.g. Farmer 95–115%, Noble 120–160% for selling), modified by tag affinity, the market trend for the item, and the shop's reputation tier with that NPC type.
  - **Budget:** the NPC can't pay more than its rolled budget. Offers above budget produce a counter at or below budget, or a walkout.
  - Offer ≤ threshold → **accept**. Offer above threshold but within `walkout_margin` → **counter-offer** (an NPC price somewhere between threshold and offer) and patience −1. Offer beyond the margin, or patience reaches 0 → **walkout**.
  - Reverse haggle mirrors this with a minimum acceptable price.
  - **No combo/streak bonuses.**
- **Outcomes:** gold change, **merchant XP** (2.13), and **reputation** change with that NPC type (fairer prices raise it more; walkouts lower it slightly).

### 2.13 Customers, Decor, Merchant Level & Reputation
- **NPC types** (`NpcTypeData`, v1 ≈ 6–8: Farmer, Laborer, Adventurer, Scholar, Noble, Collector, Wanderer-seller…) define:
  - preferred item tags and decor tags
  - budget range and patience
  - haggle threshold ranges
  - intent weights (buy/sell/request)
  - reputation tiers that unlock wealthier variants
  - min merchant level to appear
- **Customer draw (tag-weighted spawn table):**
  - **Volume per phase:** `visitors = base_visitors + appeal × appeal_scale`, where `appeal = Σ decor.appeal + display_count × display_appeal`.
  - **Type weights:** `w_t = base_weight_t × (1 + item_tag_match_t × k_item + decor_tag_match_t × k_decor) × rep_mult_t`. The tag matches compare the type's preferred tags to the tag totals of the displayed items and the placed decor.
- **Decor:** pieces are placed on the shop build grid (`DecorData`: grid size, tags, appeal value, cost, merchant-level requirement). Display stands are decor too. Buy decor at the Market.
- **Merchant level:** XP = **gross profit** on each sale (`sale_price − cost_basis`). Cost basis is 0 for dungeon loot and the paid price for bought items. Levels unlock shop expansions (bigger grid), more display slots, new decor types, and new NPC types.
- **Reputation per NPC type:** 0–100, with tiers (e.g. 0/25/50/75). Higher tiers raise spawn weight, unlock wealthier variants (higher budgets/thresholds), and make that type more lenient.

### 2.14 Market & Trends
- **Wholesale Market:** a daily-rolled stock list (`MarketData`: categories, rarity caps, markup range 70–100% of value). Buying puts items in shop storage with `cost_basis` set. The market **does not buy** from you.
- **Trends:** `MarketTrendData` events (e.g. "Weapons in demand: ×1.5 for 3 days", "Curio glut: ×0.6"). A rumor appears one day in advance on the market board. While a trend is active, its multiplier applies to **customer perceived value** (shifting acceptance thresholds) and to **market prices** for that category.

### 2.15 Save/Load
- **Saves exist only in town.** Autosave at the start of each day and on returning from a run. Manual save from the menu in town only.
- Saved state: calendar (day, phase), gold, debt progress, roster (class, level, XP, stats, traits, equipment, inventory, injured_until_day), shop (layout, displays, storage), merchant level/XP, reputation, market state & trends, explored dungeon map, discovered extraction points, boss first-kill flags, run-in-progress marker, RNG seed.
- Format: JSON via `SaveManager`, versioned with migration hooks.

---

## 3. Technical Architecture & Conventions

### 3.1 Project Layout
```
res://
  project.godot
  DUNGEON_SIEGE_GDD.md        # this file
  docs/
    manual_tests/             # per-feature manual test scripts
    decisions.md              # optional long-form ADRs
    balance.md                # combat & economy tuning targets
  autoload/                   # singletons (see 3.2)
  core/
    components/               # reusable Node components (Health, Stats, Level, ...)
    resources/                # Resource class definitions (.gd)
    economy/                  # pure logic: haggle, customer draw, ledger, pricing
    util/
  data/
    classes/                  # *.tres ClassData
    traits/                   # *.tres TraitData
    abilities/                # *.tres AbilityData
    items/                    # *.tres ItemData
    affixes/                  # *.tres AffixData
    monsters/                 # *.tres MonsterData
    loot_tables/              # *.tres LootTable
    formations/               # *.tres FormationData
    npc_types/                # *.tres NpcTypeData
    decor/                    # *.tres DecorData
    market/                   # MarketData, MarketTrendData
    progression.tres          # XP curve, level factor, xp share mode
    economy.tres              # debt schedule, salaries, injury range, phase lengths
    run_config.tres           # extraction channel, etc.
  actors/
    party_member/             # PartyMember scene + scripts
    monster/
    mule/
    shopkeeper/
    customer/
    town_npc/
  dungeon/
    chunks/                   # chunk scenes + ChunkData resources
    dungeon_graph.tres        # chunk graph definition (all levels)
    streaming/                # WorldStreamer etc.
    interactables/            # extraction points, containers, doors
  town/
    town.tscn                 # walkable town
    locations/                # market, guild hall, healer, bank, gate UIs
  shop/
    shop.tscn                 # shop interior
    build/                    # grid placement
    haggle/                   # haggle UI
  ui/
    hud/ inventory/ character_sheet/ abilities/ map/ dialog/ menus/ calendar/ run_summary/
  fx/
  audio/
  tests/                      # GUT tests (res://tests/test_*.gd)
  assets/                     # placeholder art & audio (CC0)
```

### 3.2 Autoloads (singletons)
| Name | Responsibility |
|---|---|
| `Game` | App state machine (`MENU, TOWN, SHOP_OPEN, RUN, PAUSED, GAME_OVER, ENDING`), time scale, tactical pause |
| `EventBus` | Global signals (decoupled comms) |
| `InputMapSetup` | Registers input actions at startup if missing |
| `Calendar` | Day/phase, day type, advancing time, weekly settlement trigger |
| `Economy` | Gold wallet, debt schedule & payments, salary ledger |
| `Roster` | All employed adventurers/mules, recruitment pool, injuries |
| `Party` | Deployed run party (≤6), leader, selection, formation |
| `RunManager` | Run lifecycle, run gold, found-this-run tracking, wipe/extract resolution, discovered extraction points |
| `WorldStreamer` | Dungeon chunk graph loading/unloading |
| `ItemFactory` | Generates item instances from ItemData + affixes; computes value |
| `LootService` | Rolls loot tables, spawns ground items |
| `ShopManager` | Shop layout, displays, storage, merchant level, reputation, customer spawning |
| `Market` | Daily stock, trends, price multipliers |
| `SaveManager` | Serialize/deserialize (town only) |
| `AudioManager` | Buses, music, SFX pooling |

> Keep autoloads thin. Logic lives in components/resources and `core/economy`. Autoloads are registered in `project.godot`.

### 3.3 Key Patterns
- **Components (child Nodes):** `HealthComponent`, `ManaComponent`, `StatsComponent`, `LevelComponent`, `EquipmentComponent`, `InventoryComponent`, `CombatComponent`, `AbilityCasterComponent`, `StatusEffectComponent`, `AIControllerComponent`, `FormationFollowerComponent`, `AggroComponent`, `LootDropperComponent`. Actors are scenes composing these.
- **Resources:** `ItemData`, `AffixData`, `AbilityData`, `ClassData`, `TraitData`, `MonsterData`, `LootTable`, `FormationData`, `ChunkData`, `ExtractionPointData`, `ProgressionData`, `NpcTypeData`, `DecorData`, `MarketData`, `MarketTrendData`, `EconomyData`, `RunConfig`. Runtime instances: `ItemInstance` (data ref + affixes + stack + `found_this_run` + `cost_basis`), `RecruitInstance` (class, name, level, XP, stat variance, traits, injury).
- **Signals up, calls down.** Components emit signals; parents/EventBus listen.
- **State machines** for actor behavior (`Idle, Move, Attack, Cast, Dead, Stunned`; customers: `Enter, Browse, Approach, Haggle, Leave`). One pattern project-wide.
- **Collision layers** (names must be used):
  1. `world` 2. `party` 3. `monsters` 4. `npcs` (town NPCs & customers) 5. `projectiles` 6. `pickups` 7. `triggers` 8. `click_pick` 9. `build_grid`
- **Navigation:** per-chunk `NavigationRegion3D`; cross-chunk approach decided in F-063. Town and shop each have their own navmesh.
- **Typing:** static typing everywhere. Use `class_name` for components and resources.
- **Naming:** files `snake_case.gd`, classes `PascalCase`, signals `past_tense_snake`, constants `UPPER_SNAKE`.
- **Determinism for tests:** all random calls go through the `RNG` helper with a seedable `RandomNumberGenerator`.

### 3.4 Testing
- Use **GUT** in `res://tests/`. Pure-logic features (stats, XP, loot, damage, haggle, customer draw, ledger, injury, wipe resolution, save) **must** have unit tests.
- Scene features get a **smoke test scene** `res://tests/scenes/<feature>_smoke.tscn` runnable headless, plus a manual test doc if visual.
- CI-style command: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.

### 3.5 Performance Budgets (guidelines)
- Dungeon: 60 FPS on a mid-range GPU with 6 party + 40 active monsters.
- Shop: 60 FPS with 12 customers inside.
- Chunk load must not hitch: `ResourceLoader.load_threaded_request`, instantiate over multiple frames.
- Pool projectiles, damage numbers, VFX.

### 3.6 Placeholder Art Policy
Capsule meshes for characters (color-coded by class), boxes for buildings and furniture, CSG for early dungeon geometry, free CC0 packs (Kenney, Quaternius) when needed. Every asset reference goes through a data resource so art can be swapped later with no code changes.

---

## 4. Milestones Overview

| Milestone | Goal | Features |
|---|---|---|
| **M0** | Project skeleton | F-000 – F-005 |
| **M1** | Move, camera, tactical pause in a test arena | F-010 – F-017 |
| **M2** | Combat core | F-020 – F-029 |
| **M3** | Classes, XP, abilities | F-030 – F-039 |
| **M4** | Items & inventory | F-040 – F-049 |
| **M5** | Party & AI | F-050 – F-058 |
| **M6** | Seamless multi-level dungeon | F-060 – F-068 |
| **M7** | Extraction loop | F-070 – F-076 |
| **M8** | Town, guild, calendar, economy | F-080 – F-089 |
| **M9** | Shop sim | F-090 – F-099 |
| **M10** | Market & trends; ability/AI depth | F-100 – F-104 |
| **M11** | Content & polish | F-110+ |
| **M12 (stretch)** | Multiplayer, mod tools | F-200+ |

> **Vertical slice = M0–M9:** one full loop covering 2 dungeon levels, 2 extraction points, a run, a shop day, and one weekly settlement. Don't start M10+ until the slice is playable end-to-end.

*(Feature IDs are numbered with gaps on purpose so new features can be inserted.)*

---

## 5. Feature Spec Template

```
### F-XXX Name
Depends on: F-..., F-...
Scope:      what to build (and explicitly what NOT to)
Files:      expected new/changed files
Data:       resources/data introduced
Acceptance: verifiable checklist
Notes:      pitfalls, tuning hints
```

---

## 6. Feature Specifications

### MILESTONE M0 — Skeleton

### F-000 Project Setup
Depends on: —
Scope: Create Godot 4.3+ project, folder layout (3.1), `.gitignore` for `.godot/`, install **GUT**, set rendering to Forward+, create `Main.tscn` that loads a blank 3D scene. Configure collision layer names (3.3).
Files: `project.godot`, `.gitignore`, `scenes/main.tscn`, `addons/gut/`, folder structure with `.gdkeep`.
Acceptance:
- [ ] Project opens with no errors; running shows an empty 3D scene.
- [ ] GUT command (3.4) runs and passes a trivial test.
- [ ] Collision layer names set.

### F-001 Input Map & Settings Stub
Depends on: F-000
Scope: Define all input actions from 2.1 (dungeon + town/shop). `Settings` resource (camera speeds, edge scroll, UI scale) persisted to `user://settings.cfg`.
Acceptance:
- [ ] All actions exist (`move_click`, `select_all`, `tactical_pause`, `ability_1`…`ability_6`, `potion_health`, `build_mode`, `haggle_up`, ...).
- [ ] Settings load/save round-trip test passes.

### F-002 Autoload Scaffolding
Depends on: F-000
Scope: Create empty-but-wired autoloads (3.2) with documented public API stubs. `Game` implements its state machine and the `time_scale` helper.
Acceptance:
- [ ] All autoloads load without error.
- [ ] `Game.set_state()` emits `EventBus.game_state_changed`.

### F-003 Debug Console & Overlay
Depends on: F-002
Scope: Toggle with `` ` ``. Command registry; features register their own commands (e.g. `give_item`, `spawn`, `tp`, `god`, `xp`, `gold`, `kill_all`, `day`, `wipe`, `extract`, `rep`). Overlay: FPS, loaded chunks, active actors, day/phase.
Acceptance:
- [ ] Console opens/closes, parses commands with args, errors on unknown commands.
- [ ] `DebugConsole.register(name, callable, help)` works from other features.

### F-004 RNG & Utility Library
Depends on: F-000
Scope: `RNG` helper (seedable, `weighted_pick`, `roll_range`, `chance`), `MathUtil`, `NodeUtil`.
Acceptance:
- [ ] Unit tests: same seed → same sequence; weighted pick distribution sane.

### F-005 Event Bus Contract
Depends on: F-002
Scope: Declare and document canonical signals:
- Combat & party: `actor_died(actor, killer)`, `item_picked_up(actor, item)`, `member_leveled(actor, level)`, `party_wiped()`, `party_changed()`, `selection_changed()`, `tactical_pause_toggled(paused)`
- Dungeon & runs: `chunk_loaded(id)`, `chunk_unloaded(id)`, `run_started(start_point_id)`, `run_ended(result)`, `extraction_point_discovered(id)`
- Calendar & economy: `day_started(day)`, `phase_changed(phase)`, `weekly_settlement(day)`, `gold_changed(amount)`, `debt_paid(amount, remaining)`
- Shop: `item_sold(item, price, npc_type)`, `item_bought(item, price, npc_type)`, `customer_walked_out(npc_type)`, `merchant_leveled(level)`, `reputation_changed(npc_type, value)`
Acceptance:
- [ ] Signals declared & documented; a test emits/receives each.

---

### MILESTONE M1 — Move, Camera & Pause

### F-010 Test Arena
Depends on: F-000
Scope: Flat navmesh-baked arena with obstacles. Lighting + simple sky. No streaming.
Files: `dungeon/test/test_arena.tscn`
Acceptance:
- [ ] Navmesh bakes; obstacles block pathing.

### F-011 Party Member Actor (Placeholder)
Depends on: F-010, F-002
Scope: `PartyMember` scene: `CharacterBody3D`, capsule mesh, `NavigationAgent3D`, selection ring, name label. States Idle/Move. No combat.
Files: `actors/party_member/party_member.tscn/.gd`
Acceptance:
- [ ] `move_to(Vector3)` navigates around obstacles and stops within 0.3 m.
- [ ] Move speed is data-driven.

### F-012 RTS Camera
Depends on: F-010
Scope: Fixed-pitch (~50°) orbit camera: rotate, zoom (clamped), smooth follow, edge pan when unfollowed, `V` toggles follow, camera-relative WASD pan. Reused in town and shop with different limits.
Acceptance:
- [ ] All inputs work; F-001 settings control speeds.
- [ ] No jitter while following a moving target.

### F-013 Mouse Picking
Depends on: F-011, F-012
Scope: `Picker` service: raycast returns `{kind: ground|actor|pickup|interactable, node, position}`. Hover highlight.
Acceptance:
- [ ] Hover & click return correct kinds in test arena.
- [ ] UI-covered clicks are ignored.

### F-014 Selection System
Depends on: F-011, F-013, F-005
Scope: Click select, Shift multi-select, `Ctrl+A`, box-select, `F1`–`F6`; selection ring; `selection_changed`.
Acceptance:
- [ ] All selection modes work with 3 test members.

### F-015 Click-to-Move Commands
Depends on: F-014
Scope: Click ground moves selected members (simple offset ring; formations come in F-051). Click marker VFX. New command replaces old.
Acceptance:
- [ ] Multiple members move without bad overlap (local avoidance on).
- [ ] Click marker appears.

### F-016 Basic HUD Shell
Depends on: F-014
Scope: Bottom HUD with up to 6 portrait slots, health/mana bars bound to components (stubbed), minimap placeholder, run-gold counter, ability bar placeholder. Scales with UI scale.
Acceptance:
- [ ] Portraits reflect party & selection; bars update on component change.

### F-017 Tactical Pause
Depends on: F-015, F-002
Scope: `Space` toggles pause in dungeon state only. While paused: simulation frozen (physics, AI, timers, projectiles, cooldowns), camera and UI still work, and selection/move/attack/ability commands are **queued** as each actor's current command and execute on resume. Visible "PAUSED" indicator. Pause is unavailable in town/shop.
Acceptance:
- [ ] Pausing freezes all actors and projectiles; camera still moves.
- [ ] Commands issued while paused execute on unpause.
- [ ] `tactical_pause_toggled` emitted; pause key ignored outside `RUN` state.
Notes: Prefer a `pausable` group + `process_mode` over `get_tree().paused` alone, so UI and camera keep processing.

---

### MILESTONE M2 — Combat Core

### F-020 Health, Mana, Stats Components
Depends on: F-011, F-005
Scope: `HealthComponent` (max, current, regen, `damaged`/`healed`/`died`), `ManaComponent`, `StatsComponent` (STR/DEX/INT base + modifier stack; derived values via `ProgressionData` formulas).
Data: `ProgressionData` (formulas/curves).
Acceptance:
- [ ] Unit tests: modifiers add/remove; derived values recompute; death emits once.

### F-021 Combat Component — Melee
Depends on: F-020, F-015
Scope: Attack command: path to range, face, attack on timer; hit-frame damage; hit/dodge/crit & formula (2.4). Pooled floating damage numbers.
Acceptance:
- [ ] Member kills a dummy by clicking it.
- [ ] Damage matches formula with seeded RNG.
- [ ] Attack cancels cleanly when target dies/leaves leash.

### F-022 Monster Actor & Data
Depends on: F-020
Scope: `MonsterData` (7.3). `Monster` scene built from data. 3 placeholder monsters.
Acceptance:
- [ ] Monsters instantiated purely from `.tres`.
- [ ] `spawn <id>` works.

### F-023 Monster AI (Basic)
Depends on: F-022, F-021
Scope: Idle/Chase/Attack/Return; `AggroComponent`; leash to spawn; nearest target (threat later).
Acceptance:
- [ ] Monsters notice, chase, attack, drop aggro past leash, regen at home.

### F-024 Death & Corpses
Depends on: F-021, F-023
Scope: Death state, collision off, monster corpse fades after N s. Party member death: grey portrait, can't act, **body persists** (revivable). `actor_died` emitted.
Acceptance:
- [ ] Dead monsters stop and fade; dead party members flagged and stay revivable.

### F-025 Ranged Combat & Projectiles
Depends on: F-021
Scope: Pooled `Projectile` with `ProjectileData` (speed/gravity/pierce/homing). Ranged attack with min/max range.
Acceptance:
- [ ] Archer kills monsters at range; no friendly fire (configurable).

### F-026 Hit Feedback
Depends on: F-021
Scope: Hit flash, stagger, SFX hooks, colored damage numbers, monster health bars (toggle).
Acceptance:
- [ ] All feedback toggles via Settings.

### F-027 Threat / Target Selection
Depends on: F-023
Scope: Threat table (damage + proximity), decay; taunt hook.
Acceptance:
- [ ] Unit-tested: highest threat chosen; decays over time.

### F-028 Wipe Detection
Depends on: F-024
Scope: `Party` detects all deployed non-mule members dead → emits `party_wiped` once. In the test arena, a placeholder handler shows "Party wiped" and resets the arena (real handling in F-073).
Acceptance:
- [ ] Killing all members emits `party_wiped` exactly once; mules alone alive still counts as a wipe.

### F-029 Combat Tuning Pass
Depends on: F-021..F-028
Scope: `docs/balance.md` with TTK targets (~5–10 s normal mobs).
Acceptance:
- [ ] Doc exists; tuning values live in data.

---

### MILESTONE M3 — Classes, XP, Abilities

### F-030 ClassData & LevelComponent
Depends on: F-020
Scope: `ClassData` (7.2) and `LevelComponent` (level, XP, `gain_xp(amount)`, multi-level gains, emits `member_leveled`, applies class stat growth). XP curve from `ProgressionData`. `RecruitInstance` holds class, level, XP, stat variance, traits. 5 placeholder classes.
Data: `data/classes/*.tres`, `data/traits/*.tres`.
Acceptance:
- [ ] Unit tests: thresholds, multi-level gain, per-class growth, trait modifiers applied.

### F-031 Shared Kill XP
Depends on: F-030, F-024
Scope: On monster `actor_died`, award `xp_value × level_factor` to every deployed non-mule member (alive or dead). Supports `xp_share_mode` full/split.
Acceptance:
- [ ] Every deployed member gains XP from a kill regardless of who landed it; mules gain none; dead members gain XP.
- [ ] Level factor reduces XP from much-lower-level monsters (unit test).

### F-032 Derived Stat Pipeline
Depends on: F-020, F-030
Scope: `StatsComponent.recalculate()` merges class base + level growth + traits + equipment + status effects → derived stats. Event-driven only.
Acceptance:
- [ ] Tests: stacking order (base → flat → percent → multiplicative) verified.

### F-033 Character Sheet UI
Depends on: F-030, F-016
Scope: `C` opens panel: name, class, level/XP bar, STR/DEX/INT, HP/mana, armor, damage, dodge, traits, salary, unlocked/locked abilities. Per-character tabs.
Acceptance:
- [ ] Values update live; match component data.

### F-034 Regen & Potions (Basic)
Depends on: F-020
Scope: Passive regen scaling with STR/INT; potion effect (instant heal/mana, shared cooldown per category). `Z`/`X` hotkeys.
Acceptance:
- [ ] Potion obeys cooldown; HUD shows cooldown.

### F-035 Level Scaling for Monsters
Depends on: F-022
Scope: Monster stats derive from level via curves; ±variance. Level comes from the chunk `area_level` (wired in F-065).
Acceptance:
- [ ] Test: level N monster stats match curve.

### F-036 Revive
Depends on: F-024, F-034
Scope: Revive consumable restores a dead member to 50% HP (usable in combat). `RunManager` hook stub: `revive_all_on_extract()`. Debug `revive`.
Acceptance:
- [ ] Reviving works in and out of combat; HUD updates.

### F-037 Ability Core
Depends on: F-020, F-030, F-017
Scope: `AbilityData` (7.4) and `AbilityCasterComponent`: cast state, interruption, mana, cooldown, target validation. Abilities granted by `ClassData` unlock table on level-up. Player-triggered only (auto-cast comes in F-055).
Acceptance:
- [ ] Tests: mana spend, cooldown, interrupt, unlock at correct level.
- [ ] Ability ordered while tactically paused casts on resume.

### F-038 Ability Effects & Status Effects
Depends on: F-037, F-025, F-032
Scope: Composable `AbilityEffect` resources: DirectDamage, Projectile, AreaDamage, Heal, Revive, Buff/Debuff, DoT, Taunt, Summon (stub). `StatusEffectComponent` with stacking/refresh/expiry rules, feeding F-032.
Acceptance:
- [ ] 8 sample abilities purely via `.tres` (e.g. cleave, taunt, volley, fire bolt, frost nova, heal, bless, smoke bomb).
- [ ] Status effect stacking/refresh/expiry tests pass.

### F-039 Ability Bar & Targeting UI
Depends on: F-037, F-016
Scope: HUD ability bar for the selected character (`1`–`6`), cooldown sweep, mana-insufficient tint; targeting cursors (ground/enemy/ally) with range indicator; `K` abilities list with locked abilities and their unlock levels.
Acceptance:
- [ ] Abilities castable via hotkey and click-target flow, including while paused.

---

### MILESTONE M4 — Items & Inventory

### F-040 ItemData & ItemInstance
Depends on: F-004
Scope: `ItemData` (7.1), including `category`, `shop_tags`, `allowed_classes`. `ItemInstance` (data ref, affixes, rolled values, stack, uid, `found_this_run`, `cost_basis`). JSON-serializable.
Acceptance:
- [ ] 14 sample items (3 weapons, 3 armor, 2 jewelry, potions, 2 materials, 2 curios, 1 key).
- [ ] Serialize/deserialize round-trip test.

### F-041 Inventory Component & Grid
Depends on: F-040
Scope: `InventoryComponent` W×H grid; `can_place`, `place`, `remove`, `find_space`, auto-stack, `remove_where(predicate)`. Emits `changed`.
Acceptance:
- [ ] Unit tests: collisions, stacking, full inventory, `remove_where`, serialization.

### F-042 Inventory UI (Drag & Drop)
Depends on: F-041, F-016
Scope: Grid UI per character; drag/drop between party members; right-click equip/use; tooltips (stats, requirements, **value**); drop to ground. Reusable for mule cargo and shop storage.
Acceptance:
- [ ] Items move, stack, drop; tooltip shows requirements (red if unmet) and value.

### F-043 Equipment Component
Depends on: F-040, F-032
Scope: Slots (2.8); equip validates level/stat/class reqs; updates stats; placeholder attachments; 2H blocks offhand.
Acceptance:
- [ ] Equipping changes damage and visuals; failed reqs give feedback.

### F-044 Ground Items & Pickup
Depends on: F-040, F-013
Scope: `GroundItem` with rarity-colored label; `Alt` shows labels; click to pick up; gold auto-pickup into `RunManager.run_gold` (stub var until F-070). Picked-up items are flagged `found_this_run` when a run is active.
Acceptance:
- [ ] Pickup lands in inventory with the flag set; full inventory shows message.

### F-045 Affix System & Item Generation
Depends on: F-040, F-004
Scope: `AffixData`; `ItemFactory.generate(item_id, ilvl, rarity?)`; name composition; **value derivation** (2.8). Rarity thresholds by ilvl.
Acceptance:
- [ ] Tests: seeded determinism; affix constraints; no duplicate groups; value formula.

### F-046 Loot Tables & Drops
Depends on: F-045, F-022, F-044
Scope: `LootTable` (weighted entries, gold range, rarity bias, nested tables). `LootDropperComponent`.
Acceptance:
- [ ] Monsters drop per table; 10k-roll distribution test within tolerance.

### F-047 Containers
Depends on: F-046
Scope: Breakable barrels/crates and chests that roll loot tables; opened state is **run-scoped** (resets next run).
Acceptance:
- [ ] Opens once per run; drops spawn nearby.

### F-048 Consumables Framework
Depends on: F-034, F-040
Scope: `UseEffect` resources (heal, mana, revive, buff). Data-driven. (Injuries are healed only in town, F-087.)
Acceptance:
- [ ] New consumable added purely via `.tres`.

### F-049 Comparison Tooltips
Depends on: F-042, F-043
Scope: Tooltip compares with equipped; upgrade/downgrade highlights; shows value and shop tags.
Acceptance:
- [ ] Verified against 5 sample items.

---

### MILESTONE M5 — Party & AI

### F-050 Party API
Depends on: F-014, F-043
Scope: `Party.deploy(members)`, `set_leader`, max 6 including mules; HUD portraits scale to party. Test arena stub spawns a configured party (real assembly in F-086).
Acceptance:
- [ ] Deploying 6 works; a 7th is rejected with a message.

### F-051 Formations
Depends on: F-050, F-015
Scope: `FormationData` (≤6 slots); `FormationFollowerComponent`; `F` cycles; rotates with leader; melee front, ranged back, mules rear.
Acceptance:
- [ ] 6 members follow in each formation; corridors degrade to column without jams.

### F-052 AI Stances
Depends on: F-051, F-023
Scope: Per-character stance (2.6) via HUD/`T`; `AIControllerComponent` runs when not manually commanded.
Acceptance:
- [ ] Hold doesn't chase; Aggressive chases to leash; Balanced verified.

### F-053 Manual Override Rules
Depends on: F-052
Scope: Explicit commands (incl. abilities) override AI until done/cancelled; AI resumes. Priority order documented.
Acceptance:
- [ ] Move interrupts auto-attack; after arrival AI re-engages.

### F-054 Pack Mule
Depends on: F-050, F-041
Scope: Non-combat member: large inventory, slower, flees enemies, no XP, can die (cargo stays on its body and is lootable by party; on extraction it returns with the party; on wipe, see F-073).
Acceptance:
- [ ] Mule inventory accessible; follows at rear; flees when attacked.

### F-055 Auto-Behaviors
Depends on: F-052, F-034, F-037
Scope: Per-character toggles: auto-potion at X% HP/mana; per-ability auto-cast with simple conditions (heal ally < X%, buff out of combat, AoE when ≥N enemies); mana reserve.
Acceptance:
- [ ] Potions auto-used below threshold with cooldown respected.
- [ ] Auto-cast heal triggers on a wounded ally only when toggled on.

### F-056 Party-Wide Loot Rules
Depends on: F-044, F-050
Scope: Pickup routing setting: nearest / leader / best-fit / mule-first.
Acceptance:
- [ ] Setting changes routing as expected.

### F-057 Party Panel Polish
Depends on: F-050, F-016
Scope: Per-portrait stance icon, status effects, dead overlay, drag-reorder, right-click (set leader, inspect).
Acceptance:
- [ ] Interactions work with a full 6-member party.

### F-058 Pathing Crowd Quality Pass
Depends on: F-051
Scope: Avoidance tuning, stuck detection & recovery, choke behavior.
Acceptance:
- [ ] 5 members + mule traverse a 1.5 m corridor with no permanent stuck.

---

### MILESTONE M6 — The Hollow Deep (Seamless Multi-Level Dungeon)

### F-060 Chunk Format & Sockets
Depends on: F-010
Scope: `ChunkData` (7.6): id, scene, bounds, sockets, `level_index`, `area_level`, ambience. `SocketData` = name, local transform, type (corridor/door/stair_up/stair_down/shaft), tags. Authoring guide `docs/chunk_authoring.md`.
Acceptance:
- [ ] 3 sample chunks (room, corridor, stairwell) with sockets; validator reports mismatched sockets.

### F-061 Dungeon Graph
Depends on: F-060
Scope: `DungeonGraph` resource: nodes + edges (socket ↔ socket). Editor script bakes world transforms. Supports **loops** and **vertical stacking** across levels with overlap/bounds checks.
Acceptance:
- [ ] Graph of ≥10 chunks spanning 2 levels resolves without overlap (validator warns on overlap).

### F-062 WorldStreamer (Threaded)
Depends on: F-061, F-005
Scope: Track leader; keep chunks within load radius (graph + metric distance, including vertical neighbors); threaded load; ≤1 instantiation per frame; unload beyond unload radius (hysteresis). Emits `chunk_loaded/unloaded`. `teleport_to(start_point)` preloads target area before placing the party.
Acceptance:
- [ ] Walking the test graph (including a level change) shows no >16 ms instantiation spikes; no visible pops.

### F-063 Navigation Across Chunks
Depends on: F-062, F-011
Scope: Implement and log approach (preferred: edge-matched per-chunk navmeshes merged by the nav server; fallback `NavigationLink3D`). Paths across stairs between levels.
Acceptance:
- [ ] Party crosses 4 chunks and one level change via a single click; no border stalls.

### F-064 Run-Scoped Chunk State
Depends on: F-062, F-046, F-047
Scope: `ChunkState` per chunk for the **current run** (killed spawns, opened containers, dropped items, door states), kept across unload/reload within a run and **cleared at run start**. Separate persistent store for cross-run data (explored mask, boss first-kill, discovered extraction points).
Acceptance:
- [ ] Within a run: kill monsters, leave, return → still dead; dropped items persist.
- [ ] New run: monsters and containers reset; explored map remains.

### F-065 Spawn System
Depends on: F-062, F-022, F-035
Scope: `SpawnPoint` nodes reference `SpawnGroup` data; monster level from chunk `area_level` ± variance; spawn on chunk load unless killed this run.
Acceptance:
- [ ] Re-entry respects run state; deeper chunks spawn higher-level monsters.

### F-066 Dungeon Map & Fog of War
Depends on: F-062
Scope: Minimap + `M` full map with **per-level tabs**; fog of war revealed by exploration and **persisted across runs**; party blips; extraction point icons (discovered only); current level indicator.
Acceptance:
- [ ] Explored areas persist across runs; switching level tabs works.

### F-067 Level Transitions & Ambience
Depends on: F-063, F-062
Scope: Stairs/ramps/shafts as chunk types; per-level lighting environment and ambience blend as the leader crosses `level_index`; HUD shows level name/depth.
Acceptance:
- [ ] Walking down stairs changes lighting/ambience smoothly with no loading screen.

### F-068 Bosses & First-Kill Bonus
Depends on: F-065, F-064
Scope: Boss spawn flag on `SpawnGroup`; boss respawns every run; `first_kill_reward` (item/gold/flag) granted once, recorded in the persistent store. Basic boss arena trigger (lock exits until boss dies or party wipes).
Acceptance:
- [ ] First kill grants bonus; later kills give normal loot only; flag survives save/load.

---

### MILESTONE M7 — Extraction Loop

### F-070 RunManager & Run Lifecycle
Depends on: F-050, F-062, F-028
Scope: `RunManager` states `PREP → ACTIVE → EXTRACTED | WIPED | ABANDONED → SUMMARY`. Owns `run_gold`, start point, run stats (kills, XP, loot value). Clears run-scoped chunk state at start. Emits `run_started/run_ended`. Debug `extract`, `wipe`.
Acceptance:
- [ ] State transitions unit-tested; invalid transitions rejected.

### F-071 Extraction Points
Depends on: F-070, F-013
Scope: `ExtractionPoint` interactable with `ExtractionPointData` (id, display name, chunk, radius). Discovery on proximity → `extraction_point_discovered` (persistent immediately). Leader interact starts a channel (`RunConfig.extract_channel_s`); cancels if a living member leaves the radius; success → `EXTRACTED`. Dungeon entrance is always discovered.
Acceptance:
- [ ] Discovering a point persists even if the party then wipes.
- [ ] Channel cancels when a member walks out; completes otherwise.

### F-072 Start Point Selection
Depends on: F-071, F-062
Scope: Run prep UI step (embedded in Dungeon Gate later, F-086): list discovered extraction points with level/depth; selecting one makes `WorldStreamer.teleport_to` place the party there.
Acceptance:
- [ ] Starting at a deep point spawns the party there with surrounding chunks loaded before control is given.

### F-073 Wipe & Extraction Resolution
Depends on: F-070, F-041, F-043, F-054, F-036
Scope: Pure resolver `RunResolver.resolve(result, party)`:
- **Extract:** clear `found_this_run` everywhere, bank `run_gold`, revive dead.
- **Wipe:** `remove_where(found_this_run)` on every deployed inventory and equipment slot (mule cargo included), discard `run_gold`, keep brought items, revive at town with injuries (F-074).
- **Abandoned:** same as wipe.
Acceptance:
- [ ] Unit test: brought gear (equipped or moved to inventory mid-run) survives a wipe; all found items and run gold vanish.
- [ ] Unit test: on extract, found items keep but lose the flag; gold credited.

### F-074 Injury System
Depends on: F-073, F-030
Scope: On wipe, each deployed member gets `injured_until_day = today + roll(injury_days_range)` (seeded). Injured members can't be deployed. Roster UI shows remaining days (stub until F-085).
Acceptance:
- [ ] Seeded test: injury rolls within 1–4; members become available on the right day.

### F-075 Shop Storage & Run Summary
Depends on: F-073, F-042
Scope: `ShopManager.storage` large grid. Run summary screen: result, XP gained, levels, items found with total value, gold banked, injuries; "Unload all to storage" button (auto-arrange, overflow stays on members).
Acceptance:
- [ ] Summary correct for extract and wipe; unload moves items to storage.

### F-076 Save/Load (Town-Only)
Depends on: F-073, F-064, F-030
Scope: `SaveManager` per 2.15 / 7.9. Autosave at day start and after run resolution; manual save only in town; slots ≥3. A `run_in_progress` marker written at run start: if present on load → resolve as abandoned (wipe) before entering town. Version migration hook.
Acceptance:
- [ ] Save, quit, reload restores identical state (serialized dict comparison).
- [ ] Killing the game mid-run then loading applies wipe resolution.
- [ ] Corrupt/old-version file fails gracefully.

---

### MILESTONE M8 — Town, Guild, Calendar, Economy

### F-080 Interactables & Dialog
Depends on: F-013
Scope: `Interactable` interface; dialog UI with portrait and branching choices from `DialogData` (conditions on flags).
Acceptance:
- [ ] Talk to NPC; branches respect flags.

### F-081 Town Scene & Shopkeeper
Depends on: F-012, F-013, F-011
Scope: Walkable `town.tscn` (placeholder blocks) with navmesh; `Shopkeeper` actor (click-to-move, no combat); location doors (Shop, Guild Hall, Market, Healer, Bank, Dungeon Gate) as interactables that open their location UI/scene. Ambient town NPCs (non-interactive) optional.
Acceptance:
- [ ] Shopkeeper walks to each door and opens its location.

### F-082 Calendar & Phases
Depends on: F-002, F-005
Scope: `Calendar` (day, phase, day type). Rules from 2.2: Dungeon Gate usable only in Morning of an unspent day; leaving a location advances phase; Open Shop consumes a phase; end-day-early. HUD calendar widget + `L` ledger view.
Data: `EconomyData.phases_per_day`, `shop_phase_seconds`.
Acceptance:
- [ ] Unit tests: phase advancement rules; run day consumes the full day; day 7 triggers `weekly_settlement`.

### F-083 Economy Ledger: Debt & Salaries
Depends on: F-082, F-030
Scope: Pure ledger logic: debt schedule from `EconomyData`, weekly settlement (debt first, then salaries in roster order), unpaid members leave (gear → storage), early payments at Bank. Ledger UI lists upcoming payment and total weekly salaries.
Acceptance:
- [ ] Unit tests: settlement order; partial salary payment removes the right members; early payment reduces next due.

### F-084 Debt Deadline Outcomes
Depends on: F-083
Scope: Missing a debt payment → `GAME_OVER` bad-ending screen (load last save / quit). Paying the full schedule → good ending screen, then free play.
Acceptance:
- [ ] Both outcomes reachable via debug `gold` / `day` commands.

### F-085 Guild Hall: Roster & Recruitment
Depends on: F-081, F-030, F-074
Scope: Roster UI (class, level, salary, injury days, traits, gear). Recruitment pool of N candidates rerolled weekly (`RecruitInstance` generation: class, name, level near roster average, variance, traits, hire fee). Hire (fee + adds to roster if under cap), dismiss. Guild hall upgrade raises roster cap. Hire mules here.
Acceptance:
- [ ] Hiring/dismissing updates roster and weekly salary total; cap enforced; pool rerolls weekly.

### F-086 Dungeon Gate: Party Assembly
Depends on: F-085, F-072, F-050
Scope: Gate UI: pick up to 6 non-injured roster members (mules included), set leader & formation, manage gear/consumables from shop storage, pick start point (F-072), Start Run → `RunManager.PREP→ACTIVE`, scene switch to the dungeon.
Acceptance:
- [ ] Injured members can't be selected; 7th rejected; run starts at chosen point with chosen party and gear.

### F-087 Healer
Depends on: F-081, F-074, F-083
Scope: Shorten injury by N days for gold (price scales with member level); sells potions/revives at fixed prices.
Acceptance:
- [ ] Paying reduces injury days and gold correctly.

### F-088 Main Menu, Pause, Options
Depends on: F-076, F-001
Scope: Menu flow, new game (shop name stub), options (graphics, audio, controls rebind, gameplay toggles), `Esc` menu (save only in town).
Acceptance:
- [ ] Start, save (town), load, quit from UI; save disabled in dungeon.

### F-089 Notifications & Tutorial Hints
Depends on: F-088
Scope: Notification log ("Inventory full", "Level up!", "Extraction point discovered", "Debt due in 2 days"); one-time contextual hints tracked in save.
Acceptance:
- [ ] Hints display once and persist in save.

---

### MILESTONE M9 — Shop Sim

### F-090 Shop Scene & Build Grid
Depends on: F-081, F-075
Scope: `shop.tscn` interior with counter, entrance, navmesh, and a `BuildGrid` (cell size, bounds expandable by merchant level). Shopkeeper stands at counter when open. Storage accessible in shop.
Acceptance:
- [ ] Grid renders in build mode; bounds read from current merchant level.

### F-091 Display Stands & Stocking
Depends on: F-090, F-042
Scope: Display stands are `DecorData` with `display_slots`. Placing a stand on the grid (build mode, closed only); dragging items from storage onto stands; display cap by merchant level. Items on display show their 3D model/icon.
Acceptance:
- [ ] Items move storage ↔ stand; cap enforced; stand can't be removed while stocked.

### F-092 Customer Actor & Browsing AI
Depends on: F-090, F-080
Scope: `Customer` actor built from `NpcTypeData` + rolled budget/threshold/patience. States `Enter → Browse → Approach → Haggle → Leave`. Buy intent: browse stands weighted by tag affinity, pick an item within interest; Request/Sell intents stubbed. Open Shop phase timer; arrivals stop at end; remaining customers finish.
Acceptance:
- [ ] Customers enter, browse, pick an item, approach the counter, and leave; phase ends correctly.

### F-093 Haggle Model (Pure Logic)
Depends on: F-045, F-004
Scope: `core/economy/haggle.gd` per 2.12: `create_session(item, npc, mode, trend_mult, rep_tier)`, `offer(pct) -> {accept|counter(pct)|walkout}`. Threshold, budget, patience, walkout margin. Reverse mode for buying.
Data: haggle ranges on `NpcTypeData`.
Acceptance:
- [ ] Unit tests: offers ≤ threshold accept; within margin counter and decrement patience; beyond margin or patience 0 walk out; budget cap respected; reverse mode mirrors; trend/rep modifiers shift thresholds.
- [ ] Seeded determinism.

### F-094 Haggle UI (Selling)
Depends on: F-093, F-092
Scope: Counter UI: item card (value, tags), NPC portrait/type + mood text by patience, % offer control (2.1 inputs) with live gold amount, Offer/Refuse. Result → `Economy` gold, item removed, `item_sold`, cost-basis profit computed.
Acceptance:
- [ ] Full sale flow works; refusing/walkout returns item to its stand.

### F-095 Seller & Request Customers
Depends on: F-094
Scope: **Sell intent:** NPC brings an item rolled from its type's loot table → reverse haggle → item to storage with `cost_basis`. **Request intent:** NPC names a category/tag; player picks a matching item from storage or display (or declines) → sell haggle.
Acceptance:
- [ ] Buying from an NPC puts item in storage with correct cost basis.
- [ ] Request rejects non-matching items.

### F-096 Decor Placement
Depends on: F-090
Scope: Build mode (`B`, shop closed): place/rotate/move/sell-back decor on grid with collision checks; decor bought at Market enters a decor inventory. `DecorData` tags/appeal summed into `ShopManager.shop_profile` (decor tag totals, item tag totals, appeal).
Acceptance:
- [ ] Placement blocked on overlap/out-of-bounds; profile updates on change.

### F-097 Customer Draw
Depends on: F-096, F-092, F-091
Scope: `core/economy/customer_draw.gd`: visitors-per-phase from appeal; tag-weighted type selection (2.13) with merchant-level gating and rep multipliers; spawns spread over the phase.
Acceptance:
- [ ] Distribution test: a shop with only `martial` items + decor draws Adventurer types above a tolerance; increasing appeal increases visitor count.

### F-098 Merchant Level
Depends on: F-094, F-095
Scope: Merchant XP from gross profit; level curve in `EconomyData`; unlock table (grid expansions, display cap, decor types, NPC types). Level-up notification + `merchant_leveled`.
Acceptance:
- [ ] Unit tests: XP from profit (zero-cost loot vs bought items); unlocks applied at correct levels.

### F-099 Reputation per NPC Type
Depends on: F-094, F-097
Scope: Rep 0–100 per type; gains on sales scaled by price fairness, small loss on walkout; tiers modify spawn weight, budget range, and threshold leniency; shown in ledger.
Acceptance:
- [ ] Unit tests for gain/loss formula and tier effects on draw and haggle.

---

### MILESTONE M10 — Market & Trends; Ability/AI Depth

### F-100 Wholesale Market
Depends on: F-081, F-082, F-075
Scope: Market location UI: daily stock from `MarketData` (items + decor), markup 70–100% of value, buy into storage with `cost_basis`. Decor shop tab.
Acceptance:
- [ ] Stock rerolls daily; purchases set cost basis; leaving advances phase.

### F-101 Market Trends & Events
Depends on: F-100, F-093
Scope: `MarketTrendData` (category/tag, multiplier, duration, weight); daily roll; rumor shown one day ahead on market board; active trends feed haggle `trend_mult` and market prices.
Acceptance:
- [ ] A "weapons ×1.5" trend raises customer thresholds for weapons only, for its duration.

### F-102 Price Insight
Depends on: F-101, F-099
Scope: Item tooltips in shop show last sale %, active trend arrow, and per-type "typical accept range" hint once reputation tier ≥ 2.
Acceptance:
- [ ] Hints appear only when unlocked and reflect real data.

### F-103 Class & Ability Roster v1
Depends on: F-038
Scope: 5 classes × ≥5 abilities each with unlock levels; balance pass in `docs/balance.md`.
Acceptance:
- [ ] All abilities data-only; each class playable to level 20 in test.

### F-104 Caster/Support AI
Depends on: F-055, F-103
Scope: Smarter auto-cast priorities (heal triage, buff upkeep, AoE when clustered, keep distance for ranged/casters).
Acceptance:
- [ ] A Cleric with auto-cast on keeps a tank alive in the test fight; a Mage AoEs ≥3 clustered enemies.

---

### MILESTONE M11 — Content & Polish (open-ended)

| ID | Feature | Depends |
|---|---|---|
| F-110 | Hollow Deep v1: 3 levels, ≥30 chunks, ≥5 extraction points, 1 boss per level | M6, M7 |
| F-111 | Monster roster v1 (12 types, 3 elites, 3 bosses with phases) | F-022, F-068 |
| F-112 | Item set v1 (≥80 bases incl. materials/curios, ≥60 affixes, 10 uniques) | F-045 |
| F-113 | Boss framework (phases, adds, enrage) | F-068 |
| F-114 | NPC type roster v1 (≥8 types with variants) | F-097, F-099 |
| F-115 | Decor set v1 (≥30 pieces across ≥6 tags) | F-096 |
| F-116 | Town requests board (light quests: fetch X from level N, deliver to NPC) | F-080, F-070 |
| F-117 | Animation set (adventurers, monsters, customers, shopkeeper) | F-011 |
| F-118 | VFX pass | F-038 |
| F-119 | Audio pass (buses, music states: town/shop/dungeon/combat/boss, ambience per level) | F-088 |
| F-120 | Performance pass (budgets in 3.5) | F-062, F-097 |
| F-121 | Accessibility (colorblind rarity cues, UI scale, text size, rebinding) | F-088 |
| F-122 | Localization scaffolding | F-088 |
| F-123 | Difficulty modes (debt schedule & monster scaling presets) | F-083, F-035 |
| F-124 | Story beats & endings (creditor, town characters, intro/outro) | F-084 |
| F-125 | Visual equipment (real meshes per slot) | F-043 |

### MILESTONE M12 — Stretch
| ID | Feature |
|---|---|
| F-200 | Co-op multiplayer (dungeon runs) |
| F-201 | Chunk/dungeon editor tooling plugin |
| F-202 | Mod support (`.pck`/data overrides) |
| F-203 | Steam integration |

---

## 7. Data Schemas (reference)

### 7.1 ItemData (`core/resources/item_data.gd`)
```gdscript
class_name ItemData extends Resource
@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var world_scene: PackedScene          # ground, equipped & display model
@export_enum("weapon_1h","weapon_2h","bow","staff","armor","shield","jewelry","consumable","scroll","material","curio","key") var item_type: String
@export_enum("weapon","armor","jewelry","consumable","material","curio","key") var category: String
@export_enum("none","head","chest","hands","feet","amulet","ring","main_hand","off_hand") var slot: String
@export var grid_size: Vector2i = Vector2i.ONE
@export var damage_min: float; @export var damage_max: float
@export var attack_speed: float = 1.0
@export var range: float = 1.5
@export var armor: float
@export var req_level: int
@export var req_str: int; @export var req_dex: int; @export var req_int: int
@export var allowed_classes: Array[StringName]  # empty = any
@export var base_value: int
@export var stackable: bool; @export var max_stack: int = 1
@export var use_effects: Array[UseEffect]
@export var tags: PackedStringArray            # affix filtering
@export var shop_tags: PackedStringArray       # martial, arcane, rustic, luxury, occult, practical...
@export var min_ilvl: int = 1
```

### 7.2 ClassData / TraitData
```gdscript
class_name ClassData extends Resource
@export var id: StringName; @export var display_name: String
@export var color: Color                        # placeholder capsule tint
@export var base_str: int; @export var base_dex: int; @export var base_int: int
@export var base_hp: float; @export var base_mana: float
@export var growth_str: float; @export var growth_dex: float; @export var growth_int: float  # per level
@export var growth_hp: float; @export var growth_mana: float
@export var proficiencies: PackedStringArray    # item_types usable
@export var ability_unlocks: Array[AbilityUnlock]  # {level, ability: AbilityData}
@export var base_salary: int; @export var salary_per_level: int
@export var hire_fee_base: int

class_name TraitData extends Resource
@export var id: StringName; @export var display_name: String
@export var mods: Array[StatMod]
@export var salary_mult: float = 1.0
@export var weight: int = 100
```

### 7.3 MonsterData
```gdscript
class_name MonsterData extends Resource
@export var id: StringName; @export var display_name: String
@export var scene: PackedScene
@export var level: int                          # overridden by area_level when spawned
@export var move_speed: float; @export var aggro_radius: float; @export var leash_radius: float
@export var attack_range: float; @export var attack_interval: float
@export var base_str: int; @export var base_dex: int; @export var base_int: int
@export var damage_min: float; @export var damage_max: float
@export var xp_value: int
@export var loot_table: LootTable
@export var is_boss: bool
@export var first_kill_reward: LootTable
@export var tags: PackedStringArray
@export var abilities: Array[AbilityData]
```

### 7.4 AbilityData
```gdscript
class_name AbilityData extends Resource
@export var id: StringName; @export var display_name: String
@export var mana_cost: float; @export var cast_time: float; @export var cooldown: float
@export var range: float
@export_enum("self","ally","enemy","ground","none") var target: String
@export var effects: Array[AbilityEffect]
@export var auto_cast_condition: AutoCastCondition   # used only when toggled on
@export var icon: Texture2D; @export var vfx: PackedScene; @export var sfx: AudioStream
```

### 7.5 NpcTypeData / DecorData
```gdscript
class_name NpcTypeData extends Resource
@export var id: StringName; @export var display_name: String
@export var scene: PackedScene
@export var base_weight: int = 100
@export var min_merchant_level: int = 1
@export var preferred_item_tags: Dictionary     # tag -> weight
@export var preferred_decor_tags: Dictionary    # tag -> weight
@export var budget_range: Vector2i
@export var patience_range: Vector2i            # haggle rounds
@export var sell_threshold_pct: Vector2         # max % of value they'll pay (buying from you)
@export var buy_threshold_pct: Vector2          # min % of value they'll accept (selling to you)
@export var walkout_margin_pct: float = 25.0
@export var intent_weights: Dictionary          # buy / sell / request -> weight
@export var sell_loot_table: LootTable          # items they bring to sell
@export var rep_tiers: Array[RepTier]           # {min_rep, weight_mult, budget_mult, leniency_pct}

class_name DecorData extends Resource
@export var id: StringName; @export var display_name: String
@export var scene: PackedScene
@export var grid_size: Vector2i
@export var tags: Dictionary                    # tag -> amount
@export var appeal: int
@export var cost: int
@export var display_slots: int = 0              # >0 = display stand
@export var min_merchant_level: int = 1
```

### 7.6 ChunkData / DungeonGraph / ExtractionPointData
```gdscript
class_name ChunkData extends Resource
@export var id: StringName
@export var scene: PackedScene
@export var sockets: Array[SocketData]          # {name, transform, type, tags}
@export var bounds: AABB
@export var level_index: int
@export var area_level: int
@export var ambience: AudioStream

class_name DungeonGraph extends Resource
@export var nodes: Array[DungeonNode]           # {chunk_id, resolved_transform}
@export var edges: Array[DungeonEdge]           # {a_node, a_socket, b_node, b_socket}

class_name ExtractionPointData extends Resource
@export var id: StringName; @export var display_name: String
@export var chunk_id: StringName
@export var local_position: Vector3
@export var radius: float = 4.0
@export var is_entrance: bool
```

### 7.7 EconomyData / RunConfig
```gdscript
class_name EconomyData extends Resource
@export var starting_gold: int
@export var debt_schedule: PackedInt32Array     # amount due at end of each week
@export var days_per_week: int = 7
@export var phases_per_day: int = 3
@export var shop_phase_seconds: float = 150.0
@export var mule_salary: int
@export var injury_days_range: Vector2i = Vector2i(1, 4)
@export var healer_cost_per_day_per_level: int
@export var merchant_xp_curve: Curve
@export var merchant_unlocks: Array[MerchantUnlock]  # {level, grid_size, display_cap, decor_ids, npc_type_ids}
@export var base_visitors: int; @export var appeal_scale: float
@export var k_item_tags: float; @export var k_decor_tags: float

class_name RunConfig extends Resource
@export var max_party_size: int = 6
@export var extract_channel_s: float = 3.0
```

### 7.8 MarketData / MarketTrendData
```gdscript
class_name MarketData extends Resource
@export var stock_table: LootTable
@export var stock_count: Vector2i
@export var markup_pct: Vector2 = Vector2(70, 100)
@export var decor_stock: Array[DecorData]

class_name MarketTrendData extends Resource
@export var id: StringName; @export var headline: String
@export var match_category: String              # or empty
@export var match_tag: StringName               # or empty
@export var multiplier: float
@export var duration_days: Vector2i
@export var weight: int = 100
```

### 7.9 Save Format (JSON, versioned)
```json
{
  "version": 1,
  "playtime_s": 0,
  "rng_seed": 0,
  "calendar": {"day": 1, "phase": "morning", "day_type": "unspent"},
  "economy": {"gold": 0, "debt_week_index": 0, "early_paid": 0},
  "roster": [{"uid":"r1","name":"","class":"fighter","level":1,"xp":0,"variance":{},"traits":[],
              "equipment":{},"inventory":[],"stance":"balanced","injured_until_day":0,"is_mule":false}],
  "shop": {"merchant_level":1,"merchant_xp":0,"layout":[{"decor":"id","cell":[0,0],"rot":0}],
           "displays":{"stand_uid":[]},"storage":[],"decor_inventory":[]},
  "reputation": {"farmer": 0},
  "market": {"stock":[],"active_trends":[],"rumors":[]},
  "dungeon": {"explored":{"chunk_id":"mask"},"discovered_extractions":["entrance"],"boss_first_kills":[]},
  "run_in_progress": null,
  "flags": {}
}
```

---

## 8. Progress Tracker (UPDATE EVERY SESSION)

> Format: `- [ ] F-XXX Name — notes (files/known gaps)`

**M0**
- [ ] F-000 Project Setup
- [ ] F-001 Input Map & Settings
- [ ] F-002 Autoload Scaffolding
- [ ] F-003 Debug Console
- [ ] F-004 RNG & Utilities
- [ ] F-005 Event Bus Contract

**M1**
- [ ] F-010 Test Arena
- [ ] F-011 Party Member Actor
- [ ] F-012 RTS Camera
- [ ] F-013 Mouse Picking
- [ ] F-014 Selection System
- [ ] F-015 Click-to-Move
- [ ] F-016 Basic HUD Shell
- [ ] F-017 Tactical Pause

**M2**
- [ ] F-020 Health/Mana/Stats Components
- [ ] F-021 Melee Combat
- [ ] F-022 Monster Actor & Data
- [ ] F-023 Monster AI
- [ ] F-024 Death & Corpses
- [ ] F-025 Ranged & Projectiles
- [ ] F-026 Hit Feedback
- [ ] F-027 Threat System
- [ ] F-028 Wipe Detection
- [ ] F-029 Combat Tuning

**M3**
- [ ] F-030 ClassData & LevelComponent
- [ ] F-031 Shared Kill XP
- [ ] F-032 Derived Stat Pipeline
- [ ] F-033 Character Sheet UI
- [ ] F-034 Regen & Potions
- [ ] F-035 Monster Level Scaling
- [ ] F-036 Revive
- [ ] F-037 Ability Core
- [ ] F-038 Ability & Status Effects
- [ ] F-039 Ability Bar & Targeting UI

**M4**
- [ ] F-040 ItemData & ItemInstance
- [ ] F-041 Inventory Grid
- [ ] F-042 Inventory UI
- [ ] F-043 Equipment Component
- [ ] F-044 Ground Items & Pickup
- [ ] F-045 Affix System & Generation
- [ ] F-046 Loot Tables & Drops
- [ ] F-047 Containers
- [ ] F-048 Consumables Framework
- [ ] F-049 Comparison Tooltips

**M5**
- [ ] F-050 Party API
- [ ] F-051 Formations
- [ ] F-052 AI Stances
- [ ] F-053 Manual Override Rules
- [ ] F-054 Pack Mule
- [ ] F-055 Auto-Behaviors
- [ ] F-056 Party Loot Rules
- [ ] F-057 Party Panel Polish
- [ ] F-058 Crowd Pathing Pass

**M6**
- [ ] F-060 Chunk Format & Sockets
- [ ] F-061 Dungeon Graph
- [ ] F-062 WorldStreamer
- [ ] F-063 Cross-Chunk Navigation
- [ ] F-064 Run-Scoped Chunk State
- [ ] F-065 Spawn System
- [ ] F-066 Dungeon Map & Fog
- [ ] F-067 Level Transitions & Ambience
- [ ] F-068 Bosses & First-Kill Bonus

**M7**
- [ ] F-070 RunManager & Lifecycle
- [ ] F-071 Extraction Points
- [ ] F-072 Start Point Selection
- [ ] F-073 Wipe & Extraction Resolution
- [ ] F-074 Injury System
- [ ] F-075 Shop Storage & Run Summary
- [ ] F-076 Save/Load (Town-Only)

**M8**
- [ ] F-080 Interactables & Dialog
- [ ] F-081 Town Scene & Shopkeeper
- [ ] F-082 Calendar & Phases
- [ ] F-083 Economy Ledger
- [ ] F-084 Debt Deadline Outcomes
- [ ] F-085 Guild Hall
- [ ] F-086 Dungeon Gate: Party Assembly
- [ ] F-087 Healer
- [ ] F-088 Menus & Options
- [ ] F-089 Notifications & Hints

**M9**
- [ ] F-090 Shop Scene & Build Grid
- [ ] F-091 Display Stands & Stocking
- [ ] F-092 Customer Actor & Browsing AI
- [ ] F-093 Haggle Model
- [ ] F-094 Haggle UI (Selling)
- [ ] F-095 Seller & Request Customers
- [ ] F-096 Decor Placement
- [ ] F-097 Customer Draw
- [ ] F-098 Merchant Level
- [ ] F-099 Reputation per NPC Type

**M10**
- [ ] F-100 Wholesale Market
- [ ] F-101 Market Trends & Events
- [ ] F-102 Price Insight
- [ ] F-103 Class & Ability Roster v1
- [ ] F-104 Caster/Support AI

**M11+** — track as added.

---

## 9. Decision Log (APPEND-ONLY)

| # | Date | Decision | Rationale | Feature |
|---|---|---|---|---|
| 1 | 2026-11-03 | Godot 4.3+, GDScript, 3D | Fits streaming + fixed camera; fast iteration | — |
| 2 | 2026-11-03 | Data-driven via `Resource` (.tres) | Lets Claude add content without code changes | — |
| 3 | 2026-11-03 | Single shared gold wallet | Matches original feel, simpler UI. *Amended #6: the wallet is now the shop's purse, shared by the shop and the guild.* | F-083 |
| 4 | 2026-11-03 | JSON saves, versioned | Debuggable, diffable | F-076 |
| 5 | 2026-11-03 | Original names/art/audio only | Avoid IP issues (now also covers Recettear and extraction-shooter references) | — |
| 6 | 2026-11-03 | **Core loop pivot:** continuous overworld campaign replaced by dungeon-extraction runs + Recettear-style shop | User direction | all |
| 7 | 2026-11-03 | One fixed, hand-authored, multi-level dungeon; seamless streaming kept | Learnable routes; keeps the no-loading-screens pillar | M6 |
| 8 | 2026-11-03 | Monsters and loot reset each run; explored map, extraction discoveries and boss first-kills persist | Extraction replayability with persistent progress | F-064 |
| 9 | 2026-11-03 | Extraction points fixed and always open; discovered points become free start points; discovery persists even on wipe | User direction; discovery as knowledge | F-071, F-072 |
| 10 | 2026-11-03 | Wipe loses all loot found that run and run gold; brought items kept; deployed members injured for random 1–4 days | User direction | F-073, F-074 |
| 11 | 2026-11-03 | Individual death with successful extraction carries no penalty; injury only on wipe | User direction | F-073 |
| 12 | 2026-11-03 | No in-run timer | Pressure from capacity and risk | F-070 |
| 13 | 2026-11-03 | Day = run OR town day; town days have 3 phases; location visits and shop sessions each use a phase | User direction (phases) | F-082 |
| 14 | 2026-11-03 | Weekly debt payments (miss = game over); weekly salaries for all roster members scaled by level | User direction | F-083, F-084 |
| 15 | 2026-11-03 | Roster larger than party; party max 6 including mules | User direction | F-050, F-085 |
| 16 | 2026-11-03 | Classes per recruit with fixed growth and ability unlocks; replaces use-based skills | User direction | M3 |
| 17 | 2026-11-03 | Kill XP to all deployed non-mule members, including dead ones | User direction ("all deployed") | F-031 |
| 18 | 2026-11-03 | Combat keeps DS core + tactical pause + player-triggered class abilities; AI auto-cast only when toggled | User direction | F-017, F-037, F-055 |
| 19 | 2026-11-03 | Mules: cheap salary, no XP, can die, injured on wipe | User direction | F-054 |
| 20 | 2026-11-03 | Dedicated non-combat shopkeeper protagonist; walkable 3D town | User direction | F-081 |
| 21 | 2026-11-03 | Recettear-style % haggling with patience and budget; reverse haggle for sellers; no combo XP | User direction | F-093 |
| 22 | 2026-11-03 | Customer draw via tag-weighted spawn table; decor on grid with tags + appeal | User direction | F-096, F-097 |
| 23 | 2026-11-03 | Shop progression = merchant level (XP from gross profit) + reputation per NPC type | User direction | F-098, F-099 |
| 24 | 2026-11-03 | Wholesale market with daily stock and trend events; market does not buy from player | User direction; keeps the shop as the sole selling outlet | F-100, F-101 |
| 25 | 2026-11-03 | Saves in town only; quitting mid-run resolves as wipe | Preserves extraction stakes | F-076 |
| 26 | 2026-11-03 | Extraction uses a short channel (3 s) cancelled by leaving the radius | Prevents instant mid-fight escape; tunable | F-071 |
| 27 | 2026-11-03 | Unpaid members leave at settlement; their gear goes to storage | Keeps the salary pressure meaningful without destroying items | F-083 |

*Open decisions to resolve in-feature:*
- nav across chunks (F-063)
- decor grid cell size (F-090)
- haggle curve tuning and default opening % (F-093)
- XP share mode default full vs split (F-031)
- debt schedule amounts (F-083 / `docs/balance.md`)
- number of dungeon levels for v1 (default 3, F-110)
- render pipeline Forward+ vs Mobile (F-000)

---

## 10. Glossary
- **Run:** one dungeon expedition, from start point to extraction or wipe. Uses up a whole day.
- **Extraction point:** a fixed, always-open exit from the dungeon; once discovered, also a start point.
- **Start point:** where a run begins (entrance or any discovered extraction point).
- **Wipe:** every deployed non-mule member dead. Found loot and run gold are lost and the party is injured.
- **Found this run:** flag on items picked up during the current run. Cleared on extraction; flagged items are deleted on a wipe.
- **Run gold:** gold collected during a run, credited only on extraction.
- **Injury:** days a roster member can't be deployed after a wipe.
- **Roster / Party:** all employed adventurers and mules / the ≤6 deployed on a run.
- **Phase:** a third of a town day; one activity per phase.
- **Settlement:** end-of-week debt payment + salaries.
- **Haggle:** % offer negotiation with a customer's hidden threshold, budget and patience.
- **Appeal:** shop attractiveness from decor and displays; drives visitor volume.
- **Reputation:** per-NPC-type standing that affects how often a type visits, how much it spends, and how lenient it is.
- **Merchant level:** shop progression from gross profit; unlocks space, displays, decor, NPC types.
- **Trend:** temporary market event multiplying the perceived value of a category/tag.
- **Chunk / Socket:** a streamed dungeon piece / its connection point.
- **Leash / Aggro radius / Stance / Formation slot:** as in combat (2.5–2.7).
- **ilvl:** item level, from chunk `area_level`.

---

## 11. Quick-Start Prompt for Future Sessions

Paste this to begin any session:

> Read `DUNGEON_SIEGE_GDD.md` Sections 0–3 and 8. Implement the next feature whose dependencies are complete (or **F-XXX** if I name one) following its spec in Section 6. Stay inside the scope, write tests per Section 3.4, keep the game runnable, update the Progress Tracker and Decision Log, and commit as `F-XXX: <name>`. Summarize what you built and anything I should playtest.
