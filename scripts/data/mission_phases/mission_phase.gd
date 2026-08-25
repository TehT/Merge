class_name MissionPhase
extends Resource
## MissionPhase — Strategy-pattern base for one stage of a multi-stage
## mission (EventData.phases, resolved in order by MissionPhaseRunner).
## Concrete phases (SinglePhase, ChoicePhase) resolve whatever
## MissionCheck(s) they hold and report back a standardized
## MissionPhaseResult the runner can act on and merge with the rest.

@export var phase_name: String = ""

## Resolves this phase given the squad and the outcome of whatever phase
## ran immediately before it (SUCCESS if this is the first phase in the
## sequence) — ChoicePhase's "failure" trigger uses previous_outcome to
## decide whether it activates at all. Concrete phases override this and
## must return a fully-populated MissionPhaseResult.
func resolve(_squad: Array[AgentData],
		_previous_outcome: MissionResolutionResult.Outcome) -> MissionPhaseResult:
	push_error("MissionPhase.resolve() not implemented — override in a subclass")
	return MissionPhaseResult.new()
