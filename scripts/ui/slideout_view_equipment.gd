extends VBoxContainer
## SlideoutViewEquipment — info card for one equipment item: slot type,
## description, requirements, effects, and a Transfer action to move it
## to another location (base or Global) — instant for now, a stand-in
## for the eventual logistics system (see BaseManager.transfer_equipment
## ()). Opened by clicking a row in the Equipment tab (right sidebar) —
## mirrors SlideoutViewVehicle's role for the vehicle fleet.
##
## Layout lives in scenes/ui/views/slideout_equipment.tscn (editable in
## the editor). The description / requirements / effects sections
## toggle visible per item; transfer destinations are dynamic (one per
## base plus Global) and land in %TransferList.

var _item: EquipmentData
var _base_id: String


func populate(data: Variant, on_close: Callable) -> void:
	_item = data["item"]
	_base_id = data["base_id"]

	%Header.set_title(_item.equipment_name)
	%Header.close_requested.connect(on_close)

	%SlotRow.set_value(_item.slot_type)

	if _item.description != "":
		%DescriptionSep.visible = true
		%Description.visible = true
		%Description.text = _item.description

	if not _item.requirements.is_empty():
		%RequirementsSep.visible = true
		%RequirementsSection.visible = true
		for req: EquipmentRequirement in _item.requirements:
			%RequirementsList.add_child(_make_bullet(req.get_description()))

	if not _item.effects.is_empty():
		%EffectsSep.visible = true
		%EffectsSection.visible = true
		for effect: EquipmentEffect in _item.effects:
			%EffectsList.add_child(_make_bullet(effect.get_description()))

	for loc: Dictionary in Game.base_manager.get_all_locations():
		if loc["base_id"] == _base_id:
			continue
		%TransferList.add_child(_make_destination_row(loc["label"], loc["base_id"], on_close))


func _make_bullet(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "• %s" % text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl


func _make_destination_row(label: String, dest_base_id: String, on_close: Callable) -> Control:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = "Send"
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func() -> void:
			if Game.base_manager.transfer_equipment(_item, _base_id, dest_base_id):
				on_close.call())
	row.add_child(btn)

	return row
