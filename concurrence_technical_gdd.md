# The Concurrence — Technical GDD & Architecture Reference

**Companion to `concurrence_gdd.md`.** That document owns the *vision*: premise, narrative arc, act structure, design principles. This document owns the *implementation*: what actually exists in the codebase today, how it fits together, the conventions to follow, and what to build next.

**Engine:** Godot 4.7 (stable), GDScript, Forward+
**Status as of this document:** Milestone 1 (core loop) is functionally complete and playable via UI. Well beyond original scope: travel now has three legs (travel / on-site mission / travel home), missions are built from an ordered sequence of **phases** (not one flat check) with two swappable resolution strategies and a real mid-mission player-choice pause, skills and equipment are both fully data-driven Resource systems, agents are procedurally generated, a `BaseManager` owns bases/vehicles/equipment ahead of real multi-base play, and a running **event log** records what's happened all session.

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

### The manager pattern, and `Game` (the one autoload)

Every manager is still a plain `Node` parented directly under `Main` — **managers themselves are not autoloads.** The one exception is `Game` (`scripts/game.gd` — note the lowercase; a stale git/disk case mismatch on this exact file was finally fixed this pass, see §8), a thin **typed registry**, not a duplicate of any manager: it holds `var game_clock: GameClock`, `agent_manager`, `base_manager`, `team_manager`, `event_manager`, `event_log`, `resource_state`, `concealment_state`, `geo_data`, `detail_sidebar`, `slideout_panel`, `mission_choice_dialog` — nothing else. Each manager assigns itself into the matching `Game` field as the **first line of its own `_ready()`** (`Game.agent_manager = self`), so `Game.x` is only ever read after `x`'s own `_ready()` has run.

`EventLog` must be listed *after* `EventManager` and `TeamManager` as a `Main.tscn` sibling — it connects to their signals in its own `_ready()` and needs both already registered into `Game`.

**Why this exists, replacing the earlier `%UniqueName` convention:** `%`-lookups resolve by walking a node's `owner` chain, which only works for nodes instantiated from a packed scene. Every dynamically-created UI view (`detail_view_*.gd`, `slideout_view_*.gd`, all built via `SomeControl.new()` + `add_child()`) never gets an `owner` assigned, so `%`-lookups from inside them silently fail. `Game.x` resolves by autoload identity instead, which works identically no matter how or where the calling code was created. `%UniqueName` still works fine from properly scene-owned scripts and is still used in a few places, but new code should prefer `Game.x`.

Consequences:
- Sibling order in `Main.tscn` still matters for cross-manager reads during `_ready()` — `AgentManager` before `BaseManager` before `TeamManager` (the starting team is built from the roster and placed at the primary base), all before `EventManager`.
- A leftover empty `Node` named `"Game"` (no script) still sits at the bottom of `Main.tscn`'s tree from before the registry became an autoload — dead, harmless, not yet cleaned up.

### Layering

```
      ┌─────────────────────────────────────────┐
      │  UI layer (scripts/ui/)                 │  reads managers, never mutates
      │  DetailSidebar, SlideoutPanel, tabs,     │  state directly except via
      │  detail_view_*/slideout_view_* per type  │  manager methods
      └────────────────┬────────────────────────┘
                       │ signals ↑ / method calls ↓
      ┌────────────────┴────────────────────────┐
      │  Manager layer (scripts/managers/)      │  owns all mutable game state
      │  GameClock, AgentManager, BaseManager,  │  emits signals on every change
      │  TeamManager, EventManager,             │
      │  ResourceState, ConcealmentState        │
      └────────────────┬────────────────────────┘
                       │ delegates computation to
      ┌────────────────┴────────────────────────┐
      │  Handler layer (scripts/managers/)      │  static RefCounted utilities —
      │  SkillHandler, EquipmentHandler,        │  pure functions, no state,
      │  MissionResolver, AgentGenerator,       │  no scene access, no
      │  NameGenerator                          │  registration needed
      └────────────────┬────────────────────────┘
                       │ operates on
      ┌────────────────┴────────────────────────┐
      │  Data layer (scripts/data/)             │  pure Resources, no scene
      │  AgentData, TeamData, EventData,        │  access, mostly dumb structs
      │  SkillData, VehicleData, BaseData,      │  + derived getters
      │  EquipmentData + Requirement/Effect     │
      │  subclasses, SkillTagModifier           │
      └─────────────────────────────────────────┘

      ┌─────────────────────────────────────────┐
      │  Mission phase layer                     │  the sole resolution path —
      │  (scripts/data/mission_phases/,          │  every EventData.phases is
      │  scripts/data/mission_check.gd,          │  a non-empty Array[MissionPhase],
      │  scripts/managers/mission_phase_runner)  │  run in order by the runner
      │  MissionPhase (base), SinglePhase,       │
      │  ChoicePhase, MissionCheck,               │
      │  MissionPhaseRunner, MissionPhaseResult  │
      └────────────────┬────────────────────────┘
                       │ each MissionCheck delegates to
      ┌────────────────┴────────────────────────┐
      │  Resolution strategy layer               │  Strategy pattern — Resource-
      │  (scripts/managers/resolution/)          │  based, Inspector-swappable
      │  MissionResolutionStrategy (base),       │  per MissionCheck (not per
      │  StatCheckResolutionStrategy,             │  event — EventData no longer
      │  TagBreadthResolutionStrategy,            │  holds one at all)
      │  MissionResolutionResult (contract)      │
      └─────────────────────────────────────────┘

      ┌─────────────────────────────────────────┐
      │  Geoscape layer (scripts/)              │  3D globe, markers, paths
      │  GeoscapeController, MarkerLayer,       │
      │  SurfaceMarker, TravelPathLayer, GeoData│
      └─────────────────────────────────────────┘
```

The **Handler layer** is new relative to earlier versions of this doc: as the data model grew (skills split from their computation, equipment added its own cross-cutting math), the "one big static resolver" pattern (`MissionResolver`) got imitated deliberately for each new concern (`SkillHandler` for skill aggregation, `EquipmentHandler` for equipment effects, `AgentGenerator`/`NameGenerator` for procedural content) rather than growing `MissionResolver` into a god-object. Each one is `RefCounted`, entirely static, no persistent state, no autoload registration — plain `class_name` scripts.

The **mission phase layer** and **resolution strategy layer** replaced what used to be a single `EventManager.resolution_strategy` field. `EventManager` no longer holds *any* strategy or calls one directly — it unconditionally calls `MissionPhaseRunner.resolve(event.phases, squad)` (a coroutine — see below), which runs each `MissionPhase` in order and asks each one's `MissionCheck` to resolve itself against *its own* `resolution_strategy`. `MissionResolver`'s shared math (`compute_rank_coverage`, `compute_team_suitability`, etc.) no longer takes an `EventData`/`MissionCheck` at all — it takes a plain requirements `Dictionary` (whatever `get_proficiency_requirements()` returns) plus an optional `active_tags`, so it works identically for a real `MissionCheck` resolving a mission and for the deploy screen's `EventData`-based match% preview. See §3.8 and §6.

**Resolution is a coroutine end-to-end.** A `ChoicePhase`'s `PLAYER_CHOICE` trigger can suspend mid-mission to await a real player pick (via `MissionChoiceDialog` — see §3.8), so `ChoicePhase.resolve()` → `MissionPhaseRunner.resolve()` → both of `EventManager`'s resolve entry points are all `await`-chained. Nothing else in the game pauses while a choice is pending — `GameClock` keeps ticking, deliberately (nothing else in the game is turn-based either).

### Data flow principle

> **Managers mutate and emit. UI listens and rebuilds. Data objects compute but never reach outward. Handlers compute across data objects but own no state of their own.**

Every state mutation in a manager emits a signal. UI panels connect to those signals and rebuild their contents wholesale (`_clear()` then re-add children). There is no incremental UI diffing anywhere, by design.

---

## 2. Scene Tree

`scenes/Main.tscn` (root `Main`, type `Node3D`, script `GeoscapeController.gd`). `Game` (`scripts/game.gd`) is a **project autoload**, not part of this tree — see §1.

```
Main                          [GeoscapeController.gd]
├── %GeoData                  [GeoData.gd]              country/city lookups
├── WeatherController         [WeatherController.gd]
├── DebugDriver                [debug_driver.gd]         keyboard test harness
├── %GameClock                [game_clock.gd]           ← must precede listeners
├── %ResourceState            [resource_state.gd]
├── %ConcealmentState         [concealment_state.gd]
├── %AgentManager             [agent_manager.gd]        ← must precede BaseManager/TeamManager
├── %BaseManager               [base_manager.gd]         ← must precede TeamManager
├── %TeamManager               [team_manager.gd]
├── %EventManager              [event_manager.gd]
├── %EventLog                  [event_log.gd]            ← must follow EventManager/TeamManager
├── WorldEnvironment
├── Globe                     MeshInstance3D + geoscape_material
│   ├── %MarkerLayer          [MarkerLayer.gd]          event pins + HQ pin
│   └── TravelPathLayer       [travel_path_layer.gd]    route arcs + team dots
├── %Camera3D
├── DirectionalLight3D        (disabled — sun is shader-driven)
├── UI                        CanvasLayer
│   └── Root                  [root_ui.gd]              sidebar layout manager
│       ├── TopBar            [top_bar.gd]
│       ├── %EventMapLabels   [event_map_labels.gd]     clickable chips over markers
│       ├── %SkillSlideout    [slideout_panel.gd]       secondary pop-out panel
│       ├── LeftSidebar → LeftScroll → %DetailPanel  [detail_sidebar.gd]
│       ├── LeftToggle
│       ├── %EventLogToggle   sibling button, "☰" — opens the event log (SlideoutPanel)
│       ├── %MissionChoiceDialog [mission_choice_dialog.gd]  full-screen modal, hidden by default
│       └── RightSidebar → Tabs (TabContainer)
│           ├── Squads → SquadScroll → %SquadList     [agent_tab.gd]
│           │            + "+ New Squad" button (pinned outside scroll)
│           ├── Events → %EventList                   [events_tab.gd]
│           ├── Research   (still a placeholder)
│           └── Equipment → %EquipmentList             [equipment_tab.gd]  — real now
└── Game                      empty Node, no script — dead leftover, see §1
```

