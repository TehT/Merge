class_name MissionCheck
extends Resource
## MissionCheck — the proficiency/tag profile one resolvable check within
## a mission phase needs, and which MissionResolutionStrategy resolves
## it. The phase-scoped analog of EventData's requirement/target/tag
## fields, without the event-level concerns (location, rewards,
## escalation, decision prompts, ...) that don't apply to a single check
## — a phase's check is much narrower than a whole event.

@export var check_name: String = ""

@export_group("Requirements")
@export_range(0, 10) var req_combat: int = 0
@export_range(0, 10) var req_subterfuge: int = 0
@export_range(0, 10) var req_attunement: int = 0
@export_range(0, 10) var req_erudition: int = 0
@export_range(0, 10) var req_influence: int = 0
@export_range(0, 10) var req_ingenuity: int = 0

@export_group("Target Values")
@export var target_combat: float = 0.0
@export var target_subterfuge: float = 0.0
@export var target_attunement: float = 0.0
@export var target_erudition: float = 0.0
@export var target_influence: float = 0.0
@export var target_ingenuity: float = 0.0

@export_group("Tags")
@export var tags: PackedStringArray = []
@export var counter_tags: PackedStringArray = []

## Which MissionResolutionStrategy resolves this check. Defaults to
## StatCheckResolutionStrategy if left unassigned, same live-default
## reasoning as EventManager.resolution_strategy — an unset Resource-typed
## @export shows as "[empty]" with nothing to click into otherwise.
@export var resolution_strategy: MissionResolutionStrategy = StatCheckResolutionStrategy.new()

## Builds a throwaway EventData carrying just this check's requirement/
## target/tag fields, for handing to resolution_strategy.resolve() — the
## Strategy pattern contract is (EventData, Array[AgentData]), and this
## keeps that contract completely unchanged for every existing and future
## strategy rather than widening it just for phases.
func to_event_data() -> EventData:
	var e := EventData.new()
	e.req_combat = req_combat
	e.req_subterfuge = req_subterfuge
	e.req_attunement = req_attunement
	e.req_erudition = req_erudition
	e.req_influence = req_influence
	e.req_ingenuity = req_ingenuity
	e.target_combat = target_combat
	e.target_subterfuge = target_subterfuge
	e.target_attunement = target_attunement
	e.target_erudition = target_erudition
	e.target_influence = target_influence
	e.target_ingenuity = target_ingenuity
	e.tags = tags
	e.counter_tags = counter_tags
	return e

func resolve(squad: Array[AgentData]) -> MissionResolutionResult:
	var strategy := resolution_strategy if resolution_strategy != null else StatCheckResolutionStrategy.new()
	return strategy.resolve(to_event_data(), squad)
