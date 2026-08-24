## ReqSupernaturalType — requires the agent's origin to match exactly
## (e.g. gear that only a Mundane operative — SupernaturalType.NONE — can
## use, or gear reserved for a specific Awakened type).
class_name ReqSupernaturalType
extends EquipmentRequirement

@export var required_type: AgentData.SupernaturalType = AgentData.SupernaturalType.NONE

func is_met(agent: AgentData) -> bool:
	return agent.supernatural_type == required_type

func get_description() -> String:
	return "Requires origin: %s" % _type_name(required_type)

## Local name lookup rather than reusing AgentData.get_type_name(), which
## is an instance method bound to an agent's own supernatural_type — this
## needs to name a type in the abstract, not describe a specific agent.
static func _type_name(t: AgentData.SupernaturalType) -> String:
	match t:
		AgentData.SupernaturalType.NONE: return "Mundane"
		AgentData.SupernaturalType.PSYCHIC: return "Psychic"
		AgentData.SupernaturalType.ELEMENTAL: return "Elemental"
		AgentData.SupernaturalType.SHADOW: return "Shadow"
		AgentData.SupernaturalType.WARD: return "Ward"
		AgentData.SupernaturalType.BEAST: return "Beast"
		AgentData.SupernaturalType.SEER: return "Seer"
	return "Unknown"
