## EffectModifySkill — while equipped, finds every skill in the agent's
## effective pool carrying target_tag and modifies it: appending add_tag
## (if not already present) and/or shifting its rank by rank_bonus.
## Matched skills are duplicate()d before modification, so the agent's
## real SkillData resources are never permanently altered — the change
## only lives in the working copy EquipmentHandler builds per calculation.
class_name EffectModifySkill
extends EquipmentEffect

@export var target_tag: String = ""
@export var add_tag: String = ""
@export var rank_bonus: int = 0

func apply_to_skills(skills: Array[SkillData]) -> Array[SkillData]:
	var out: Array[SkillData] = []
	for skill: SkillData in skills:
		if skill.has_tag(target_tag):
			var modified: SkillData = skill.duplicate()
			if add_tag != "" and not modified.has_tag(add_tag):
				# Built fresh (not "var t := modified.tags; t.append(...)")
				# because Resource.duplicate() doesn't reliably break
				# copy-on-write sharing for PackedStringArray export
				# fields — appending to a derived copy can still mutate
				# the original skill's tags buffer.
				var new_tags := PackedStringArray()
				for t: String in skill.tags:
					new_tags.append(t)
				new_tags.append(add_tag)
				modified.tags = new_tags
			modified.rank = maxi(0, modified.rank + rank_bonus)
			out.append(modified)
		else:
			out.append(skill)
	return out

func get_description() -> String:
	var parts: Array[String] = []
	if rank_bonus != 0:
		parts.append("%s%d rank" % ["+" if rank_bonus >= 0 else "", rank_bonus])
	if add_tag != "":
		parts.append("adds [%s]" % add_tag)
	var effect_text := " / ".join(parts) if not parts.is_empty() else "no change"
	return "Skills tagged [%s]: %s" % [target_tag, effect_text]
