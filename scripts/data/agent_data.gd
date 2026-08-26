## AgentData — Core data structure for a Concurrence field agent.
##
## Agents are the player's primary resource. Each has a set of tagged skills
## that derive six Proficiency scores (Combat, Subterfuge, Attunement,
## Erudition, Influence, Ingenuity), an optional supernatural ability, and
## runtime condition/status state managed by AgentManager.
class_name AgentData
extends Resource

## ── Enums ────────────────────────────────────────────────────────────────────

enum SupernaturalType {
	NONE,
	PSYCHIC,
	ELEMENTAL,
	SHADOW,
	WARD,
	BEAST,
	SEER,
}

enum Status { AVAILABLE, DEPLOYED, INJURED, TRAINING, KIA }

## ── Identity ────────────────────────────────────────────────────────────────

@export var id: String = ""
@export var agent_name: String = ""
@export_multiline var backstory: String = ""
@export var personality_traits: PackedStringArray = []

## ── Personality ─────────────────────────────────────────────────────────────
## Five axes (0-100), the Personality Matrix — see PersonalityHandler and
## concurrence_agent_design_merged.md §3. Modulates outcome texture
## (nothing yet actually reads these beyond display and get_archetype() —
## Quirks/Crucibles/team-synergy modifiers are a separate, not-yet-built
## system), not the base mission-resolution arithmetic.

@export_group("Personality")
@export_range(0, 100) var protocol: int = 50     ## Improviser ↔ Orthodox
@export_range(0, 100) var nerve: int = 50        ## Cautious ↔ Reckless
@export_range(0, 100) var attachment: int = 50   ## Detached ↔ Compassionate
@export_range(0, 100) var esoterica: int = 50    ## Pragmatic ↔ Attuned
@export_range(0, 100) var ego: int = 50          ## Collaborator ↔ Dominant

## ── Skills & Proficiencies ─────────────────────────────────────────────────
## Proficiency scores are derived from the skills array — not set directly.
## Each skill contributes rank × RANK_SCALE to its proficiency category.

@export_group("Skills")
@export var skills: Array[SkillData] = []

## ── Supernatural ────────────────────────────────────────────────────────────

@export_group("Supernatural")
@export var supernatural_type: SupernaturalType = SupernaturalType.NONE
@export var supernatural_power: float = 0.0

## ── Condition ───────────────────────────────────────────────────────────────

@export_group("Condition")
@export var max_health: float = 100.0

var health: float = 100.0
var morale: float = 75.0
var status: Status = Status.AVAILABLE

## ── Equipment ───────────────────────────────────────────────────────────────
## Composable EquipmentData (see scripts/data/equipment/) — one slot per
## slot_type. Effects apply automatically wherever ranks/scores are read
## (get_proficiency_ranks/get_proficiency_scores below); nothing else
## needs to know equipment exists.

@export_group("Equipment")
@export var equipped_weapon: EquipmentData
@export var equipped_armor: EquipmentData
@export var equipped_gadget: EquipmentData
@export var magical_item_slot: String = ""

## ── Convenience ─────────────────────────────────────────────────────────────

func setup(p_name: String, p_skills: Array[SkillData],
		p_type: SupernaturalType = SupernaturalType.NONE) -> AgentData:
	id = _generate_id()
	agent_name = p_name
	skills = p_skills
	supernatural_type = p_type
	health = max_health
	return self

static func _generate_id() -> String:
	return "agt_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

## Proficiency scores (0-200 scale) derived from this agent's effective
## skill pool — their own skills plus whatever equipped gear grants or
## modifies — and adjusted by any equipped EffectStatBoost. See
## EquipmentHandler.compute_effective_scores().
func get_proficiency_scores() -> Dictionary:
	return EquipmentHandler.compute_effective_scores(self)

## Effective proficiency scores against a specific event's counter-tags.
## Skills whose tags are countered contribute nothing. Equipment-aware
## (granted/modified skills included) but does not apply EffectStatBoost —
## that's a separate axis from counter-tag negation.
func get_effective_scores(counter_tags: PackedStringArray) -> Dictionary:
	var scores := SkillHandler.empty_proficiency_dict()
	for skill: SkillData in EquipmentHandler.get_effective_skills(self):
		if not SkillHandler.is_countered_by(skill, counter_tags):
			scores[skill.get_proficiency_key()] += float(skill.get_scaled_rank())
	return scores

## Alias for get_proficiency_scores() — used by TeamData and MissionResolver
## where the key names must match EventData.get_proficiency_requirements().
func get_skills() -> Dictionary:
	return get_proficiency_scores()

