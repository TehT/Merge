extends VBoxContainer
## DeployRow — one team option in the deploy picker: team name +
## availability count, a status line (Match %, "No members", or the
## traveling/on-mission state), an autowrap travel description (with a
## route dropdown when in range), and a Deploy button. The status and
## travel labels' text/color and the button's disabled state are all
## dependent on the team's current situation vs. the event — kept as a
## template so the layout is editor-editable and the enclosing view
## only fills in text/state.

signal deploy_requested(team: TeamData, route: Array)

var _team: TeamData


## Called by SlideoutViewDeploy with all the resolved state — this row
## just applies it to visible labels/dropdowns/button.
func populate(team: TeamData, event: EventData) -> void:
	_team = team

	var available := _get_available(team)
	%Name.text = "%s  (%d/%d available)" % [team.team_name, available.size(), team.member_ids.size()]

	if team.is_traveling:
		var hours_left := maxf(0.0, (team.travel_arrival_day - Game.game_clock.get_current_time_days()) * 24.0)
		%StatusLine.text = "En route to %s — %s left" % [
				team.travel_destination_name, VehicleData.format_duration(hours_left)]
		%StatusLine.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
		%TravelLine.visible = false
		%ButtonRow.visible = false
		return

	if team.is_on_mission:
		var hours_left := maxf(0.0, (team.mission_ready_day - Game.game_clock.get_current_time_days()) * 24.0)
		%StatusLine.text = "On mission at %s — %s left" % [
				team.location_name, VehicleData.format_duration(hours_left)]
		%StatusLine.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
		%TravelLine.visible = false
		%ButtonRow.visible = false
		return

	var routes: Array = TravelRouter.find_routes(team.location, team.location_name,
			event.geo_coordinates, event.location_city, available.size(),
			VehicleData.Role.TACTICAL, Game.base_manager.bases, team.current_vehicle)
	var in_range := not routes.is_empty()
	var can_deploy := not available.is_empty() and in_range

	if not in_range:
		%StatusLine.text = "No vehicle can reach this (range or capacity)"
		%StatusLine.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	elif available.is_empty():
		%StatusLine.text = "No members available"
		%StatusLine.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	else:
		var suitability := MissionResolver.compute_mission_suitability(event.phases, available)
		var pct := int(round(suitability * 100.0))
		%StatusLine.text = "Match: %d%%" % pct
		if suitability >= 1.0:
			%StatusLine.add_theme_color_override("font_color", Color(0.4, 0.8, 0.45, 1.0))
		elif suitability >= 0.6:
			%StatusLine.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2, 1.0))
		else:
			%StatusLine.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))

	%TravelLine.visible = true
	if in_range:
		_populate_route_dropdown(routes)
		%RouteDropdown.item_selected.connect(func(_idx: int) -> void: _update_travel_label())
		_update_travel_label()
	else:
		%RouteDropdown.visible = false
		var distance := GeoData.haversine_km(team.location.y, team.location.x,
				event.geo_coordinates.y, event.geo_coordinates.x)
		%TravelLine.text = "%s km" % _format_distance(distance)

	%DeployBtn.disabled = not can_deploy
	%DeployBtn.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if can_deploy else Control.CURSOR_ARROW)
	%DeployBtn.pressed.connect(func() -> void:
			var selected: Array = %RouteDropdown.get_item_metadata(%RouteDropdown.get_selected())
			deploy_requested.emit(_team, selected))


func _populate_route_dropdown(routes: Array) -> void:
	%RouteDropdown.clear()
	for i in range(routes.size()):
		var route: Array = routes[i]
		%RouteDropdown.add_item(TravelRouter.describe(route))
		%RouteDropdown.set_item_metadata(i, route)
	%RouteDropdown.select(0)


func _update_travel_label() -> void:
	var route: Array = %RouteDropdown.get_item_metadata(%RouteDropdown.get_selected())
	%TravelLine.text = "%s km — %s" % [
			_format_distance(TravelRouter.total_distance_km(route)), TravelRouter.describe(route)]


func _get_available(team: TeamData) -> Array[AgentData]:
	var members: Array[AgentData] = []
	for agent_id in team.member_ids:
		var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
		if a != null and a.is_available():
			members.append(a)
	return members


## Format a whole-km distance with thousands separators — "12,345 km"
## reads more naturally than "12345 km" at the widths this fits into.
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
