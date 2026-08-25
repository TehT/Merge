class_name TagBreadthResolutionStrategy
extends MissionResolutionStrategy
## TagBreadthResolutionStrategy — alternate resolution: instead of pooling
## skills by Proficiency category alone and walking SkillHandler's
## RANK_THRESHOLDS tier table, this pools by TAG within each category and
## rewards a team that covers a category from several angles over one
## that stacks copies of the same angle. Two passes:
##
## 1. Modifier Pass — before pooling, every skill's rank is adjusted
##    against the check's own tags:
##      - Countered: the skill shares a tag with check.counter_tags ->
##        effective rank 0 (contributes nothing). This is the first real
##        use of counter_tags anywhere in resolution.
##      - Exploited: the skill shares a tag with check.tags (the check's
##        general context tags — there's no separate "hazard" field, so
##        this reads that as the closest existing concept) -> effective
##        rank + 1. Counter takes priority over exploit if a skill somehow
##        matches both.
##
## 2. Redundancy Pass — group each category's (modified) skills by tag;
##    within a tag group, sort by effective rank descending and weight
##    each skill's contribution so a lone top skill counts fully but
##    redundant copies of the same rank increasingly don't:
##      - A skill alone at its rank-tier: 100% / 50% / 0% for the 1st /
##        2nd / 3rd+ distinct tier it occupies (by rank, descending).
##      - Skills tied at the same rank share a tier and split a *higher*
##        total than a lone skill would get, but at a discount per head:
##        per-skill weight = max(0, 180/n - 15) percent, for a tie of
##        size n. This exactly reproduces the anchor points given when
##        this strategy was speced (2-way 75% each, 3-way 45% each,
##        4-way 30% each) as one closed-form curve, extended smoothly
##        beyond n=4 rather than left undefined ("and so forth").
##      - A skill with several tags contributes under each one it holds
##        that isn't fully redundant with a teammate's — this is the
##        literal reading of "reward breadth": a single versatile skill
##        gets credited for each angle it covers, same as several
##        specialists would.
##    Every tag's weighted total is summed into one continuous "total
##    party proficiency value" per category (not a discrete 0-10 rank),
##    which is compared against that category's target (MissionCheck.
##    get_target_values() — a separate, continuous-scale field from req_*,
##    falling back to req_*'s own value if unset) via
##    MissionResolver.compute_value_coverage() — the literal reading of
##    "actual hard check requirements are based on total party
##    proficiency values."
##
## 3. Hard Prerequisite Gate — req_* stays a real gate even though the
##    Redundancy Pass compares totals against target_* instead: a team can
##    have a great tag-weighted total in a category (enough breadth to
##    clear its target) while still lacking the baseline rank req_*
##    demands. Each required category whose actual pooled rank (the
##    ordinary aggregation, not this strategy's own totals) falls short
##    multiplies the final chance by missing_prereq_penalty — compounding
##    once per category missed, so failing two prerequisites is worse
##    than failing one.
##
## The suitability float this produces (alongside a trace of all three
## steps, on MissionResolutionResult.log_lines) feeds the same
## "suitability -> dice" math StatCheckResolutionStrategy uses
## (MissionResolver.resolve_from_suitability) — only how suitability
## itself is computed, and the extra prereq-gate multiplier, differ.

## Chance multiplier applied once per required category whose team rank
## doesn't clear its req_* hard prerequisite (compounds: two missed
## categories apply this twice). Tunable in the Inspector — 0.75 means
## one missed prerequisite cuts the chance by a quarter. 0.5 (a straight
## halving) played too harsh in practice — a 95% shot dropping to ~40-48%
## off a single missed prerequisite felt like too big a swing.
@export_range(0.0, 1.0) var missing_prereq_penalty: float = 0.75


func resolve(check: MissionCheck, squad: Array[AgentData]) -> MissionResolutionResult:
	var computed := _compute_suitability(check, squad)
	var prereq := _compute_prereq_multiplier(check, squad)
	var log: PackedStringArray = computed["log"]
	for line: String in prereq["log"]:
		log.append(line)
	return MissionResolver.resolve_from_suitability(
		computed["suitability"], squad, log, prereq["multiplier"])


