## SkillData — a single tagged skill contributing to one of six Proficiencies.
##
## Skills are the building blocks of an agent's capability profile. Each
## skill belongs to exactly one Proficiency category and carries tags that
## interact with event modifiers — an event tagged [Flier] can negate skills
## tagged [Melee], reducing the agent's effective Proficiency score for that
## mission without changing their base sheet.
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

const RANK_SCALE: int = 20

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

func is_countered_by(counter_tags: PackedStringArray) -> bool:
	for ct in counter_tags:
		if ct in tags:
			return true
	return false

const VISIBLE_MAX_RANK: int = 5

const RANK_THRESHOLDS: Array[Dictionary] = [
	{"min_skills": 1, "min_rank": 1},
	{"min_skills": 1, "min_rank": 2},
	{"min_skills": 2, "min_rank": 2},
	{"min_skills": 2, "min_rank": 3},
	{"min_skills": 3, "min_rank": 3},
	{"min_skills": 3, "min_rank": 4},
	{"min_skills": 3, "min_rank": 4},
	{"min_skills": 4, "min_rank": 4},
	{"min_skills": 4, "min_rank": 5},
	{"min_skills": 5, "min_rank": 5},
]

static func compute_proficiency_rank(skills_in_category: Array[SkillData]) -> int:
	if skills_in_category.is_empty():
		return 0
	var ranks: Array[int] = []
	for s: SkillData in skills_in_category:
		ranks.append(s.rank)
	ranks.sort()
	var prof_rank := 0
	for i in range(RANK_THRESHOLDS.size()):
		var req: Dictionary = RANK_THRESHOLDS[i]
		var min_skills: int = req["min_skills"]
		var min_rank: int = req["min_rank"]
		if ranks.size() < min_skills:
			break
		var qualifying := 0
		for r: int in ranks:
			if r >= min_rank:
				qualifying += 1
		if qualifying >= min_skills:
			prof_rank = i + 1
		else:
			break
	return prof_rank

static func empty_proficiency_dict() -> Dictionary:
	return {
		"combat": 0.0,
		"subterfuge": 0.0,
		"attunement": 0.0,
		"erudition": 0.0,
		"influence": 0.0,
		"ingenuity": 0.0,
	}

static func empty_rank_dict() -> Dictionary:
	return {
		"combat": 0,
		"subterfuge": 0,
		"attunement": 0,
		"erudition": 0,
		"influence": 0,
		"ingenuity": 0,
	}

static func proficiency_key_for(prof: Proficiency) -> String:
	return PROFICIENCY_KEYS[prof]

static func proficiency_name_for(prof: Proficiency) -> String:
	return PROFICIENCY_NAMES[prof]
