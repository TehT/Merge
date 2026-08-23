# The Concurrence — Technical GDD & Architecture Reference

**Companion to `concurrence_gdd.md`.** That document owns the *vision*: premise, narrative arc, act structure, design principles. This document owns the *implementation*: what actually exists in the codebase today, how it fits together, the conventions to follow, and what to build next.

**Engine:** Godot 4.7 (stable), GDScript, Forward+
**Status as of this document:** Milestone 1 (core loop) is functionally complete and playable via UI. Travel, teams, and vehicles have been added beyond the original Milestone 1 scope.

> ⚠️ **The original GDD is partly out of date.** See [§9 Divergences](#9-divergences-from-the-original-gdd) before treating it as spec.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Scene Tree](#2-scene-tree)
3. [Data Model](#3-data-model)
4. [File & Function Reference](#4-file--function-reference)
5. [Signal Map](#5-signal-map)
6. [The Current Game Loop](#6-the-current-game-loop)
7. [Coding Conventions & Best Practices](#7-coding-conventions--best-practices)
8. [Gotchas Learned The Hard Way](#8-gotchas-learned-the-hard-way)
9. [Divergences From The Original GDD](#9-divergences-from-the-original-gdd)
10. [Known Gaps & Tech Debt](#10-known-gaps--tech-debt)
11. [Roadmap To A Playable Slice](#11-roadmap-to-a-playable-slice)
12. [Expanded Features (Discussed, Not Built)](#12-expanded-features-discussed-not-built)

---

## 1. Architecture Overview

### The manager pattern

All global game state lives in **plain `Node`s parented directly under `Main`**, each with `unique_name_in_owner = true`, accessed everywhere via scene-unique names (`%GameClock`, `%EventManager`, …).

**These are deliberately NOT autoloads.** A stale `[autoload]` block in `project.godot` was removed after it caused every manager to exist twice — once correctly under `Main`, once orphaned under `/root` where `%`-lookups can't resolve (autoloads aren't part of `Main`'s owned scene, so their `_ready()` threw on `%GameClock`). **Do not re-add them to `[autoload]`.**

Consequences of this choice:
- Sibling order in `Main.tscn` matters where one manager reads another during `_ready()`. `TeamManager` must come after `AgentManager` (it builds the starting team from the roster).
- By the time *any* node's `_ready()` runs, the whole tree exists — so `%`-lookups inside `_ready()` are always safe regardless of order. Only *reading another manager's initialized data* is order-sensitive.

### Layering

```
      ┌─────────────────────────────────────────┐
      │  UI layer (scripts/ui/)                 │  reads managers, never mutates
      │  DetailPanel, SquadList, EventList,     │  state directly except via
      │  SkillSlideout, TopBar, EventMapLabels  │  manager methods
      └────────────────┬────────────────────────┘
                       │ signals ↑ / method calls ↓
      ┌────────────────┴────────────────────────┐
      │  Manager layer (scripts/managers/)      │  owns all mutable game state
      │  GameClock, AgentManager, TeamManager,  │  emits signals on every change
      │  EventManager, ResourceState,           │
      │  ConcealmentState                       │
      └────────────────┬────────────────────────┘
                       │ operates on
      ┌────────────────┴────────────────────────┐
      │  Data layer (scripts/data/)             │  pure Resources, no scene
      │  AgentData, TeamData, EventData,        │  access, mostly dumb structs
      │  SkillData, VehicleData                 │  + derived getters
      └─────────────────────────────────────────┘

      ┌─────────────────────────────────────────┐
      │  Geoscape layer (scripts/)              │  3D globe, markers, paths
      │  GeoscapeController, MarkerLayer,       │
      │  SurfaceMarker, TravelPathLayer, GeoData│
      └─────────────────────────────────────────┘
```

**MissionResolver** sits outside this: a `RefCounted` static utility (pure math, no state, no scene access).

### Data flow principle

> **Managers mutate and emit. UI listens and rebuilds. Data objects compute but never reach outward.**

Every state mutation in a manager emits a signal. UI panels connect to those signals and rebuild their contents wholesale (`_clear()` then re-add children). There is no incremental UI diffing anywhere, by design — the panels are small and rebuilding is simpler to reason about than patching.

---

## 2. Scene Tree

`scenes/Main.tscn` (root `Main`, type `Node3D`, script `GeoscapeController.gd`):

```
Main                          [GeoscapeController.gd]
├── %GeoData                  [GeoData.gd]              country/city lookups
├── WeatherController         [WeatherController.gd]
├── DebugDriver               [debug_driver.gd]         keyboard test harness
├── %GameClock                [game_clock.gd]           ← must precede listeners
├── %ResourceState            [resource_state.gd]
├── %ConcealmentState         [concealment_state.gd]
├── %AgentManager             [agent_manager.gd]        ← must precede TeamManager
├── %TeamManager              [team_manager.gd]
├── %EventManager             [event_manager.gd]
├── WorldEnvironment
├── Globe                     MeshInstance3D + geoscape_material
│   ├── %MarkerLayer          [MarkerLayer.gd]          event pins + HQ pin
│   └── TravelPathLayer       [travel_path_layer.gd]    route arcs + team dots
├── %Camera3D
├── DirectionalLight3D        (disabled — sun is shader-driven)
└── UI                        CanvasLayer
    └── Root                  [root_ui.gd]              sidebar layout manager
        ├── TopBar            [top_bar.gd]
        ├── %EventMapLabels   [event_map_labels.gd]     clickable chips over markers
        ├── %SkillSlideout    [skill_slideout.gd]       secondary pop-out panel
        ├── LeftSidebar → LeftScroll → %DetailPanel  [detail_panel.gd]
        ├── LeftToggle
        └── RightSidebar → Tabs (TabContainer)
            ├── Squads → SquadScroll → %SquadList     [agent_tab.gd]
            │            + "+ New Squad" button (pinned outside scroll)
            ├── Events → %EventList                   [events_tab.gd]
            ├── Research   (placeholder)
            └── Equipment  (placeholder)
```

**Layout note:** the left sidebar is 320px, positioned *programmatically* by `root_ui.gd` (`_apply_left`/`_apply_right`) via tweened `offset_left`/`offset_right` — not by scene anchors. `SkillSlideout` (260px) slides out to the *right* of the left sidebar, offset past `LeftToggle` so it never covers the toggle button.

---

## 3. Data Model

### 3.1 Proficiencies & Skills (the core stat system)

This replaced the original GDD's five flat skills (Combat/Stealth/Arcane/Diplomacy/Tech).

**Six Proficiencies:**

| Proficiency | Key | Colour | Domain |
|---|---|---|---|
| Combat | `combat` | red-orange | Direct physical intervention, containment, brute force |
| Subterfuge | `subterfuge` | purple | Infiltration, misdirection, bypassing hazards unnoticed |
| Attunement | `attunement` | cyan | Raw magical manipulation, warding, sensing auras |
| Erudition | `erudition` | gold | Occult knowledge, ancient languages, anomaly behaviours |
| Influence | `influence` | green | Social engineering, crowd control, diplomacy |
| Ingenuity | `ingenuity` | blue | Modern tech, equipment deployment, tactical adaptation |

**Proficiencies are never set directly.** They are *derived* from an agent's `Array[SkillData]`. Each `SkillData` has:
- `skill_name: String` — e.g. "Shadowmeld"
- `proficiency: Proficiency` — which of the six it feeds
- `rank: int` (1–5)
- `tags: PackedStringArray` — e.g. `["Stealth", "Arcane"]`

**Two derived values coexist, and this distinction matters:**

1. **Proficiency *score*** (`AgentData.get_proficiency_scores()`) — sum of `rank × RANK_SCALE (20)` per category. A 0–200-ish continuous number. **Currently used by almost nothing** — see [§10](#10-known-gaps--tech-debt).
2. **Proficiency *rank*** (`AgentData.get_proficiency_ranks()`) — a 0–10 tier derived from a threshold table. **This is what the UI shows and what mission resolution uses.**

**Rank thresholds** (`SkillData.RANK_THRESHOLDS`) — you reach a rank by having *N skills at minimum rank M* in that category:

| Prof. Rank | Requires |
|---|---|
| 1 | 1 skill @ rank 1+ |
| 2 | 1 skill @ rank 2+ |
| 3 | 2 skills @ rank 2+ |
| 4 | 2 skills @ rank 3+ |
| 5 | 3 skills @ rank 3+ |
| 6 | 3 skills @ rank 4+ |
| 7 | 3 skills @ rank 4+ ⚠️ *identical to 6 — see below* |
| 8 | 4 skills @ rank 4+ |
| 9 | 4 skills @ rank 5+ |
| 10 | 5 skills @ rank 5+ |

The design intent: **breadth and depth both matter.** A single rank-5 specialist caps at proficiency rank 2. You need multiple competent skills in a category to push higher.

`SkillData.VISIBLE_MAX_RANK = 5` — the UI only ever draws 5 pips. Ranks 6–10 exist in data for late game but are deliberately not shown yet.

> ⚠️ **Known balance bug:** tiers 6 and 7 have identical requirements, so meeting them awards rank 7 directly and **rank 6 is unreachable**. Needs a pass when late-game tuning happens.

**Tags & counters:** `EventData.counter_tags` negate matching agent skills. `AgentData.get_effective_scores(counter_tags)` implements this — but **it is currently never called**, because resolution moved to the rank system. Wiring counter-tags into the rank path is an open task.

### 3.2 Starting roster (code-generated, not `.tres`)

`AgentManager._create_starting_roster()` builds 4 agents in code. This was a deliberate choice — with no roster-editing UI, code is faster to author and diff than resource files. Revisit when content authoring becomes a real workflow.

| Agent | Type | Skills (rank) | Resulting proficiency ranks |
|---|---|---|---|
| **Mara Okonkwo** | Mundane | CQC (K4), Firearms (K3), Fieldcraft (Su2), Threat Assessment (Ig1) | K4, Su2, Ig1 |
| **Iris Vance** | Shadow | Shadowmeld (Su4), Infiltration (Su3), Dark Channeling (At3), Occult Lore (Er2) | Su4, At2, Er2 |
| **Desmond Ffrench** | Mundane | Negotiation (In4), Electronic Surveillance (Ig3), Research (Er3), Cryptography (Ig2) | In2, Ig3, Er2 |
| **Kalinda Reyes** | Seer | Precognition (At3), Combat Training (K2), Intuition (In2), Anomaly Reading (Er2) | At2, K2, In2, Er2 |

**Alpha Team** (all four) therefore fields: **K4, Su4, At2, Er2, In2, Ig3** (team rank = best individual rank per proficiency). Event templates require ranks 1–3 at base difficulty, so the starting team comfortably handles early events and struggles as `magic_intensity` pushes requirements up.

### 3.3 Events

`EventData` — spawned by `EventManager` from `_SPAWN_TEMPLATES`, placed at a real city via `GeoData.get_random_city(50000)`.

- **Requirements are proficiency ranks** (`req_combat: int` 0–10, etc.), *not* raw scores. 0 = irrelevant.
- **Status lifecycle:** `ACTIVE → DEPLOYED → RESOLVED_SUCCESS | RESOLVED_PARTIAL | RESOLVED_FAIL`, or `ACTIVE → EXPIRED`.
- **`DEPLOYED` pauses the countdown** — `_tick_active_events()` skips non-`ACTIVE` events, so an event doesn't expire out from under a team in transit.
- **Escalation:** on expiry, if `can_escalate`, spawns `escalates_to` at the same location with every non-zero requirement bumped by `escalation_rank_bump` (default +1).
- **Decision-event fields exist but are entirely unused** (`is_decision_event`, `decision_prompt`, `decision_option_*`) — scaffolding for Milestone 3.

**Spawn templates** (base ranks, order: `[K, Su, At, Er, In, Ig]`):

| Type | Urgency | Reqs | Days | Escalates to |
|---|---|---|---|---|
| Cryptid Sighting | Low | `[1,2,0,0,0,0]` | 4 | — |
| Magical Surge | Medium | `[0,0,2,1,0,1]` | 3 | Portal Breach |
| Artifact Activation | Medium | `[0,1,1,1,0,2]` | 3 | — |
| Cult Activity | High | `[2,1,0,0,2,0]` | 3 | Portal Breach |
| Haunting | Low | `[0,1,2,0,0,0]` | 4 | — |
| Fairy Incursion | Medium | `[1,0,1,1,2,0]` | 3 | — |
| *Portal Breach* (escalation only) | High | `[1,1,3,1,0,2]` | 3 | — |

Difficulty scaling: `bonus = int(magic_intensity - 1.0)` added to every non-zero requirement, capped at 10.

### 3.4 Teams & Travel

`TeamData` — 3–5 members (`MIN_SIZE`/`MAX_SIZE`), `cohesion` 0–100 (up to `MAX_COHESION_BONUS = 0.5`, i.e. +50%).

**Location & travel state:**
```gdscript
location / location_name              # where they are now
is_traveling                          # the "away" flag
travel_destination / _name            # where they're headed
travel_departure_day / travel_arrival_day
travel_event_id                       # what to resolve on arrival
travel_vehicle_name                   # which vehicle is carrying them
travel_is_return                      # true on the trip home
travel_return_to / _name              # where "home" was when they left
pending_agent_results                 # agent_id → Status, applied on return
```

**HQ:** `TeamManager.HQ_LOCATION = Vector2(13.405, 52.52)` (Berlin, lon/lat), `HQ_NAME = "HQ (Berlin, Germany)"`. All new teams spawn there via `_at_hq()`.

### 3.5 Vehicles

`VehicleData` — the base fleet lives in `TeamManager.vehicles: Array[VehicleData]`. Vehicles are **not** owned by teams; the best one is auto-selected per dispatch.

Starting vehicle — **Airbus H225 / EC725 transport helicopter**, loosely modelled on the real airframe (~260 km/h cruise, 900–1200 km range) with numbers pushed up for black-budget plausibility:

| Field | Value |
|---|---|
| `speed_km_per_day` | 2400 |
| `max_range_km` | 3000 (hard cutoff) |
| `capacity` | 8 agents |
| `operation_cost` | 0 *(displayed, not yet charged)* |
| `mode` | `CONTINUOUS` |

`Mode.TELEPORT` exists as a seam (instant, `max_range_km` per jump, `cooldown_days`) but **nothing uses it yet**.

**Range is a hard gate, not a speed penalty.** Beyond 3000 km, `get_best_vehicle()` returns `null`, `begin_travel()` refuses, and the deploy UI disables the button. This is intentional tension: distant events simply expire until better transport exists.

`TeamManager.get_best_vehicle(distance, team_size)` picks the **fastest** vehicle that can both reach the distance and carry the team, tie-broken by lowest `operation_cost`.

---

## 4. File & Function Reference

### `scripts/data/`

#### `skill_data.gd` → `class_name SkillData extends Resource`
The atom of the stat system. Also the **home of all proficiency constants** — other files read `SkillData.PROFICIENCY_KEYS` etc. rather than redefining them.

| Member | Purpose |
|---|---|
| `enum Proficiency` | COMBAT, SUBTERFUGE, ATTUNEMENT, ERUDITION, INFLUENCE, INGENUITY |
| `PROFICIENCY_NAMES / _KEYS / _COLORS` | Display name, dict key, UI colour — indexed by enum |
| `RANK_SCALE = 20` | Multiplier for score derivation |
| `VISIBLE_MAX_RANK = 5` | How many pips the UI draws |
| `RANK_THRESHOLDS` | 10-entry `[{min_skills, min_rank}]` table |
| `_init(name, prof, rank, tags)` | Convenience ctor used by the roster generator |
| `get_proficiency_key() / _name()` | Enum → string |
| `get_scaled_rank()` | `rank * RANK_SCALE` |
| `is_countered_by(counter_tags)` | Tag intersection test |
| `static compute_proficiency_rank(skills)` | The threshold-walk that produces a 0–10 tier |
| `static empty_proficiency_dict()` | Zeroed float dict (scores) |
| `static empty_rank_dict()` | Zeroed int dict (ranks) |

#### `agent_data.gd` → `class_name AgentData extends Resource`
| Member | Purpose |
|---|---|
| `id, agent_name, backstory, personality_traits` | Identity (backstory/traits unused so far) |
| `skills: Array[SkillData]` | Source of truth for all stats |
| `supernatural_type, supernatural_power` | Flavour + future synergies |
| `max_health` / runtime `health, morale, experience, level, status` | Condition |
| `weapon_slot, armor_slot, gadget_slot, magical_item_slot` | Plain strings — no equipment system yet |
| `setup(name, skills, type)` | Assigns id, seeds health |
| `get_proficiency_scores()` | Continuous 0–200 scores *(largely unused)* |
| `get_effective_scores(counter_tags)` | Counter-tag-aware scores *(currently unused)* |
| `get_proficiency_ranks()` | **The one the UI and resolver use** |
| `get_skills()` | Legacy alias → `get_proficiency_scores()` |
| `get_primary_proficiency()` | Highest-scoring category key |
| `get_type_name() / get_status_name() / is_available()` | Display + guards |
| `compute_suitability(event)` | Solo-agent coverage via `MissionResolver` |

#### `team_data.gd` → `class_name TeamData extends Resource`
Constants `MIN_SIZE=3`, `MAX_SIZE=5`, `MAX_COHESION_BONUS=0.5`. Holds membership, cohesion, location, and the full travel-state block (§3.4).
`compute_effective_skills(members)` — level-weighted, cohesion-boosted score dict. **Currently has no callers** (superseded by `MissionResolver.compute_team_ranks`); kept because cohesion needs to re-enter resolution somewhere.

#### `event_data.gd` → `class_name EventData extends Resource`
See §3.3. Key methods: `setup()`, `set_proficiency_profile(6 ints)`, `get_proficiency_requirements()` → dict, `get_primary_proficiency()`, `get_total_difficulty()`, `get_urgency_color()`, `is_expired()`.

#### `vehicle_data.gd` → `class_name VehicleData extends Resource`
See §3.5. `compute_travel_days(distance)` (min 1 day for CONTINUOUS, 0 for TELEPORT), `can_reach(distance)`, `can_carry(team_size)`, `get_mode_name()`.

---

### `scripts/managers/`

#### `game_clock.gd` — `%GameClock`
The single source of truth for in-game time. `GeoscapeController` derives sun position and calendar date from it, so the visual day/night cycle can never drift from the simulation.

| Member | Notes |
|---|---|
| `seconds_per_day = 60.0` | Real seconds per game day |
| `current_day, paused, _accum` | |
| `_process(delta)` | Accumulates, fires `_advance_day()` per full day |
| `pause() / resume() / toggle_pause()` | |
| `advance_days(n)` | Debug stepping — **deliberately ignores `paused`** |
| `set_speed(seconds)` | **Rescales `_accum` proportionally** so day-progress stays continuous — without this the terminator teleports on speed change (fixed bug) |
| `get_day_progress()` | 0–1 fraction through the current day; drives sun + travel dot |

#### `resource_state.gd` — `%ResourceState`
Funding (500) and Intel (20). `earn_*` / `spend_*` (spend returns `false` if insufficient), signals on change. Kept separate from concealment: a plain ledger vs. a threshold meter.

#### `concealment_state.gd` — `%ConcealmentState`
0–100 meter. `daily_decay = 1.0` on each `day_advanced`. `add()` / `reduce()`. Fires `threshold_crossed` at 25/50/75/100 and `revelation_triggered()` at 100 (stubbed — no Act 3 transition).

#### `agent_manager.gd` — `%AgentManager`
Owns `roster: Array[AgentData]`. `_create_starting_roster()` (§3.2), `get_available_agents()`, `get_agent_by_id()`, `set_status()` — **on `KIA` the agent is erased from the roster permanently** (permadeath). `print_roster_status()` for debug.

#### `team_manager.gd` — `%TeamManager`
The largest manager. Owns teams, HQ, the vehicle fleet, training, and all travel.

| Function | Purpose |
|---|---|
| `_create_starting_team()` | Groups the whole 4-agent roster into "Alpha Team" |
| `_at_hq(team)` | Stamps HQ location onto a new team |
| `create_empty_team(name)` | **Bypasses MIN_SIZE** — needed for the drag-and-drop squad-building flow |
| `create_team(name, ids)` | Validating constructor (enforces 3–5) |
| `rename_team(id, name)` | |
| `add_member / remove_member / swap_member` | Each scales cohesion proportionally rather than resetting it |
| `grant_mission_cohesion(id)` | +8 after any mission, win or lose |
| `start_training(id)` / `_finish_training(id)` | 2 days, all members must be Available, +12 cohesion |
| `get_training_days_left(id)` | |
| **`get_best_vehicle(dist, size)`** | Fastest reachable + capable vehicle, tie-break on cost |
| **`begin_travel(id, dest, name, event_id)`** | Picks vehicle, computes days, marks members DEPLOYED, records return point. Returns plan dict or `{}` |
| **`begin_return_travel(id)`** | Sends them home; members stay DEPLOYED |
| **`_complete_travel(team)`** | On return leg: applies `pending_agent_results`. Either way: updates location, emits `team_arrived` |
| `_on_day_advanced` | Ticks training countdowns **and** checks travel arrivals |

#### `event_manager.gd` — `%EventManager`
| Function | Purpose |
|---|---|
| `_on_day_advanced` | `magic_intensity += 0.02`; tick events; maybe spawn |
| `_maybe_spawn_event()` | `chance = clamp(0.35 * magic_intensity, 0, 0.95)` |
| `spawn_random_event(template?)` | Builds `EventData`, scales reqs, places at a real city |
| `_tick_active_events()` | Decrements `days_remaining` for `ACTIVE` events only |
| `_handle_expiration(event)` | EXPIRED + concealment + optional escalation |
| `_spawn_escalation(parent)` | Child at same location, reqs bumped |
| **`deploy_team(event_id, team_id)`** | Marks event DEPLOYED, delegates to `begin_travel`. Returns plan dict |
| **`_on_team_arrived(team_id, event_id)`** | Resolves the mission, stashes agent outcomes as *pending*, starts the return trip |
| `_apply_resolution(event, result)` | Rewards / concealment / final status. **Does not apply agent statuses** (deferred to return) |
| `resolve_event_solo(event_id, agent_id)` | Legacy instant path — unused by UI, applies statuses immediately |

#### `mission_resolver.gd` → `class_name MissionResolver extends RefCounted`
Static-only, no state.

| Function | Purpose |
|---|---|
| `compute_rank_coverage(ranks, event)` | Mean of `clamp(agent_rank / required_rank, 0, 2)` across required proficiencies. ~1.0 = exact match |
| `compute_team_ranks(members)` | **Best individual rank per proficiency** across the team |
| `compute_team_suitability(event, members, team?)` | Coverage + `_compute_synergy_bonus()` (stubbed at 0.0) |
| `resolve(event, members, team?)` | `chance = clamp(0.3 + suitability*0.4, 0.05, 0.95)`; roll buckets into success (≤ 60% of chance) / partial (≤ chance) / failure. Injury 5%/15%/15–50%; KIA = injury × 0.2. Returns `{outcome, roll, chance, team_suitability, agent_results}` |

---

### `scripts/` (geoscape)

#### `GeoscapeController.gd` (on `Main`)
Globe rotation/momentum, zoom (with zoom-toward-cursor when flat), **drag-to-pan on the flat map**, sphere↔plane unfold (`Tab`), sun/season/calendar driven by `GameClock`.

- `get_flatten_amount()` — exposes the smooth 0–1 unfold blend. **Other layers must read this**, not the shader material (see §8).
- `get_date_string()` / `get_current_year()` / `set_date(m, d)` — calendar.
- `enable_cell_selection` / `enable_detail_view` — **both `false`.** The legacy grid-cell hover/click and the corner detail quad are gated off, not deleted. All click/hover/detail code paths null-check against these.

#### `GeoData.gd` → `class_name GeoData`
Loads `country_index_map.png` + `countries.json` + `cities.json` (258 countries, 7342 cities).
`get_country_at(lon,lat)`, `get_nearest_city()`, `get_nearby_cities()`, `get_random_city(min_pop)`, `describe_location()`, and **`static haversine_km(lat1,lon1,lat2,lon2)`** — static so `TeamManager` can compute distances without an instance.

#### `MarkerLayer.gd` (`%MarkerLayer`, child of Globe)
Owns all surface pins and resolves clicks. Subscribes to `EventManager` to add/remove event pins automatically. Creates the permanent HQ pin in `_create_hq_marker()`.
`add_site()`, `remove_site()`, `select()`, `_pick_marker(pos, radius)` (screen-space nearest, camera-facing only), `get_event_marker(id)`, `set_flatten(v)`.

#### `SurfaceMaker.gd` → `class_name SurfaceMarker` (`@tool`)
One billboard pin. **Contains the canonical lat/lon → position math that must stay in sync with `geoscape.gdshader`:**
- `static latlon_to_position(lat, lon, radius)` — sphere
- `static latlon_to_flat_position(lat, lon)` — plane (`PLANE_HALF_WIDTH = PI`, `PLANE_HALF_HEIGHT = PI/2`)
- `_reposition()` — replicates the shader's **two-stage** unfold (sphere→cylinder, then unroll) so pins track coastlines mid-animation.

Properties: `selected`, `hovered`, `is_base` (diamond HQ icon), `spawn_highlight_duration = 2.5` (one-shot "new event" ring).

#### `travel_path_layer.gd` (child of Globe)
Draws, per traveling team, an `ImmediateMesh` line (40 segments) plus a dot at the interpolated current position.
- Sphere: `Vector3.slerp` great-circle arc. Flat: linear interpolation. Blended by `get_flatten_amount()`.
- **Documented simplification:** unlike `SurfaceMarker`, it does *not* replicate the two-stage unroll — it's exact at flatten 0 and 1, approximate only during the ~0.5 s transition.
- Auto-picks up the return leg (it just watches `is_traveling`).

---

### `scripts/ui/`

| File | Node | Role |
|---|---|---|
| `root_ui.gd` | `UI/Root` | Sidebar open/close tweens, slideout positioning, and **the central signal-to-panel wiring** (`agent_selected`, `team_selected`, `event_selected`, `event_label_clicked`, `event_marker_clicked`, `hq_marker_clicked`) |
| `top_bar.gd` | `TopBar` | Date, pause, 1x/2x/4x speed, funding, intel, concealment bar with 25/50/75 ticks + threshold flash |
| `agent_tab.gd` | `%SquadList` | Squad list grouped by team, **drag-and-drop agents between squads**, "+ New Squad" pinned at the bottom outside the scroll |
| `events_tab.gd` | `%EventList` | Active events sorted by urgency then time |
| `detail_panel.gd` | `%DetailPanel` | The left panel. Views: `EMPTY, AGENT, TEAM, EVENT, RESULT, HQ` |
| `skill_slideout.gd` | `%SkillSlideout` | Secondary pop-out. Modes: `PROFICIENCY, DEPLOY, VEHICLE` |
| `event_map_labels.gd` | `%EventMapLabels` | Screen-space clickable title chips above each event pin |

**`detail_panel.gd` views in detail:**
- **AGENT** — proficiency rank pips (clickable → slideout), condition, team, supernatural
- **TEAM** — editable name (`LineEdit`), members, cohesion, **location / en-route ETA**, team proficiency ranks, member list
- **EVENT** — title, urgency, **"Deploy Team ›"** (placed high, above the fold), satellite mini-map, location, days left, requirement pips, stakes, rewards
- **HQ** — vehicles (clickable rows → slideout), squads with location/ETA, Equipment & Base Upgrades placeholders
- **RESULT** — travel confirmation (distance/days/arrival) *and* mission report (outcome, suitability, chance, roll, per-agent outcomes)

**`skill_slideout.gd` modes:**
- **PROFICIENCY** — rank pips, category description, per-skill cards with rank pips + tag chips
- **DEPLOY** — every non-empty squad with match %, availability, **distance + travel days + chosen vehicle**, Deploy button
- **VEHICLE** — image slot (or placeholder), mode, speed, range, capacity, op cost, description

Clicking the same trigger twice toggles the slideout closed.

#### `scripts/debug/debug_driver.gd`
Raw-keycode harness (matches `GeoscapeController`'s existing pattern; no InputMap actions anywhere in the project):

`1` spawn event · `2` list events · `3` deploy first team to most urgent · `4`/`5` advance 1/7 days · `6` toggle pause · `7` roster · `8` resources · `9` full status · `0` team status · `T` train first team

---

## 5. Signal Map

```
GameClock          day_advanced(day) ──┬──► ConcealmentState._on_day_advanced   (decay)
									   ├──► EventManager._on_day_advanced       (intensity, tick, spawn)
									   ├──► TeamManager._on_day_advanced        (training, ARRIVALS)
									   ├──► TopBar._update_date
									   └──► EventsTab._refresh
				   pause_changed(paused) ──► TopBar

ResourceState      funding_changed / intel_changed ──► TopBar
ConcealmentState   concealment_changed / threshold_crossed / revelation_triggered ──► TopBar

AgentManager       roster_changed / agent_status_changed ──► SquadList, DetailPanel

TeamManager        team_created / team_renamed / membership_changed /
				   cohesion_changed / training_started / training_completed
													──► SquadList, DetailPanel
				   team_departed(team_id)           ──► DetailPanel, TravelPathLayer
				   team_arrived(team_id, event_id)  ──► EventManager._on_team_arrived  ★
														DetailPanel, TravelPathLayer

EventManager       event_spawned  ──► MarkerLayer, EventMapLabels, EventsTab
				   event_expired  ──► MarkerLayer, EventMapLabels, EventsTab
				   event_resolved ──► MarkerLayer, EventMapLabels, EventsTab,
									  DetailPanel._on_mission_resolved (auto mission report)
				   event_escalated

MarkerLayer        event_marker_clicked(ev) ──► RootUI._on_event_selected
				   hq_marker_clicked()      ──► RootUI._on_hq_selected
				   event_marker_added/removed ──► (GeoscapeController detail quad — disabled)

GeoscapeController globe_clicked(pos) ──► MarkerLayer._on_globe_clicked

UI                 SquadList.agent_selected / .team_selected ──► RootUI
				   EventList.event_selected                  ──► RootUI
				   EventMapLabels.event_label_clicked        ──► RootUI
```

★ **The load-bearing connection.** `TeamManager` doesn't know what a mission is; `EventManager` doesn't own travel. `team_arrived` is the seam between them.

---

## 6. The Current Game Loop

### Per-day tick (automatic)

```
GameClock accumulates real seconds → seconds_per_day elapsed → day_advanced(n)
  │
  ├─ ConcealmentState  : value -= 1.0  (public forgets)
  │
  ├─ EventManager      : magic_intensity += 0.02
  │                      for each ACTIVE event: days_remaining -= 1
  │                        └─ hits 0 → EXPIRED
  │                                    + concealment_on_fail
  │                                    + escalate (if can_escalate) at same city, reqs +1
  │                      roll spawn: chance = clamp(0.35 × magic_intensity, 0, 0.95)
  │                        └─ new event at a random city (pop ≥ 50k), reqs scaled by intensity
  │
  └─ TeamManager       : training countdowns
						 for each traveling team: current_day ≥ arrival_day?
						   └─ _complete_travel() → team_arrived(team_id, event_id)
```

### Player action loop

```
1. NOTICE      Event spawns → pin appears with a one-shot white "spawn" ring,
			   a clickable urgency-coloured chip floats above it,
			   and it lists in the Events tab (sorted by urgency, then time).

2. INSPECT     Click pin / chip / list row → DetailPanel EVENT view:
			   requirement rank pips, satellite mini-map, stakes, rewards,
			   days remaining.

3. DISPATCH    "Deploy Team ›" → SkillSlideout DEPLOY mode.
			   Per squad it shows:
				 • match %  (compute_team_suitability → rank coverage)
				 • members available
				 • distance, travel days, and the auto-selected vehicle
			   Out of range (>3000 km) or over capacity → button disabled.

4. TRAVEL      EventManager.deploy_team()
				 → event.status = DEPLOYED   (countdown PAUSES)
				 → TeamManager.begin_travel()
					 • get_best_vehicle(distance, size)
					 • members → DEPLOYED
					 • records return point
			   DetailPanel shows a "Team Deployed" confirmation
			   (distance / days / arrival day).
			   TravelPathLayer draws the arc + a dot that moves smoothly
			   using get_day_progress().

5. RESOLVE     On arrival day → team_arrived → EventManager._on_team_arrived:
				 • MissionResolver.resolve()
					 chance = clamp(0.3 + suitability × 0.4, 0.05, 0.95)
					 roll ≤ chance×0.6 → success
					 roll ≤ chance     → partial
					 else              → failure
				 • rewards / concealment applied, event status set, event removed
				 • cohesion +8
				 • agent outcomes stashed in pending_agent_results  ← NOT applied yet
				 • begin_return_travel()
			   DetailPanel auto-pops the Mission Report.

6. RETURN      Arrival home → _complete_travel() applies pending outcomes:
			   Available / Injured / KIA (KIA = erased from roster, permanently).
			   Team is unavailable for the WHOLE round trip, not just the outbound leg.
```

### Squad management (parallel, any time)

Drag agents between squads in the Squads tab. Empty squads persist (so you can drag members back in). "+ New Squad" creates an empty one, bypassing MIN_SIZE. Click a squad header → team detail with editable name, cohesion, location/ETA, team proficiency ranks.

### What's missing from the loop

The loop is **complete but thin**: there is no progression, no economy sink, no narrative. Funding and Intel accumulate with nothing to spend them on. Agents never level up. Nothing unlocks. See §11.

---

## 7. Coding Conventions & Best Practices

### GDScript style (as established in this codebase)

1. **Strict typing everywhere.** `func f(x: int) -> String:`, `var a: Array[AgentData] = []`. Use `:=` inference only when the right-hand type is unambiguous.
2. **`##` doc comments** on every class and any non-obvious function. Explain *why*, not *what* — the existing comments consistently justify decisions ("Kept separate from ResourceState because…", "deliberately ignores `paused` so…"). Preserve this; it's the main defence against re-litigating past decisions.
3. **Section headers** in long files:
   ```gdscript
   ## ── Identity ────────────────────────────────────────────
   # =============================================================================
   # Lifecycle
   # =============================================================================
   ```
4. **Signals declared at the top**, immediately after the class doc comment.
5. **`_private` prefix** for internal state and helpers. Public API has no prefix.
6. **`@export` for tunables**, plain `var` for runtime state. Anything a designer might want to tweak should be exported.

### Architectural rules

7. **Managers own state; UI never mutates directly.** UI calls manager methods; managers emit; UI rebuilds.
8. **Every mutation emits a signal.** If you add a mutator, add or reuse a signal, or UI will silently go stale. *(This exact bug hit the HQ panel — it needed `team_created`/`team_renamed` added.)*
9. **Constants live with their concept.** `SkillData` owns all proficiency constants; `TeamData` owns size/cohesion limits; `TeamManager` owns HQ location. Never redefine them elsewhere.
10. **Data classes never touch the scene tree.** No `%Node` inside `scripts/data/`. Anything needing scene access belongs in a manager.
11. **Batch signal-driven refreshes** with `call_deferred`:
	```gdscript
	func _schedule_refresh() -> void:
		if _refresh_pending: return
		_refresh_pending = true
		_refresh_view.call_deferred()
	```
	Several signals often fire in one frame; this collapses them into one rebuild.
12. **Rebuild UI wholesale.** `_clear()` (queue_free all children) then re-add. No incremental patching.
13. **Gate disabled features behind exported bools** rather than deleting them (`enable_cell_selection`, `enable_detail_view`) — but **null-check every path they touch**, since gating creation means the objects are `null` at runtime.

### Verification

14. **Always run the headless parse check after edits:**
	```bash
	./Godot_v4.7-stable_win64_console.exe --headless --path . --quit
	```
	Expected clean output is:
	```
	GeoData loaded: 258 countries, 7342 cities
	[AgentManager] roster initialized with 4 agents
	[TeamManager] Alpha Team (4 members, cohesion 0%)
	```
	Anything else — `SCRIPT ERROR`, `Parse Error`, `Node not found` — is a real failure.
15. **Never truncate that output.** Piping through `Select-Object -First N` / `head -N` can hide errors, because PowerShell interleaves native stderr unpredictably. Use `| Out-String` and read all of it. *(This produced a false "clean parse" report once — a genuinely misleading result.)*

---

## 8. Gotchas Learned The Hard Way

Each of these cost real debugging time. They are listed so they don't cost it twice.

| # | Gotcha | Fix / Rule |
|---|---|---|
| 1 | **New `class_name` scripts aren't found in headless runs.** The editor regenerates `.godot/global_script_class_cache.cfg`; headless doesn't. | After adding a `class_name`, either open the editor once or hand-add the entry to the cache file. |
| 2 | **Stale `[autoload]` entries duplicate managers.** Autoloads live under `/root`, outside `Main`'s owned scene, so their `%`-lookups fail and every manager exists twice. | Managers are scene nodes only. Keep `[autoload]` empty. |
| 3 | **`%UniqueName` only resolves within the same owned scene.** | Never rely on `%` from an autoload or a separately-instanced scene. |
| 4 | **Empty `Callable()` in `set_drag_forwarding` breaks drops.** Godot 4.7 appears to treat it as "explicitly refuses" rather than "no handler". | Pass real methods (`_always_deny_drop`, `_noop_drop`). |
| 5 | **`MOUSE_FILTER_STOP` blocks `can_drop_data` propagation.** | Use `MOUSE_FILTER_PASS` on drag containers, `IGNORE` on their decorative children. |
| 6 | **Type inference fails on untyped returns.** `var x := %TeamManager.begin_travel(...)` → *"Cannot infer the type"*, because `%TeamManager` is an untyped `Node`. | Annotate explicitly: `var x: Dictionary = %TeamManager...`. This bit twice. |
| 7 | **`@export_file` takes separate arguments.** `@export_file("*.png,*.jpg")` errors; `@export_file("*.png", "*.jpg")` is correct. | |
| 8 | **Changing `seconds_per_day` without rescaling `_accum` teleports the sun.** `get_day_progress()` is `_accum / seconds_per_day` — changing the denominator alone jumps the fraction. | `set_speed()` preserves progress by rescaling `_accum`. Any future time manipulation must do the same. |
| 9 | **Don't read shader parameters as a data source.** Reading `flatten` back off the material was fragile and silently failed on the flat map. | Expose a getter (`GeoscapeController.get_flatten_amount()`). Shader params are for rendering, one-way. |
| 10 | **Markers clip into height-displaced terrain.** The small `SURFACE_OFFSET` isn't enough over mountains. | `depth_test_disabled` in `marker.gdshader`. Safe *only* because far-side hiding is done CPU-side (`is_facing_camera`), not by depth. Applying the same to travel paths would let them show through the globe — don't, without adding a visibility check. |
| 11 | **Gating feature creation leaves nulls behind.** Disabling `enable_detail_view` skipped `_create_detail_view()`, but `_on_globe_clicked` still assigned `_detail_mesh.visible` → crash on click. | When gating a feature off, audit *every* reference, not just the constructor. |
| 12 | **Children `_ready()` before parents.** `MarkerLayer` (under `Globe`) readies before `Main` assigns `camera`. | Resolve such references lazily (`_get_camera()`), or give the target a unique name and use `%`. |
| 13 | **Marker↔shader math must stay in sync.** `SurfaceMarker._reposition()` replicates `geoscape.gdshader`'s two-stage unfold. | Change one, change the other, or pins drift off the coastlines. |
| 14 | **UID warnings on `.tscn` ext_resources are harmless.** `invalid UID … using text path instead` appears when a script is created outside the editor. | Cosmetic. The editor rewrites them on next save. |

---

## 9. Divergences From The Original GDD

`concurrence_gdd.md` predates several implemented decisions. Where they conflict, **the code is correct** and the old GDD should be read as historical intent.

| Original GDD says | Reality |
|---|---|
| Five skills: Combat, Stealth, Arcane, Diplomacy, Tech | **Six Proficiencies** (Combat, Subterfuge, Attunement, Erudition, Influence, Ingenuity), *derived from tagged skills*, not set directly. Note Combat survives the rename but is now a *derived* proficiency, not a directly-set skill |
| Skill requirements as 0–200 values | **Proficiency ranks 0–10** (UI caps display at 5) |
| "Suitability rating" per agent | Team ranks = **best individual rank per proficiency**; suitability = mean coverage ratio |
| Events resolve on assignment | **Events resolve on arrival** after real travel time; teams then fly home before becoming available |
| Agents deploy to events directly | Agents belong to **persistent squads** (`TeamData`) with cohesion; squads deploy |
| Milestone 1 checklist unchecked | Milestone 1 is **substantially complete** — see below |
| No mention of vehicles/bases | **HQ in Berlin + a vehicle fleet** with range/speed/capacity gating exist |

**Milestone 1 actual status:**

- [x] Event data structure
- [x] Event spawner at real city locations
- [x] Event markers (clickable, urgency-coloured, spawn-highlight, map labels)
- [x] Agent data structure
- [x] Starting roster of 4 agents with distinct profiles
- [x] Event detail panel with requirements
- [x] Stat-based resolution
- [x] Outcome feedback (mission report, concealment, rewards)
- [x] Concealment meter with decay and thresholds
- [x] Day counter with adjustable speed
- [x] Pause
- [x] *(beyond scope)* Squads, cohesion, training, drag-and-drop roster management
- [x] *(beyond scope)* Travel time, vehicles, HQ, travel path visualisation
- [ ] Assign/unassign **individual agents** to an event — superseded by squad deployment

---

## 10. Known Gaps & Tech Debt

**Dead or orphaned code**
- `TeamData.compute_effective_skills()` — no callers. **Cohesion currently has no effect on mission outcomes at all**, which is a real gameplay hole: you can build it up via missions and training and it does nothing. Highest-value cleanup.
- `AgentData.get_effective_scores(counter_tags)` — no callers. **Counter-tags are therefore entirely inert**, despite being modelled on both skills and events.
- `AgentData.get_proficiency_scores()` / `get_skills()` — only used by `get_primary_proficiency()` and debug printing.
- `EventManager.resolve_event_solo()` — unused by UI.
- `EventData.assigned_agent_ids` — never populated (squads replaced it).
- `EventData` decision fields — scaffolding only.

**Balance issues**
- `RANK_THRESHOLDS` tiers 6 and 7 are identical → **rank 6 is unreachable**.
- Injury/KIA rates are unvalidated guesses (5%/15%/15–50%, KIA = injury × 0.2).
- `magic_intensity` growth (+0.02/day) means requirement bumps every 50 days — untested at length.

**Systems intentionally missing**
- No vehicle scheduling/exclusivity — two squads could "use" the single helicopter simultaneously.
- `operation_cost` is displayed but never charged.
- No save/load. **Nothing persists.**
- Agents never gain XP or level (`experience`/`level` exist, never change; `level` *is* read by the unused `compute_effective_skills`).
- `morale` never changes.
- Equipment slots are inert strings.

**Untested / unverified**
- Everything visual was verified only by headless parse, not by eye: travel arc rendering during unfold, HQ diamond proportions, chip readability, spawn-ring timing.
- Long-run behaviour (50+ days) has never been observed.

---

## 11. Roadmap To A Playable Slice

**Target:** 45–60 minutes of play with real decisions, visible progression, and an arc — i.e. Act 1 as a self-contained experience.

The ordering below is chosen so each phase makes the *existing* loop better before adding surface area.

### Phase A — Make existing systems matter *(highest value per effort)*

The loop works but several built systems are inert. Fix that before building anything new.

1. **Cohesion affects outcomes.** Re-wire `TeamData.compute_effective_skills()` (or a rank-space equivalent) into `MissionResolver`. Simplest version: cohesion adds a flat bonus to `compute_team_suitability`. Makes training and squad stability meaningful.
2. **Counter-tags do something.** Route `counter_tags` into the rank path — e.g. exclude countered skills before `compute_proficiency_rank`. Give 2–3 event templates real counter-tags. Instantly creates "wrong team for this job" decisions.
3. **Charge `operation_cost`.** Deduct funding in `begin_travel`; refuse if unaffordable. Gives funding its first sink.
4. **Fix the rank-6 threshold gap.**
5. **Agent XP and levelling.** Award XP on mission completion; level-up grants a skill rank. This is the main progression fantasy and it's currently absent.

### Phase B — Economy and progression

6. **Hire pool.** Rotating recruits, cost funding. Needs a Recruit tab. Makes permadeath survivable and roster-building a real decision.
7. **Research system (minimal).** One project at a time, costs intel + days, unlocks: a second vehicle, +1 proficiency rank in a category, or a concealment reducer. Even 6–8 nodes gives the game a spine.
8. **Vehicle progression.** A second vehicle unlocked by research — longer range is the natural first upgrade, since range is currently the hardest wall.

### Phase C — Narrative texture

9. **Decision events.** The data model already exists (`is_decision_event`, `decision_prompt`, `decision_option_*`). Pause the clock, show 2–4 choices, apply concealment/funding consequences. Even 5 hand-written ones transform tone.
10. **Concealment threshold events.** 25/50/75 currently just print. Fire actual decision events ("a journalist has footage").
11. **Event flavour text.** `description`/`summary` are unused. Region- and type-specific text makes events feel authored rather than procedural.

### Phase D — Slice completion

12. **Save/load.** Everything is `Resource`-based, so `ResourceSaver`/`ConfigFile` is tractable — but travel state and pending results need care.
13. **Onboarding.** First 3 days scripted: a guaranteed easy nearby event, tooltips on the deploy flow.
14. **A slice ending.** Reaching concealment 100 *or* surviving 60 days ends the slice with an epilogue card. Gives the session shape.
15. **Balance pass.** Play 5 full sessions; tune spawn rate, intensity growth, injury rates, funding flow.

### Deliberately deferred

Act 2–5 systems, factions, base building, tactical combat, mirror worlds. The slice is Act 1 only.

---

## 12. Expanded Features (Discussed, Not Built)

Captured from design conversation so they aren't lost. **None of these are specced — each needs a design pass before implementation.**

### Fast travel between fixed bases
Unlockable relatively early. Instant or near-instant movement between owned/allied bases, turning the base network into a logistics puzzle: a distant base extends effective reach far beyond the helicopter's 3000 km.

*Open questions:* How are bases acquired — research, funding, faction reputation? Does fast travel cost funding per use? Is it instant or 1 day? Does it need a vehicle at all?

### Teleportation
`VehicleData.Mode.TELEPORT` already exists as a seam (instant, `max_range_km` per jump, `cooldown_days`) but is entirely unused. Design intent: powerful but rationed — a limited-range, cooldown-gated jump that solves emergencies rather than routine travel.

*Discussed extension:* the dispatch screen should **automatically route via the nearest teleport pad when that's faster**, combining fast travel + conventional transport into one computed plan. This makes `get_best_vehicle()` a multi-leg **route planner** rather than a single-vehicle chooser — a significant rewrite, worth designing carefully.

### Expanded vehicle fleet
Progression from helicopter → magical vehicles → teleport pads. Each is a `VehicleData` preset; the auto-selection logic already handles a fleet of any size. Vehicles have an image slot in the UI awaiting art.

*Not yet handled:* vehicle scheduling/exclusivity (one airframe, one mission at a time), maintenance, per-vehicle crew limits beyond `capacity`.

### Base management
The HQ panel already has **Equipment** and **Base Upgrades** sections stubbed as "Coming soon". The original GDD frames base building as Act 4 content, but a light version (a few HQ upgrades: faster research, larger hire pool, extended vehicle range) would give funding a sink much earlier.

### Equipment
Four slots exist on `AgentData` as inert strings. Needs an item data type, an inventory, and a modifier hook in `MissionResolver`.

### Supernatural synergies
`MissionResolver._compute_synergy_bonus()` is stubbed at `0.0` with the Seer+Shadow ambush example from the GDD. The extension point is ready; the design isn't.

### Multi-leg / relay travel
Implied by the range wall: refuelling stops, forward staging, or dropping a team at an allied base. Currently a hard cutoff instead.

---

## Quick Reference

**Run headless check:**
```bash
./Godot_v4.7-stable_win64_console.exe --headless --path . --quit
```

**Key tunables and where they live:**

| Tunable | Location | Value |
|---|---|---|
| Real seconds per game day | `game_clock.gd` | 60 |
| Daily concealment decay | `concealment_state.gd` | 1.0 |
| Magic intensity growth/day | `event_manager.gd` | 0.02 |
| Base spawn chance/day | `event_manager.gd` | 0.35 |
| Starting funding / intel | `resource_state.gd` | 500 / 20 |
| Squad size | `team_data.gd` | 3–5 |
| Max cohesion bonus | `team_data.gd` | +50% |
| Mission / training cohesion | `team_manager.gd` | +8 / +12 |
| Training duration | `team_manager.gd` | 2 days |
| HQ location | `team_manager.gd` | Berlin (13.405, 52.52) |
| Vehicle speed / range / capacity | `vehicle_data.gd` | 2400 km/day / 3000 km / 8 |
| Skill rank scale | `skill_data.gd` | ×20 |
| Visible max proficiency rank | `skill_data.gd` | 5 (of 10) |
