class_name MissionPhaseResult
extends RefCounted
## MissionPhaseResult — what one MissionPhase.resolve() hands back to
## MissionPhaseRunner: whether it actually ran (a failure-gated
## ChoicePhase can be skipped entirely), its outcome, agent status rolls,
## and a trace log. The runner merges these across every phase into one
## overall MissionResolutionResult. RefCounted, not Resource — a fresh
## disposable value per phase resolution, same reasoning as
## MissionResolutionResult.

var ran: bool = true
var outcome: MissionResolutionResult.Outcome = MissionResolutionResult.Outcome.FAILURE
var agent_results: Dictionary = {} # agent_id -> AgentData.Status
var log_lines: PackedStringArray = []
