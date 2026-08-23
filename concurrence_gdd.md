# The Concurrence — Game Design Document

*This document owns the premise, narrative arc, and design principles — the vision. For how systems actually work, see the companion docs: **`concurrence_technical_gdd.md`** (implementation, architecture, current build status, roadmap) and **`concurrence_agent_design_merged.md`** (detailed agent/squad design — skills, personality, quirks). Where those docs are more specific or more current than what's below, they win; this document stays high-level rather than duplicate them.*

## Premise

An alternate-universe Earth where magic is real but suppressed by a shadow council. The player commands a global network of rapid-response agents — the magical equivalent of the Men in Black — who intercept supernatural events before they go public. A global sensor grid detects magical surges and gives agents a head start.

What begins as routine containment work escalates into a world-ending crisis: the planet and its many "mirror" realities are being merged together by an unknown power seeking to exploit the revealed magic for total dominion. The player must try to prevent the Concurrence, and when that fails, survive the fallout and fight back.

---

## Narrative Arc

### Act 1 — Containment (Early Game)
Mundane firefighting. Cryptid sightings, minor hauntings, artifact activations, small cults. The tone is procedural — a paranormal agency doing its job. Events are manageable and the concealment meter stays low. Slowly, anomalies stop fitting known patterns. Ley line readings spike in ways the models can't explain. Reports of "double places" trickle in — locations that seem to exist in two states at once.

### Act 2 — Escalation
The mirror worlds become undeniable. Portal breaches increase, fae diplomats arrive uninvited, and entire neighborhoods phase between realities. The player juggles increasingly dangerous events while researching the Concurrence. Key decision events force moral and strategic trade-offs. Concealment becomes harder to maintain; the question shifts from "if" to "when."

### Act 3 — Revelation
Concealment breaks. Magic goes public. The fallout is catastrophic — governments fracture, the shadow council splinters, and the player's infrastructure is gutted. The player is left with a single base and a skeleton crew. This is effectively a soft reset and acts as the true "start" of the second half of the game.

### Act 4 — Resistance
Rebuild from the ashes. The world now knows magic is real, which changes the tone and available options. Former enemies may become allies. The player recruits openly, develops overt magical capabilities, and prepares for a direct confrontation with the power behind the Concurrence.

### Act 5 — Final Battle
The source of the Concurrence is located. The player launches a final operation with everything they've built. Multiple endings based on preparation, alliances, and decisions made throughout the game.

---

## Existing Foundation

- Geoscape with day/night cycle and seasonal day tracking
- Basic weather system
- Climate biomes
- Country borders
- Major cities

---

## Core Systems

*Sections 1–3 (Event System, Agent System, Concealment Meter) are implemented — see `concurrence_technical_gdd.md` for how they actually work. Sections 4–8 remain design targets. Where a description below differs from what's actually built, the technical GDD and `concurrence_agent_design_merged.md` are authoritative.*

### 1. Event System
The heartbeat of the game. Magical events spawn on the geoscape and must be dealt with before they escalate or expire.

**Features:**
- Events spawn at locations on the map with type, urgency, proficiency requirements, and a time limit
- Event types: Cryptid Sighting, Magical Surge, Artifact Activation, Portal Breach, Cult Activity, Fairy Incursion, Haunting, Mirror Merge
- Urgency tiers (Low / Medium / High / Critical) with visual distinction on the map
- Spawn rate and difficulty scale with global magic intensity, which rises over time
- Events that expire unresolved add to the concealment meter and may chain into worse events
- Some events are multi-stage (e.g., a cult activity that, if failed, escalates into a portal breach)
- Region-specific flavor — events in Transylvania feel different from events in Tokyo

**Decision Events:**
- Special narrative events that pause the game and present 2–4 choices
- Choices have trade-offs across concealment, resources, agent morale, faction relations, and long-term consequences
- Examples: a journalist with proof, a child manifesting powers, fae demanding diplomatic recognition, mirror-world refugees
- Some decisions have delayed consequences that surface acts later

### 2. Agent System
Agents are the player's primary resource. Building a well-rounded roster is the core strategic challenge.

