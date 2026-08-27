extends "res://scripts/ui/detail_view_base.gd"
## DetailViewMissionResult — the report shown once a mission actually
## resolves (which can be days after dispatch, when the team arrives on
## site — see EventManager._on_team_arrived). Outcome, suitability roll,
## resolution log lines, and per-agent status. Split off from the older
## combined detail_view_result.gd (which also housed the travel-
## confirmation shell) once each PanelHost view had a single
## populate() — see detail_view_travel_confirmation.gd for the other
## half.

func populate(data: Variant, on_close: Callable) -> void:
	var team_name: String = data["team_name"]
	var ev_title: String = data["ev_title"]
	var result: MissionResolutionResult = data["result"]

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
