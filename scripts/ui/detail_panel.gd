extends VBoxContainer
## DetailPanel — left sidebar content. Shows details for whatever item
## is currently selected in the right sidebar's overview tabs.

enum _View { EMPTY, AGENT, TEAM, EVENT, RESULT, HQ }

var _map_shader: Shader
var _satellite_tex: Texture2D
var _view: _View = _View.EMPTY
var _view_agent: AgentData
var _view_team: TeamData
var _view_event: EventData
var _refresh_pending := false

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_map_shader = load("res://shaders/detail_map_2d.gdshader")
	_satellite_tex = load("res://textures/satellite_map_4096.png")

	%TeamManager.membership_changed.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.cohesion_changed.connect(func(_tid: String, _v: float, _d: float) -> void: _schedule_refresh())
	%TeamManager.training_started.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.training_completed.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.team_departed.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.team_arrived.connect(func(_tid: String, _eid: String) -> void: _schedule_refresh())
	%TeamManager.team_created.connect(func(_t: TeamData) -> void: _schedule_refresh())
	%TeamManager.team_renamed.connect(func(_tid: String) -> void: _schedule_refresh())
	%AgentManager.agent_status_changed.connect(func(_aid: String, _o: AgentData.Status, _n: AgentData.Status) -> void: _schedule_refresh())
	%AgentManager.roster_changed.connect(_schedule_refresh)
	%EventManager.event_resolved.connect(_on_mission_resolved)

	show_empty()


func _schedule_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	_refresh_view.call_deferred()


func _refresh_view() -> void:
	_refresh_pending = false
	match _view:
		_View.AGENT:
			if _view_agent:
				show_agent(_view_agent)
		_View.TEAM:
			if _view_team:
				show_team(_view_team)
		_View.HQ:
			show_hq()


func show_agent(agent: AgentData) -> void:
	_view = _View.AGENT
	_view_agent = agent
	_clear()

	var title := Label.new()
	title.text = agent.agent_name
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s  —  %s" % [agent.get_status_name(), agent.get_type_name()]
	subtitle.add_theme_color_override("font_color", _status_color(agent.status))
	add_child(subtitle)

	add_child(HSeparator.new())

	_add_section("Proficiencies")
	var ranks := agent.get_proficiency_ranks()
	for key: String in SkillData.PROFICIENCY_KEYS:
		if ranks[key] > 0:
			_add_clickable_prof_rank(key, ranks[key], SkillData.PROFICIENCY_COLORS[key], agent)

	add_child(HSeparator.new())

	_add_section("Condition")
	_add_info_row("Health", "%d / %d" % [int(agent.health), int(agent.max_health)])
	_add_info_row("Morale", "%d" % int(agent.morale))
	_add_info_row("Level", "%d" % agent.level)
	_add_info_row("XP", "%d" % agent.experience)

	var team: TeamData = %TeamManager.get_team_of_agent(agent.id)
	if team:
		add_child(HSeparator.new())
		_add_info_row("Team", team.team_name)
		_add_info_row("Cohesion", "%.0f%%" % team.cohesion)

	if agent.supernatural_type != AgentData.SupernaturalType.NONE:
		add_child(HSeparator.new())
		_add_section("Supernatural")
		_add_info_row("Type", agent.get_type_name())
		_add_info_row("Power", "%.0f" % agent.supernatural_power)


func show_event(ev: EventData) -> void:
	_view = _View.EVENT
	_view_event = ev
	_clear()

	var title := Label.new()
	title.text = ev.title
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s  —  %s" % [ev.get_type_name(), ev.get_urgency_name()]
	subtitle.add_theme_color_override("font_color", ev.get_urgency_color())
	add_child(subtitle)

	add_child(_make_deploy_team_row(ev))
	add_child(HSeparator.new())

	if ev.geo_coordinates != Vector2.ZERO:
		add_child(_create_event_map(ev))

	if ev.location_city != "":
		var loc_parts: PackedStringArray = [ev.location_city]
		if ev.location_country != "":
			loc_parts.append(ev.location_country)
		_add_info_row("Location", ", ".join(loc_parts))

	if ev.geo_coordinates != Vector2.ZERO:
		var lon: float = ev.geo_coordinates.x
		var lat: float = ev.geo_coordinates.y
		var lat_str := "%.1f°%s" % [absf(lat), "N" if lat >= 0.0 else "S"]
		var lon_str := "%.1f°%s" % [absf(lon), "E" if lon >= 0.0 else "W"]
		_add_info_row("Coords", "%s, %s" % [lat_str, lon_str])

	_add_info_row("Days Left", "%d" % ev.days_remaining)

	add_child(HSeparator.new())

	_add_section("Requirements")
	var reqs := ev.get_proficiency_requirements()
	for key: String in SkillData.PROFICIENCY_KEYS:
		if reqs[key] > 0:
			_add_prof_rank_row(key, reqs[key], SkillData.PROFICIENCY_COLORS[key])

	add_child(HSeparator.new())

	_add_section("Stakes")
	_add_info_row("On Fail", "+%.0f concealment" % ev.concealment_on_fail)
	_add_info_row("On Partial", "+%.0f concealment" % ev.concealment_on_partial)
	_add_info_row("On Success", "%+.0f concealment" % ev.concealment_on_success)

	_add_section("Rewards")
	_add_info_row("Funding", "+%d" % ev.reward_funding)
	_add_info_row("Intel", "+%d" % ev.reward_intel)
	if ev.reward_item != "":
		_add_info_row("Item", ev.reward_item)