**Full design lives in `concurrence_agent_design_merged.md`** — six operational Proficiencies (Combat, Subterfuge, Attunement, Erudition, Influence, Ingenuity) derived from tagged underlying skills, a five-axis Personality Matrix, Archetypes, Crucibles/Quirks, and the full squad-building tension design. What follows here is the high-level summary.

**Features:**
- Six Proficiencies derived from tagged skills, not set directly — implemented (see technical GDD §3.1)
- Supernatural ability type (Psychic, Elemental, Shadow, Ward, Beast, Seer) or mundane specialist
- Supernatural power level that can grow with use and training
- Status tracking: Available, Deployed, Injured, Training, KIA
- Health, morale, and experience/leveling
- Equipment loadout: weapon, armor, gadget, magical item
- Suitability rating — calculated match between agent proficiencies and event requirements
- Backstory, personality traits, and the full Personality Matrix (see companion doc) affecting decision-event outcomes and inter-agent dynamics
- Permadeath — KIA agents are gone
- Recruitment from a rotating hire pool (costs funding)

**Team Composition:**
- Events require teams, not solo agents — implemented as persistent squads with cohesion, not ad-hoc per-mission picks
- Team suitability aggregates member proficiency ranks; personality-driven synergy/friction between teammates is designed (companion doc §3.3) but not yet built
- Some supernatural types synergize (e.g., Seer + Shadow = ambush bonus) — designed, stubbed in code as an extension point, not yet built
- Sending too few agents increases injury/death risk; sending too many leaves other events uncovered

### 3. Concealment Meter
The central tension mechanic. Replaces a traditional lose condition with a narrative pivot.

**Features:**
- Ranges from 0 (perfectly hidden) to 100 (full public knowledge)
- Failed or ignored events add concealment
- Successful containment and certain research reduce it
- Passive daily decay represents the public's short memory
- At certain thresholds (25, 50, 75), escalation events fire — media investigations, government inquiries, viral footage
- Hitting 100 triggers the Revelation and the transition to Act 3
- Post-Revelation, the meter is replaced by a different system (public panic, government cooperation, etc.)

### 4. Research System
XCOM-style tech tree adapted for a magical setting. One active project at a time, costs resources and days.

**Features:**
- Categories: Equipment, Arcane, Containment, Intelligence, Supernatural
- Prerequisites create a branching tree
- Research unlocks: new equipment for agents, new containment methods, passive bonuses, narrative options
- Costs funding and intel (a secondary resource earned from events)
- Some research requires recovered artifacts or captured entities (from events)
- Late-game research pivots from concealment tools to overt magical warfare

**Example branches:**
- Intelligence: Enhanced Sensors → Ley Line Mapping → Concurrence Prediction
- Arcane: Basic Wards → Portal Theory → Mirror World Theory → Concurrence Countermeasures
- Containment: Memory Suppression → Advanced Containment → (post-Revelation) Public Messaging
- Equipment: Tactical Gear → Arcane Weapons → Reality Anchors
- Supernatural: Agent Training → Power Amplification → Ability Fusion

### 5. Resource Management

**Funding:**
- Primary resource, earned from successful events and periodic council payments
- Spent on: hiring agents, research, equipment, base upgrades
- Post-Revelation, funding sources change (governments, open magical economy)

**Intel:**
- Secondary resource earned from events, especially stealth- and tech-heavy ones
- Spent on: advanced research, locating decision events, unlocking narrative options

**Magic Intensity (Global):**
- Not a player resource — a rising global variable
- Increases over time, accelerating in Act 2+
- Affects event spawn rate, event difficulty, and available research
- Post-Revelation it spikes dramatically

### 6. Base Management (Post-Revelation)
After the Revelation strips the player down, they operate from a single base.

**Features:**
- Facility building: barracks, lab, armory, sensor room, containment cells, training grounds
- Facilities take time and resources to build
- Base defense events — the base can be attacked
- Expansion: eventually establish satellite bases in allied territories
- The base is the player's home screen in Act 4, replacing the pure geoscape focus

### 7. Faction / Diplomacy System
Various groups with their own agendas react to the player's decisions.

