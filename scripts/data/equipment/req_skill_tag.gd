## ReqSkillTag — requires the agent to have at least one skill (their own,
## plus any granted by other currently-equipped gear — see
## EquipmentHandler.get_effective_skills) carrying the given tag.
class_name ReqSkillTag
extends EquipmentRequirement

@export var tag: String = ""

func is_met(agent: AgentData) -> bool:
	for skill: SkillData in EquipmentHandler.get_effective_skills(agent):
		if skill.has_tag(tag):
			return true
	return false

func get_description() -> String:
	return "Requires a skill tagged [%s]" % tag
