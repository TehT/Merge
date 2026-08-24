## MissionResolver — pure stat-based suitability math, shared by mission
## resolution strategies (scripts/managers/resolution/) and UI preview
## displays (match% in the deploy picker, team proficiency rows). A static
## utility (RefCounted), not an autoload: it has no persistent state, so it
## doesn't need global registration.
class_name MissionResolver
extends RefCounted

## Computes how well a team (or solo agent) covers an event's required
## proficiency ranks. Returns ~1.0 when ranks exactly meet requirements,
## >1.0 when exceeding, <1.0 when under-qualified.
static func compute_rank_coverage(agent_ranks: Dictionary, event: EventData) -> float:
	var reqs := event.get_proficiency_requirements()
	var req_count := 0
	var coverage_sum := 0.0

	for key: String in reqs:
		var req: int = reqs[key]
		if req <= 0:
			continue
		req_count += 1
		var agent_rank: int = agent_ranks.get(key, 0)
		coverage_sum += clampf(float(agent_rank) / float(req), 0.0, 2.0)

	if req_count == 0:
		return 1.0
	return coverage_sum / float(req_count)


## EXPERIMENTAL "teamwork" model: instead of each member's proficiency
## being computed independently and the team taking the best of those,
## every member's skills are pooled into one shared pile per proficiency
## category *before* rank aggregation runs — so a team can reach a
## proficiency rank none of its members could hit alone (two agents each
## with one rank-2 Combat skill don't just have "one rank-2 Combat skill
## twice," they collectively look like one agent with two rank-2 Combat
## skills, which is enough to qualify for rank 3). Reduces to a solo
## agent's own get_proficiency_ranks() for a 1-member team, since pooling
## one member's skills changes nothing. Pass active_tags (typically the
## event's own tags) to recalculate under that context — see
## SkillHandler.compute_effective_rank.
static func compute_team_ranks(members: Array[AgentData],
		active_tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var pooled_skills: Dictionary = {}
	for key: String in SkillData.PROFICIENCY_KEYS:
		pooled_skills[key] = [] as Array[SkillData]
	for m: AgentData in members:
		for skill: SkillData in m.skills:
			pooled_skills[skill.get_proficiency_key()].append(skill)

	var ranks := SkillHandler.empty_rank_dict()
	for key: String in SkillData.PROFICIENCY_KEYS:
		ranks[key] = SkillHandler.compute_proficiency_rank(pooled_skills[key], active_tags)
	return ranks


static func compute_team_suitability(event: EventData, members: Array[AgentData]) -> float:
	if members.is_empty():
		return 0.0
	return compute_rank_coverage(compute_team_ranks(members, event.tags), event) + _compute_synergy_bonus(members)


static func _compute_synergy_bonus(_members: Array[AgentData]) -> float:
	return 0.0
