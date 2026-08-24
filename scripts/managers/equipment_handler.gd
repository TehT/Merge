## EquipmentHandler — cross-cutting equipment computation: validating
## whether an agent can equip an item, and weaving equipped items'
## effects into the agent's skill pool / proficiency ranks / proficiency
## scores without ever mutating the agent's real SkillData resources. A
## static utility (RefCounted), not an autoload — mirrors SkillHandler's
## shape and role for the equipment system.
class_name EquipmentHandler
extends RefCounted

## agent's equipped items, weapon/armor/gadget slots collapsed into one
## list (empty slots skipped). This is also the order effects apply in.
static func get_equipped_items(agent: AgentData) -> Array[EquipmentData]:
	var out: Array[EquipmentData] = []
	if agent.equipped_weapon != null:
		out.append(agent.equipped_weapon)
	if agent.equipped_armor != null:
		out.append(agent.equipped_armor)
	if agent.equipped_gadget != null:
		out.append(agent.equipped_gadget)
	return out

## True if every one of item's requirements is met. Checked against the
## agent's current effective ranks/skills — i.e. gear already equipped
## can satisfy another item's requirement (a boost from one piece can
## unlock another), so equip order can matter for borderline loadouts.
static func can_equip(agent: AgentData, item: EquipmentData) -> bool:
	for req: EquipmentRequirement in item.requirements:
		if not req.is_met(agent):
			return false
	return true

## The agent's skill pool with every equipped item's apply_to_skills()
## effects applied, in equip-slot order (weapon, armor, gadget). Starts
## from a duplicated copy of agent.skills so nothing an effect does here
## — appending a granted skill, modifying a matched one — ever touches the
## agent's real sheet.
static func get_effective_skills(agent: AgentData) -> Array[SkillData]:
	var skills: Array[SkillData] = agent.skills.duplicate()
	for item: EquipmentData in get_equipped_items(agent):
		for effect: EquipmentEffect in item.effects:
			skills = effect.apply_to_skills(skills)
	return skills

## Runs every equipped item's apply_to_ranks() over ranks, in equip-slot
## order. Split out from compute_effective_ranks() so MissionResolver can
## apply the same per-member rank effects on top of a team-pooled rank
## dict, not just a single agent's own.
static func apply_rank_effects(agent: AgentData, ranks: Dictionary) -> Dictionary:
	for item: EquipmentData in get_equipped_items(agent):
		for effect: EquipmentEffect in item.effects:
			ranks = effect.apply_to_ranks(ranks)
	return ranks

## Runs every equipped item's apply_to_scores() over scores, in equip-slot
## order. Same split-out rationale as apply_rank_effects().
static func apply_score_effects(agent: AgentData, scores: Dictionary) -> Dictionary:
	for item: EquipmentData in get_equipped_items(agent):
		for effect: EquipmentEffect in item.effects:
			scores = effect.apply_to_scores(scores)
	return scores

## Proficiency ranks from the agent's effective (equipment-modified)
## skill pool, then adjusted by every equipped item's flat rank effects.
static func compute_effective_ranks(agent: AgentData,
		active_tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var by_key: Dictionary = {}
	for key: String in SkillData.PROFICIENCY_KEYS:
		by_key[key] = [] as Array[SkillData]
	for skill: SkillData in get_effective_skills(agent):
		by_key[skill.get_proficiency_key()].append(skill)

	var ranks := SkillHandler.empty_rank_dict()
	for key: String in SkillData.PROFICIENCY_KEYS:
		ranks[key] = SkillHandler.compute_proficiency_rank(by_key[key], active_tags)

	return apply_rank_effects(agent, ranks)

## Proficiency scores from the agent's effective (equipment-modified)
## skill pool, then adjusted by every equipped item's flat score effects.
static func compute_effective_scores(agent: AgentData) -> Dictionary:
	var scores := SkillHandler.empty_proficiency_dict()
	for skill: SkillData in get_effective_skills(agent):
		scores[skill.get_proficiency_key()] += float(skill.get_scaled_rank())

	return apply_score_effects(agent, scores)
