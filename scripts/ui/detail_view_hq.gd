extends "res://scripts/ui/detail_view_base.gd"
## DetailViewHQ — base overview: fleet (clickable, opens the vehicle info
## slideout), squads and their status, Equipment/Base Upgrades placeholders.

func populate() -> void:
	_add_title(%TeamManager.HQ_NAME)
	_add_subtitle("Home base", Color(0.55, 0.55, 0.6, 1.0))

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
				var hours_left := maxf(0.0, (team.travel_arrival_day - %GameClock.get_current_time_days()) * 24.0)
				_add_info_row(team.team_name, "En route to %s (%s)" % [
					team.travel_destination_name, VehicleData.format_duration(hours_left)])
			else:
				_add_info_row(team.team_name, "At base")

	add_child(HSeparator.new())
	_add_section("Equipment")
	_add_placeholder_row("Coming soon")

	add_child(HSeparator.new())
	_add_section("Base Upgrades")
	_add_placeholder_row("Coming soon")


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
	stats_lbl.text = "%d km/h  •  %d km range  •  %d cap" % [
		int(round(vehicle.speed_kmh)), int(vehicle.max_range_km), vehicle.capacity]
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
