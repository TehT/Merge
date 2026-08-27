extends VBoxContainer
## SlideoutViewEquipSlot — picker for one of an agent's equipment slots:
## shows what's currently equipped (with an Unequip option), then every
## reachable item for that slot_type with an Equip button, disabled and
## annotated when the agent doesn't meet its requirements. "Reachable"
## is Global equipment (usable from anywhere) plus whatever's local to
## the base the agent is actually at right now (TeamManager.
## get_agent_base()) — not other bases' local_equipment, and not
## anything at all if the agent's team is away from every base
## (traveling, or on-site at a mission). Mirrors SlideoutViewDeploy's
## "list of options with an action button" shape.
##
## Layout lives in scenes/ui/views/slideout_equip_slot.tscn (editable
## in the editor); each reachable item row is an instance of
## equip_option_row.tscn.

@export var option_row_scene: PackedScene

var _agent: AgentData
var _slot_type: String


func populate(data: Variant, on_close: Callable) -> void:
	_agent = data["agent"]
	_slot_type = data["slot_type"]

	%Header.set_title("Equip: %s" % _slot_type)
	%Header.close_requested.connect(on_close)

	var current: EquipmentData = _current_equipped()
	if current != null:
		%CurrentSep.visible = true
		%CurrentRow.visible = true
		%CurrentLabel.text = "Equipped: %s" % current.equipment_name
		%UnequipBtn.pressed.connect(func() -> void:
				_agent.unequip(_slot_type)
				on_close.call()
				Game.left_detail.show_view("agent", _agent))

	var current_base: BaseData = Game.team_manager.get_agent_base(_agent.id)
	var reachable: Array[EquipmentData] = Game.base_manager.global_equipment.duplicate()
	if current_base != null:
		reachable.append_array(current_base.local_equipment)
	var pool: Array[EquipmentData] = reachable.filter(
			func(item: EquipmentData) -> bool: return item.slot_type == _slot_type)

	if pool.is_empty():
		%EmptyLabel.visible = true
		if current_base == null:
			%EmptyLabel.text = "%s is away from base — only Global equipment is reachable, and none is %s." % [
					_agent.agent_name, _slot_type.to_lower()]
		else:
			%EmptyLabel.text = "No %s items at %s (or Global)." % [_slot_type.to_lower(), current_base.base_name]
		return

	for item: EquipmentData in pool:
		var row := option_row_scene.instantiate()
		%ItemList.add_child(row)
		row.populate(item, current, _agent)
		row.equip_pressed.connect(func(picked: EquipmentData) -> void:
				if not _agent.equip(picked):
					return
				on_close.call()
				Game.left_detail.show_view("agent", _agent))


func _current_equipped() -> EquipmentData:
	match _slot_type:
		"Weapon": return _agent.equipped_weapon
		"Armor": return _agent.equipped_armor
		"Gadget": return _agent.equipped_gadget
	return null
