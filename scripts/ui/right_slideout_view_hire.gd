extends "res://scripts/ui/slideout_view_base.gd"
## RightSlideoutViewHire — the weekly hiring pool (HiringManager), shown in
## the right-side popout (RightSlideoutPanel). Each row shows a recruit's
## name/type/proficiency spread and a Hire button (disabled if funding is
## short); hiring moves them onto the roster immediately and removes them
## from the pool. Clicking anywhere on a row other than the Hire button
## opens that recruit's full agent sheet in the left DetailPanel (same
## view a roster agent gets) — a preview before committing funding to them.

var _list: VBoxContainer


func populate(on_close: Callable) -> void:
	_add_header("Hire", on_close)
	add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)

	Game.hiring_manager.pool_refreshed.connect(_refresh)
	Game.hiring_manager.recruit_hired.connect(_on_recruit_hired)
	Game.resource_state.funding_changed.connect(_on_funding_changed)
	_refresh()


func _on_recruit_hired(_agent: AgentData) -> void:
	_refresh()


func _on_funding_changed(_new_value: int, _delta: int) -> void:
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var days_left := Game.hiring_manager.get_days_until_refresh()
	var header := Label.new()
	header.text = "New recruits in %d day%s" % [days_left, "" if days_left == 1 else "s"]
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	_list.add_child(header)

	var pool: Array[AgentData] = Game.hiring_manager.pool
	if pool.is_empty():
		var empty := Label.new()
		empty.text = "No recruits available right now."
		empty.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		_list.add_child(empty)
		return

	for recruit: AgentData in pool:
		_list.add_child(_make_recruit_row(recruit))


func _make_recruit_row(recruit: AgentData) -> Control:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s  (%s)" % [recruit.agent_name, recruit.get_type_name()]
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var archetype_lbl := Label.new()
	archetype_lbl.text = recruit.get_archetype()
	archetype_lbl.add_theme_font_size_override("font_size", 12)
	archetype_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 1.0))
	archetype_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(archetype_lbl)

	var ranks := recruit.get_proficiency_ranks()
	var stats := Label.new()
	stats.text = "C %d  Su %d  At %d  Er %d  In %d  Ig %d" % [
		ranks["combat"], ranks["subterfuge"],
		ranks["attunement"], ranks["erudition"],
		ranks["influence"], ranks["ingenuity"],
	]
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68, 1.0))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats)

	var cost := Game.hiring_manager.hire_cost
	var hire_btn := Button.new()
	hire_btn.text = "Hire (%d)" % cost
	hire_btn.focus_mode = Control.FOCUS_NONE
	hire_btn.disabled = Game.resource_state.funding < cost
	if not hire_btn.disabled:
		hire_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hire_btn.pressed.connect(func() -> void:
		Game.hiring_manager.hire(recruit.id))
	vbox.add_child(hire_btn)

	# The Hire button (default MOUSE_FILTER_STOP) consumes its own clicks
	# before they'd reach this — everything else on the row (name/stats,
	# both set to IGNORE above) falls through to it instead.
	panel.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed \
				and input_event.button_index == MOUSE_BUTTON_LEFT:
			Game.detail_sidebar.show_agent(recruit)
			Game.root_ui.open_left())

	return panel
