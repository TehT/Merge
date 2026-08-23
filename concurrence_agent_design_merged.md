# The Concurrence — Agent & Squad Systems

*A working companion to `concurrence_gdd.md`. Design/content thinking only — nothing here is implemented. Treat every mechanic below as a proposal to argue with, not a spec to build from blindly.*

## Purpose

This document defines three interlocking systems that make agents feel like people the player forms opinions about — the kind of roster where losing someone specific hurts in a specific way, not just "a body with good stats died."

- **Capability** — six operational categories derived from underlying tagged skills, shaped by gear. What an agent *can do*.
- **Personality** — five axes that drift over time, generating Archetypes and Quirks. Who an agent *is*.
- **Pressure** — scarcity, consequences, and incomplete information that prevent squad building from becoming a solved puzzle.

These systems layer on top of each other rather than competing. Capability determines whether a squad *can* handle an event. Personality determines how reliably, at what cost, and with what side effects.

---

## 1. The Unified Agent Dossier

**How much of an agent should the player be able to see?**

The Concurrence already leans legible — the core tension lives in the *external* systems (Concealment, funding, event pressure), and "Scope is the enemy" / "the map is the game" both argue against layering a guessing-game on top of the roster. So: **full transparency for baselines and current state, narrative opacity for *why* things are the way they are.** The player always knows an agent's Nerve is 72. They don't get a tooltip explaining *why* — that's what Backgrounds, Crucibles, and mission history are for. The numbers are legible; the person behind them is still discovered.

The Dossier is one panel with three tiers:

1. **Baseline** — the five personality sliders, current Archetype readout.
2. **History** — Background, active Quirks (max 3), scrollable mission log, and the Drift Log (§3.5).
3. **Capability** — the six operational categories with drillable underlying skills, equipment, current status, and a suitability preview against whatever event/team context the player currently has selected.

---

## 2. Operational Categories & Skills

### 2.1 The six categories

Every agent has a score in six categories, displayed as a six-point radar chart on their character sheet and the squad summary screen. These scores are **derived** from the agent's underlying skills — they are not set directly.

| Category | Covers |
|---|---|
| **Combat** | Direct physical intervention, physical containment, and brute force. |
| **Subterfuge** | Infiltration, misdirection, and bypassing localized hazards unnoticed. |
| **Attunement** | Raw magical manipulation, warding, and sensing esoteric auras. |
| **Erudition** | Deep knowledge of occult rituals, ancient languages, and anomaly behaviors. |
| **Influence** | Social engineering, civilian crowd control, and diplomatic maneuvering. |
| **Ingenuity** | Utilizing modern technology, deploying equipment, and tactical adaptation. |

**Design intent:** Attunement vs Erudition deliberately splits magic into "can do magic" vs "understands magic." A raw-talent sorcerer and a bookish occult professor both contribute to magical events but in different ways, and some events need both. Six categories is the upper edge of what a radar chart displays cleanly — resist adding a seventh and fold it into an existing one instead.

### 2.2 Underlying skills and tags

Each agent's category scores come from **skills** listed under that category. Every skill has a **rank** (numeric) and one or more **tags**.

Example agent sheet:

```
Agent: Torres
Combat (5)
  Firearms [Ranged, Mundane] ........... 4
  CQC [Melee] .......................... 3
Ingenuity (2)
  Field Medicine [Support] .............. 2
```

Tags serve two roles:

1. **Mission modifier interactions.** An event tagged [Flier] reduces or zeroes the contribution of skills tagged [Melee]. An event tagged [Magic Resistant] negates [Arcane]-tagged skills. The agent's *effective* category score for that event drops — the same agent is an A-tier pick for one mission and a C-tier pick for another, and the player can see why.
2. **Gear and ability design.** Equipment and learned abilities are additional skills with tags added to an agent's sheet (see §2.4). They're not flat stat bonuses — they reshape what the agent is good at.

