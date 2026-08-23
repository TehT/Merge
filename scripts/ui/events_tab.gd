extends VBoxContainer
## EventsTab — lists active events in the right sidebar. Clicking a row
## emits event_selected so the detail panel can show full event info.
## Refreshes on spawn/expire/resolve and each day tick (days_remaining).

signal event_selected(ev: EventData)

var _selected_event_id: String = ""

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	%EventManager.event_spawned.connect(func(_e: EventData) -> void: _refresh())
	%EventManager.event_expired.connect(func(_e: EventData) -> void: _refresh())
	%EventManager.event_resolved.connect(func(_e: EventData, _r: Dictionary) -> void: _refresh())
	%GameClock.day_advanced.connect(func(_d: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var events: Array[EventData] = %EventManager.get_active_events()
	if events.is_empty():
		var empty := Label.new()
		empty.text = "No active events."
		add_child(empty)
		return

	var sorted := events.duplicate()
	sorted.sort_custom(func(a: EventData, b: EventData) -> bool:
		if a.urgency != b.urgency:
			return a.urgency > b.urgency
		return a.days_remaining < b.days_remaining)

	for ev in sorted:
		add_child(_make_event_row(ev))


func _make_event_row(ev: EventData) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if ev.id == _selected_event_id:
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

	var title := Label.new()
	title.text = ev.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title)

	var urgency := Label.new()
	urgency.text = ev.get_urgency_name()
	urgency.add_theme_color_override("font_color", ev.get_urgency_color())
	urgency.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(urgency)

	var info := Label.new()
	var loc := ev.location_city if ev.location_city != "" else "Unknown"
	if ev.status == EventData.Status.DEPLOYED:
		info.text = "%s  |  team en route" % loc
	else:
		info.text = "%s  |  %dd left" % [loc, ev.days_remaining]
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info)

	panel.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed \
				and input_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_event_id = ev.id
			event_selected.emit(ev)
			_refresh())

	return panel
