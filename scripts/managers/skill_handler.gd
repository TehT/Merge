## SkillHandler — computation over sets of skills: aggregating skills into a
## Proficiency rank, and evaluating a skill against an outside tag list
## (event counter-tags today; the natural home for skill-combo synergies
## later too). A static utility (RefCounted), not an autoload: it has no
## persistent state, so it doesn't need global registration. Kept separate
## from SkillData so that class stays a plain data container — SkillData is
## "what a skill is," this is "what happens when skills interact."
class_name SkillHandler
extends RefCounted

## How many skills at what minimum rank are needed to reach each
## Proficiency rank (array index + 1). e.g. index 0 says Proficiency rank 1
## needs at least 1 skill at rank >= 1; higher ranks need more skills at
## higher minimum ranks.
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

## True if any of counter_tags appears on the skill's own tags — e.g. an
## event tagged [Flier] counters (negates) any skill tagged [Flier].
static func is_countered_by(skill: SkillData, counter_tags: PackedStringArray) -> bool:
	for ct in counter_tags:
		if skill.has_tag(ct):
			return true
	return false

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
