extends VBoxContainer
## EquipmentTab — lists every equipment item available anywhere
## (Game.base_manager.get_all_equipment() — org-wide global_equipment plus
## every base's local_equipment pooled together) in the right sidebar.
## Clicking a row opens a read-only info card in the slideout — same role
## EventsTab/SquadList play for their own lists. Flat/unsorted for now;
## sorting and category filters (including, eventually, filtering by
## base) are a planned follow-up once the locker has enough items to need
## them.

var _selected_item: EquipmentData

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var items: Array[EquipmentData] = Game.base_manager.get_all_equipment()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "No equipment in the locker."
		empty.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(empty)
		return

	for item: EquipmentData in items:
		add_child(_make_item_row(item))


func _make_item_row(item: EquipmentData) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if item == _selected_item:
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.15, 0.2, 0.3, 0.95)
		sel.set_corner_radius_all(4)
		sel.content_margin_left = 10.0
		sel.content_margin_top = 6.0
		sel.content_margin_right = 10.0
		sel.content_margin_bottom = 6.0
		panel.add_theme_stylebox_override("panel", sel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = item.equipment_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(name_lbl)

	var slot_lbl := Label.new()
	slot_lbl.text = item.slot_type
	slot_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(slot_lbl)

	panel.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed \
				and input_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_item = item
			Game.slideout_panel.show_equipment_info(item)
			_refresh())

	return panel
