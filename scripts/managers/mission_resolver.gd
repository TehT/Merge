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


## Best proficiency ranks across all members — the team's combined rank
## in each proficiency is the highest individual rank among its members.
## Works the same for a solo agent (a 1-member array reduces to that
## agent's own ranks).
static func compute_team_ranks(members: Array[AgentData]) -> Dictionary:
	var best := SkillData.empty_rank_dict()
	for m: AgentData in members:
		var ranks := m.get_proficiency_ranks()
		for key: String in SkillData.PROFICIENCY_KEYS:
			if ranks[key] > best[key]:
				best[key] = ranks[key]
	return best


static func compute_team_suitability(event: EventData, members: Array[AgentData]) -> float:
	if members.is_empty():
		return 0.0
	return compute_rank_coverage(compute_team_ranks(members), event) + _compute_synergy_bonus(members)


static func _compute_synergy_bonus(_members: Array[AgentData]) -> float:
	return 0.0