### 2.3 How category scores are calculated

The exact formula is a tuning question (best skill, weighted average, sum-with-cap — needs playtesting), but the key rule is: **only skills whose tags are not countered by the event's modifiers contribute to the effective score.** The base category score on the character sheet assumes no modifiers; the mission select screen shows the effective score against the selected event.

### 2.4 Gear and abilities as skills

Gear and learned abilities are implemented as **additional skills with tags** added to an agent's sheet. An item should change *what an agent is good at* or *what situations they can handle*, not just make a number bigger.

Examples:

- **Enchanted Rifle** → adds `Enchanted Marksmanship [Ranged, Arcane]` — contributes to Combat, bypasses [Magic Resistant], works against [Flier].
- **Ward Amulet** → adds `Warding [Arcane, Defensive]` — contributes to Attunement.
- **Grapple Launcher** → adds `Vertical Assault [Melee, Flier]` — lets a melee agent engage [Flier] enemies, contributes to Combat.
- **Linguistic Codex** → adds `Ancient Languages [Knowledge]` — contributes to Erudition.

### 2.5 Skill count per agent

Agents should have roughly **3–5 underlying skills** plus 1–2 from gear. This keeps each agent readable as a character ("she's the sniper with demolitions training") rather than a spreadsheet. Progression can add new skills or raise existing ranks.

---

## 3. The Personality Matrix

### 3.1 Five axes and what each one does

The five personality axes are sliders (0–100), mechanically distinct from the six operational categories. Categories measure *capability*. Personality modulates *how capability plays out* — outcome variance, team chemistry, quirk eligibility, and decision-event availability. None of this touches the core skill-coverage formula in mission resolution; personality changes the *texture* of outcomes, not the base arithmetic.

- **Protocol** (Improviser ↔ Orthodox) — gates which Quirks an agent can roll (orthodox agents lean toward discipline-tied Threshold quirks; improvisers toward chaotic Crucible outcomes) and modulates decision-event option availability. A 90-Protocol agent might not get the "burn the evidence, screw procedure" choice at all, or gets it with a morale penalty.
- **Nerve** (Cautious ↔ Reckless) — the most directly mechanical axis. Feeds into injury/KIA roll bias: high-Nerve agents pull outcomes toward the extremes (bigger wins, uglier losses) rather than changing the base suitability. Reckless agents are a swingier bet, not a strictly worse one.
- **Attachment** (Detached ↔ Compassionate) — the morale lever. High-Attachment agents lose morale hard when a teammate is hurt/KIA but accelerate that teammate's recovery and are less likely to abandon a bad mission early. Detached agents are morale-stable but don't seek out struggling teammates, starving certain bonding-triggered quirks.
- **Esoterica** (Pragmatic ↔ Attuned) — governs how well an agent tolerates and grows magical ability. Pragmatic agents resist magical growth but are immune to certain horror/sanity Crucibles. Attuned agents grow faster magically but are more exposed to esoteric Crucibles.
- **Ego** (Collaborator ↔ Dominant) — the team-composition lever. Two high-Ego agents on one team fight for primacy (cohesion grows slower, Archetype-pairing penalties apply). A team of all-Collaborators is harmonious but slow to make decisive calls under Critical urgency (small suitability penalty on Critical-tier events, representing decision paralysis).

### 3.2 Archetypes

Derived from an agent's **two most extreme axes** (largest distance from the 50 midpoint), each contributing its high- or low-pole name. That gives 10 unordered pairs × 4 pole combinations = 40 possible slots. Hand-write the ~15–20 most narratively interesting combinations; the rest fall back to a generic "[Pole A] [Pole B]" label.

Seed examples:

