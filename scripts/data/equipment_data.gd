## EquipmentData — a piece of gear as a container of composed rules, not
## hardcoded behavior. requirements/effects are Strategy-pattern lists
## (see EquipmentRequirement/EquipmentEffect) a designer mixes and matches
## in the Inspector to build an item's conditions and consequences without
## touching code — same composition approach as MissionResolutionStrategy
## and SkillTagModifier elsewhere in this project.
class_name EquipmentData
extends Resource

@export var equipment_name: String = ""
@export_enum("Weapon", "Armor", "Gadget") var slot_type: String = "Weapon"
@export var description: String = ""

@export_group("Rules")
@export var requirements: Array[EquipmentRequirement] = []
@export var effects: Array[EquipmentEffect] = []