**Factions:**
- The Shadow Council (fragments post-Revelation)
- National governments (varying cooperation levels)
- The Fae Courts (Seelie/Unseelie)
- Mirror-world factions (refugees, invaders, neutrals)
- Rogue magical practitioners
- The Concurrence cult (antagonist faction)

**Features:**
- Faction reputation tracks shaped by decisions and event outcomes
- High reputation unlocks faction-specific agents, equipment, intel, or narrative paths
- Low reputation creates hostile events from that faction
- Post-Revelation, faction alliances determine available resources and ending options

### 8. Mission Resolution
How events are actually resolved once agents are deployed.

**Features:**
- Resolution is primarily stat-based (not tactical combat)
- Team suitability vs. event difficulty produces a success probability
- Modifiers from equipment, research bonuses, supernatural synergies, and morale
- Resolution produces a short narrative outcome (success/partial success/failure)
- Partial success: event contained but with concealment leak or agent injury
- Critical outcomes (very high or very low rolls) produce special narrative beats
- Some events have optional bonus objectives (recover the artifact, recruit the cryptid, etc.)

*Future consideration: tactical mini-game for high-stakes missions (Act 4/5 boss events). Keep scope manageable — the strategy layer is the game.*

---

## UI / UX Plan

### Geoscape View (Primary)
- Event markers with urgency-colored indicators and pulsing for critical events
- Click event marker → event detail panel (description, requirements, assign agents)
- Agent deployment lines showing who is going where (implemented — geodesic arcs on the globe, straight lines on the flat map)
- Concealment bar always visible
- Day counter, phase indicator, resources in top bar
- Notification feed for event spawns, resolutions, and research completions

### Bottom / Side Panel (Tabbed)
- **Events tab:** list of active events sorted by urgency
- **Agents tab:** roster with status, skills at a glance, filter by availability
- **Research tab:** tech tree visualization or list of available projects
- **Recruit tab:** hire pool with agent previews and costs
- **Base tab (Act 4+):** facility management

### Event Detail Popup
- Event description and flavor text
- Proficiency requirements displayed as rank pips (implemented) or radar chart
- Agent assignment slots with suitability scores
- Deploy / recall buttons
- Decision event choices when applicable

### Agent Detail View
- Full proficiency breakdown, drillable to underlying skills (implemented as a pop-out slideout)
- Equipment loadout (swappable)
- Supernatural ability description
- Mission history
- Suitability preview against currently selected event

---

## Milestones

> **Milestone 1 is complete and the game is playable.** For actual build status, the current game loop, known gaps, and the near-term roadmap, see `concurrence_technical_gdd.md` §6, §10, and §11. The checklist below is kept as a record of original scope, not a live tracker — Milestones 2–7 remain the long-term structure the technical GDD's phased roadmap pulls from.

### Milestone 1 — Core Loop (Vertical Slice) — ✅ Complete, scope exceeded
**Goal:** A playable loop where events spawn, agents are assigned, and events resolve.

- [x] Event data structure (type, proficiency requirements, urgency, location, time limit)
- [x] Event spawner that places events on the geoscape at city locations
- [x] Event markers on the map (clickable, urgency-colored, spawn highlight, clickable labels)
- [x] Agent data structure (tagged skills → derived proficiencies, status, supernatural type, equipment)
- [x] Starting roster of 4 agents with distinct proficiency profiles
- [x] Event detail panel: view requirements, deploy squads
- [x] Stat-based resolution system (suitability vs. difficulty → success roll)
- [x] Outcome feedback (mission report, concealment change, rewards)
- [x] Concealment meter with passive decay and event-driven increases
- [x] Day counter advancing in real time (adjustable speed)
- [x] Pause functionality
- Beyond original scope: persistent squads with cohesion/training, an HQ with a vehicle fleet, real travel time with round-trip logistics, drag-and-drop roster management

### Milestone 2 — Progression
**Goal:** The game has a forward arc. Things get harder and the player gets stronger.

- [ ] Magic intensity scaling (events get harder over time)
- [ ] Agent experience and leveling
- [ ] Research system: tech tree data, one-at-a-time research queue, unlocks
- [ ] Equipment system: items that modify agent stats
- [ ] Funding and intel as tracked resources with income/spend
- [ ] Hire pool: recruit new agents from a rotating selection
- [ ] Event spawn rate tied to magic intensity and game phase

