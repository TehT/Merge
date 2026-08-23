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
var experience: int = 0
var level: int = 1
var status: Status = Status.AVAILABLE

## ── Equipment ───────────────────────────────────────────────────────────────

@export_group("Equipment")
@export var weapon_slot: String = ""
@export var armor_slot: String = ""
@export var gadget_slot: String = ""
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

## Base proficiency scores derived from all skills (no event context).
## Returns { "combat": float, "subterfuge": float, ... } on the 0-200 scale.
func get_proficiency_scores() -> Dictionary:
	var scores := SkillData.empty_proficiency_dict()
	for skill: SkillData in skills:
		scores[skill.get_proficiency_key()] += float(skill.get_scaled_rank())
	return scores

## Effective proficiency scores against a specific event's counter-tags.
## Skills whose tags are countered contribute nothing.
func get_effective_scores(counter_tags: PackedStringArray) -> Dictionary:
	var scores := SkillData.empty_proficiency_dict()
	for skill: SkillData in skills:
		if not skill.is_countered_by(counter_tags):
			scores[skill.get_proficiency_key()] += float(skill.get_scaled_rank())
	return scores

## Alias for get_proficiency_scores() — used by TeamData and MissionResolver
## where the key names must match EventData.get_proficiency_requirements().
func get_skills() -> Dictionary:
	return get_proficiency_scores()

func get_proficiency_ranks() -> Dictionary:
	var by_key: Dictionary = {}
	for key: String in SkillData.PROFICIENCY_KEYS:
		by_key[key] = [] as Array[SkillData]
	for skill: SkillData in skills:
		by_key[skill.get_proficiency_key()].append(skill)
	var ranks := SkillData.empty_rank_dict()
	for key: String in SkillData.PROFICIENCY_KEYS:
		ranks[key] = SkillData.compute_proficiency_rank(by_key[key])
	return ranks

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

func compute_suitability(event: EventData) -> float:
	return MissionResolver.compute_rank_coverage(get_proficiency_ranks(), event)
