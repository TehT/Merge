## EquipmentEffect — Strategy-pattern base for what a piece of equipment
## does while worn. EquipmentData.effects holds a list of these;
## EquipmentHandler runs every equipped item's effects through three
## injection points, in this order:
##
##   1. apply_to_skills() — on a working copy of the agent's skill list
##      (already duplicated, so nothing here ever mutates the agent's real
##      SkillData resources). Used by effects that add or modify skills.
##   2. apply_to_ranks() — after Proficiency ranks are aggregated from the
##      (possibly skill-modified) pool. A flat adjustment to the 0-10 rank
##      track that resolution actually reads.
##   3. apply_to_scores() — after Proficiency scores are summed from the
##      same pool. A flat adjustment to the 0-200 score track, which
##      MissionResolver blends into suitability as a smaller-weighted
##      smoothing term alongside rank coverage.
##
## Each hook is a no-op by default — a concrete effect only overrides the
## one(s) it actually needs.
class_name EquipmentEffect
extends Resource

func apply_to_skills(skills: Array[SkillData]) -> Array[SkillData]:
	return skills

func apply_to_ranks(ranks: Dictionary) -> Dictionary:
	return ranks

func apply_to_scores(scores: Dictionary) -> Dictionary:
	return scores

## Human-readable summary for the equipment UI (e.g. "+6 Combat"). Concrete
## effects override this; the base default covers an un-subclassed effect
## left in an item's list by mistake.
func get_description() -> String:
	return "Unknown effect"