func _create_event_map(ev: EventData) -> Control:
	var lon: float = ev.geo_coordinates.x
	var lat: float = ev.geo_coordinates.y

	var center_u := lon / 360.0 + 0.5
	var center_v := 0.5 - lat / 180.0
	var half_w := 15.0 / 360.0
	var half_h := 10.0 / 180.0

	var uv_min := Vector2(
		clampf(center_u - half_w, 0.0, 1.0),
		clampf(center_v - half_h, 0.0, 1.0))
	var uv_max := Vector2(
		clampf(center_u + half_w, 0.0, 1.0),
		clampf(center_v + half_h, 0.0, 1.0))

	var map_rect := ColorRect.new()
	map_rect.custom_minimum_size = Vector2(280, 160)
	map_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var mat := ShaderMaterial.new()
	mat.shader = _map_shader
	mat.set_shader_parameter("satellite_map", _satellite_tex)
	mat.set_shader_parameter("uv_min", uv_min)
	mat.set_shader_parameter("uv_max", uv_max)
	mat.set_shader_parameter("marker_uv", Vector2(center_u, center_v))
	mat.set_shader_parameter("aspect", 280.0 / 160.0)
	map_rect.material = mat

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.12, 1.0)
	style.border_color = Color(0.18, 0.25, 0.35, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 1.0
	style.content_margin_top = 1.0
	style.content_margin_right = 1.0
	style.content_margin_bottom = 1.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(map_rect)

	return panel


func show_team(team: TeamData) -> void:
	_view = _View.TEAM
	_view_team = team
	_clear()

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
		var eta := maxi(0, team.travel_arrival_day - %GameClock.current_day)
		_add_info_row("Location", "En route to %s" % team.travel_destination_name)
		_add_info_row("ETA", "%d day(s)" % eta)
	else:
		_add_info_row("Location", team.location_name)

	var days_left: int = %TeamManager.get_training_days_left(team.id)
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


func show_hq() -> void:
	_view = _View.HQ
	_clear()

	var title := Label.new()
	title.text = %TeamManager.HQ_NAME
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Home base"
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	add_child(subtitle)

	add_child(HSeparator.new())

	_add_section("Vehicles")
	var vehicles: Array[VehicleData] = %TeamManager.vehicles
	if vehicles.is_empty():
		_add_placeholder_row("No vehicles in the fleet.")
	else:
		for vehicle: VehicleData in vehicles:
			add_child(_make_vehicle_row(vehicle))

	add_child(HSeparator.new())
	_add_section("Squads")
	var teams: Array[TeamData] = %TeamManager.teams
	if teams.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No squads formed yet."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(none_lbl)
	else:
		for team: TeamData in teams:
			if team.is_traveling:
				var eta := maxi(0, team.travel_arrival_day - %GameClock.current_day)
				_add_info_row(team.team_name, "En route to %s (%dd)" % [team.travel_destination_name, eta])
			else:
				_add_info_row(team.team_name, "At base")

	add_child(HSeparator.new())
	_add_section("Equipment")
	_add_placeholder_row("Coming soon")

	add_child(HSeparator.new())
	_add_section("Base Upgrades")
	_add_placeholder_row("Coming soon")


func _add_placeholder_row(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
	add_child(lbl)


func _get_team_members(team: TeamData) -> Array[AgentData]:
	var members: Array[AgentData] = []
	for agent_id in team.member_ids:
		var a: AgentData = %AgentManager.get_agent_by_id(agent_id)
		if a != null:
			members.append(a)
	return members


func _make_deploy_team_row(ev: EventData) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "Deploy Team"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	row.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
			%SkillSlideout.show_deploy_teams(ev))

	return row


func _make_vehicle_row(vehicle: VehicleData) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = vehicle.vehicle_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	info.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "%d km/day  •  %d km range  •  %d cap" % [
		int(vehicle.speed_km_per_day), int(vehicle.max_range_km), vehicle.capacity]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	info.add_child(stats_lbl)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	row.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
			%SkillSlideout.show_vehicle(vehicle))

	return row


