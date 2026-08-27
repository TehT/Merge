extends "res://scripts/ui/detail_view_base.gd"
## DetailViewMissionResult — the report shown once a mission actually
## resolves (which can be days after dispatch, when the team arrives on
## site — see EventManager._on_team_arrived). Outcome, suitability roll,
## resolution log lines, and per-agent status.
##
## Layout lives in scenes/ui/views/detail_mission_result.tscn (editable
## in the editor). Static skeleton (title, section headers, close button)
## sits in the scene; per-log-line labels and per-agent outcome rows are
## built dynamically into the two mount points (%ResolutionList,
## %OutcomesList) since their counts vary per-mission.


func populate(data: Variant, on_close: Callable) -> void:
	var team_name: String = data["team_name"]
	var ev_title: String = data["ev_title"]
	var result: MissionResolutionResult = data["result"]

	%Subtitle.text = "%s  →  %s" % [team_name, ev_title]

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
	%Outcome.text = outcome_text
	%Outcome.add_theme_color_override("font_color", outcome_color)

	%SuitabilityRow.set_value("%d%%" % int(round(float(result.team_suitability) * 100.0)))
	%ChanceRow.set_value("%d%%" % int(round(float(result.chance) * 100.0)))
	%RollRow.set_value("%.2f" % result.roll)

	_fill_resolution_lines(result.log_lines)
	_fill_agent_outcomes(result.agent_results)

	%CloseButton.pressed.connect(on_close)


func _fill_resolution_lines(log_lines: PackedStringArray) -> void:
	var has_lines := not log_lines.is_empty()
	%ResolutionSep.visible = has_lines
	%ResolutionSection.visible = has_lines
	for child in %ResolutionList.get_children():
		child.queue_free()
	if not has_lines:
		return
	for line in log_lines:
		var line_lbl := Label.new()
		line_lbl.text = line
		line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line_lbl.add_theme_font_size_override("font_size", 11)
		line_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
		%ResolutionList.add_child(line_lbl)


func _fill_agent_outcomes(agent_results: Dictionary) -> void:
	for child in %OutcomesList.get_children():
		child.queue_free()
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
		%OutcomesList.add_child(row)
