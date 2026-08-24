## SkillData — a single tagged skill contributing to one of six Proficiencies.
##
## Skills are the building blocks of an agent's capability profile. Each
## skill belongs to exactly one Proficiency category and carries tags that
## interact with event modifiers — an event tagged [Flier] can negate skills
## tagged [Melee], reducing the agent's effective Proficiency score for that
## mission without changing their base sheet.
##
## This class only holds one skill's own data (name, proficiency, rank,
## tags) plus lookups that never need another skill or an outside tag list
## to answer. Anything that reasons about a *set* of skills together, or a
## skill against something external (rank aggregation, tag-countering,
## eventually synergies) lives in SkillHandler instead — see
## scripts/managers/skill_handler.gd.
class_name SkillData
extends Resource

enum Proficiency {
	COMBAT,      ## Direct physical intervention, containment, brute force
	SUBTERFUGE,  ## Infiltration, misdirection, bypassing hazards unnoticed
	ATTUNEMENT,  ## Raw magical manipulation, warding, sensing auras
	ERUDITION,   ## Occult knowledge, ancient languages, anomaly behaviors
	INFLUENCE,   ## Social engineering, crowd control, diplomatic maneuvering
	INGENUITY,   ## Modern technology, equipment deployment, tactical adaptation
}

const PROFICIENCY_NAMES: PackedStringArray = [
	"Combat", "Subterfuge", "Attunement", "Erudition", "Influence", "Ingenuity",
]

const PROFICIENCY_KEYS: PackedStringArray = [
	"combat", "subterfuge", "attunement", "erudition", "influence", "ingenuity",
]

const PROFICIENCY_COLORS: Dictionary = {
	"combat": Color(0.9, 0.35, 0.25),
	"subterfuge": Color(0.6, 0.3, 0.8),
	"attunement": Color(0.2, 0.75, 0.85),
	"erudition": Color(0.85, 0.7, 0.2),
	"influence": Color(0.35, 0.75, 0.4),
	"ingenuity": Color(0.4, 0.6, 0.85),
}

## Points a single skill rank contributes toward its proficiency's 0-200
## score — i.e. what a skill gains per rank.
const RANK_SCALE: int = 20

const VISIBLE_MAX_RANK: int = 5

@export var skill_name: String = ""
@export var proficiency: Proficiency = Proficiency.COMBAT
@export_range(1, 5) var rank: int = 1
@export var tags: PackedStringArray = []

func _init(p_name: String = "", p_prof: Proficiency = Proficiency.COMBAT,
		p_rank: int = 1, p_tags: PackedStringArray = []) -> void:
	skill_name = p_name
	proficiency = p_prof
	rank = p_rank
	tags = p_tags

func get_proficiency_name() -> String:
	return PROFICIENCY_NAMES[proficiency]

func get_proficiency_key() -> String:
	return PROFICIENCY_KEYS[proficiency]

func get_scaled_rank() -> int:
	return rank * RANK_SCALE

func has_tag(tag: String) -> bool:
	return tag in tags

static func proficiency_key_for(prof: Proficiency) -> String:
	return PROFICIENCY_KEYS[prof]

static func proficiency_name_for(prof: Proficiency) -> String:
	return PROFICIENCY_NAMES[prof]
