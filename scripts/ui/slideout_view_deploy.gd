extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewDeploy — squad picker for deploying to an event: every
## non-empty squad with match %, availability, a route dropdown (every
## viable way to get there — direct or relayed through a Transport hop to
## another base, via TravelRouter — ranked fastest first, auto-selects the
## fastest but overridable), and a Deploy button.

var _event: EventData


func populate(ev: EventData, on_close: Callable) -> void:
	_event = ev

	_add_header("Deploy Team", on_close)

	var subtitle := Label.new()
	subtitle.text = ev.title
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1.0))
	add_child(subtitle)

	add_child(HSeparator.new())

	var teams: Array[TeamData] = Game.team_manager.teams
	var deployable := teams.filter(func(t: TeamData) -> bool: return not t.member_ids.is_empty())

	if deployable.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No squads to deploy."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(none_lbl)
		return

	for team: TeamData in deployable:
		add_child(_make_deploy_row(team, on_close))


func _get_available_team_members(team: TeamData) -> Array[AgentData]:
	var members: Array[AgentData] = []
	for agent_id in team.member_ids:
		var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
		if a != null and a.is_available():
			members.append(a)
	return members


func _make_deploy_row(team: TeamData, on_close: Callable) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)

	var available := _get_available_team_members(team)
	var distance := GeoData.haversine_km(team.location.y, team.location.x,
			_event.geo_coordinates.y, _event.geo_coordinates.x)
	var routes: Array = TravelRouter.find_routes(team.location, team.location_name,
			_event.geo_coordinates, _event.location_city, available.size(),
			VehicleData.Role.TACTICAL, Game.base_manager.bases, team.current_vehicle)
	var in_range := not routes.is_empty()
	var can_deploy := not available.is_empty() and not team.is_traveling and not team.is_on_mission and in_range

	var name_lbl := Label.new()
	name_lbl.text = "%s  (%d/%d available)" % [team.team_name, available.size(), team.member_ids.size()]
	name_lbl.add_theme_font_size_override("font_size", 13)
	card.add_child(name_lbl)

	if team.is_traveling:
		var hours_left := maxf(0.0, (team.travel_arrival_day - Game.game_clock.get_current_time_days()) * 24.0)
		var travel_lbl := Label.new()
		travel_lbl.text = "En route to %s — %s left" % [
			team.travel_destination_name, VehicleData.format_duration(hours_left)]
		travel_lbl.add_theme_font_size_override("font_size", 12)
		travel_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
		card.add_child(travel_lbl)
		card.add_child(HSeparator.new())
		return card

	if team.is_on_mission:
		var hours_left := maxf(0.0, (team.mission_ready_day - Game.game_clock.get_current_time_days()) * 24.0)
		var mission_lbl := Label.new()
		mission_lbl.text = "On mission at %s — %s left" % [
			team.location_name, VehicleData.format_duration(hours_left)]
		mission_lbl.add_theme_font_size_override("font_size", 12)
		mission_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
		card.add_child(mission_lbl)
		card.add_child(HSeparator.new())
		return card

	var match_lbl := Label.new()
	if not in_range:
		match_lbl.text = "No vehicle can reach this (range or capacity)"
		match_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	elif available.is_empty():
		match_lbl.text = "No members available"
		match_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	else:
		var suitability := MissionResolver.compute_mission_suitability(_event.phases, available)
		var pct := int(round(suitability * 100.0))
		match_lbl.text = "Match: %d%%" % pct
		if suitability >= 1.0:
			match_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.45, 1.0))
		elif suitability >= 0.6:
			match_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2, 1.0))
		else:
			match_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	match_lbl.add_theme_font_size_override("font_size", 12)
	card.add_child(match_lbl)

	var travel_lbl := Label.new()
	travel_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	travel_lbl.add_theme_font_size_override("font_size", 11)
	travel_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	card.add_child(travel_lbl)

	var route_dropdown: OptionButton = null
	if in_range:
		route_dropdown = _make_route_dropdown(routes)
		route_dropdown.item_selected.connect(func(_idx: int) -> void:
			_update_travel_label(travel_lbl, route_dropdown))
		card.add_child(route_dropdown)
		_update_travel_label(travel_lbl, route_dropdown)
	else:
		travel_lbl.text = "%s km" % _format_distance(distance)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var deploy_btn := Button.new()
	deploy_btn.text = "Deploy"
	deploy_btn.disabled = not can_deploy
	deploy_btn.focus_mode = Control.FOCUS_NONE
	if can_deploy:
		deploy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	deploy_btn.pressed.connect(_on_deploy_pressed.bind(team, route_dropdown, on_close))
	row.add_child(deploy_btn)

	card.add_child(HSeparator.new())

	return card


## One item per candidate route (already ranked fastest-first by
## TravelRouter), item 0 pre-selected — no disabled items needed since
## every returned route is viable by construction, unlike the old flat
## vehicle dropdown which had to show out-of-range/over-capacity options.
func _make_route_dropdown(routes: Array) -> OptionButton:
	var dropdown := OptionButton.new()
	dropdown.focus_mode = Control.FOCUS_NONE
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dropdown.clip_text = true  # a long route description (relay + vehicle names) must truncate, not force the whole slideout panel wider -- ScrollContainer's horizontal scroll is disabled here, so an oversized child's minimum width otherwise propagates straight up through it

	for i in range(routes.size()):
		var route: Array = routes[i]
		dropdown.add_item(TravelRouter.describe(route))
		dropdown.set_item_metadata(i, route)

	dropdown.select(0)
	return dropdown


func _update_travel_label(label: Label, dropdown: OptionButton) -> void:
	var route: Array = dropdown.get_item_metadata(dropdown.get_selected())
	label.text = "%s km — %s" % [
		_format_distance(TravelRouter.total_distance_km(route)), TravelRouter.describe(route)]


func _format_distance(km: float) -> String:
	var digits := str(int(round(km)))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return out


func _on_deploy_pressed(team: TeamData, dropdown: OptionButton, on_close: Callable) -> void:
	if dropdown == null:
		return
	var team_name := team.team_name
	var ev_title := _event.title
	var selected_route: Array = dropdown.get_item_metadata(dropdown.get_selected())
	var plan: Dictionary = Game.event_manager.deploy_team(_event.id, team.id, selected_route)
	if plan.is_empty():
		return
	on_close.call()
	Game.detail_sidebar.show_travel_confirmation(team_name, ev_title, plan)
