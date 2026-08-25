## MissionResolver — pure stat-based suitability math, shared by mission
## resolution strategies (scripts/managers/resolution/) and UI preview
## displays (match% in the deploy picker, team proficiency rows). A static
## utility (RefCounted), not an autoload: it has no persistent state, so it
## doesn't need global registration.
class_name MissionResolver
extends RefCounted

## Computes how well a team (or solo agent) covers a set of required
## proficiency ranks (a get_proficiency_requirements()-shaped Dictionary,
## from either EventData or MissionCheck). Returns ~1.0 when ranks exactly
## meet requirements, >1.0 when exceeding, <1.0 when under-qualified.
static func compute_rank_coverage(agent_ranks: Dictionary, reqs: Dictionary) -> float:
	var req_count := 0
	var coverage_sum := 0.0

	for key: String in reqs:
		var req: int = reqs[key]
		if req <= 0:
			continue
		req_count += 1
		var agent_rank: int = agent_ranks.get(key, 0)
		coverage_sum += clampf(float(agent_rank) / float(req), 0.0, 2.0)

	if req_count == 0:
		return 1.0
	return coverage_sum / float(req_count)


## EXPERIMENTAL "teamwork" model: instead of each member's proficiency
## being computed independently and the team taking the best of those,
## every member's *effective* skills (own skills plus whatever their own
## equipped gear grants/modifies — see EquipmentHandler.get_effective_skills)
## are pooled into one shared pile per proficiency category *before* rank
## aggregation runs — so a team can reach a proficiency rank none of its
## members could hit alone (two agents each with one rank-2 Combat skill
## don't just have "one rank-2 Combat skill twice," they collectively look
## like one agent with two rank-2 Combat skills, which is enough to
## qualify for rank 3). Each member's equipped items' flat rank effects
## (EffectStatBoost-style) are then applied on top of the pooled result.
## Reduces to a solo agent's own get_proficiency_ranks() for a 1-member
## team, since pooling one member's skills changes nothing. Pass
## active_tags (typically the event's own tags) to recalculate under that
## context — see SkillHandler.compute_effective_rank.
static func compute_team_ranks(members: Array[AgentData],
		active_tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var pooled_skills: Dictionary = {}
	for key: String in SkillData.PROFICIENCY_KEYS:
		pooled_skills[key] = [] as Array[SkillData]
	for m: AgentData in members:
		for skill: SkillData in EquipmentHandler.get_effective_skills(m):
			pooled_skills[skill.get_proficiency_key()].append(skill)

	var ranks := SkillHandler.empty_rank_dict()
	for key: String in SkillData.PROFICIENCY_KEYS:
		ranks[key] = SkillHandler.compute_proficiency_rank(pooled_skills[key], active_tags)

	for m: AgentData in members:
		ranks = EquipmentHandler.apply_rank_effects(m, ranks)
	return ranks


## Team proficiency scores (0-200 scale) — simply summed per member, since
## score (unlike rank) is already additive by construction. Each member's
## own get_proficiency_scores() is already equipment-aware.
static func compute_team_scores(members: Array[AgentData]) -> Dictionary:
	var totals := SkillHandler.empty_proficiency_dict()
	for m: AgentData in members:
		var scores := m.get_proficiency_scores()
		for key: String in totals:
			totals[key] += scores[key]
	return totals


## Score-based counterpart to compute_rank_coverage(): compares team score
## against a requirement converted to its equivalent score (req *
## SkillData.RANK_SCALE, the same relationship a single skill's own
## rank/score already have). Lets equipment score bonuses move suitability
## even when they're too small to cross a rank threshold.
static func compute_score_coverage(team_scores: Dictionary, reqs: Dictionary) -> float:
	var req_count := 0
	var coverage_sum := 0.0

	for key: String in reqs:
		var req: int = reqs[key]
		if req <= 0:
			continue
		req_count += 1
		var expected_score: float = float(req) * float(SkillData.RANK_SCALE)
		var team_score: float = team_scores.get(key, 0.0)
		coverage_sum += clampf(team_score / expected_score, 0.0, 2.0)

	if req_count == 0:
		return 1.0
	return coverage_sum / float(req_count)


## How much team suitability leans on score coverage vs. rank coverage.
## Ranks stay primary (event requirements are rank-scaled, and rank
## aggregation is the "real" threshold system); score adds a smaller
## continuous nudge so equipment bonuses too small to cross a rank
## threshold still move the needle.
const SCORE_WEIGHT: float = 0.2


## Same computation as compute_team_suitability(), but also returns a
## human-readable trace of the rank/score coverage breakdown per required
## category — for callers (resolution strategies) that want to surface
## *why* a suitability number came out the way it did.
## compute_team_suitability() is a thin wrapper around this that just
## discards the log, for callers (e.g. the deploy screen's match%
## preview) that only want the number. reqs is a
## get_proficiency_requirements()-shaped Dictionary (EventData or
## MissionCheck); active_tags is typically the check's own tags, omitted
## for callers (like the deploy preview) with no specific check in mind.
static func compute_team_suitability_explained(reqs: Dictionary, members: Array[AgentData],
		active_tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	if members.is_empty():
		return {"suitability": 0.0, "log": PackedStringArray()}

	var team_ranks := compute_team_ranks(members, active_tags)
	var team_scores := compute_team_scores(members)
	var rank_coverage := compute_rank_coverage(team_ranks, reqs)
	var score_coverage := compute_score_coverage(team_scores, reqs)
	var synergy := _compute_synergy_bonus(members)
	var suitability := lerpf(rank_coverage, score_coverage, SCORE_WEIGHT) + synergy

	var log: PackedStringArray = []
	for key: String in SkillData.PROFICIENCY_KEYS:
		var req: int = reqs.get(key, 0)
		if req <= 0:
			continue
		log.append("  %s: team rank %d/%d, score %.0f/%.0f" % [
			key.capitalize(), team_ranks[key], req, team_scores[key], float(req) * float(SkillData.RANK_SCALE),
		])
	log.append("Rank coverage %.2f, score coverage %.2f (blended %d%% score) -> suitability %.2f" % [
		rank_coverage, score_coverage, int(SCORE_WEIGHT * 100.0), suitability,
	])
	return {"suitability": suitability, "log": log}


static func compute_team_suitability(reqs: Dictionary, members: Array[AgentData],
		active_tags: PackedStringArray = PackedStringArray()) -> float:
	if members.is_empty():
		return 0.0
	return compute_team_suitability_explained(reqs, members, active_tags)["suitability"]


static func _compute_synergy_bonus(_members: Array[AgentData]) -> float:
	return 0.0


## Average team suitability across every phase of a multi-stage mission —
## the deploy screen's match% preview. Per phase, averages suitability
## against each of the phase's own checks first (a ChoicePhase's checks
## all "count" since only one will actually run and which one isn't known
## ahead of time), then averages those per-phase numbers across all
## phases. A phase with no checks (misconfigured) is skipped rather than
## dragging the average to 0. Returns 0.0 if there's nothing to compute
## (no members, or no phase has any checks) — same "no data" convention
## as compute_team_suitability().
static func compute_mission_suitability(phases: Array[MissionPhase], members: Array[AgentData]) -> float:
	if members.is_empty():
		return 0.0

	var phase_total := 0.0
	var phase_count := 0
	for phase: MissionPhase in phases:
		var checks := phase.get_checks()
		if checks.is_empty():
			continue
		var check_total := 0.0
		for check: MissionCheck in checks:
			check_total += compute_team_suitability(check.get_proficiency_requirements(), members, check.tags)
		phase_total += check_total / float(checks.size())
		phase_count += 1

	if phase_count == 0:
		return 0.0
	return phase_total / float(phase_count)


## Coverage using arbitrary continuous per-category values against
## explicit per-category targets — for strategies whose aggregation isn't
## the standard RANK_THRESHOLDS tier walk and whose target isn't
## necessarily req_* itself (e.g. TagBreadthResolutionStrategy's totaled
## tag-weighted values against MissionCheck.get_target_values()). A
## category only counts if reqs still requires it (req_* > 0 — that stays
## the single source of truth for "is this category in play at all") and
## has a resolvable (>0) target. Same shape/clamping as
## compute_rank_coverage, just float-safe (compute_rank_coverage
## truncates its dict's values to int, which would silently lose
## precision here).
static func compute_value_coverage(values: Dictionary, targets: Dictionary, reqs: Dictionary) -> float:
	var req_count := 0
	var coverage_sum := 0.0

	for key: String in reqs:
		var req: int = reqs[key]
		if req <= 0:
			continue
		var target: float = targets.get(key, 0.0)
		if target <= 0.0:
			continue
		req_count += 1
		var value: float = values.get(key, 0.0)
		coverage_sum += clampf(value / target, 0.0, 2.0)

	if req_count == 0:
		return 1.0
	return coverage_sum / float(req_count)


## Turns an already-computed suitability float into a full resolution
## result: success chance, outcome bucket, and per-agent injury/KIA rolls.
## Factored out of StatCheckResolutionStrategy so multiple
## MissionResolutionStrategy implementations can share the same
## "suitability -> dice" math while computing suitability itself in
## entirely different ways. log_lines, if given, is whatever trace the
## caller already built while computing suitability (see
## compute_team_suitability_explained) — this appends the chance/roll/
## outcome and per-agent-roll lines on top and returns the combined log
## on the result. Duplicates log_lines before appending rather than
## mutating the caller's array in place — plain GDScript parameter
## passing doesn't isolate PackedStringArray the way it would an Array;
## .append() on the parameter is visible to the caller's own variable too
## unless duplicated first (a broader case of the same copy-on-write
## surprise as Resource.duplicate() — see EffectModifySkill).
## chance_multiplier, if not 1.0, is applied to chance before the roll
## happens (not after — a caller wanting to penalize an unmet hard
## prerequisite, see TagBreadthResolutionStrategy.missing_prereq_penalty,
## needs the roll itself to see the penalized chance, not just the
## displayed number).
static func resolve_from_suitability(suitability: float, squad: Array[AgentData],
		log_lines: PackedStringArray = PackedStringArray(), chance_multiplier: float = 1.0) -> MissionResolutionResult:
	var log := log_lines.duplicate()
	var chance: float = clampf(0.3 + suitability * 0.4, 0.05, 0.95)
	if not is_equal_approx(chance_multiplier, 1.0):
		var pre_penalty_chance := chance
		chance = clampf(chance * chance_multiplier, 0.05, 0.95)
		log.append("Prereq penalty x%.2f: chance %d%% -> %d%%" % [
			chance_multiplier, int(round(pre_penalty_chance * 100.0)), int(round(chance * 100.0)),
		])
	var roll := randf()

	var outcome: MissionResolutionResult.Outcome
	if roll <= chance * 0.6:
		outcome = MissionResolutionResult.Outcome.SUCCESS
	elif roll <= chance:
		outcome = MissionResolutionResult.Outcome.PARTIAL
	else:
		outcome = MissionResolutionResult.Outcome.FAILURE

	log.append("Chance %d%%, roll %.2f -> %s" % [
		int(round(chance * 100.0)), roll, MissionResolutionResult.outcome_name(outcome).capitalize(),
	])

	var badness: float = clampf((roll - chance) / maxf(0.0001, 1.0 - chance), 0.0, 1.0)
	var injury_chance: float
	match outcome:
		MissionResolutionResult.Outcome.SUCCESS: injury_chance = 0.05
		MissionResolutionResult.Outcome.PARTIAL: injury_chance = 0.15
		_: injury_chance = lerpf(0.15, 0.5, badness)
	var kia_chance := injury_chance * 0.2

	var agent_results := {}
	for member in squad:
		var r := randf()
		var status: AgentData.Status
		if r < kia_chance:
			status = AgentData.Status.KIA
		elif r < injury_chance:
			status = AgentData.Status.INJURED
		else:
			status = AgentData.Status.AVAILABLE
		agent_results[member.id] = status
		log.append("  %s: roll %.2f -> %s" % [member.agent_name, r, _status_log_name(status)])

	var result := MissionResolutionResult.new()
	result.outcome = outcome
	result.roll = roll
	result.chance = chance
	result.team_suitability = suitability
	result.agent_results = agent_results
	result.log_lines = log
	return result


static func _status_log_name(status: AgentData.Status) -> String:
	match status:
		AgentData.Status.KIA: return "KIA"
		AgentData.Status.INJURED: return "Injured"
		_: return "Available"