| Dominant pair | Archetype | Read |
|---|---|---|
| High Nerve + High Ego | **Glory Hound** | First through the door, wants credit for it |
| High Attachment + Low Ego | **Guardian** | Protects the team over the mission |
| High Esoterica + High Protocol | **Ritualist** | Treats magic like a discipline, not a gift |
| Low Protocol + High Nerve | **Wildcard** | Thrives in chaos, useless on a leash |
| High Ego + High Protocol | **Zealous Enforcer** | Leads by the book, brooks no dissent |
| High Attachment + High Esoterica | **Empath** | Feels the weight of the supernatural on people, not just events |
| Low Nerve + Low Ego | **Steady Hand** | Never the plan's author, always the reason it survives contact |

Archetype should be recomputed live (a *readout*, not a stored value) so drift can visibly change someone's Archetype mid-campaign — a Guardian who hardens into a Steady Hand, or worse a Glory Hound, is a story the player watches happen.

### 3.3 Archetype and team synergy

An **Archetype-pair modifier table** — small, curated, applied to cohesion growth rate (not raw suitability) when two teammates share a team:

- **Same dominant Ego-high archetypes** (two Glory Hounds, two Zealous Enforcers): cohesion growth rate penalty — they're competing, not gelling.
- **Complementary pairs** (Glory Hound + Guardian, Wildcard + Ritualist): cohesion growth bonus — one's excess is the other's counterweight.
- **Esoterica mismatch** (a 90-Esoterica Ritualist next to a 10-Esoterica Pragmatist): flat cohesion penalty early, but the pairing is what unlocks a handful of high-value Crucibles later ("The Pragmatist starts to believe") — friction that pays off if the player sticks with it.

This turns team-building into a second optimization axis layered on top of skill coverage: a mechanically perfect skill spread with two Glory Hounds in it will always underperform a slightly-worse skill spread with good Archetype chemistry, once cohesion is factored in over a campaign's timescale.

### 3.4 Drift

Two distinct tiers of personality change:

1. **Crucible shocks** (permanent, sudden) — a specific traumatic or formative event instantly shifts one or two axes by a large amount (±15–30), paired with the Quirk it generates (§4.2). This is a scar, not a mood.
2. **Organic drift** (gradual, semi-reversible) — repeated exposure to a mission *type* nudges the relevant axis a small amount per mission (e.g., three Fairy Incursion missions in a row nudges Esoterica up 2–3 points each). This drift can creep back toward baseline during quiet stretches. A future Rest/R&R action (parallel to Training, but personality-focused instead of skill-focused) would slot in here. Not needed now, but keep the design door open.

### 3.5 Communicating drift in the UI

Three layers:

1. **Immediate, transient** — a toast notification the moment a Crucible fires: "Mara Okonkwo survived the Kinshasa ambush. Something in her hardened." Announced, not buried.
2. **Persistent, at-a-glance** — on the slider itself, a thin **ghost tick** at the value it held at the start of the campaign (or last Crucible shift). The current handle position reads against where it used to be — a slider that's drifted far shows a widening gap. The player never has to hunt for whether someone's changed.
3. **On-demand, detailed** — the Drift Log in the Dossier's History tier: "Day 47: Nerve 42→58, cause: survived Kinshasa Portal Breach ambush at 18% suitability." For deep roster reviews.

### 3.6 No universal ideal personality

Three coexisting notions of "ideal," each answering a different question:

- **No mechanically-best profile.** Every axis's high AND low pole has both an upside and a downside. If playtesting reveals one pole is strictly dominant, that's the bug to fix.
- **Fit, not optimality.** Specific events reward specific profiles. Specific teams want spread rather than five of the same archetype. "Ideal" is contextual.
- **A personal "self" implied by Background.** An Ex-Paramedic implies high Attachment, moderate Esoterica. Crucibles can reinforce or violate that self. This is narrative bookkeeping — no new number, just a comparison the Dossier can surface ("Mara has drifted far from who she used to be"). It makes drift feel like an arc instead of noise.

---

## 4. Organic Quirks

### 4.1 Backgrounds

