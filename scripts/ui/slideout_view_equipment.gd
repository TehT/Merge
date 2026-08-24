extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewEquipment — read-only info card for one equipment item:
## slot type, description, requirements, effects. Opened by clicking a row
## in the Equipment tab (right sidebar) — mirrors SlideoutViewVehicle's role
## for the vehicle fleet.

func populate(item: EquipmentData, on_close: Callable) -> void:
	var accent := Color(0.5, 0.6, 0.8, 1.0)

	_add_header(item.equipment_name, on_close, accent, 15)
	_add_stat("Slot", item.slot_type)

	if item.description != "":
		add_child(HSeparator.new())
		var desc := Label.new()
		desc.text = item.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
		add_child(desc)

	if not item.requirements.is_empty():
		add_child(HSeparator.new())
		_add_section("Requirements")
		for req: EquipmentRequirement in item.requirements:
			_add_bullet(req.get_description())

	if not item.effects.is_empty():
		add_child(HSeparator.new())
		_add_section("Effects")
		for effect: EquipmentEffect in item.effects:
			_add_bullet(effect.get_description())


func _add_section(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
	add_child(lbl)


func _add_bullet(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "• %s" % text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	add_child(lbl)


func _add_stat(label: String, value: String) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	row.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)

	add_child(row)
