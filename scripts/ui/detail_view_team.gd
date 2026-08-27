extends "res://scripts/ui/detail_view_base.gd"
## DetailViewTeam — squad sheet: editable name, cohesion, location/travel
## ETA, team proficiency ranks, member roster.
##
## Layout lives in scenes/ui/views/detail_team.tscn (editable in the
## editor). The location row switches shape depending on travel state:
## clickable (opens transport picker) when stationary, plain info row
## when traveling or on mission; the .tscn keeps one %LocationRow that
## script re-wires per state, rather than three separate rows.

func populate(data: Variant, _dismiss: Callable) -> void:
	var team: TeamData = data

	%Title.text = team.team_name
	%Title.text_submitted.connect(func(new_text: String) -> void:
			_rename_team(team, new_text)
			%Title.release_focus())
	%Title.focus_exited.connect(func() -> void:
			_rename_team(team, %Title.text))

	%MembersRow.set_value("%d" % team.member_ids.size())
	%CohesionRow.set_value("%.0f%%" % team.cohesion)

	_apply_location(team)
	_apply_training(team)
	_fill_proficiencies(team)
	_fill_members(team)


## Location row's shape depends on team state. Traveling: plain, "En
## route to X" with a companion "ETA" row shown. On mission: plain,
## "On mission at X" with a "Wrapping up in" row. Stationary: clickable,
## just the current location, opens the base-transport picker on click.
func _apply_location(team: TeamData) -> void:
	if team.is_traveling:
		%LocationRow.clickable = false
		%LocationRow.set_value("En route to %s" % team.travel_destination_name)
		var hours_left := maxf(0.0, (team.travel_arrival_day - Game.game_clock.get_current_time_days()) * 24.0)
		%ETARow.visible = true
		%ETARow.key = "ETA"
		%ETARow.set_value(VehicleData.format_duration(hours_left))
	elif team.is_on_mission:
		%LocationRow.clickable = false
		%LocationRow.set_value("On mission at %s" % team.location_name)
		var hours_left := maxf(0.0, (team.mission_ready_day - Game.game_clock.get_current_time_days()) * 24.0)
		%ETARow.visible = true
		%ETARow.key = "Wrapping up in"
		%ETARow.set_value(VehicleData.format_duration(hours_left))
	else:
		%LocationRow.clickable = true
		%LocationRow.set_value(team.location_name)
		%LocationRow.clicked.connect(func() -> void:
				Game.left_popout.toggle_showing("base_transport", team))


func _apply_training(team: TeamData) -> void:
	if not team.is_training:
		return
	var days_left: int = Game.team_manager.get_training_days_left(team.id)
	if days_left <= 0:
		return
	%TrainingRow.visible = true
	%TrainingRow.set_value("%d days left" % days_left)


func _fill_proficiencies(team: TeamData) -> void:
	for child in %ProficienciesList.get_children():
		child.queue_free()
	var members := _get_team_members(team)
	var team_ranks := MissionResolver.compute_team_ranks(members)
	for prof_key: String in SkillData.PROFICIENCY_KEYS:
		if team_ranks[prof_key] > 0:
			_add_prof_rank_row(prof_key, team_ranks[prof_key],
					SkillData.PROFICIENCY_COLORS[prof_key], %ProficienciesList)


func _fill_members(team: TeamData) -> void:
	for child in %MembersList.get_children():
		child.queue_free()
	for m in _get_team_members(team):
		_add_info_row(m.agent_name, m.get_status_name(), %MembersList)


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
