## ReqProficiencyRank — requires the agent's computed Proficiency rank
## (equipment-inclusive — see EquipmentHandler.compute_effective_ranks) to
## be at least min_rank in the given category.
class_name ReqProficiencyRank
extends EquipmentRequirement

@export var proficiency: SkillData.Proficiency = SkillData.Proficiency.COMBAT
@export_range(0, 10) var min_rank: int = 1

func is_met(agent: AgentData) -> bool:
	var ranks := agent.get_proficiency_ranks()
	var key := SkillData.PROFICIENCY_KEYS[proficiency]
	return int(ranks[key]) >= min_rank

func get_description() -> String:
	return "Requires %s rank %d+" % [SkillData.PROFICIENCY_NAMES[proficiency], min_rank]
