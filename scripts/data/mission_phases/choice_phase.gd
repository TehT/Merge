class_name ChoicePhase
extends MissionPhase
## ChoicePhase — a phase that picks ONE check from its own list to
## resolve, per trigger:
##
##   FAILURE       — a conditional branch, not a pick-among-alternatives
##                   mode: this phase only activates at all if the
##                   PREVIOUS phase's outcome was a failure (a reactive
##                   "recovery" stage). If the previous phase didn't fail,
##                   this phase is skipped entirely — MissionPhaseResult.ran
##                   is false and it contributes nothing to the mission.
##                   If it does activate, it picks among checks the same
##                   way RANDOM does.
##   RANDOM        — always activates; picks one of checks uniformly at
##                   random.
##   PLAYER_CHOICE — always activates; SHOULD let the player pick which
##                   check to attempt. There's no mid-mission choice UI
##                   yet (resolution is currently synchronous — pausing
##                   for player input mid-resolve() is a different kind
##                   of problem than anything else in this pipeline), so
##                   this is a stub: it auto-picks the first listed check.
##                   Deliberately not silently identical to RANDOM, so
##                   it's easy to grep for when the real UI gets built.

enum Trigger { FAILURE, RANDOM, PLAYER_CHOICE }

@export var trigger: Trigger = Trigger.RANDOM
@export var checks: Array[MissionCheck] = []

func resolve(squad: Array[AgentData],
		previous_outcome: MissionResolutionResult.Outcome) -> MissionPhaseResult:
	var result := MissionPhaseResult.new()

	if trigger == Trigger.FAILURE and previous_outcome != MissionResolutionResult.Outcome.FAILURE:
		result.ran = false
		return result

	if checks.is_empty():
		push_error("ChoicePhase '%s' has no checks to choose from" % phase_name)
		result.ran = false
		return result

	var chosen := _pick_check()
	var check_result := chosen.resolve(squad)
	result.outcome = check_result.outcome
	result.agent_results = check_result.agent_results
	result.log_lines = check_result.log_lines
	return result


func _pick_check() -> MissionCheck:
	if trigger == Trigger.PLAYER_CHOICE:
		return checks[0] # stub — see class comment
	return checks[randi() % checks.size()]