**Layout note:** the left sidebar is 320px, positioned *programmatically* by `root_ui.gd` (`_apply_left`/`_apply_right`) via tweened `offset_left`/`offset_right` — not by scene anchors. `SkillSlideout` (260px) slides out to the *right* of the left sidebar, offset past `LeftToggle` so it never covers the toggle button.

---

## 3. Data Model

### 3.1 Proficiencies & Skills (the core stat system)

This replaced the original GDD's five flat skills (Combat/Stealth/Arcane/Diplomacy/Tech), and was later split into a data/handler pair.

**Six Proficiencies** (unchanged): Combat, Subterfuge, Attunement, Erudition, Influence, Ingenuity.

**`SkillData`** (`scripts/data/skill_data.gd`) is now a *plain data container* — the `Proficiency` enum, `PROFICIENCY_NAMES`/`_KEYS`/`_COLORS`, `RANK_SCALE = 20`, `VISIBLE_MAX_RANK = 5`, and one skill's own fields (`skill_name`, `proficiency`, `rank` 1–5, `tags`), plus lookups that only ever need the skill's own data (`get_scaled_rank()`, `has_tag()`, `get_proficiency_name/key()`).

**`SkillHandler`** (`scripts/managers/skill_handler.gd`) owns everything that reasons about a *set* of skills, or a skill against something external:
- `compute_proficiency_rank(skills, active_tags = [])` — the threshold-walk (`RANK_THRESHOLDS`, unchanged table, same rank-6/7 bug — see §10) that turns a list of skill ranks into one 0–10 tier. Now takes an optional `active_tags` context.
- `compute_effective_rank(skill, active_tags)` — a skill's rank as modified by **tag modifiers** (new — see below), floored at 0. Called internally by `compute_proficiency_rank` before aggregating, so tag modifiers apply *before* the threshold walk, not after.
- `is_countered_by(skill, counter_tags)` — unchanged tag-intersection test. **Still has no callers in the resolution path** (see §10) — a separate, newer mechanism (tag modifiers, below) now does something similar but isn't the same feature.
- `instantiate(base_skill, rank)` — duplicates a catalog skill and sets its rank. Used everywhere a skill is assigned to an agent, so multiple agents referencing the same catalog `.tres` never alias one `SkillData` instance.
- `get_skills_for_proficiency(prof)` — scans `res://data/skills/<proficiency>/` live via `DirAccess`. Adding a `.tres` there makes it available with no code or registration changes.

**Two derived values coexist — and unlike the earlier version of this doc, *both are now live*:**

1. **Proficiency *score*** (`AgentData.get_proficiency_scores()`) — sum of `rank × 20` per category, 0–200-ish continuous. **Now used**: it's the input to `MissionResolver.compute_score_coverage()`, which is blended into mission suitability (§3.6/§6), and it's what equipment `EffectStatBoost` modifies. Also now shown in the UI next to the Tier pips (agent sheet, proficiency drill-down) specifically so a stat boost too small to move the Tier is still visible.
2. **Proficiency *rank*** (`AgentData.get_proficiency_ranks()`) — the 0–10 tier. Still the primary signal the UI shows and mission resolution weights most heavily.

**Skill catalog** — `data/skills/<proficiency>/*.tres`, 18 entries (3 per Proficiency), the "Base Skill Roster: Mundane Operatives": every skill carries `[Mundane]` plus two descriptive tags (e.g. Firearms: `[Mundane, Ballistic, Ranged]`). This is a shared *catalog*, not per-agent data — skills aren't agent-specific; `SkillHandler.instantiate()` is how an agent gets their own independent copy at their own rank.