Pre-assigned at recruitment from a mundane-history pool: Ex-Paramedic, Former Cop, Investigative Journalist, Occult Hobbyist, Ex-Military, Off-the-Grid Survivalist, Academic (folklore/theology), Con Artist, etc.

Two jobs:

- **Early-game utility floor.** Before magic ramps up, Backgrounds are the only thing differentiating mundane agents beyond raw skill numbers — an Ex-Paramedic contributing to injury recovery, a Former Cop getting a Cult Activity suitability nudge. Serves the Act 1 "procedural paranormal agency" tone.
- **Implying the personal "ideal"** from §3.6 — Background is the seed the whole personality arc grows from.

Keep the pool small at launch (8–10 entries). By Act 2 Backgrounds should read as "flavor with a small permanent perk," with Quirks doing the heavy lifting.

### 4.2 Crucibles

Dynamically generated from a **Crucible template pool** keyed to event type and severity, triggered by specific conditions (surviving a Critical-urgency event at low suitability, being the sole survivor, a botched Mirror Merge exposure, etc.). Each template is a paired bonus + drawback plus a personality-axis shift:

- *Survived a Cryptid mauling*: +Combat suitability vs. Cryptid Sightings specifically, −morale regeneration at night, Nerve +12.
- *Watched a teammate get lost to a Portal Breach*: +team cohesion growth rate, −Esoterica, Attachment +18.
- *Successfully talked down a Fae diplomat solo*: +Influence suitability vs. Fae content, Ego +15, Protocol −10 ("rules didn't save that room, instinct did").

The double-edged framing matters — a maximally field-tested veteran is mechanically guaranteed to be carrying real liabilities alongside their bonuses. There is no "grind until perfect."

### 4.3 Thresholds and intersections

Two trigger shapes, borrowing the Concealment meter's existing threshold pattern (25/50/75):

