class_name MissionPhaseRunner
extends RefCounted
## MissionPhaseRunner — resolves a multi-stage mission (EventData.phases)
## end-to-end: runs each phase in order, tracking the previous phase's
## outcome so a failure-gated ChoicePhase knows whether to activate, and
## merges every phase's agent-status rolls into one combined
## MissionResolutionResult. EventManager calls this instead of a single
## resolution_strategy.resolve() whenever event.phases isn't empty;
## single-stage events (still the overwhelming majority) are entirely
## unaffected — an empty phases array was always the default.
##
## Agent statuses merge worst-wins across phases (KIA > Injured >
## Available) — an agent injured in an earlier phase can't come out
## "healed" just because a later phase's independent roll landed
## Available. There's no fatigue modeling yet (an agent used hard in one
## phase's check isn't any worse at a different phase's check) —
## deliberately deferred, per the request that introduced this system.
##
## The final result's outcome is whichever phase actually resolved last
## (skipped ChoicePhases don't count) — the simplest, most narratively
## legible way to collapse a sequence into the single outcome
## EventManager._apply_resolution() still expects. roll/chance/
## team_suitability don't have one clean meaning across several phases,
## so they're left at their MissionResolutionResult defaults; the
## per-phase numbers live in log_lines instead.
##
## A coroutine — a PLAYER_CHOICE ChoicePhase suspends resolution to await
## the player's pick (see ChoicePhase.resolve()), so every call site must
## `await` this, even though most missions (no PLAYER_CHOICE phase)
## resolve synchronously in practice. Callers: EventManager, whenever
## event.phases isn't empty.

static func resolve(phases: Array[MissionPhase], squad: Array[AgentData]) -> MissionResolutionResult:
	var result := MissionResolutionResult.new()
	if phases.is_empty():
		push_warning("[MissionPhaseRunner] resolve() called with an empty phases array — nothing to run.")
		return result

	var log: PackedStringArray = []
	var merged_agent_results: Dictionary = {}
	var previous_outcome := MissionResolutionResult.Outcome.SUCCESS
	var last_outcome := MissionResolutionResult.Outcome.SUCCESS
	var any_phase_ran := false

	for i in range(phases.size()):
		var phase: MissionPhase = phases[i]
		var label := phase.phase_name if phase.phase_name != "" else "Phase %d" % (i + 1)
		# log so far (everything from earlier phases) — passed by reference,
		# safe because resolve() only ever reads it (see MissionChoiceDialog).
		var phase_result: MissionPhaseResult = await phase.resolve(squad, previous_outcome, log)

		if phase_result == null or not phase_result.ran:
			log.append("[%s] skipped" % label)
			continue

		any_phase_ran = true
		log.append("[%s] -> %s" % [label, MissionResolutionResult.outcome_name(phase_result.outcome).capitalize()])
		for line: String in phase_result.log_lines:
			log.append("  " + line)

		for agent_id: String in phase_result.agent_results:
			var status: AgentData.Status = phase_result.agent_results[agent_id]
			if not merged_agent_results.has(agent_id) or \
					_status_severity(status) > _status_severity(merged_agent_results[agent_id]):
				merged_agent_results[agent_id] = status

		previous_outcome = phase_result.outcome
		last_outcome = phase_result.outcome

	if not any_phase_ran:
		push_warning("[MissionPhaseRunner] every phase was skipped — no check ever ran.")

	result.outcome = last_outcome
	result.agent_results = merged_agent_results
	result.log_lines = log
	return result


static func _status_severity(status: AgentData.Status) -> int:
	match status:
		AgentData.Status.KIA: return 2
		AgentData.Status.INJURED: return 1
		_: return 0