**Tag modifiers (new)** — `SkillTagModifier` (`scripts/data/skill_tag_modifier.gd`): a data-driven rule, `trigger_tag` (a context tag — an event's, say) + `affects_tag` (a skill tag) + `rank_delta`. `SkillHandler.tag_modifiers` preloads every `.tres` under `res://data/tag_modifiers/` (currently two: `fragile_penalizes_explosive.tres` at −1, `swarm_boosts_area.tres` at +1). No skill interaction is ever hardcoded — a new interaction is a new `.tres` file. Currently the only source of "active tags" fed into this system is an event's own `tags` field; `counter_tags` is a separate, still-unwired field (§3.3).

### 3.2 Starting roster (now procedurally generated)

`AgentManager._create_starting_roster()` no longer hand-authors agents. `@export var starting_roster_size: int = 4` recruits are generated each game start; each independently rolls Generalist vs. Specialist against `@export_range var generalist_chance: float = 0.6` (0.6 = 3:5 generalists = a 2:3 specialist:generalist ratio), then delegates to `AgentGenerator`:

- **`AgentGenerator.generate_specialist(name, primary, secondary, type)`** — 5 skills: 3 in `primary` at ranks `[2, 1, 1]` (resolves to exactly Proficiency rank 2 via the threshold table — 1 skill ≥ rank 2, not 2, so it caps there) and 2 in `secondary` at `[1, 1]` (resolves to rank 1).
- **`AgentGenerator.generate_generalist(name, type)`** — 6 skills at rank 1, spread across 4 randomly-chosen Proficiencies (2 with 2 skills, 2 with 1 skill) — every active Proficiency lands at rank 1, since nothing in an all-rank-1 category clears the rank-2 threshold.
- Recruit names come from **`NameGenerator`** (`scripts/managers/name_generator.gd`): 50 first names × 50 last names (2,500 combinations), picked for the international mix the original hand-authored agents had.
- All generated recruits are mundane (`SupernaturalType.NONE`) — nothing rolls an Awakened type yet, since there's no Awakened skill catalog for a generator to draw from.

The old fixed 4-agent roster (Mara Okonkwo, Iris Vance, Desmond Ffrench, Kalinda Reyes) is gone from code; the flavor names now only exist in `NameGenerator`'s pool and in git history.

### 3.3 Events

`EventData` — spawned by `EventManager` from `spawn_templates: Array[EventData]`, an `@export` array **empty by default**, populated via the Inspector by dragging in `.tres` resources from `res://data/event_templates/` (7 exist on disk: the 6 spawnable types + `portal_breach` as escalation-only; as configured today only `magical_surge.tres` is actually wired into the live `spawn_templates` array — the rest exist but aren't in the active pool until someone drags them in). `spawn_random_event()` `duplicate(true)`s the chosen template rather than building one from scratch.

- **`req_combat: int` (0–10) etc. are now a coarse, spawn-time/UI-facing summary only** — `EventManager.spawn_random_event()`'s difficulty scaling, escalation rank bumps, and the deploy screen's match% preview all read them, but **nothing in resolution does**. Every event resolves through `phases` instead (below); each phase's own `MissionCheck` carries the real req_*/target_*/tags a strategy actually reads.
- **`target_*` (Target Values) and `tags`/`counter_tags` are gone from `EventData` entirely** — moved to `MissionCheck` (§3.8), the actual unit resolution strategies operate on. `get_target_values()`/`has_tag()` no longer exist on `EventData`.
- **`phases: Array[MissionPhase]`** (new, mandatory) — every event resolves through this, run in order by `MissionPhaseRunner`. A simple, single-check mission is just a one-element array holding one `SinglePhase`. An empty array resolves nothing (logs a warning) — treat it as a content bug, not a valid state. See §3.8.
- **`mission_duration_hours: float = 2.0`** — how long a deployed team spends actively on-site working the event, once they arrive, before heading home. See §3.4 and §6 for the state machine this drives.
- **Status lifecycle:** `ACTIVE → DEPLOYED → RESOLVED_SUCCESS | RESOLVED_PARTIAL | RESOLVED_FAIL`, or `ACTIVE → EXPIRED`. Unchanged.
- **`DEPLOYED` pauses the countdown** — unchanged.
- **Escalation:** unchanged — on expiry, if `can_escalate`, spawns `escalates_to` at the same location with every non-zero requirement bumped by `escalation_rank_bump`.
- **Decision-event fields still entirely unused** (`is_decision_event`, `decision_prompt`, `decision_option_*`).

### 3.4 Teams & Travel (now three legs, not two)

`TeamData` — 3–5 members (`MIN_SIZE`/`MAX_SIZE`), `cohesion` 0–100 (up to `MAX_COHESION_BONUS = 0.5`).

**Location & state:**
```gdscript
location / location_name              # where they are now
is_traveling                          # the "away, physically moving" flag
travel_destination / _name / travel_departure_day / travel_arrival_day
travel_event_id / travel_vehicle_name / travel_is_return
travel_return_to / _name
pending_agent_results                 # agent_id → Status, applied on return

# New: the on-site "working the mission" phase, distinct from is_traveling
is_on_mission
mission_ready_day                     # fractional-day target, same units as travel_arrival_day
mission_event_id
```

A deployment's full timeline is now: **travel there** (`is_traveling`) → **work the mission** (`is_on_mission`, for `event.mission_duration_hours`) → **resolve** → **travel home** (`is_traveling`, `travel_is_return = true`). `TeamManager._process()` checks both `is_traveling`/`travel_arrival_day` and `is_on_mission`/`mission_ready_day` every frame (sub-day precision matters for short hops and short missions alike). On physical arrival, if the event's `mission_duration_hours > 0`, the team parks in `is_on_mission` instead of immediately firing `team_arrived`; `_complete_mission_work()` fires the same signal once the timer elapses. **`EventManager` needed zero changes for this** — it still just resolves on `team_arrived`, whenever it actually fires.

**HQ moved off `TeamManager`** — see §3.7. `TeamManager._at_hq(team)` now reads `Game.base_manager.get_primary_base()` instead of a local constant.

### 3.5 Vehicles (now base-local)

`VehicleData` fields: `vehicle_name`, `description`, `speed_kmh` (not `speed_km_per_day` — renamed early this project after realizing day-scaled speed was an internal-tick convenience, not a domain unit a player reads), `max_range_km`, `capacity`, `operation_cost` (displayed, not yet charged), `mode` (`CONTINUOUS` / `TELEPORT`, only `CONTINUOUS` used), `cooldown_days`.

**Vehicles no longer live on `TeamManager`.** They belong to whichever `BaseData` owns them (§3.7); `TeamManager.get_best_vehicle()` now searches `Game.base_manager.get_all_vehicles()` — every base's fleet pooled together, a stand-in until teams track a specific home base to search just its own fleet.

Starting vehicle unchanged — Airbus H225/EC725, 320 km/h, 3000 km range (hard cutoff), 8 capacity, `data/vehicles/eurocopter_h225.tres`.

### 3.6 Equipment (new — composition over inheritance)

`EquipmentData` (`scripts/data/equipment_data.gd`) is a container of composable Resources a designer mixes in the Inspector, not hardcoded per-item logic:

```gdscript
equipment_name: String
slot_type: String            # @export_enum("Weapon", "Armor", "Gadget")
description: String
requirements: Array[EquipmentRequirement]
effects: Array[EquipmentEffect]
```

**Requirements** (`scripts/data/equipment/`) — `EquipmentRequirement` base (`is_met(agent) -> bool`, `get_description() -> String`), subclassed by:
- `ReqProficiencyRank` — agent's *effective* rank (equipment-inclusive) in a Proficiency ≥ some value.
- `ReqSkillTag` — agent has a skill (own or gear-granted) carrying a tag.
- `ReqSupernaturalType` — agent's origin matches exactly.

Checked against the agent's **current** effective state, not their bare sheet — so one equipped item's bonus can satisfy another item's requirement. Equip order can matter for borderline loadouts; this was a deliberate simplicity choice over building "requirements ignore other gear."

**Effects** — `EquipmentEffect` base with three no-op-by-default hooks, run in this order by `EquipmentHandler`:
1. `apply_to_skills(skills)` — on a duplicated working copy of the agent's skill list.
2. `apply_to_ranks(ranks)` — after Proficiency ranks are aggregated from that pool.
3. `apply_to_scores(scores)` — after Proficiency scores are summed from that pool.

Subclasses: `EffectStatBoost` (flat addition to one Proficiency's *score*), `EffectGrantSkill` (appends a virtual `SkillData`, duplicated so the shared template is never mutated), `EffectModifySkill` (finds skills matching a tag and adds a tag/rank to duplicates of them).

**`EquipmentHandler`** (`scripts/managers/equipment_handler.gd`) is the aggregation/validation engine: `can_equip()`, `get_effective_skills()` (the equipment-modified skill pool, never mutating the agent's real `SkillData`), `apply_rank_effects()`/`apply_score_effects()` (split out so `MissionResolver`'s team-level pooling can reuse them per-member), `compute_effective_ranks()`/`compute_effective_scores()`.

**`AgentData`** gained `equipped_weapon`/`equipped_armor`/`equipped_gadget` (`EquipmentData`, replacing the old inert `weapon_slot`/`armor_slot`/`gadget_slot` strings — `magical_item_slot` is still a plain string, not covered by the 3-slot system), plus `can_equip()`/`equip()`/`unequip()`. **`get_proficiency_ranks()`/`get_proficiency_scores()` are equipment-aware by default** — every existing caller (resolution, UI) picked this up automatically, no call sites changed.

**A real engine quirk hit and worked around:** `Resource.duplicate()` doesn't reliably break copy-on-write sharing for `PackedStringArray` export fields in this Godot build — `EffectModifySkill` originally corrupted the *original* skill's tags when adding a tag to a duplicate. Fixed by rebuilding the tags array element-by-element from scratch instead of mutating a derived copy. Worth remembering before writing any other code that mutates a duplicated Resource's array fields.

**Storage:** `AgentManager.equipment_inventory` (an earlier, single-pool attempt) is gone — see §3.7, equipment now lives on `BaseManager`.

**UI:** `equipment_tab.gd` (right sidebar, flat unsorted list — sorting/categories deferred until there's enough content to need them), `slideout_view_equipment.gd` (read-only info card: slot, description, requirements, effects — each requirement/effect has a `get_description()` for this), `slideout_view_equip_slot.gd` (the agent-sheet picker: shows what's equipped with an Unequip button, then every candidate item with the specific unmet requirement shown if the agent doesn't qualify).

### 3.7 Bases (new)

`BaseManager` (`scripts/managers/base_manager.gd`) owns `bases: Array[BaseData]` plus `global_equipment: Array[EquipmentData]` (usable from any base, as opposed to a base's own local stock). **Single-base for now, by design** — this was an explicit scope decision (data model ready for multiple bases; no gameplay yet lets the player found a second one or station a team at a specific base). If `bases` is empty on `_ready()`, it seeds one HQ (`"HQ (Berlin, Germany)"`, the same location as before) with the starting Eurocopter.

`BaseData` (`scripts/data/base_data.gd`): `id`, `base_name`, `location` (lon/lat), `vehicles: Array[VehicleData]`, `local_equipment: Array[EquipmentData]`.

`BaseManager.get_primary_base()` / `get_all_vehicles()` / `get_all_equipment()` are **explicitly documented as pooling stand-ins** — every current caller treats "which base" as "all of them, indiscriminately," because nothing (no team, no agent) tracks a home base yet. Wiring real per-base availability is a distinct, not-yet-started task; adding a second base today would work data-wise but wouldn't change any behavior, since nothing filters by which base is "yours."

### 3.8 Multi-Stage Missions, Alternate Resolution, and Player Choice (new)

**`MissionCheck`** (`scripts/data/mission_check.gd`) is the phase-scoped analog of `EventData`'s old requirement/target/tag fields, and the actual unit every `MissionResolutionStrategy` resolves against: `req_*`/`target_*`/`tags`/`counter_tags`, a `check_name`, and its own `resolution_strategy` (defaults to `StatCheckResolutionStrategy`). `get_proficiency_requirements()`/`get_target_values()` live here now, not on `EventData`. `resolve(squad)` just calls `resolution_strategy.resolve(self, squad)` — no conversion step.

**`MissionPhase`** (`scripts/data/mission_phases/mission_phase.gd`) is the Strategy-pattern base for one stage of a mission. `get_checks() -> Array[MissionCheck]` lets UI/preview code (requirement display, match% averaging) walk any phase without caring which concrete type it is.
- **`SinglePhase`** — one `MissionCheck`, always runs.
- **`ChoicePhase`** — picks one `MissionCheck` from `checks`, per `trigger`:
  - `FAILURE` — a *conditional branch*, not a pick-among-alternatives mode: only activates if the immediately preceding phase's outcome was a failure. Skipped (silently, `MissionPhaseResult.ran = false`) otherwise.
  - `RANDOM` — always activates, picks uniformly at random.
  - `PLAYER_CHOICE` — always activates, pauses resolution and awaits a real player pick via `MissionChoiceDialog`. `player_choice_picker: Callable` is an injectable override (used for testing without a real UI/Signal round-trip; falls back to the dialog in normal play).

**`MissionPhaseRunner`** (`scripts/managers/mission_phase_runner.gd`, static, a coroutine) runs an event's `phases` in order: threads the previous phase's outcome into the next (for `ChoicePhase.FAILURE`), threads the accumulated log-so-far into each phase (so the player-choice dialog can show "how the mission's gone"), and merges every phase's agent-status rolls **worst-status-wins** (KIA > Injured > Available — an agent hurt in an earlier phase can't come out "healed" by a later phase's independent roll). No fatigue modeling yet (deliberately deferred). The final outcome is whichever phase actually ran last.

**Two resolution strategies now exist**, both taking `(check: MissionCheck, squad)`:
- **`StatCheckResolutionStrategy`** — the original math (team rank/score coverage vs. `req_*`), unchanged in substance.
- **`TagBreadthResolutionStrategy`** — pools skills by *tag* within a category rather than by category alone, rewarding a team that covers a category from several angles over one that stacks copies of the same angle. Two-pass: a **Modifier Pass** (a skill sharing a tag with `check.counter_tags` → effective rank 0; sharing a tag with `check.tags` → effective rank +1 — this is the first real use of `counter_tags` anywhere in resolution, via `MissionCheck` rather than the old inert `EventData.counter_tags`) and a **Redundancy Pass** (skills grouped by tag, sorted by rank, weighted so a lone top skill counts fully but redundant copies of the same rank increasingly don't — closed-form: 100%/50%/0% for a solo skill's 1st/2nd/3rd rank-tier, or `max(0, 180/n − 15)%` per head for an *n*-way tie, reproducing the spec'd 75%/45%/30% anchors at n=2/3/4). The pooled tag-weighted totals are compared against `target_*` (continuous), while `req_*` stays a separate hard prerequisite gate: a missing prerequisite multiplies the roll chance by `missing_prereq_penalty` (`@export`, default 0.75 — 0.5 played too harsh, a 95% shot dropping to ~40% off one missed prereq) per category missed, compounding.

`MissionResolver.resolve_from_suitability()` — shared by both strategies — also now returns a human-readable trace (`MissionResolutionResult.log_lines`): rank/score coverage per category, the chance/roll/outcome line, per-agent roll lines. `EventManager` prints it under the one-line summary; `detail_view_result.gd` shows it in the Mission Report.

**`MissionChoiceDialog`** (`scripts/ui/mission_choice_dialog.gd`, `Game.mission_choice_dialog`) — a full-screen modal (scrim + centered panel), hidden by default. `request_choice(phase, log_so_far)` populates it (phase name, the log so far, one clickable card per check showing name + rank pips) and `await`s its own private `choice_made` signal, returning the chosen `MissionCheck`. Nothing else pauses while it's up — see §1.

**Deploy screen / event sheet previews**, now rebuilt around phases instead of `EventData`'s old flat fields:
- `MissionResolver.compute_mission_suitability(phases, members)` — the deploy screen's match% — averages suitability per phase (a `ChoicePhase`'s own checks are averaged together first, since only one will actually run and which isn't known ahead of time), then averages across phases. A phase with no checks configured is skipped, not counted as 0.
- `detail_view_event.gd`'s Requirements section is a **per-phase breakdown** — phase count in the header, a trigger note for `ChoicePhase` (`(random choice)`, `(if previous phase fails)`, `(player choice)`), and each check's own rank pips, labeled `Option: <name>` when a phase has more than one.

### 3.9 Event Log (new)

**`EventLog`** (`scripts/managers/event_log.gd`, `Game.event_log`) listens to `EventManager`/`TeamManager` signals and keeps a running, player-facing history: events spawning/expiring/escalating/resolving, teams departing/setting-out-for-home/arriving/returning (`team_departed` and `team_arrived` each cover two semantically different moments with the same signal signature — `EventLog` reads `team.travel_is_return` / whether `event_id` is empty at the moment the signal fires to tell them apart). Capped at 300 entries (`MAX_ENTRIES`).

**`EventLogEntry`** (`scripts/managers/event_log_entry.gd`) — a local in-game timestamp (`day`/`hour`, straight from `GameClock.current_day`/`current_hour`, its actual whole-hour resolution) plus the entry text. `format_timestamp()` → `"Day 5, 14:00"`.

**Ordering matters and was a real bug**: `EventManager._on_team_arrived()` used to call `begin_return_travel()` (which synchronously fires `team_departed` for the return leg) *before* emitting `event_resolved` — so the log showed "set out for home" ahead of "resolved," even though resolution happens first. Fixed by moving `event_resolved.emit()` + its prints ahead of the return-travel call.

Shown via **`SlideoutViewEventLog`** (`scripts/ui/slideout_view_event_log.gd`), a new `SlideoutPanel` mode (`_Mode.EVENT_LOG`) opened by a small `☰` button (`EventLogToggle`) — a plain sibling under `UI/Root`, not nested inside `LeftToggle` (an earlier attempt to nest it so it'd auto-follow the sidebar's slide was reverted; it doesn't currently move when the sidebar opens/closes — flagged, not yet fixed, see §11).

---

## 4. File & Function Reference

### `scripts/data/`

#### `skill_data.gd` → `class_name SkillData extends Resource`
Plain data now — see §3.1. `Proficiency` enum + `PROFICIENCY_NAMES/_KEYS/_COLORS` + `RANK_SCALE`/`VISIBLE_MAX_RANK`, `skill_name`/`proficiency`/`rank`/`tags`, `get_proficiency_name()/_key()`, `get_scaled_rank()`, `has_tag()`, static `proficiency_key_for()/_name_for()`.

#### `skill_tag_modifier.gd` → `class_name SkillTagModifier extends Resource`
`trigger_tag`, `affects_tag`, `rank_delta`. See §3.1.

#### `agent_data.gd` → `class_name AgentData extends Resource`
| Member | Purpose |
|---|---|
| `id, agent_name, backstory, personality_traits` | Identity (backstory/traits unused so far) |
| `skills: Array[SkillData]` | Source of truth for all stats |
| `supernatural_type, supernatural_power` | Flavour + future synergies |
| `max_health` / runtime `health, morale, experience, level, status` | Condition |
| `equipped_weapon/armor/gadget: EquipmentData`, `magical_item_slot: String` | Real equipment slots (last one still a placeholder string) |
| `setup(name, skills, type)` | Assigns id, seeds health |
| `get_proficiency_scores()` | **Equipment-aware** 0–200 scores — now used, see §3.1/§3.6 |
| `get_effective_scores(counter_tags)` | Counter-tag-aware scores; equipment-aware skills, but *not* stat-boost-aware. Still no callers in resolution |
| `get_proficiency_ranks(active_tags = [])` | **Equipment- and tag-modifier-aware.** The one resolution and the UI use |
| `get_skills()` | Legacy alias → `get_proficiency_scores()` |
| `get_primary_proficiency()` | Highest-scoring category key |
| `can_equip(item) / equip(item) / unequip(slot_type)` | See §3.6 |
| `get_type_name() / get_status_name() / is_available()` | Display + guards |

#### `team_data.gd` → `class_name TeamData extends Resource`
Constants `MIN_SIZE=3`, `MAX_SIZE=5`, `MAX_COHESION_BONUS=0.5`. Holds membership, cohesion, location, the travel-state block, and the newer on-mission state block (§3.4).
`compute_effective_skills(members)` — level-weighted, cohesion-boosted score dict. **Still has no callers** — cohesion still has zero effect on mission outcomes (§10).

#### `event_data.gd` → `class_name EventData extends Resource`
See §3.3. Key methods: `setup()`, `set_proficiency_profile(6 ints)`, `get_proficiency_requirements()` → dict (now a coarse summary, not a resolution input), `get_primary_proficiency()`, `get_total_difficulty()`, `get_urgency_color()`, `is_expired()`. `phases: Array[MissionPhase]` is the sole resolution path (§3.8) — `get_target_values()`/`has_tag()`/`tags`/`counter_tags` no longer exist here, moved to `MissionCheck`.

#### `mission_check.gd` → `class_name MissionCheck extends Resource`
See §3.8. `req_*`, `target_*`, `tags`/`counter_tags`, `check_name`, `resolution_strategy`. `get_proficiency_requirements()`, `get_target_values()`, `resolve(squad)`.

#### `scripts/data/mission_phases/`
`mission_phase.gd` (base, `get_checks()`/`resolve(squad, previous_outcome, log_so_far)` — a coroutine, always call with `await`), `single_phase.gd`, `choice_phase.gd` (`Trigger` enum, `player_choice_picker`). See §3.8.

#### `vehicle_data.gd` → `class_name VehicleData extends Resource`
See §3.5. `compute_travel_hours(distance)`, `can_reach(distance)`, `can_carry(team_size)`, `get_mode_name()`, static `format_duration(hours)`.

#### `base_data.gd` → `class_name BaseData extends Resource`
See §3.7. `setup(name, location)`.

#### `equipment_data.gd` → `class_name EquipmentData extends Resource`
See §3.6.

#### `scripts/data/equipment/`
`equipment_requirement.gd` (base) + `req_proficiency_rank.gd` / `req_skill_tag.gd` / `req_supernatural_type.gd`.
`equipment_effect.gd` (base) + `effect_stat_boost.gd` / `effect_grant_skill.gd` / `effect_modify_skill.gd`.
All described in §3.6.

---

### `scripts/managers/`

#### `game_clock.gd` — `%GameClock` / `Game.game_clock`
Ticks in whole **hours** internally (`hour_advanced(hour)`), `day_advanced(day)` still fires exactly every 24 hours. `HOURS_PER_DAY = 24`, `seconds_per_day = 60.0` (real seconds per game day), `current_day`, `current_hour`, `paused`. `advance_days(n)`/`advance_hours(n)` for debug stepping (ignore `paused`). `set_speed(seconds)` rescales `_accum` proportionally so the sun/progress bar stays continuous across a speed change. `get_day_progress()` (0–1), `get_current_time_days()` (fractional day count — the canonical "now" for travel/mission timing, sub-day precision).

#### `resource_state.gd` — `%ResourceState` / `Game.resource_state`
Unchanged: Funding (500), Intel (20), `earn_*`/`spend_*`, change signals.

#### `concealment_state.gd` — `%ConcealmentState` / `Game.concealment_state`
Unchanged: 0–100 meter, daily decay, threshold signals at 25/50/75/100 (100 stubbed, no Act 3 transition).

#### `agent_manager.gd` — `%AgentManager` / `Game.agent_manager`
`roster: Array[AgentData]`, `starting_roster_size: int = 4`, `generalist_chance: float = 0.6` (§3.2). `get_available_agents()`, `get_agent_by_id()`, `set_status()` — KIA still erases from the roster permanently. `print_roster_status()`.

#### `base_manager.gd` — `%BaseManager` / `Game.base_manager` (new)
See §3.7. `bases`, `global_equipment`, `get_primary_base()`, `get_all_vehicles()`, `get_all_equipment()`.

#### `team_manager.gd` — `%TeamManager` / `Game.team_manager`
| Function | Purpose |
|---|---|
| `_create_starting_team()` | Groups the whole procedurally-generated roster into "Alpha Team" |
| `_at_hq(team)` | Stamps `Game.base_manager.get_primary_base()`'s location onto a new team |
| `create_empty_team(name)` | Bypasses MIN_SIZE — needed for drag-and-drop squad building |
| `create_team(name, ids)` | Validating constructor (enforces 3–5) |
| `rename_team` / `add_member` / `remove_member` / `swap_member` | Membership ops; cohesion scales proportionally rather than resetting |
| `grant_mission_cohesion(id)` | +8 after any mission, win or lose |
| `start_training(id)` / `_finish_training(id)` | 2 days, +12 cohesion |
| `get_best_vehicle(dist, size)` | Now searches `Game.base_manager.get_all_vehicles()` (§3.5) |
| `begin_travel(id, dest, name, event_id)` | Picks vehicle, computes hours, marks members DEPLOYED, records return point |
| `begin_return_travel(id)` | Sends them home; members stay DEPLOYED |
| `_complete_travel(team)` | On arrival: if the event has `mission_duration_hours > 0`, parks the team in `is_on_mission` instead of resolving immediately (§3.4); on the return leg, applies `pending_agent_results` |
| `_complete_mission_work(team)` | New — fires once `mission_ready_day` is reached, emits `team_arrived` |
| `_process` | Checks travel-arrival **and** mission-ready every frame, sub-day precision |

#### `event_manager.gd` — `%EventManager` / `Game.event_manager`
No `resolution_strategy` field anymore — resolution is unconditionally `await MissionPhaseRunner.resolve(event.phases, squad)` (§3.8); both resolve entry points are coroutines.

| Function | Purpose |
|---|---|
| `spawn_templates` / `escalation_templates: Array[EventData]` | Inspector-populated pools (empty by default; see §3.3) |
| `_on_day_advanced` | `magic_intensity += 0.02`; tick events; maybe spawn |
| `spawn_random_event(template?)` | `duplicate(true)`s the chosen template `EventData`, scales reqs, places at a real city |
| `deploy_team(event_id, team_id)` | Marks event DEPLOYED, delegates to `begin_travel` |
| `_on_team_arrived(team_id, event_id)` | `await MissionPhaseRunner.resolve(...)`, backfills any missing `agent_results`, **emits `event_resolved` before calling `begin_return_travel()`** (fixed ordering bug — see §3.9), stashes outcomes as pending, starts the return trip |
| `_backfill_agent_results(members, result)` | Fills in AVAILABLE for any squad member a strategy's `agent_results` left out, so a strategy that doesn't mention an agent can't strand them DEPLOYED forever. No status change means they came home safe |
| `_apply_resolution(event, result)` | Rewards / concealment / final status |
| `_print_resolution_log(result)` | Prints `result.log_lines` under the one-line summary (§3.8) |
| `resolve_event_solo(event_id, agent_id)` | Legacy instant path (also a coroutine now) — unused by UI, applies statuses immediately, also backfilled |

#### `skill_handler.gd` → `class_name SkillHandler extends RefCounted`
See §3.1. `RANK_THRESHOLDS`, `tag_modifiers`, `compute_effective_rank()`, `compute_proficiency_rank(skills, active_tags?)`, `is_countered_by()`, `instantiate(base, rank)`, `get_skills_for_proficiency(prof)`, `empty_proficiency_dict()`/`empty_rank_dict()`.

#### `equipment_handler.gd` → `class_name EquipmentHandler extends RefCounted`
See §3.6.

#### `mission_resolver.gd` → `class_name MissionResolver extends RefCounted`
**Decoupled from `EventData`/`MissionCheck` this pass** — every function below takes a plain requirements `Dictionary` (`get_proficiency_requirements()`'s shape), not either concrete type, so the same math serves real resolution (against a `MissionCheck`) and UI previews (against an `EventData`) alike.

| Function | Purpose |
|---|---|
| `compute_rank_coverage(ranks, reqs)` | Mean of `clamp(rank / required_rank, 0, 2)` across required proficiencies |
| `compute_team_ranks(members, active_tags?)` | "teamwork" pooling, marked experimental in code. Every member's *effective* skills (own + equipment-granted/modified) are pooled into one shared pile per category *before* rank aggregation, instead of each member's rank being computed independently and the team taking the best. Two agents with one rank-2 skill each can jointly reach rank 3. Each member's equipped flat-rank effects apply on top afterward. Reduces to a solo agent's own ranks for a 1-member team |
| `compute_team_scores(members)` | Simple per-member sum (score is linear, no threshold quirks) |
| `compute_score_coverage(team_scores, reqs)` | Score-based counterpart to rank coverage, comparing against `req × RANK_SCALE` |
| `compute_team_suitability(reqs, members, active_tags?)` | `lerp(rank_coverage, score_coverage, SCORE_WEIGHT=0.2) + synergy_bonus(stub, 0.0)`. Score is a smaller-weighted continuous nudge so equipment bonuses too small to cross a rank threshold still move suitability |
| `compute_value_coverage(values, targets, reqs)` | Continuous counterpart to rank coverage — `TagBreadthResolutionStrategy`'s pooled tag-weighted totals vs. `target_*`, gated by `reqs` still being >0 |
| `compute_mission_suitability(phases, members)` | **New** — the deploy screen's match%, averaged across an event's phases (§3.8) |
| `resolve_from_suitability(suitability, squad, log_lines?, chance_multiplier?)` | **New** — turns a suitability float into the full roll/outcome/injury result, shared by both resolution strategies; also builds `MissionResolutionResult.log_lines` (§3.8) |

#### `agent_generator.gd` → `class_name AgentGenerator extends RefCounted` (new)
See §3.2. `Archetype` enum, `generate_specialist()`, `generate_generalist()`, `generate_random_specialist()`, `generate()`.

#### `name_generator.gd` → `class_name NameGenerator extends RefCounted` (new)
See §3.2. `FIRST_NAMES`/`LAST_NAMES` (50 each), `generate_name()`.

#### `scripts/managers/resolution/` (the Strategy pattern — now resolves against `MissionCheck`, not `EventData`)
- `mission_resolution_strategy.gd` → `class_name MissionResolutionStrategy extends Resource` — base, `resolve(check: MissionCheck, squad) -> MissionResolutionResult`.
- `stat_check_resolution_strategy.gd` → `class_name StatCheckResolutionStrategy extends MissionResolutionStrategy` — the original math: `chance = clamp(0.3 + suitability*0.4, 0.05, 0.95)`; roll ≤ chance×0.6 → success, ≤ chance → partial, else failure; injury 5%/15%/`lerp(15%,50%,badness)`; KIA = injury × 0.2. `MissionCheck`'s default.
- `tag_breadth_resolution_strategy.gd` → `class_name TagBreadthResolutionStrategy extends MissionResolutionStrategy` — **new alternate strategy**, see §3.8. `@export var missing_prereq_penalty: float = 0.75`.
- `mission_resolution_result.gd` → `class_name MissionResolutionResult extends RefCounted` — `Outcome` enum (SUCCESS/PARTIAL/FAILURE), `roll`, `chance`, `team_suitability`, `agent_results: Dictionary`, `log_lines: PackedStringArray` (new — human-readable resolution trace, §3.8). The contract every strategy must fill in and every caller (EventManager, UI) reads.
- `mission_phase_result.gd` → `class_name MissionPhaseResult extends RefCounted` — what one `MissionPhase.resolve()` hands `MissionPhaseRunner`: `ran`, `outcome`, `agent_results`, `log_lines`. See §3.8.

#### `mission_phase_runner.gd` → `class_name MissionPhaseRunner extends RefCounted`
Static, a coroutine (`await` it). `resolve(phases, squad) -> MissionResolutionResult`. See §3.8.

#### `event_log.gd` → `class_name EventLog extends Node` — `%EventLog` / `Game.event_log`
See §3.9. `entries: Array[EventLogEntry]`, `signal entry_added(entry)`.

#### `event_log_entry.gd` → `class_name EventLogEntry extends RefCounted`
`day`, `hour`, `text`, `format_timestamp()`. See §3.9.

---

### `scripts/` (geoscape)

Unchanged from the previous version of this doc — `GeoscapeController.gd`, `GeoData.gd`, `MarkerLayer.gd` (now reads `Game.base_manager.get_primary_base()` for the HQ pin instead of `TeamManager.HQ_NAME`/`HQ_LOCATION`), `SurfaceMarker.gd`, `travel_path_layer.gd`. See §8 for the marker/shader-sync gotchas, still current.

---

### `scripts/ui/`

| File | Node | Role |
|---|---|---|
| `root_ui.gd` | `UI/Root` | Sidebar tweens, slideout positioning, central signal-to-panel wiring |
| `top_bar.gd` | `TopBar` | Date, pause, speed, funding, intel, concealment bar |
| `agent_tab.gd` | `%SquadList` | Squad list, drag-and-drop, "+ New Squad" |
| `events_tab.gd` | `%EventList` | Active events sorted by urgency then time |
| `equipment_tab.gd` | `%EquipmentList` (new) | Right-sidebar equipment locker list — see §3.6 |
| `detail_sidebar.gd` | `%DetailPanel` | Left panel loader — `_View` enum (`EMPTY, AGENT, TEAM, EVENT, RESULT, HQ`) |
| `slideout_panel.gd` | `%SkillSlideout` | Pop-out loader — `_Mode` enum now `PROFICIENCY, DEPLOY, VEHICLE, EQUIPMENT_INFO, EQUIP_SLOT, EVENT_LOG` |
| `event_map_labels.gd` | `%EventMapLabels` | Clickable title chips above each event pin |
| `mission_choice_dialog.gd` | `%MissionChoiceDialog` / `Game.mission_choice_dialog` | Full-screen player-choice modal (§3.8) |

**Detail views** (`extends "res://scripts/ui/detail_view_base.gd"` by path, no `class_name`):
- `detail_view_agent.gd` — proficiency rank pips **and now the raw score number** (clickable rows → slideout), a new **Equipment** section (3 clickable slots → equip picker), condition, team, supernatural.
- `detail_view_team.gd` — editable name, cohesion, location — now with three states (at base / en route / **on mission**, new), team proficiency ranks, members.
- `detail_view_event.gd` — Requirements section is now a **per-phase breakdown** (phase count, trigger notes, per-option rank pips), not a flat list from `EventData`'s old top-level fields; also a "Phases: N" info row. See §3.8.
- `detail_view_hq.gd` — vehicles (now the primary base's, via `Game.base_manager`), squads (now with an **on mission** state too), **base-local equipment** (was a "Coming soon" placeholder, now real — clickable rows → info slideout), Base Upgrades still a placeholder.
- `detail_view_result.gd` — unchanged.

**Slideout views** (`extends "res://scripts/ui/slideout_view_base.gd"` by path):
- `slideout_view_proficiency.gd` — rank pips **and the score number**; per-skill cards now read `EquipmentHandler.get_effective_skills()` instead of `agent.skills` directly, so gear-granted/modified skills actually appear here.
- `slideout_view_deploy.gd` — per-team card now has a third early-return state for `is_on_mission` (previously only handled `is_traveling`), matching text style.
- `slideout_view_vehicle.gd` — unchanged.
- `slideout_view_equipment.gd` (new) — read-only item info card (slot, description, requirements, effects, each with `get_description()`).
- `slideout_view_equip_slot.gd` (new) — the agent-sheet equip/unequip picker.
- `slideout_view_event_log.gd` (new) — the event log panel (§3.9), newest entry first, live-refreshing.

#### `scripts/debug/debug_driver.gd`
Unchanged keys: `1` spawn event · `2` list events · `3` deploy first team to most urgent · `4`/`5` advance 1/7 days · `6` toggle pause · `7` roster · `8` resources · `9` full status · `0` team status · `T` train first team.

---

## 5. Signal Map

```
GameClock          hour_advanced(hour)
                   day_advanced(day) ──┬──► ConcealmentState._on_day_advanced   (decay)
                                       ├──► EventManager._on_day_advanced       (intensity, tick, spawn)
                                       ├──► TeamManager._on_day_advanced        (training)
                                       ├──► TopBar._update_date
                                       └──► EventsTab._refresh
                   pause_changed(paused) ──► TopBar

ResourceState      funding_changed / intel_changed ──► TopBar
ConcealmentState   concealment_changed / threshold_crossed / revelation_triggered ──► TopBar

AgentManager       roster_changed / agent_status_changed ──► SquadList, DetailPanel

TeamManager        team_created / team_renamed / membership_changed /
                   cohesion_changed / training_started / training_completed
                                                    ──► SquadList, DetailPanel
                   team_departed(team_id)           ──► DetailPanel, TravelPathLayer, EventLog
                     (fires for BOTH the outbound leg and the return leg — EventLog
                      reads team.travel_is_return, already set before either emit,
                      to log "departed for X" vs. "set out for home, to X")
                   team_arrived(team_id, event_id)  ──► EventManager._on_team_arrived  ★
                                                         DetailPanel, TravelPathLayer, EventLog
                     (now fires after mission_duration_hours elapses on-site,
                      not on physical arrival — see §3.4/§6; event_id == "" means
                      "just a return, nothing to resolve" — EventLog logs "returned to X"
                      instead of "arrived at X" for that case)

EventManager       event_spawned  ──► MarkerLayer, EventMapLabels, EventsTab, EventLog
                   event_expired  ──► MarkerLayer, EventMapLabels, EventsTab, EventLog
                   event_resolved(event, team_name, result: MissionResolutionResult)
                                  ──► MarkerLayer, EventMapLabels, EventsTab, EventLog,
                                      DetailPanel._on_mission_resolved (auto mission report)
                     (team_name is now its own signal parameter, not smuggled into the
                      result dict; result is a typed MissionResolutionResult, not a Dictionary.
                      Emitted BEFORE _on_team_arrived() calls begin_return_travel() — see §3.9
                      for the ordering bug this fixes)
                   event_escalated ──► EventLog

EventLog           entry_added(entry: EventLogEntry) ──► SlideoutViewEventLog (live refresh)

MarkerLayer        event_marker_clicked(ev) ──► RootUI._on_event_selected
                   hq_marker_clicked()      ──► RootUI._on_hq_selected
                   event_marker_added/removed ──► (GeoscapeController detail quad — disabled)

GeoscapeController globe_clicked(pos) ──► MarkerLayer._on_globe_clicked

UI                 SquadList.agent_selected / .team_selected ──► RootUI
                   EventList.event_selected                  ──► RootUI
                   EventMapLabels.event_label_clicked        ──► RootUI
```

★ **The load-bearing connection**, now carrying more weight than before: `TeamManager` still doesn't know what a mission is, but it now also owns the on-site *waiting* before this signal fires. `EventManager` didn't need to change at all when that wait was added — proof the seam is in the right place.

---

## 6. The Current Game Loop

### Per-day / per-hour tick (automatic)

```
GameClock accumulates real seconds → seconds_per_hour elapsed → hour_advanced(h)
                                    → every 24th hour also fires → day_advanced(n)
  │
  ├─ ConcealmentState  : value -= 1.0  (public forgets, on day_advanced)
  │
  ├─ EventManager      : magic_intensity += 0.02  (on day_advanced)
  │                      for each ACTIVE event: days_remaining -= 1 → EXPIRED / escalate
  │                      roll spawn from spawn_templates (chance = clamp(0.35 × intensity, 0, 0.95))
  │
  └─ TeamManager       : training countdowns (on day_advanced)
                         every frame (_process, sub-day precision):
                           traveling team, arrival reached?      → _complete_travel()
                           on-mission team, ready day reached?   → _complete_mission_work()
```

### Player action loop

```
1. NOTICE      Event spawns → pin, chip, Events tab entry (unchanged).

2. INSPECT     Click through to DetailPanel EVENT view (unchanged).

3. DISPATCH    "Deploy Team ›" → SkillSlideout DEPLOY mode. Per squad:
                 • match % — MissionResolver.compute_mission_suitability(),
                   averaged across the event's phases (§3.8), each itself a
                   blend of rank coverage and score coverage
                 • members available, distance, travel time, vehicle
                   (now sourced from Game.base_manager.get_all_vehicles())
               A team already is_on_mission elsewhere shows that status
               and can't be redeployed (same as an is_traveling team).

4. TRAVEL      EventManager.deploy_team() → event DEPLOYED, TeamManager.begin_travel().
               DetailPanel shows "Team Deployed"; TravelPathLayer draws the arc.

5. WORK        (New leg.) On arrival, TeamManager checks event.mission_duration_hours.
               If > 0: team enters is_on_mission instead of resolving immediately.
               UI shows "On mission at X — Nh left" (squad sheet, HQ squads list,
               deploy picker) instead of misleadingly showing "at base".

6. RESOLVE     Once mission_ready_day is reached, team_arrived fires (same signal
               as before, just later) → EventManager._on_team_arrived (a coroutine):
                 • await MissionPhaseRunner.resolve(event.phases, squad) — runs
                   every phase in order (§3.8); if a ChoicePhase's trigger is
                   PLAYER_CHOICE, resolution SUSPENDS here until the player
                   picks in MissionChoiceDialog. Everything else keeps running
                   meanwhile (GameClock isn't paused for this).
                 • _backfill_agent_results() — any squad member no phase
                   mentioned defaults to AVAILABLE (safety net, not a
                   silent-forever-DEPLOYED bug)
                 • rewards / concealment applied, event status set
                 • cohesion +8
                 • event_resolved emitted + logged (EventLog, §3.9) — BEFORE
                   the team is sent home, so the log reads in the right order
                 • agent outcomes stashed in pending_agent_results ← NOT
                   applied yet
                 • begin_return_travel()
               DetailPanel auto-pops the Mission Report (now includes the
               resolution trace — result.log_lines, §3.8).

7. RETURN      Arrival home → _complete_travel() applies pending outcomes:
               Available / Injured / KIA (KIA = erased from roster, permanently).
               Team is unavailable for the WHOLE round trip — travel there,
               the mission itself, and travel back.
```

### Squad management (parallel, any time)

Unchanged.

### What's missing from the loop

Still thin in the same ways as before: no progression, no economy sink, no narrative. Funding and Intel accumulate with nothing to spend them on beyond equipment sitting in a locker with no acquisition cost. Agents never level up. Cohesion still does nothing. See §11.

---

## 7. Coding Conventions & Best Practices

Unchanged from the previous version of this document — strict typing, `##` doc comments explaining *why*, section headers, signals at the top, `_private` prefix, `@export` for tunables. Architectural rules 7–13 (managers own state, every mutation emits, constants live with their concept, data classes never touch the scene tree, `call_deferred` batching, wholesale UI rebuild, gate-don't-delete) all still hold and now additionally apply to the Handler layer (§1): handlers compute, they never emit or hold state.

One addition:

16. **New `class_name` scripts need cache registration for headless verification the same way as always** (see §8 gotcha #1) — this project added a *lot* of new `class_name` scripts this pass (every equipment class, `BaseData`/`BaseManager`, `AgentGenerator`/`NameGenerator`, the whole resolution-strategy family). If a headless run reports "Identifier not found" for a class you know exists, check the cache first before assuming a real bug.

18. **A function that ever `await`s anything is a coroutine for every caller, forever** — `ChoicePhase.resolve()` → `MissionPhaseRunner.resolve()` → `EventManager`'s two entry points are now all `await`-chained because of one `PLAYER_CHOICE` branch three calls deep. Call with `await` even on a call that resolves synchronously in practice (no real suspension happens unless the awaited thing is an actual `Signal` or another coroutine that itself suspends) — the `await` keyword itself is free when nothing actually yields.

### Verification

Unchanged commands and expected output shape — `--headless --path . --quit`, never truncate the output. One new environment-specific caveat worth recording:

17. **Headless `--script` runs that instantiate `Node`-derived manager classes directly (e.g. `EventManager.new()`, `AgentManager.new()`) have been unreliable in this environment** — intermittent hangs, seemingly tied to the Godot editor being open on the same project concurrently rather than to the code itself. Prefer testing `RefCounted`/`Resource`-based logic (handlers, data classes) directly, which has been consistently reliable; fall back to the plain `--quit` parse check plus manual playtesting for anything that needs a live manager instance.

---

## 8. Gotchas Learned The Hard Way

All 14 entries from the previous version of this document still apply unchanged. Additions from this pass:

| # | Gotcha | Fix / Rule |
|---|---|---|
| 15 | **`Resource.duplicate()` doesn't reliably isolate `PackedStringArray` export fields from copy-on-write sharing.** Mutating a `var t := dup.some_packed_array; t.append(x); dup.some_packed_array = t` pattern can still mutate the *original* Resource's array, even though `dup` and the original are genuinely different instances (confirmed: a plain `int` field duplicates and isolates correctly; a `PackedStringArray` field did not, in this Godot 4.7 build). | Build the new array from scratch (`PackedStringArray()` + append each element read from the *original*) instead of deriving it from a `.duplicate()`d property. See `EffectModifySkill.apply_to_skills()`. |
| 16 | **`%`-lookups fail from any dynamically-created node** (`Control.new()` + `add_child()`), because `add_child()` alone never assigns `owner`, and `%` resolves by walking the `owner` chain. | Use the `Game` autoload registry (§1) instead for anything a dynamically-built view needs to reach. |
| 17 | **Godot autoloads aren't resolvable as bare identifiers from a standalone `--script` `SceneTree` run** — `Identifier not found: Game` even though the project's `[autoload]` entry is correct and the game runs fine normally. **This applies even if the reference is in a branch that never executes** — the compiler resolves every identifier in a script at load time, so a production file that references `Game` anywhere at all (e.g. `ChoicePhase._pick_check()`'s fallback to `Game.mission_choice_dialog`, only reached when no picker is injected) can't be `--script`-tested in isolation even with a test that never takes that branch. Worked around by temporarily appending test code to an existing autoload-adjacent manager's own `_ready()` (where `Game` is genuinely available) and running the *real* `--quit` boot instead, then reverting the test code afterward. |
| 18 | **GDScript lambda closures capture outer local variables by VALUE, not by reference** — `var n := 0; var f := func(): n += 1; f.call(); print(n)` still prints `0`. This bit ad-hoc test code twice this pass (a counter meant to track how many times an injected callback fired, silently staying at its initial value). Reference types (`Array`, `Dictionary`, `Object`) don't have this problem — `results.append(x)` inside a lambda *does* mutate the outer `Array`, since the "copy" is a copy of the reference. For anything that needs a lambda to report back a scalar, use a small `RefCounted` tracker object with real fields (and a bound-method `Callable`) instead. |
| 19 | **A ternary between two array literals doesn't preserve static `Array[T]` typing** — `func f() -> Array[MissionCheck]: return [x] if x != null else []` compiles, but the caller's `var y := f()` throws `Trying to assign an array of type "Array" to a variable of type "Array[MissionCheck]"` at runtime, because the ternary's result is a plain untyped `Array`, not coerced to match the declared return type. Fix: build the typed array explicitly (`var result: Array[MissionCheck] = []; if x != null: result.append(x); return result`) instead of a ternary between literals. |
| 20 | **`core.ignorecase` (Windows default) lets git's tracked path casing silently diverge from the actual on-disk filename** — this repo's `scripts/game.gd` was tracked by git in lowercase (matching every other file's snake_case convention and the GDD's own references to it) while the file on disk had somehow become `Game.gd`, which Godot warned about on every single boot ("Case mismatch... will not open when exported to other case-sensitive platforms") without ever actually breaking anything on Windows. Fixed with a two-step `git mv` through a temporary name (a same-target-different-case `git mv` is a no-op on a case-insensitive filesystem) to force git's index back in sync with the intended casing. Worth checking for on any file whose on-disk name doesn't match what's referenced elsewhere, especially after any rename done outside of git. |

---

## 9. Divergences From The Original GDD

All entries from the previous version still hold, plus:

| Original GDD says | Reality |
|---|---|
| (not mentioned) | **Mission resolution is a swappable Strategy pattern**, not a single hardcoded function. The current math is unchanged in substance, just relocated behind `MissionResolutionStrategy` |
| (not mentioned) | **Agents are procedurally generated** (Specialist/Generalist archetypes, generated names), not a fixed hand-authored roster |
| (not mentioned) | **Equipment is a real, composable system** — requirements and effects assembled from independent Resources in the Inspector, not a design gap |
| (not mentioned) | **Missions take real time on-site**, not just travel time — a third leg between arrival and resolution |
| No mention of vehicles/bases | HQ + a vehicle fleet exist, and are now owned by a `BaseManager` designed (but not yet used) for multiple bases |
| (not mentioned) | **A mission is a sequence of phases, not one check** — travel + infiltration + retrieval-style structure, with a second alternate resolution math (tag-breadth pooling) and a real mid-mission player choice, none of which the original GDD anticipates at all |
| (not mentioned) | **A running event log** records what's happened all session — not part of the original design |

Milestone 1 checklist unchanged from the previous version — still substantially complete, same items checked.

---

## 10. Known Gaps & Tech Debt

**Dead or orphaned code**
- `TeamData.compute_effective_skills()` — still no callers. **Cohesion still has no effect on mission outcomes**, despite two separate pooling mechanics (`MissionResolver`'s "teamwork" pooling, `TagBreadthResolutionStrategy`'s redundancy pass) landing since. Still the highest-value cleanup/wiring task, unchanged pass over pass.
- `AgentData.get_effective_scores(counter_tags)` and `SkillHandler.is_countered_by()` — still no callers from `StatCheckResolutionStrategy`. **`counter_tags` is no longer uniformly inert, though** — it moved from `EventData` to `MissionCheck` this pass, and `TagBreadthResolutionStrategy`'s Modifier Pass genuinely reads it (zeroes a skill's effective rank). So counter-tags now do something, but only for checks using that strategy — `StatCheckResolutionStrategy` (the default) still ignores it entirely. Worth a deliberate decision either way rather than leaving it strategy-dependent by accident.
- `EventManager.resolve_event_solo()` — still unused by UI.
- ~~`AgentData.compute_suitability(event)`~~ — **actually removed this pass** (it referenced `event.tags`, which no longer exists on `EventData`; had no callers, so deleting was safe). Cross this one off for real.
- `EventData.assigned_agent_ids` — never populated.
- `EventData` decision fields — still scaffolding only.
- A leftover empty, scriptless `"Game"` Node still sits in `Main.tscn` from before the registry became an autoload (§1) — dead, not yet removed.

**Balance issues**
- `RANK_THRESHOLDS` tiers 6 and 7 are still identical → rank 6 still unreachable. Unfixed.
- Injury/KIA rates still unvalidated guesses.
- The "teamwork" skill-pooling model, the rank/score suitability blend, and now `TagBreadthResolutionStrategy`'s whole redundancy-weighting curve are all **explicitly marked experimental** — least playtested of everything here.
- `TagBreadthResolutionStrategy.missing_prereq_penalty` (default 0.75, tuned down once already from an initial 0.5 that playtested as too harsh) is still a single guessed number, not validated further.
- Only 1 of 7 event templates and 1 equipment item are actually wired into their respective Inspector arrays right now. **This is now a sharper problem than before**: the other 6 templates predate the mandatory-`phases` rework, so if one were dragged into `spawn_templates` today it would spawn with an empty `phases` array — `MissionPhaseRunner` would log a warning and resolve *nothing*, forever, for that event. Any of those 6 needs actual phases/checks authored before it's usable, not just a drag-and-drop.

**Systems intentionally missing**
- No vehicle/equipment scheduling or exclusivity — pooled across all bases with no ownership checks.
- `operation_cost` still displayed, never charged.
- No save/load.
- Agents never gain XP or level.
- `morale` never changes.
- `magical_item_slot` is still an inert string (the only one of the four original slots not covered by the new equipment system).
- No multi-base gameplay yet — `BaseManager` is ready for it, nothing uses it (§3.7).
- No mid-mission decision UI outside of `ChoicePhase.PLAYER_CHOICE` — that one case is real now (§3.8), but the older, separate `EventData` decision-event fields (`is_decision_event` etc.) are still untouched scaffolding, a different half-built feature.

**Untested / unverified**
- Everything visual still verified only by headless parse plus occasional manual spot-checks, not systematic playtesting.
- Long-run behavior (50+ days) still never observed.
- The mission-duration state machine (§3.4) has only been verified by code tracing and a clean headless parse — deeper functional headless testing was unreliable in this environment (§7); worth a manual playtest pass.
- **`MissionChoiceDialog`'s actual look and click-handling has never been manually playtested** — every check on the async resolution chain and the injectable-picker mechanism was verified headlessly (§3.8), but nobody has looked at the real dialog rendering or clicked an option in a running editor.
- **`EventLogToggle` doesn't currently follow the left sidebar's slide animation** — an attempt to fix this by nesting it under `LeftToggle` was tried (in-editor) and reverted; it's back to a plain `UI/Root` sibling with a fixed position, so it visually detaches from the sidebar edge when the sidebar opens. Unresolved.
- The deploy screen's match% (`compute_mission_suitability`) correctly reads each phase's own `MissionCheck.req_*`, not `EventData`'s top-level (now-vestigial) copy — but a `MissionCheck` authored with no `req_*` set at all still reports 100% for that check specifically (the same "nothing required, trivially satisfied" convention `compute_rank_coverage` has always had). Only matters for a `MissionCheck` someone forgot to fill in; not currently an issue for `magical_surge.tres`, whose checks all have real requirements.

---

## 11. Roadmap To A Playable Slice

**Target:** unchanged — 45–60 minutes of play with real decisions, visible progression, an arc.

### What this pass actually built

Worth stating plainly since it's easy to lose track of: this pass added **mission-structure depth** (multi-stage/branching missions, a second alternate resolution strategy, a real player-choice pause, an event history log) rather than advancing the Phase A–D checklist below. That checklist is **exactly where it was** — nothing in it got smaller. This was a deliberate, valuable detour (the game now has real moment-to-moment texture during a mission, not just a single roll), but it means Phase A is still the highest-value next move, not something to defer further in favor of more mission-mechanics work.

### Phase A — Make existing systems matter *(highest value per effort, unchanged priority)*

1. **Cohesion affects outcomes.** Still open. Now with *two* precedents to follow instead of one: `TagBreadthResolutionStrategy`'s Modifier Pass (rank deltas from tag matches) and `EquipmentHandler`'s `apply_to_ranks` hook are both "adjust a rank based on some external factor" patterns cohesion could reuse directly — e.g. a flat rank/score bonus scaled by `team.cohesion`, applied in `MissionResolver.compute_team_ranks()` or `compute_team_scores()` right where equipment effects already apply.
2. **Counter-tags do something, consistently** — no longer fully inert (`TagBreadthResolutionStrategy` reads `MissionCheck.counter_tags` now), but `StatCheckResolutionStrategy` (the default) still ignores it entirely. Decide: wire it into `StatCheckResolutionStrategy` too, or document it as a `TagBreadthResolutionStrategy`-only mechanic on purpose.
3. **Charge `operation_cost` and equipment acquisition cost.**
4. **Fix the rank-6 threshold gap** (`RANK_THRESHOLDS` tiers 6/7 identical).
5. **Agent XP and levelling.**

### Phase B — Economy and progression

6. **Hire pool** (`AgentGenerator` already built as the engine — UI + funding-cost task).
7. **Research system.**
8. **Vehicle and equipment acquisition** (`BaseData`/`BaseManager` data model ready, no way to add to it outside the Inspector).

### Phase C — Narrative texture

9–11. Unchanged: decision events, concealment threshold events, event flavor text. Note `ChoicePhase.PLAYER_CHOICE` (§3.8) is a *different*, already-built mechanism from the still-scaffolding `EventData.is_decision_event` fields — worth deciding whether decision events become "an event whose one phase is a PLAYER_CHOICE ChoicePhase" rather than a separate system.

### Phase D — Slice completion

12–15. Unchanged: save/load, onboarding, a slice ending, a balance pass — now with more to balance (mission duration, teamwork pooling, score/rank blend weight, `TagBreadthResolutionStrategy`'s redundancy curve, `missing_prereq_penalty`).

### Deliberately deferred

Act 2–5 systems, factions, tactical combat, mirror worlds, real multi-base gameplay (§3.7).

---

## Next Session — Concrete Plan

Small, mechanical cleanup first (cheap, removes rough edges from *this* pass), then back to Phase A, which is still the actual priority.

### 1. Cheap fixes left over from this pass *(~30–60 min, do these first)*

- **`EventLogToggle` doesn't follow the sidebar.** Re-add the tween in `root_ui.gd._apply_left()` for `%EventLogToggle`'s `offset_left`/`offset_right` (mirroring `$LeftToggle`'s) — was written once already this pass, then removed when the node was briefly (and unstably) reparented under `LeftToggle` in-editor; it's back to a plain sibling now, so the code-level fix applies again. See §10.
- **Playtest `MissionChoiceDialog` for real.** Everything about it was verified headlessly (async chain, injectable picker, log threading) but nobody has looked at the actual rendering or clicked a real option. Add a `PLAYER_CHOICE` `ChoicePhase` to a live event template (or a debug-driver key) and actually trigger it in a running editor.
- **Author phases for at least 2–3 more event templates.** 6 of 7 templates on disk (`data/event_templates/*.tres`) predate the mandatory-`phases` rework — dragging any of them into `spawn_templates` today would spawn an event that silently never resolves (empty `phases`, `MissionPhaseRunner` just warns). Either give them real phases/checks or leave them out of the pool until someone does.

### 2. Phase A, in priority order

1. Cohesion affecting outcomes (item 1 above) — the single highest-value item on the whole roadmap, unchanged for at least two passes running.
2. Counter-tags decision (item 2 above).
3. Rank-6 threshold fix — smallest, most mechanical item here; good warm-up before the cohesion work.
4. `operation_cost` charging.
5. Agent XP/leveling — biggest of the five, probably its own session.

### 3. If there's time left over

Pick up Phase B (hire pool is the most self-contained — `AgentGenerator` already does the hard part).

---

## 12. Expanded Features (Discussed, Not Built)

Two items from the previous version of this list have moved to **built** (equipment — §3.6; base management's data-model half — §3.7) and are removed from here. Remaining:

### Fast travel between fixed bases
Now has a real foundation to build on (`BaseManager`/`BaseData` exist), but the actual gameplay — founding/acquiring a second base, fast-travel mechanics between them — is unbuilt. Same open questions as before: acquisition method, cost per use, instant vs. timed.

### Teleportation
Unchanged — `VehicleData.Mode.TELEPORT` still an unused seam.

### Expanded vehicle fleet
Unchanged in substance; now naturally scoped per-base rather than per-org, which changes "progression" framing slightly — a second base could come with (or need) its own vehicle rather than sharing one global fleet.

### Base management (gameplay half)
The data model exists (§3.7); the HQ panel's Equipment section is now real (§3.6), Base Upgrades is still a placeholder. Founding/upgrading additional bases is unbuilt.

### Supernatural synergies
Unchanged — `MissionResolver._compute_synergy_bonus()` still stubbed at `0.0`. Note the newer equipment/tag-modifier systems are adjacent but distinct extension points that could inform how this eventually gets built.

### Multi-leg / relay travel
Unchanged — still a hard range cutoff, not staged travel.

### Awakened skill catalog
New item: `AgentGenerator` only produces mundane agents because there's no skill catalog for any `SupernaturalType` other than `NONE`. Building one (and deciding how Awakened agents should generate differently) is a natural next step once mundane content feels complete.

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
| Starting roster size / generalist ratio | `agent_manager.gd` | 4 / 60% |
| HQ location | `base_manager.gd` (seeded default) | Berlin (13.405, 52.52) |
| Vehicle speed / range / capacity | `data/vehicles/eurocopter_h225.tres` | 320 km/h / 3000 km / 8 |
| Skill rank scale | `skill_data.gd` | ×20 |
| Visible max proficiency rank | `skill_data.gd` | 5 (of 10) |
| Suitability score-vs-rank weight | `mission_resolver.gd` | 20% score / 80% rank |
| Default mission duration | `event_data.gd` | 2.0 hours |
