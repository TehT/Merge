extends VBoxContainer
## BasesTab — lists every base the player owns (Game.base_manager.bases)
## in the right sidebar. Clicking a row opens it in the left DetailPanel —
## the same view/behavior as clicking the HQ marker on the map.

signal base_selected(base: BaseData)

var _selected_base: BaseData


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var bases: Array[BaseData] = Game.base_manager.bases
	if bases.is_empty():
		var empty := Label.new()
		empty.text = "No bases."
		empty.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(empty)
		return

	for base: BaseData in bases:
		add_child(_make_base_row(base))


func _make_base_row(base: BaseData) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if base == _selected_base:
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

	var name_lbl := Label.new()
	name_lbl.text = base.base_name
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "%d vehicle%s  •  %d equipment" % [
		base.vehicles.size(), "" if base.vehicles.size() == 1 else "s", base.local_equipment.size(),
	]
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	panel.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed \
				and input_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_base = base
			base_selected.emit(base)
			_refresh())

	return panel
