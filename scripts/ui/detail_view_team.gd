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
		_add_info_row("Location", team.location_name)

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
		_add_info_row(m.agent_name, "%s  Lv%d" % [m.get_status_name(), m.level])


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
