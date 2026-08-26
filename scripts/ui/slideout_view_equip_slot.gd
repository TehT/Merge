extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewEquipSlot — picker for one of an agent's equipment slots:
## shows what's currently equipped (with an Unequip option), then every
## reachable item for that slot_type with an Equip button, disabled and
## annotated when the agent doesn't meet its requirements. "Reachable" is
## Global equipment (usable from anywhere) plus whatever's local to the
## base the agent is actually at right now (TeamManager.get_agent_base())
## — not other bases' local_equipment, and not anything at all if the
## agent's team is away from every base (traveling, or on-site at a
## mission). Mirrors SlideoutViewDeploy's "list of options with an action
## button" shape.

var _agent: AgentData
var _slot_type: String

func populate(agent: AgentData, slot_type: String, on_close: Callable) -> void:
	_agent = agent
	_slot_type = slot_type

	_add_header("Equip: %s" % slot_type, on_close)

	var current: EquipmentData = _current_equipped()
	if current != null:
		add_child(HSeparator.new())
		var current_row := HBoxContainer.new()
		var current_lbl := Label.new()
		current_lbl.text = "Equipped: %s" % current.equipment_name
		current_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		current_row.add_child(current_lbl)
		var unequip_btn := Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.focus_mode = Control.FOCUS_NONE
		unequip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		unequip_btn.pressed.connect(_on_unequip_pressed.bind(on_close))
		current_row.add_child(unequip_btn)
		add_child(current_row)

	add_child(HSeparator.new())

	var current_base: BaseData = Game.team_manager.get_agent_base(agent.id)
	var reachable: Array[EquipmentData] = Game.base_manager.global_equipment.duplicate()
	if current_base != null:
		reachable.append_array(current_base.local_equipment)
	var pool: Array[EquipmentData] = reachable.filter(
		func(item: EquipmentData) -> bool: return item.slot_type == slot_type)

	if pool.is_empty():
		var none_lbl := Label.new()
		if current_base == null:
			none_lbl.text = "%s is away from base — only Global equipment is reachable, and none is %s." % [
				agent.agent_name, slot_type.to_lower()]
		else:
			none_lbl.text = "No %s items at %s (or Global)." % [slot_type.to_lower(), current_base.base_name]
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(none_lbl)
	else:
		for item: EquipmentData in pool:
			add_child(_make_item_row(item, current, on_close))


func _current_equipped() -> EquipmentData:
	match _slot_type:
		"Weapon": return _agent.equipped_weapon
		"Armor": return _agent.equipped_armor
		"Gadget": return _agent.equipped_gadget
	return null


func _make_item_row(item: EquipmentData, current: EquipmentData, on_close: Callable) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)

	var name_lbl := Label.new()
	name_lbl.text = item.equipment_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	card.add_child(name_lbl)

	var can := _agent.can_equip(item)
	var is_current := item == current

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 11)
	if is_current:
		status_lbl.text = "Currently equipped"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
	elif can:
		status_lbl.text = "Ready to equip"
		status_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.45, 1.0))
	else:
		var unmet: Array[String] = []
		for req: EquipmentRequirement in item.requirements:
			if not req.is_met(_agent):
				unmet.append(req.get_description())
		status_lbl.text = " / ".join(unmet) if not unmet.is_empty() else "Requirements not met"
		status_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	card.add_child(status_lbl)

	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var equip_btn := Button.new()
	equip_btn.text = "Equip"
	equip_btn.disabled = not can or is_current
	equip_btn.focus_mode = Control.FOCUS_NONE
	if not equip_btn.disabled:
		equip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	equip_btn.pressed.connect(_on_equip_pressed.bind(item, on_close))
	row.add_child(equip_btn)
	card.add_child(row)

	card.add_child(HSeparator.new())

	return card


func _on_equip_pressed(item: EquipmentData, on_close: Callable) -> void:
	if not _agent.equip(item):
		return
	on_close.call()
	Game.detail_sidebar.show_agent(_agent)


func _on_unequip_pressed(on_close: Callable) -> void:
	_agent.unequip(_slot_type)
	on_close.call()
	Game.detail_sidebar.show_agent(_agent)
