class_name MissionPhase
extends Resource
## MissionPhase — Strategy-pattern base for one stage of a multi-stage
## mission (EventData.phases, resolved in order by MissionPhaseRunner).
## Concrete phases (SinglePhase, ChoicePhase) resolve whatever
## MissionCheck(s) they hold and report back a standardized
## MissionPhaseResult the runner can act on and merge with the rest.

@export var phase_name: String = ""

## Every MissionCheck this phase could possibly resolve — one for
## SinglePhase, all of them for ChoicePhase (only one actually runs, but
## which one isn't known ahead of time). Lets UI/preview code (requirement
## display, match% averaging) walk an event's phases without caring which
## concrete phase type it's looking at. Concrete phases override this.
func get_checks() -> Array[MissionCheck]:
	return []

## Resolves this phase given the squad and the outcome of whatever phase
## ran immediately before it (SUCCESS if this is the first phase in the
## sequence) — ChoicePhase's "failure" trigger uses previous_outcome to
## decide whether it activates at all. log_so_far is everything
## MissionPhaseRunner has logged for this mission up to (not including)
## this phase — ChoicePhase's PLAYER_CHOICE trigger shows it in the choice
## dialogue so the player can see how the mission's gone before deciding.
## Concrete phases override this and must return a fully-populated
## MissionPhaseResult. May be a coroutine (PLAYER_CHOICE awaits the
## player's pick) — always call with `await`, even on a phase that
## resolves synchronously in practice.
func resolve(_squad: Array[AgentData], _previous_outcome: MissionResolutionResult.Outcome,
		_log_so_far: PackedStringArray = PackedStringArray()) -> MissionPhaseResult:
	push_error("MissionPhase.resolve() not implemented — override in a subclass")
	return MissionPhaseResult.new()