## Checks the team's actual pooled Proficiency rank (the ordinary
## aggregation MissionResolver.compute_team_ranks() uses — not this
## strategy's own tag-weighted totals) against each required category's
## hard req_* prerequisite. Returns {"multiplier": float, "log":
## PackedStringArray} — multiplier is 1.0 if every prerequisite is met.
func _compute_prereq_multiplier(check: MissionCheck, squad: Array[AgentData]) -> Dictionary:
	var team_ranks := MissionResolver.compute_team_ranks(squad, check.tags)
	var reqs := check.get_proficiency_requirements()
	var multiplier := 1.0
	var log: PackedStringArray = []
	for key: String in SkillData.PROFICIENCY_KEYS:
		var req: int = reqs.get(key, 0)
		if req <= 0:
			continue
		var rank: int = team_ranks.get(key, 0)
		if rank < req:
			multiplier *= missing_prereq_penalty
			log.append("  [prereq missed] %s: rank %d < required %d (x%.2f chance)" % [
				key.capitalize(), rank, req, missing_prereq_penalty])
	return {"multiplier": multiplier, "log": log}


## Returns {"suitability": float, "log": PackedStringArray} — the log
## traces both passes: which skills got countered/exploited, then each
## category's total value against its requirement.
func _compute_suitability(check: MissionCheck, squad: Array[AgentData]) -> Dictionary:
	if squad.is_empty():
		return {"suitability": 0.0, "log": PackedStringArray()}

	var log: PackedStringArray = []

	# Pool every member's effective (equipment-aware) skills by category,
	# each carrying its Modifier-Pass-adjusted effective rank.
	var by_category: Dictionary = {}
	for key: String in SkillData.PROFICIENCY_KEYS:
		by_category[key] = []
	for member: AgentData in squad:
		for skill: SkillData in EquipmentHandler.get_effective_skills(member):
			var effective_rank := _apply_modifier_pass(skill, check)
			if effective_rank == 0 and skill.rank > 0:
				log.append("  [countered] %s's %s (rank %d -> 0)" % [
					member.agent_name, skill.skill_name, skill.rank])
			elif effective_rank > skill.rank:
				log.append("  [exploited] %s's %s (rank %d -> %d)" % [
					member.agent_name, skill.skill_name, skill.rank, effective_rank])
			by_category[skill.get_proficiency_key()].append({"skill": skill, "rank": effective_rank})

	var totals := SkillHandler.empty_proficiency_dict()
	var reqs := check.get_proficiency_requirements()
	var targets := check.get_target_values()
	for key: String in SkillData.PROFICIENCY_KEYS:
		totals[key] = _compute_category_value(by_category[key])
		var req: int = reqs.get(key, 0)
		if req > 0 or totals[key] > 0.0:
			log.append("  %s: total value %.2f (target %.1f, req rank %d)" % [
				key.capitalize(), totals[key], targets.get(key, 0.0), req])

	var suitability := MissionResolver.compute_value_coverage(totals, targets, reqs)
	log.append("Total-value coverage -> suitability %.2f" % suitability)
	return {"suitability": suitability, "log": log}


func _apply_modifier_pass(skill: SkillData, check: MissionCheck) -> int:
	# is_countered_by() is really just "does any of these tags match the
	# skill's own tags" — reused here for both directions, since Countered
	# and Exploited are the same tag-intersection test against two
	# different tag lists.
	if SkillHandler.is_countered_by(skill, check.counter_tags):
		return 0
	if SkillHandler.is_countered_by(skill, check.tags):
		return skill.rank + 1
	return skill.rank


func _compute_category_value(entries: Array) -> float:
	var tags_seen: Dictionary = {}
	for entry: Dictionary in entries:
		var skill: SkillData = entry["skill"]
		for tag: String in skill.tags:
			tags_seen[tag] = true

	var total := 0.0
	for tag: String in tags_seen:
		var matching: Array = entries.filter(
			func(e: Dictionary) -> bool: return (e["skill"] as SkillData).has_tag(tag))
		total += _compute_tag_group_value(matching)
	return total


## Sorts matching skills by effective rank descending, groups into tiers
## of equal rank, and weights each tier by how far down the sorted order
## it falls (single skills) or how many teammates share its rank (ties) —
## see the class comment for the exact formula and where its numbers
## come from.
func _compute_tag_group_value(matching: Array) -> float:
	var sorted: Array = matching.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] > b["rank"])

	var tiers: Array = []
	for entry: Dictionary in sorted:
		var r: int = entry["rank"]
		if not tiers.is_empty() and tiers[-1][0] == r:
			tiers[-1].append(r)
		else:
			tiers.append([r])

	var total := 0.0
	for slot_index in range(tiers.size()):
		var tier: Array = tiers[slot_index]
		var n := tier.size()
		var weight: float
		if n == 1:
			weight = maxf(0.0, 1.0 - 0.5 * slot_index)
		else:
			weight = maxf(0.0, 180.0 / float(n) - 15.0) / 100.0
		for r: int in tier:
			total += float(r) * weight
	return total
