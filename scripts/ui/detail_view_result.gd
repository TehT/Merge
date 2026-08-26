extends "res://scripts/ui/detail_view_base.gd"
## DetailViewResult — two distinct outcomes shown through the same shell:
## a "Team Deployed" travel confirmation right after dispatch, and a full
## mission report once the mission actually resolves (which can be days
## later, once the team arrives — see EventManager._on_team_arrived /
## DetailSidebar._on_mission_resolved). Both need a way to return to the
## empty state, which lives on the loader, so it's passed in as a callable
## rather than this view knowing about DetailSidebar directly.

func populate_mission_result(team_name: String, ev_title: String, result: MissionResolutionResult, on_close: Callable) -> void:
	var outcome_color: Color
	var outcome_text: String
	match result.outcome:
		MissionResolutionResult.Outcome.SUCCESS:
			outcome_color = Color(0.4, 0.8, 0.45, 1.0)
			outcome_text = "Success"
		MissionResolutionResult.Outcome.PARTIAL:
			outcome_color = Color(0.85, 0.7, 0.2, 1.0)
			outcome_text = "Partial Success"
		_:
			outcome_color = Color(0.85, 0.35, 0.3, 1.0)
			outcome_text = "Failure"

	_add_title("Mission Report")
	_add_subtitle("%s  →  %s" % [team_name, ev_title], Color(0.55, 0.55, 0.6, 1.0))

	add_child(HSeparator.new())

	var outcome_lbl := Label.new()
	outcome_lbl.text = outcome_text
	outcome_lbl.add_theme_font_size_override("font_size", 16)
	outcome_lbl.add_theme_color_override("font_color", outcome_color)
	add_child(outcome_lbl)

	_add_info_row("Suitability", "%d%%" % int(round(float(result.team_suitability) * 100.0)))
	_add_info_row("Chance", "%d%%" % int(round(float(result.chance) * 100.0)))
	_add_info_row("Roll", "%.2f" % result.roll)

	if not result.log_lines.is_empty():
		add_child(HSeparator.new())
		_add_section("Resolution Details")
		for line: String in result.log_lines:
			var line_lbl := Label.new()
			line_lbl.text = line
			line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line_lbl.add_theme_font_size_override("font_size", 11)
			line_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
			add_child(line_lbl)

	add_child(HSeparator.new())
	_add_section("Agent Outcomes")
	var agent_results: Dictionary = result.agent_results
	for agent_id: String in agent_results:
		var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
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
	_add_close_button(on_close)


func populate_travel_confirmation(team_name: String, ev_title: String, plan: Dictionary,
		on_close: Callable, title: String = "Team Deployed") -> void:
	_add_title(title)
	_add_subtitle("%s  →  %s" % [team_name, ev_title], Color(0.55, 0.55, 0.6, 1.0))

	add_child(HSeparator.new())

	var status_lbl := Label.new()
	status_lbl.text = "En route"
	status_lbl.add_theme_font_size_override("font_size", 16)
	status_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
	add_child(status_lbl)

	var arrival_time: float = plan.arrival_time
	var arrival_hour := int(fmod(arrival_time, 1.0) * 24.0)

	_add_info_row("Distance", "%d km" % int(round(float(plan.distance_km))))
	_add_info_row("Travel Time", VehicleData.format_duration(plan.travel_hours))
	_add_info_row("Arriving", "Day %d, ~%02d:00" % [int(arrival_time), arrival_hour])

	add_child(HSeparator.new())
	_add_close_button(on_close)


func _add_close_button(on_close: Callable) -> void:
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(on_close)
	add_child(close_btn)
