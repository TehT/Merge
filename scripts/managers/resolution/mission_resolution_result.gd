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

## Human-readable trace of how a strategy arrived at this result — per-
## category coverage, tag/modifier breakdowns, the chance/roll/outcome
## line, per-agent rolls, whatever the producing strategy thinks is worth
## showing. Purely for visibility (EventManager prints it, the Mission
## Report UI displays it) — never read by any decision logic. Empty by
## default, so a strategy that doesn't populate it just shows nothing
## extra; nothing breaks.
var log_lines: PackedStringArray = []

static func outcome_name(outcome: Outcome) -> String:
	match outcome:
		Outcome.SUCCESS: return "success"
		Outcome.PARTIAL: return "partial"
		_: return "failure"
