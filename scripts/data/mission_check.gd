class_name MissionCheck
extends Resource
## MissionCheck — the proficiency/tag profile one resolvable check within
## a mission phase needs, and the actual unit every MissionResolutionStrategy
## resolves against (EventData no longer is — see EventData's Proficiency
## Requirements group). Holds requirement/target/tag fields plus its own
## resolution_strategy, without the event-level concerns (location,
## rewards, escalation, decision prompts, ...) that don't apply to a
## single check.

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

## Which MissionResolutionStrategy resolves this check. Defaults to a live
## instance rather than null so the Inspector shows a populated,
## expandable resource from the start — an unset Resource-typed @export
## shows as "[empty]" with nothing to click into otherwise.
@export var resolution_strategy: MissionResolutionStrategy = StatCheckResolutionStrategy.new()

func get_proficiency_requirements() -> Dictionary:
	return {
		"combat": req_combat,
		"subterfuge": req_subterfuge,
		"attunement": req_attunement,
		"erudition": req_erudition,
		"influence": req_influence,
		"ingenuity": req_ingenuity,
	}

## Per-category continuous targets, each falling back to its own req_*
## value when left unset (0), so a check works without needing explicit
## target tuning.
func get_target_values() -> Dictionary:
	return {
		"combat": target_combat if target_combat > 0.0 else float(req_combat),
		"subterfuge": target_subterfuge if target_subterfuge > 0.0 else float(req_subterfuge),
		"attunement": target_attunement if target_attunement > 0.0 else float(req_attunement),
		"erudition": target_erudition if target_erudition > 0.0 else float(req_erudition),
		"influence": target_influence if target_influence > 0.0 else float(req_influence),
		"ingenuity": target_ingenuity if target_ingenuity > 0.0 else float(req_ingenuity),
	}

func resolve(squad: Array[AgentData]) -> MissionResolutionResult:
	var strategy := resolution_strategy if resolution_strategy != null else StatCheckResolutionStrategy.new()
	return strategy.resolve(self, squad)
