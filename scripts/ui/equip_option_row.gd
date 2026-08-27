extends VBoxContainer
## EquipOptionRow — one item option in the equip-slot picker: item name,
## status line (Currently equipped / Ready to equip / requirements not
## met, colored to match), and an Equip button that fires equip_pressed
## with this row's item. Kept as a template scene so the layout is
## editable in the editor; the enclosing view (SlideoutViewEquipSlot)
## instantiates one per reachable item and connects the signal.

signal equip_pressed(item: EquipmentData)

var _item: EquipmentData


func populate(item: EquipmentData, current: EquipmentData, agent: AgentData) -> void:
	_item = item
	%Name.text = item.equipment_name

	var can := agent.can_equip(item)
	var is_current := item == current

	if is_current:
		%Status.text = "Currently equipped"
		%Status.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
	elif can:
		%Status.text = "Ready to equip"
		%Status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.45, 1.0))
	else:
		var unmet: Array[String] = []
		for req: EquipmentRequirement in item.requirements:
			if not req.is_met(agent):
				unmet.append(req.get_description())
		%Status.text = " / ".join(unmet) if not unmet.is_empty() else "Requirements not met"
		%Status.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))

	%EquipBtn.disabled = not can or is_current
	%EquipBtn.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if not %EquipBtn.disabled else Control.CURSOR_ARROW)
	%EquipBtn.pressed.connect(func() -> void: equip_pressed.emit(_item))
