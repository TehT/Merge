class_name StatCheckResolutionStrategy
extends MissionResolutionStrategy
## StatCheckResolutionStrategy — the original resolution method: team
## proficiency-rank coverage vs. the event's requirements sets a success
## chance, one roll buckets the outcome into success/partial/failure, and a
## second roll per agent derives injury/KIA from how badly the first roll
## missed. This is EventManager's default strategy when none is assigned,
## preserving prior behavior exactly.

func resolve(event: EventData, squad: Array[AgentData]) -> MissionResolutionResult:
	var suitability := MissionResolver.compute_team_suitability(event, squad)
	var chance: float = clampf(0.3 + suitability * 0.4, 0.05, 0.95)
	var roll := randf()

	var outcome: MissionResolutionResult.Outcome
	if roll <= chance * 0.6:
		outcome = MissionResolutionResult.Outcome.SUCCESS
	elif roll <= chance:
		outcome = MissionResolutionResult.Outcome.PARTIAL
	else:
		outcome = MissionResolutionResult.Outcome.FAILURE

	var badness: float = clampf((roll - chance) / maxf(0.0001, 1.0 - chance), 0.0, 1.0)
	var injury_chance: float
	match outcome:
		MissionResolutionResult.Outcome.SUCCESS: injury_chance = 0.05
		MissionResolutionResult.Outcome.PARTIAL: injury_chance = 0.15
		_: injury_chance = lerpf(0.15, 0.5, badness)
	var kia_chance := injury_chance * 0.2

	var agent_results := {}
	for member in squad:
		var r := randf()
		if r < kia_chance:
			agent_results[member.id] = AgentData.Status.KIA
		elif r < injury_chance:
			agent_results[member.id] = AgentData.Status.INJURED
		else:
			agent_results[member.id] = AgentData.Status.AVAILABLE

	var result := MissionResolutionResult.new()
	result.outcome = outcome
	result.roll = roll
	result.chance = chance
	result.team_suitability = suitability
	result.agent_results = agent_results
	return result
