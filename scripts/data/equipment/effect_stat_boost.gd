## EffectStatBoost — flat addition to a Proficiency's 0-200 score while
## equipped (e.g. +6 Combat). Operates on the score track specifically,
## not the rank track — see MissionResolver.compute_score_coverage() for
## how that reaches actual mission outcomes.
class_name EffectStatBoost
extends EquipmentEffect

@export var proficiency: SkillData.Proficiency = SkillData.Proficiency.COMBAT
@export var amount: float = 0.0

func apply_to_scores(scores: Dictionary) -> Dictionary:
	var key := SkillData.PROFICIENCY_KEYS[proficiency]
	scores[key] = float(scores[key]) + amount
	return scores

func get_description() -> String:
	return "%s%d %s (score)" % ["+" if amount >= 0 else "", int(amount), SkillData.PROFICIENCY_NAMES[proficiency]]
