class_name SinglePhase
extends MissionPhase
## SinglePhase — one basic check, resolved by whatever
## MissionResolutionStrategy the check specifies. Always runs (no
## activation gate — that's ChoicePhase's job).

@export var check: MissionCheck

func resolve(squad: Array[AgentData],
		_previous_outcome: MissionResolutionResult.Outcome) -> MissionPhaseResult:
	var result := MissionPhaseResult.new()
	if check == null:
		push_error("SinglePhase '%s' has no check assigned" % phase_name)
		result.ran = false
		return result

	var check_result := check.resolve(squad)
	result.outcome = check_result.outcome
	result.agent_results = check_result.agent_results
	result.log_lines = check_result.log_lines
	return result
