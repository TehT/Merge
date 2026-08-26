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
## higher minimum ranks. This is a mechanic-scope table, not a reflection
## of the current content — the 3 skills per category on disk today are
## just a starting mundane baseline (more will be added, and Awakened
## categories aren't built yet), so tiers up to min_skills 5 stay here
## even though nothing can reach them yet; a category short of a tier's
## min_skills simply can't progress past the previous tier
## (ranks.size() < min_skills breaks the walk) until it grows enough
## skills, same as any agent short of a tier's min_rank.
const RANK_THRESHOLDS: Array[Dictionary] = [
	{"min_skills": 1, "min_rank": 1}, #Rank 1
	{"min_skills": 1, "min_rank": 2}, #Rank 2
	{"min_skills": 2, "min_rank": 2}, #Rank 3
	{"min_skills": 2, "min_rank": 3}, #Rank 4
	{"min_skills": 3, "min_rank": 3}, #Rank 5
	{"min_skills": 2, "min_rank": 4}, #Rank 6
	{"min_skills": 3, "min_rank": 4}, #Rank 7
	{"min_skills": 4, "min_rank": 4}, #Rank 8
	{"min_skills": 4, "min_rank": 5}, #Rank 9
	{"min_skills": 5, "min_rank": 5}, #Rank 10
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

## An independent copy of a catalog skill at a specific rank. Skills aren't
## agent-specific — the same res://data/skills/<proficiency>/*.tres catalog
## entry can back any number of agents — so this always duplicate()s rather
## than handing back the shared preloaded/loaded resource directly. Without
## this, two agents assigned "the same" skill would alias one SkillData
## instance and a rank change for one would silently bleed into the other.
static func instantiate(base: SkillData, rank: int) -> SkillData:
	var s: SkillData = base.duplicate()
	s.rank = rank
	return s

## Flat XP cost to advance a skill by one rank. A placeholder curve, not a
## tuned one — revisit once there's real playtesting to balance XP gain
## rates against, same "don't nail it down yet" posture as operation_cost.
const XP_PER_RANK: int = 100

## Multiplier applied to a skill's XP award when it was specifically
## exercised during whatever earned the XP, vs. riding along on its
## Proficiency category's base award (see award_proficiency_xp). Also a
## placeholder value.
const UTILIZED_XP_MULTIPLIER: float = 2.0

## Adds xp to one skill, ranking it up (possibly more than once in a
## single call) whenever accumulated xp clears XP_PER_RANK, capped at
## VISIBLE_MAX_RANK. XP is discarded once a skill hits the cap — nothing
## to carry forward toward, since rank can't go higher.
static func award_skill_xp(skill: SkillData, amount: int) -> void:
	skill.xp += amount
	while skill.rank < SkillData.VISIBLE_MAX_RANK and skill.xp >= XP_PER_RANK:
		skill.xp -= XP_PER_RANK
		skill.rank += 1
	if skill.rank >= SkillData.VISIBLE_MAX_RANK:
		skill.xp = 0

## Awards XP to every one of an agent's own skills (not equipment-granted
## ones — those aren't the agent's to level) in one Proficiency category:
## base_amount to each, times UTILIZED_XP_MULTIPLIER for whichever skills'
## names appear in utilized_skill_names. Nothing supplies that list yet —
## no resolution strategy currently exposes "which specific skills this
## check drew on" in a queryable form (TagBreadthResolutionStrategy comes
## closest, via its per-skill Modifier Pass, but doesn't surface it
## outside its own log) — so today every skill in the category gets the
## same base award until that's wired up.
static func award_proficiency_xp(agent: AgentData, proficiency_key: String,
		base_amount: int, utilized_skill_names: PackedStringArray = PackedStringArray()) -> void:
	for skill: SkillData in agent.skills:
		if skill.get_proficiency_key() != proficiency_key:
			continue
		var amount := base_amount
		if skill.skill_name in utilized_skill_names:
			amount = int(round(base_amount * UTILIZED_XP_MULTIPLIER))
		award_skill_xp(skill, amount)

## Base XP a resolved check awards per qualifying Proficiency category,
## before CHECK_OUTCOME_XP_MULTIPLIER and UTILIZED_XP_MULTIPLIER scale it
## further. Placeholder, not tuned — same posture as XP_PER_RANK.
const BASE_CHECK_XP: int = 20

## How much of BASE_CHECK_XP a check actually pays out per outcome — a
## botched check still teaches something, just less than a clean one.
## Placeholder values.
const CHECK_OUTCOME_XP_MULTIPLIER: Dictionary = {
	MissionResolutionResult.Outcome.SUCCESS: 1.0,
	MissionResolutionResult.Outcome.PARTIAL: 0.5,
	MissionResolutionResult.Outcome.FAILURE: 0.25,
}

## Mission-aware entry point, called automatically from MissionCheck.
## resolve() (both SinglePhase and ChoicePhase's chosen check run through
## it — see there) — nothing else needs to call this directly. Awards XP
## for one resolved check across a squad, at the granularity the mission
## actually earned it: only in the categories the check requires (a squad
## member with no skills in a required category simply has nothing to
## award), scaled by CHECK_OUTCOME_XP_MULTIPLIER for how the check actually
## went, and with per-skill "utilized" detection based on tag overlap with
## the check itself rather than a caller-supplied list. A skill counts as
## utilized if it shares a tag with check.tags (the same Exploited-style
## match TagBreadthResolutionStrategy already uses) and isn't countered by
## check.counter_tags — a countered skill contributed nothing to the roll,
## so it shouldn't earn the bonus even if it happens to share another tag
## with the check.
##
## Example: a check requiring Combat + Subterfuge, tagged [Olfactory],
## that resolves SUCCESS. Nick has skills in both categories -> XP in
## both. Judy only has Subterfuge skills -> XP in Subterfuge only, and
## her Subterfuge skill "Sniffer" (tagged [Olfactory]) gets the utilized
## multiplier on top.
static func award_xp_for_check(check: MissionCheck, squad: Array[AgentData],
		outcome: MissionResolutionResult.Outcome) -> void:
	var amount := int(round(BASE_CHECK_XP * float(CHECK_OUTCOME_XP_MULTIPLIER.get(outcome, 0.0))))
	if amount <= 0:
		return
	var reqs := check.get_proficiency_requirements()
	for key: String in SkillData.PROFICIENCY_KEYS:
		if reqs.get(key, 0) <= 0:
			continue
		for agent: AgentData in squad:
			var utilized := _utilized_skill_names(agent, key, check)
			award_proficiency_xp(agent, key, amount, utilized)

static func _utilized_skill_names(agent: AgentData, proficiency_key: String,
		check: MissionCheck) -> PackedStringArray:
	var names := PackedStringArray()
	for skill: SkillData in agent.skills:
		if skill.get_proficiency_key() != proficiency_key:
			continue
		if is_countered_by(skill, check.counter_tags):
			continue
		if is_countered_by(skill, check.tags):
			names.append(skill.skill_name)
	return names

## Every catalog skill belonging to one Proficiency, scanned live from
## res://data/skills/<proficiency>/ — add a .tres there and it's picked up
## automatically on the next call, no registration or code changes needed.
static func get_skills_for_proficiency(prof: SkillData.Proficiency) -> Array[SkillData]:
	var out: Array[SkillData] = []
	var dir_path := "res://data/skills/%s/" % SkillData.PROFICIENCY_KEYS[prof]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var skill: SkillData = load(dir_path + file_name)
			if skill != null:
				out.append(skill)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out

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
