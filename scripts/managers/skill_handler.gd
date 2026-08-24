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

## Every known tag-interaction rule (see SkillTagModifier), loaded from
## res://data/tag_modifiers/ — data-driven, not hardcoded. Add a new .tres
## there to add a new interaction; no code changes needed.
static var tag_modifiers: Array[SkillTagModifier] = [
	preload("res://data/tag_modifiers/fragile_penalizes_explosive.tres"),
	preload("res://data/tag_modifiers/swarm_boosts_area.tres"),
]

## A skill's rank as modified by whatever context tags are currently active
## (an event's tags, an encounter phase's tags, ...): base rank plus every
## tag_modifiers rule whose trigger_tag is active and whose affects_tag the
## skill carries, floored at 0. With no active_tags this is just the
## skill's own rank — no modifier can ever match an empty tag set.
static func compute_effective_rank(skill: SkillData, active_tags: PackedStringArray) -> int:
	var delta := 0
	for mod: SkillTagModifier in tag_modifiers:
		if active_tags.has(mod.trigger_tag) and skill.has_tag(mod.affects_tag):
			delta += mod.rank_delta
	return maxi(0, skill.rank + delta)

## Aggregates a category's skills into a single Proficiency rank. Pass
## active_tags to recalculate under a specific context (a mission's tags
## today; nothing stops this being called again mid-mission with a
## different set, e.g. an encounter phase revealing new tags) — omit it to
## get the unmodified base rank.
static func compute_proficiency_rank(skills_in_category: Array[SkillData],
		active_tags: PackedStringArray = PackedStringArray()) -> int:
	if skills_in_category.is_empty():
		return 0
	var ranks: Array[int] = []
	for s: SkillData in skills_in_category:
		ranks.append(compute_effective_rank(s, active_tags))
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