- **Threshold quirks**: a single axis crossing 25 or 75 unlocks a passive trait tied to that pole — 75+ Protocol might grant "By The Book" (small suitability bonus on standard Containment events, penalty on chaotic Cult/Portal events). The most predictable/discoverable quirks, good for teaching the system.
- **Intersection quirks**: two specific axes *both* past their thresholds simultaneously unlock something more specific — 75+ Nerve and 75+ Ego together might grant "Glory Hound" the Quirk (distinct from but named after the associated Archetype, reinforcing that they're two views of the same underlying drift).

### 4.4 The three-quirk cap

When a fourth would trigger, don't silently discard it. Two options:

- **Player chooses what to drop.** A small prompt at the moment of the new trigger. Gives agency and a moment to read what's on the agent, but adds a UI interruption.
- **Weakest/oldest auto-fades**, with a notification. Zero interaction cost, but removes player choice at the moment they might care most.

Leaning toward player-choice given the transparency philosophy — but flagged as genuinely needing a playtest before committing, since it's a UX cost/agency trade-off.

---

## 5. Events

### 5.1 Event structure

Events appear on the globe and have:

- **Category thresholds.** Minimum effective scores needed across one or more of the six categories. Most events emphasize 2–3, not all six.
- **Tags/modifiers.** e.g. [Flier], [Magic Resistant], [Swarm], [Underground], [Urban], [Warded]. These interact with agent skill tags to alter effective scores.
- **Intel level.** How much of the above is visible to the player before committing a squad.
- **Escalation.** Events worsen over time if ignored or only partially addressed.

### 5.2 Intel and the recon loop

At low intel, the player sees only vague category emphasis ("Combat-heavy, Attunement presence detected"). At higher intel, specific tags and thresholds are revealed.

Players can deploy a **recon/investigative squad** to raise intel before sending a strike team. This is a real resource cost — those agents are committed and unavailable, and the event may escalate while the recon squad works.

Scouting should usually be smart but occasionally cost the player. Possible costs: time (event escalates), risk (recon squad gets pinned), agent availability. It must remain a genuine decision, not an automatic first step.

### 5.3 Hard tag gates

A small number of high-stakes, thematically-loaded event types should mechanically *require* a specific tag to attempt at all — not just "high Attunement helps" but "you need someone with [Warding] present, period." This is the single strongest lever against spreadsheet-optimization: grinding a category score is no substitute for having the right specific capability on the roster.

Reserve this for a handful of events. Used everywhere it becomes annoying gatekeeping; used sparingly it becomes "I need to find someone with the right skill for this," which is exactly the right tension.

---

## 6. Squad Building & Mission Select

### 6.1 The core loop

1. Events appear on the globe with partial intel.
2. Player optionally deploys a recon squad to gather intel.
3. Player assembles a strike squad from available agents.
4. Mission select screen shows the squad's effective category scores against the event's known requirements.
5. Squad deploys; outcome is resolved.

### 6.2 What keeps squad building a decision

The skill-tag system provides the vocabulary. The following systems provide the tension:

- **Scarcity.** Multiple events burn simultaneously. You never have enough agents to send your best squad everywhere. Every deployment is a compromise.
- **Consequences.** Agents return injured, fatigued, stressed, or potentially dead. Sending your A-team to a routine event is wasteful if something worse appears tomorrow.
- **Incomplete information.** Without full intel, you're hedging — maybe you bring a generalist instead of a specialist just in case.
- **Personality chemistry.** Archetype synergy/friction (§3.3) means the squad with the best skill coverage isn't necessarily the best squad. Two Glory Hounds might have perfect Combat coverage and still underperform because they're fighting each other.
- **Quirk liabilities.** Your most experienced agents are also carrying the most Crucible-generated drawbacks (§4.2). The veteran who's +Combat against Cryptids is also −morale at night. Experience and liability are the same mechanism.
- **Progression pressure.** Agents grow by being deployed. Rookies need field time, but every rookie deployment is a risk. Leaning on your best five forever means your bench never develops.
- **Personality-gated skill ceilings.** A high-Ego agent could mechanically resist growing Influence past a soft cap — breadth requires roster diversity in personality, not just training hours.
- **Same-tag diminishing returns.** Two agents with the same skill on one team shouldn't stack additively — this pushes composition toward breadth across a team.

**Design test:** At least one late-Act-2-or-later event type should be *unwinnable* by the best possible generalist team and *straightforward* for a team built around the right narrow specialization. That's the concrete test for whether this system is doing its job.

### 6.3 Mission select screen — UX direction

The player-facing language is **categories and colors**. The system-facing language is **tags and math**.

- Show each category score as a color-coded indicator (green/amber/red) relative to the event's known thresholds.
- Amber/red scores should be tappable to show *why* — "Torres: Combat 5 → effective 3 (Firearms negated by [Flier])."
- The underlying tag math should be discoverable but never required. The surface reads as "green number good, red number bad, tap to see why."

---

## 7. Open Design Questions

These are identified but not yet resolved — flag for future iteration:

- Exact formula for deriving category scores from underlying skills (best-of, weighted average, sum-with-cap — needs playtesting).
- How many skill tags is too many? Start conservative (8–12 total in the game), expand only as needed.
- Full Archetype naming pass (the ~15–20 hand-picked combinations out of the 40-slot matrix).
- Concrete Background list and their specific mechanical perks — currently only sketched by example.
- The Crucible template pool — needs to be sized (how many per event type? per severity tier?) before it can be built.
- Whether Rest/R&R becomes a real Base action alongside Training, and what it costs.
- Player-choice vs auto-fade for the quirk cap — flagged as genuinely open.
- Event failure consequences — partial success states? Civilian casualties? Region destabilization?
- Escalation mechanics — how fast, how punishing, can escalated events become unwinnable?
- Which specific event types get hard tag gates — a short, deliberate list, not a blanket rule.
- Magical aptitude system (innate attunement to a type of magic, separate from learned skills) — designed separately once the core capability/personality systems are stable.