func show_mission_result(team_name: String, ev_title: String, result: Dictionary) -> void:
	_view = _View.RESULT
	_clear()

	var outcome: String = result.outcome
	var outcome_color: Color
	var outcome_text: String
	match outcome:
		"success":
			outcome_color = Color(0.4, 0.8, 0.45, 1.0)
			outcome_text = "Success"
		"partial":
			outcome_color = Color(0.85, 0.7, 0.2, 1.0)
			outcome_text = "Partial Success"
		_:
			outcome_color = Color(0.85, 0.35, 0.3, 1.0)
			outcome_text = "Failure"

	var title := Label.new()
	title.text = "Mission Report"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s  →  %s" % [team_name, ev_title]
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	add_child(subtitle)

	add_child(HSeparator.new())

	var outcome_lbl := Label.new()
	outcome_lbl.text = outcome_text
	outcome_lbl.add_theme_font_size_override("font_size", 16)
	outcome_lbl.add_theme_color_override("font_color", outcome_color)
	add_child(outcome_lbl)

	_add_info_row("Suitability", "%d%%" % int(round(float(result.team_suitability) * 100.0)))
	_add_info_row("Chance", "%d%%" % int(round(float(result.chance) * 100.0)))
	_add_info_row("Roll", "%.2f" % result.roll)

	add_child(HSeparator.new())
	_add_section("Agent Outcomes")
	var agent_results: Dictionary = result.agent_results
	for agent_id: String in agent_results:
		var a: AgentData = %AgentManager.get_agent_by_id(agent_id)
		var status: AgentData.Status = agent_results[agent_id]
		var agent_name := a.agent_name if a else agent_id
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = agent_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var status_lbl := Label.new()
		status_lbl.text = _status_name_for(status)
		status_lbl.add_theme_color_override("font_color", _status_color(status))
		row.add_child(status_lbl)
		add_child(row)

	add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(show_empty)
	add_child(close_btn)


## Mission resolution now happens whenever a traveling team arrives (see
## TeamManager.team_arrived / EventManager._on_team_arrived), which can be
## days after the player clicked Deploy and long after they've moved on to
## something else — so the report pops up on its own rather than only
## showing right after a Deploy click.
func _on_mission_resolved(ev: EventData, result: Dictionary) -> void:
	show_mission_result(result.get("team_name", "Squad"), ev.title, result)


func show_travel_confirmation(team_name: String, ev_title: String, plan: Dictionary) -> void:
	_view = _View.RESULT
	_clear()

	var title := Label.new()
	title.text = "Team Deployed"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s  →  %s" % [team_name, ev_title]
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	add_child(subtitle)

	add_child(HSeparator.new())

	var status_lbl := Label.new()
	status_lbl.text = "En route"
	status_lbl.add_theme_font_size_override("font_size", 16)
	status_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
	add_child(status_lbl)

	_add_info_row("Distance", "%d km" % int(round(float(plan.distance_km))))
	_add_info_row("Travel Time", "%d day(s)" % int(plan.travel_days))
	_add_info_row("Arriving", "Day %d" % int(plan.arrival_day))

	add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(show_empty)
	add_child(close_btn)


func _status_name_for(status: AgentData.Status) -> String:
	match status:
		AgentData.Status.AVAILABLE: return "Available"
		AgentData.Status.DEPLOYED: return "Deployed"
		AgentData.Status.INJURED: return "Injured"
		AgentData.Status.TRAINING: return "Training"
		AgentData.Status.KIA: return "KIA"
	return "Unknown"


func show_empty() -> void:
	_view = _View.EMPTY
	_view_agent = null
	_view_team = null
	_view_event = null
	_clear()
	var hint := Label.new()
	hint.text = "Select an agent or event to view details."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	add_child(hint)


func _clear() -> void:
	%SkillSlideout.dismiss()
	for child in get_children():
		child.queue_free()


func _add_section(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	add_child(lbl)


func _add_info_row(label: String, value: String) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	row.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(val_lbl)

	add_child(row)


func _add_clickable_prof_rank(prof_key: String, rank: int,
		color: Color, agent: AgentData) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = prof_key.capitalize()
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visible_max: int = SkillData.VISIBLE_MAX_RANK
	for i in range(visible_max):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 16)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < rank:
			pip.color = color
		else:
			pip.color = Color(0.15, 0.16, 0.2, 1.0)
		pips.add_child(pip)
	row.add_child(pips)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			%SkillSlideout.show_proficiency(agent, prof_key))

	add_child(row)


func _add_prof_rank_row(prof_key: String, rank: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = prof_key.capitalize()
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var visible_max: int = SkillData.VISIBLE_MAX_RANK
	for i in range(visible_max):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 16)
		if i < rank:
			pip.color = color
		else:
			pip.color = Color(0.15, 0.16, 0.2, 1.0)
		pips.add_child(pip)
	row.add_child(pips)

	add_child(row)


func _rename_team(team: TeamData, new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed == "" or trimmed == team.team_name:
		return
	%TeamManager.rename_team(team.id, trimmed)


func _status_color(status: AgentData.Status) -> Color:
	match status:
		AgentData.Status.AVAILABLE: return get_theme_color("available", "StatusColors")
		AgentData.Status.DEPLOYED: return get_theme_color("deployed", "StatusColors")
		AgentData.Status.INJURED: return get_theme_color("injured", "StatusColors")
		AgentData.Status.TRAINING: return get_theme_color("training", "StatusColors")
		AgentData.Status.KIA: return get_theme_color("kia", "StatusColors")
	return Color.WHITE
