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
##   PLAYER_CHOICE — always activates; pauses mission resolution and asks
##                   the player which check to attempt, via
##                   MissionChoiceDialog (Game.mission_choice_dialog) —
##                   see resolve() below. player_choice_picker lets tests
##                   (or any other caller) supply a different picker
##                   without touching UI/await plumbing.

enum Trigger { FAILURE, RANDOM, PLAYER_CHOICE }

@export var trigger: Trigger = Trigger.RANDOM
@export var checks: Array[MissionCheck] = []

## Overrides how PLAYER_CHOICE resolves its pick. Must be a Callable
## accepting (ChoicePhase, PackedStringArray) and returning a MissionCheck
## (awaitable — may itself be a coroutine). Left invalid in normal play,
## which falls back to Game.mission_choice_dialog.request_choice(); tests
## can assign a synchronous stand-in here to avoid needing a real UI/
## Signal round-trip. Not @export — this is a runtime/test hook, not
## authored content.
var player_choice_picker: Callable = Callable()

func get_checks() -> Array[MissionCheck]:
	return checks

## May suspend (via `await`) when trigger is PLAYER_CHOICE — always call
## with `await`, even for the other triggers, which resolve synchronously
## in practice but still live behind the same coroutine-shaped signature
## (see MissionPhase.resolve()).
func resolve(squad: Array[AgentData], previous_outcome: MissionResolutionResult.Outcome,
		log_so_far: PackedStringArray = PackedStringArray()) -> MissionPhaseResult:
	var result := MissionPhaseResult.new()

	if trigger == Trigger.FAILURE and previous_outcome != MissionResolutionResult.Outcome.FAILURE:
		result.ran = false
		return result

	if checks.is_empty():
		push_error("ChoicePhase '%s' has no checks to choose from" % phase_name)
		result.ran = false
		return result

	var chosen: MissionCheck = await _pick_check(log_so_far)
	var check_result := chosen.resolve(squad)
	result.outcome = check_result.outcome
	result.agent_results = check_result.agent_results
	result.log_lines = check_result.log_lines
	return result


func _pick_check(log_so_far: PackedStringArray) -> MissionCheck:
	if trigger == Trigger.PLAYER_CHOICE:
		var picker := player_choice_picker if player_choice_picker.is_valid() \
				else Callable(Game.mission_choice_dialog, "request_choice")
		return await picker.call(self, log_so_far)
	return checks[randi() % checks.size()]
