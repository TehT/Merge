extends "res://scripts/ui/detail_view_base.gd"
## DetailViewTeam — squad sheet: editable name, cohesion, location/travel
## ETA, team proficiency ranks, member roster.

func populate(team: TeamData) -> void:
	var title := LineEdit.new()
	title.text = team.team_name
	title.add_theme_font_size_override("font_size", 18)
	title.expand_to_text_length = true
	title.flat = true
	title.placeholder_text = "Squad name"
	title.text_submitted.connect(func(new_text: String) -> void:
		_rename_team(team, new_text)
		title.release_focus())
	title.focus_exited.connect(func() -> void:
		_rename_team(team, title.text))
	add_child(title)

	_add_info_row("Members", "%d" % team.member_ids.size())
	_add_info_row("Cohesion", "%.0f%%" % team.cohesion)

	if team.is_traveling:
		var hours_left := maxf(0.0, (team.travel_arrival_day - Game.game_clock.get_current_time_days()) * 24.0)
		_add_info_row("Location", "En route to %s" % team.travel_destination_name)
		_add_info_row("ETA", VehicleData.format_duration(hours_left))
	elif team.is_on_mission:
		var hours_left := maxf(0.0, (team.mission_ready_day - Game.game_clock.get_current_time_days()) * 24.0)
		_add_info_row("Location", "On mission at %s" % team.location_name)
		_add_info_row("Wrapping up in", VehicleData.format_duration(hours_left))
	else:
		_add_clickable_location_row(team)

	if team.is_training:
		var days_left: int = Game.team_manager.get_training_days_left(team.id)
		if days_left > 0:
			_add_info_row("Training", "%d days left" % days_left)

	var members := _get_team_members(team)

	add_child(HSeparator.new())
	_add_section("Team Proficiencies")
	var team_ranks := MissionResolver.compute_team_ranks(members)
	for prof_key: String in SkillData.PROFICIENCY_KEYS:
		if team_ranks[prof_key] > 0:
			_add_prof_rank_row(prof_key, team_ranks[prof_key], SkillData.PROFICIENCY_COLORS[prof_key])

	add_child(HSeparator.new())
	_add_section("Members")
	for m in members:
		_add_info_row(m.agent_name, m.get_status_name())


## Only shown while the team is stationary (not traveling/on mission —
## see populate()) since transporting mid-trip doesn't make sense. Opens
## the base-transport picker (distance/travel time/aircraft dropdown),
## same drill-down pattern as a clickable proficiency row.
func _add_clickable_location_row(team: TeamData) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "Location"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = team.location_name
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_lbl)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Game.slideout_panel.show_base_transport(team))

	add_child(row)


func _get_team_members(team: TeamData) -> Array[AgentData]:
	var members: Array[AgentData] = []
	for agent_id in team.member_ids:
		var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
		if a != null:
			members.append(a)
	return members


func _rename_team(team: TeamData, new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed == "" or trimmed == team.team_name:
		return
	Game.team_manager.rename_team(team.id, trimmed)
