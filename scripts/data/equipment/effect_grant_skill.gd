## EffectGrantSkill — while equipped, appends a virtual skill to the
## agent's effective skill pool, so it counts toward rank thresholds, tag
## checks (including other equipment's ReqSkillTag), and scores exactly
## like an owned skill would. The granted_skill resource itself is never
## handed out directly — always a duplicate(), so it can't be mutated by
## an EffectModifySkill (its own or another item's) or aliased across
## every agent who equips this item.
class_name EffectGrantSkill
extends EquipmentEffect

@export var granted_skill: SkillData

func apply_to_skills(skills: Array[SkillData]) -> Array[SkillData]:
	if granted_skill != null:
		skills.append(granted_skill.duplicate())
	return skills

func get_description() -> String:
	if granted_skill == null:
		return "Grants a skill (none set)"
	return "Grants skill: %s (%s r%d)" % [
		granted_skill.skill_name, granted_skill.get_proficiency_name(), granted_skill.rank]
