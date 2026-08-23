class_name MissionResolutionResult
extends RefCounted
## MissionResolutionResult — the standardized state every
## MissionResolutionStrategy hands back to EventManager. Plain data, no
## behavior: EventManager and the UI only ever read these fields, regardless
## of which strategy produced them (a single stat roll today, maybe a
## multi-phase gauntlet later). RefCounted, not Resource — this is a fresh
## disposable value per resolution, never saved/edited as an asset.

enum Outcome { SUCCESS, PARTIAL, FAILURE }

var outcome: Outcome = Outcome.FAILURE
var roll: float = 0.0
var chance: float = 0.0
var team_suitability: float = 0.0
var agent_results: Dictionary = {} # agent_id -> AgentData.Status

static func outcome_name(outcome: Outcome) -> String:
	match outcome:
		Outcome.SUCCESS: return "success"
		Outcome.PARTIAL: return "partial"
		_: return "failure"