### Milestone 3 — Narrative Layer
**Goal:** The game tells a story through its mechanics.

- [ ] Decision events with branching choices and consequences
- [ ] Game phase progression: Containment → Escalation → Revelation → Resistance
- [ ] Concealment threshold events (media investigations, government pressure)
- [ ] Revelation event sequence (Act 3 transition)
- [ ] Narrative event log the player can review
- [ ] Multi-stage events (failure chains into worse event)
- [ ] Delayed consequences from earlier decisions surfacing

### Milestone 4 — Depth
**Goal:** Strategic decisions have weight and the roster feels personal.

- [ ] Supernatural type synergies between team members
- [ ] Agent morale system (overwork, losses, and downtime)
- [ ] Faction reputation tracking
- [ ] Faction-specific agents, equipment, or intel unlocks
- [ ] Agent permadeath with emotional weight (funeral notification, memorial)
- [ ] Region-specific event flavor
- [ ] Bonus objectives on events

### Milestone 5 — Act 4 Systems
**Goal:** The post-Revelation game works as a satisfying second act.

- [ ] Base management: facility building, upgrades, defense
- [ ] Open recruitment (no longer covert)
- [ ] Overt magical capabilities for agents
- [ ] New research branches for the post-Revelation world
- [ ] Faction alliance system affecting available resources and narrative
- [ ] Base defense events

### Milestone 6 — Endgame
**Goal:** The game has a satisfying conclusion.

- [ ] Final operation structure (multi-event assault)
- [ ] Multiple endings based on preparation, alliances, and key decisions
- [ ] Ending narration/epilogue system
- [ ] Victory/defeat conditions clearly communicated

### Milestone 7 — Polish
**Goal:** The game feels good to play.

- [ ] Sound design: ambient geoscape audio, event alerts, UI feedback
- [ ] Music: phase-appropriate soundtrack
- [ ] Visual polish: event animations, map effects, UI transitions
- [ ] Tutorial / onboarding for the first few days
- [ ] Difficulty settings
- [ ] Save/load system
- [ ] Balance pass on event difficulty curve, research costs, and pacing

---

## Design Principles

**The map is the game.** Everything should flow through and back to the geoscape. Menus support the map, they don't replace it.

**Tension over punishment.** The concealment meter isn't a fail state — it's a narrative accelerator. "Losing" concealment transitions the game into a new phase, not a game over screen. The only true fail state should feel earned and dramatic.

**Agents are people, not units.** Permadeath, backstories, morale, and narrative involvement should make each loss hurt and each success feel personal.

**Decisions should haunt.** The best decision events are ones where the player thinks about them three acts later. No obvious right answers.

**Escalation is the engine.** The game should always feel like it's accelerating. Quiet moments exist to make the next crisis hit harder.

**Scope is the enemy.** The strategy layer IS the game. Resist the pull toward tactical combat mini-games until the core loop is bulletproof. If tactical combat happens, it should be limited to a handful of climactic moments, not every event.

---

## Open Questions

- **Tactical layer:** Should high-stakes events (Act 4/5 boss fights) have a turn-based tactical mini-game, or should everything stay abstracted? Abstraction is faster to develop and keeps the focus on the strategy layer. A tactical mode adds variety but massively increases scope.

- **Agent cap:** How many agents should the player manage? Too few and there's no choice in team composition. Too many and they become disposable. Probably 8–12 active feels right.

- **Revelation timing:** Should the Revelation be inevitable on a fixed timeline, or purely driven by concealment? Fixed timing makes pacing predictable. Concealment-driven rewards skilled play but might make Act 3 feel punitive.

- **Multiplayer:** Is there any async/competitive angle worth exploring? (Probably not for v1.)

- **Mirror worlds:** How much do we show of the alternate realities? Text-only through event descriptions, or are there visual geoscape changes as the merge progresses (territories changing, double-cities appearing)?

- **Post-Revelation economy:** What replaces the shadow council's funding? Government contracts? Magical commerce? Faction patronage? This shapes Act 4's feel significantly.

- **Agent relationships:** Should agents form bonds/rivalries that affect team performance, or is that too much overhead on the roster management?
