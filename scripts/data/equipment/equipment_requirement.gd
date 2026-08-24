## EquipmentRequirement — Strategy-pattern base for equip conditions.
## EquipmentData.requirements holds a list of these; EquipmentHandler.can_equip()
## requires every one to pass. Concrete requirements (ReqProficiencyRank,
## ReqSkillTag, ReqSupernaturalType, ...) are independent Resources composed
## in the Inspector rather than hardcoded per item.
class_name EquipmentRequirement
extends Resource

## True if agent satisfies this requirement. Concrete requirements
## override this; the base implementation is a defensive default for an
## un-subclassed requirement left in an items's list by mistake.
func is_met(_agent: AgentData) -> bool:
	push_error("EquipmentRequirement.is_met() not implemented — override in a subclass")
	return false

## Human-readable summary for the equipment UI (e.g. "Requires Subterfuge
## rank 2+"). Concrete requirements override this.
func get_description() -> String:
	return "Unknown requirement"