## Proficiency ranks derived from this agent's effective skill pool (their
## own skills plus whatever equipped gear grants or modifies), adjusted by
## any equipped EffectStatBoost-style rank effects. Pass active_tags
## (typically an event's tags) to recalculate under that context — a skill
## tagged e.g. [Explosive] can rank lower or higher than its sheet value
## depending on which tag_modifiers rules match, which can shift which
## Proficiency rank the category as a whole reaches. Callable again at any
## time with a different active_tags set (e.g. mid-mission, if an
## encounter phase changes what's active) — omit it for the base ranks.
## See EquipmentHandler.compute_effective_ranks().
func get_proficiency_ranks(active_tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	return EquipmentHandler.compute_effective_ranks(self, active_tags)

## Single "how developed is this agent overall" number — the mean of all
## six Proficiency ranks. Replaces the old flat AgentData.level (removed):
## TeamData's per-member weighting uses this instead, and Proficiency
## ranks are already the live, derived signal of capability now that
## individual skills carry their own XP (see SkillHandler.award_skill_xp/
## award_proficiency_xp) rather than a separate agent-level XP track.
func get_average_proficiency_rank() -> float:
	var ranks := get_proficiency_ranks()
	var total := 0
	for key: String in ranks:
		total += ranks[key]
	return float(total) / ranks.size()

## True if agent meets every one of item's requirements — see
## EquipmentHandler.can_equip().
func can_equip(item: EquipmentData) -> bool:
	return EquipmentHandler.can_equip(self, item)

## Equips item into the slot matching its slot_type ("Weapon"/"Armor"/
## "Gadget"), replacing whatever was there. Returns false (no change) if
## can_equip() fails or slot_type isn't recognized.
func equip(item: EquipmentData) -> bool:
	if item == null or not can_equip(item):
		return false
	match item.slot_type:
		"Weapon": equipped_weapon = item
		"Armor": equipped_armor = item
		"Gadget": equipped_gadget = item
		_: return false
	return true

## Clears the named slot ("Weapon"/"Armor"/"Gadget"). No-op for an
## unrecognized slot name.
func unequip(slot_type: String) -> void:
	match slot_type:
		"Weapon": equipped_weapon = null
		"Armor": equipped_armor = null
		"Gadget": equipped_gadget = null

func get_primary_proficiency() -> String:
	var scores := get_proficiency_scores()
	var best_key := "combat"
	var best_val := -1.0
	for key: String in scores:
		if scores[key] > best_val:
			best_val = scores[key]
			best_key = key
	return best_key

func get_type_name() -> String:
	match supernatural_type:
		SupernaturalType.NONE: return "Mundane"
		SupernaturalType.PSYCHIC: return "Psychic"
		SupernaturalType.ELEMENTAL: return "Elemental"
		SupernaturalType.SHADOW: return "Shadow"
		SupernaturalType.WARD: return "Ward"
		SupernaturalType.BEAST: return "Beast"
		SupernaturalType.SEER: return "Seer"
	return "Unknown"

func get_status_name() -> String:
	match status:
		Status.AVAILABLE: return "Available"
		Status.DEPLOYED: return "Deployed"
		Status.INJURED: return "Injured"
		Status.TRAINING: return "Training"
		Status.KIA: return "KIA"
	return "Unknown"

func is_available() -> bool:
	return status == Status.AVAILABLE

## Live-computed Personality Matrix readout — never stored, so drift
## changes it for free. See PersonalityHandler.compute_archetype().
func get_archetype() -> String:
	return PersonalityHandler.compute_archetype(self)

## Nudges one personality axis by delta (+/-), clamped to 0-100. The
## primitive behind both Drift tiers (design doc §3.4) — callers should
## generally go through PersonalityHandler.apply_crucible_shock()/
## apply_organic_drift() instead of calling this directly, since those
## are the documented, tier-labeled entry points other systems hook into.
func drift_axis(axis_key: String, delta: int) -> void:
	match axis_key:
		"protocol": protocol = clampi(protocol + delta, 0, 100)
		"nerve": nerve = clampi(nerve + delta, 0, 100)
		"attachment": attachment = clampi(attachment + delta, 0, 100)
		"esoterica": esoterica = clampi(esoterica + delta, 0, 100)
		"ego": ego = clampi(ego + delta, 0, 100)
		_: push_warning("AgentData.drift_axis: unknown axis '%s'" % axis_key)
