class_name StatCheckResolutionStrategy
extends MissionResolutionStrategy
## StatCheckResolutionStrategy — the original resolution method: team
## proficiency-rank coverage vs. the event's requirements sets a success
## chance, one roll buckets the outcome into success/partial/failure, and a
## second roll per agent derives injury/KIA from how badly the first roll
## missed. This is EventManager's default strategy when none is assigned,
## preserving prior behavior exactly. The "suitability -> dice" part of
## this (chance/outcome/injury math) now lives in
## MissionResolver.resolve_from_suitability(), shared with other
## strategies that compute suitability differently — see
## TagBreadthResolutionStrategy.

func resolve(event: EventData, squad: Array[AgentData]) -> MissionResolutionResult:
	var computed := MissionResolver.compute_team_suitability_explained(event, squad)
	return MissionResolver.resolve_from_suitability(computed["suitability"], squad, computed["log"])
