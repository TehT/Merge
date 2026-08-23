## MissionResolver — pure stat-based resolution math. A static utility
## (RefCounted), not an autoload: it has no persistent state, so it doesn't
## need global registration.
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
static func compute_team_ranks(members: Array[AgentData]) -> Dictionary:
	var best := SkillData.empty_rank_dict()
	for m: AgentData in members:
		var ranks := m.get_proficiency_ranks()
		for key: String in SkillData.PROFICIENCY_KEYS:
			if ranks[key] > best[key]:
				best[key] = ranks[key]
	return best


static func compute_team_suitability(event: EventData, members: Array[AgentData], team: TeamData = null) -> float:
	if members.is_empty():
		return 0.0

	var ranks: Dictionary
	if team != null:
		ranks = compute_team_ranks(members)
	else:
		ranks = members[0].get_proficiency_ranks()

	return compute_rank_coverage(ranks, event) + _compute_synergy_bonus(members)


static func _compute_synergy_bonus(_members: Array[AgentData]) -> float:
	return 0.0


static func resolve(event: EventData, members: Array[AgentData], team: TeamData = null) -> Dictionary:
	var suitability := compute_team_suitability(event, members, team)
	var chance: float = clampf(0.3 + suitability * 0.4, 0.05, 0.95)
	var roll := randf()

	var outcome: String
	if roll <= chance * 0.6:
		outcome = "success"
	elif roll <= chance:
		outcome = "partial"
	else:
		outcome = "failure"

	var badness: float = clampf((roll - chance) / maxf(0.0001, 1.0 - chance), 0.0, 1.0)
	var injury_chance: float
	match outcome:
		"success": injury_chance = 0.05
		"partial": injury_chance = 0.15
		_: injury_chance = lerpf(0.15, 0.5, badness)
	var kia_chance := injury_chance * 0.2

	var agent_results := {}
	for member in members:
		var r := randf()
		if r < kia_chance:
			agent_results[member.id] = AgentData.Status.KIA
		elif r < injury_chance:
			agent_results[member.id] = AgentData.Status.INJURED
		else:
			agent_results[member.id] = AgentData.Status.AVAILABLE

	return {
		"outcome": outcome,
		"roll": roll,
		"chance": chance,
		"team_suitability": suitability,
		"agent_results": agent_results,
	}
