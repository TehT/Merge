extends VBoxContainer
## SquadList — lists the player's roster grouped by team. Each team is a
## toggleable (collapsible) section showing its members; agents not on
## any team show under a separate "Unassigned" section (always visible).
## Agents can be dragged between teams and to/from Unassigned.
## Empty teams remain visible so agents can be dragged back in.

signal agent_selected(agent: AgentData)
signal team_selected(team: TeamData)

var _expanded: Dictionary = {}
var _selected_agent_id: String = ""
var _next_team_number: int = 2
var _bottom_row: HBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	Game.agent_manager.roster_changed.connect(_refresh)
	Game.agent_manager.agent_status_changed.connect(_on_agent_status_changed)
	Game.team_manager.team_created.connect(_on_team_changed)
	Game.team_manager.cohesion_changed.connect(_on_cohesion_changed)
	Game.team_manager.training_started.connect(_on_team_changed)
	Game.team_manager.training_completed.connect(_on_team_changed)
	Game.team_manager.membership_changed.connect(_on_membership_changed)
	Game.team_manager.team_renamed.connect(_on_team_changed)
	_bottom_row = _make_bottom_row()
	get_parent().get_parent().add_child.call_deferred(_bottom_row)
	_refresh()


func _on_agent_status_changed(_agent_id: String, _old_status: AgentData.Status, _new_status: AgentData.Status) -> void:
	_refresh()

func _on_team_changed(_team: Variant) -> void:
	_refresh()

func _on_cohesion_changed(_team_id: String, _new_value: float, _delta: float) -> void:
	_refresh()

func _on_membership_changed(_team_id: String) -> void:
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var roster: Array[AgentData] = Game.agent_manager.roster
	if roster.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No agents."
		add_child(empty_label)
		return

	var by_team: Dictionary = {}
	var unassigned: Array[AgentData] = []
	for agent in roster:
		var team: TeamData = Game.team_manager.get_team_of_agent(agent.id)
		if team == null:
			unassigned.append(agent)
			continue
		if not by_team.has(team.id):
			var empty: Array[AgentData] = []
			by_team[team.id] = empty
		by_team[team.id].append(agent)

	var teams: Array[TeamData] = Game.team_manager.teams
	for team in teams:
		var members: Array[AgentData] = []
		if by_team.has(team.id):
			members = by_team[team.id]
		var title := "%s — Cohesion %.0f%%" % [team.team_name, team.cohesion]
		var days_left: int = Game.team_manager.get_training_days_left(team.id)
		if days_left > 0:
			title += "  (training, %dd left)" % days_left
		add_child(_make_group(team.id, title, members))

	add_child(_make_group("unassigned", "Unassigned", unassigned))


## Pinned outside the scrollable list, at the bottom of the Squads tab:
## "+ New Squad" plus "Hire", side by side — Hire used to be its own
## right-sidebar icon (opening the right popout directly), moved here
## since it's squad-roster-adjacent and the icon column was getting
## crowded with things that aren't really tab switches.
func _make_bottom_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_flat_button("+ New Squad", _on_new_squad_pressed))
	row.add_child(_make_flat_button("Hire", func() -> void: Game.right_popout.toggle_showing("hire")))
	return row


func _make_flat_button(text: String, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 0.8))
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(on_pressed)
	return btn


func _on_new_squad_pressed() -> void:
	var team_name := "Squad %d" % _next_team_number
	_next_team_number += 1
	Game.team_manager.create_empty_team(team_name)


func _make_group(key: String, title: String, members: Array[AgentData]) -> Control:
	if not _expanded.has(key):
		_expanded[key] = true
	var expanded: bool = _expanded[key]

	var container := VBoxContainer.new()

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	container.add_child(header_row)

	var toggle := Button.new()
	toggle.text = "▼" if expanded else "▶"
	toggle.custom_minimum_size.x = 28
	toggle.focus_mode = Control.FOCUS_NONE
	header_row.add_child(toggle)

	if key != "unassigned":
		var team_btn := Button.new()
		team_btn.text = "%s (%d)" % [title, members.size()]
		team_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		team_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team_btn.flat = true
		team_btn.focus_mode = Control.FOCUS_NONE
		team_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		team_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		header_row.add_child(team_btn)

		var team: TeamData = Game.team_manager.get_team(key)
		if team:
			team_btn.pressed.connect(func() -> void:
				team_selected.emit(team))

		header_row.set_drag_forwarding(
			Callable(),
			_can_drop_agent.bind(key),
			_on_agent_dropped.bind(key))
	else:
		var lbl := Label.new()
		lbl.text = "%s (%d)" % [title, members.size()]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		header_row.add_child(lbl)

		header_row.set_drag_forwarding(
			Callable(),
			_can_drop_agent.bind(key),
			_on_agent_dropped.bind(key))

	var body := VBoxContainer.new()
	body.visible = expanded
	body.add_theme_constant_override("separation", 4)
	body.custom_minimum_size.y = 30

	for agent in members:
		body.add_child(_make_agent_row(agent))

	if members.is_empty():
		var hint := Label.new()
		hint.text = "Drag agents here"
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		hint.add_theme_font_size_override("font_size", 12)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(hint)

	body.set_drag_forwarding(
		Callable(),
		_can_drop_agent.bind(key),
		_on_agent_dropped.bind(key))

	container.add_child(body)

	toggle.pressed.connect(func() -> void:
		var now_expanded: bool = not _expanded[key]
		_expanded[key] = now_expanded
		body.visible = now_expanded
		toggle.text = "▼" if now_expanded else "▶")

	return container


func _make_agent_row(agent: AgentData) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if agent.id == _selected_agent_id:
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.15, 0.2, 0.3, 0.95)
		sel.set_corner_radius_all(4)
		sel.content_margin_left = 10.0
		sel.content_margin_top = 6.0
		sel.content_margin_right = 10.0
		sel.content_margin_bottom = 6.0
		panel.add_theme_stylebox_override("panel", sel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var header_label := Label.new()
	header_label.text = "%s  —  %s (%s)" % [agent.agent_name, agent.get_status_name(), agent.get_type_name()]
	header_label.add_theme_color_override("font_color", _status_color(agent.status))
	header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header_label)

	var ranks := agent.get_proficiency_ranks()
	var stats := Label.new()
	stats.text = "C %d  Su %d  At %d  Er %d  In %d  Ig %d   HP %d/%d" % [
		ranks["combat"], ranks["subterfuge"],
		ranks["attunement"], ranks["erudition"],
		ranks["influence"], ranks["ingenuity"],
		int(agent.health), int(agent.max_health),
	]
	stats.add_theme_font_size_override("font_size", 12)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats)

	panel.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and not input_event.pressed \
				and input_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_agent_id = agent.id
			agent_selected.emit(agent)
			_refresh())

	if agent.is_available():
		panel.set_drag_forwarding(
			_get_agent_drag_data.bind(agent, panel),
			_always_deny_drop,
			_noop_drop)

	return panel


func _always_deny_drop(_at_pos: Vector2, _data: Variant) -> bool:
	return false

func _noop_drop(_at_pos: Vector2, _data: Variant) -> void:
	pass

func _get_agent_drag_data(_at_pos: Vector2, agent: AgentData, source: PanelContainer) -> Variant:
	var preview := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0
	preview.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = agent.agent_name
	lbl.add_theme_font_size_override("font_size", 13)
	preview.add_child(lbl)

	source.set_drag_preview(preview)
	return {"type": "agent", "agent_id": agent.id}


func _can_drop_agent(_at_pos: Vector2, data: Variant, target_key: String) -> bool:
	if not data is Dictionary:
		return false
	var dict: Dictionary = data as Dictionary
	if dict.get("type") != "agent":
		return false

	var agent_id: String = dict.get("agent_id", "")
	if agent_id == "":
		return false

	var current_team: TeamData = Game.team_manager.get_team_of_agent(agent_id)

	if target_key == "unassigned":
		return current_team != null
	else:
		if current_team and current_team.id == target_key:
			return false
		var team: TeamData = Game.team_manager.get_team(target_key)
		return team != null and team.member_ids.size() < TeamData.MAX_SIZE


func _on_agent_dropped(_at_pos: Vector2, data: Variant, target_key: String) -> void:
	if not data is Dictionary:
		return
	var dict: Dictionary = data as Dictionary
	if dict.get("type") != "agent":
		return

	var agent_id: String = dict.get("agent_id", "")
	if agent_id == "":
		return

	_move_agent(agent_id, target_key)


func _move_agent(agent_id: String, target_key: String) -> void:
	var current_team: TeamData = Game.team_manager.get_team_of_agent(agent_id)

	if target_key == "unassigned":
		if current_team:
			Game.team_manager.remove_member(current_team.id, agent_id)
	else:
		if current_team:
			if current_team.id == target_key:
				return
			Game.team_manager.remove_member(current_team.id, agent_id)
		Game.team_manager.add_member(target_key, agent_id)


func _status_color(status: AgentData.Status) -> Color:
	match status:
		AgentData.Status.AVAILABLE: return get_theme_color("available", "StatusColors")
		AgentData.Status.DEPLOYED: return get_theme_color("deployed", "StatusColors")
		AgentData.Status.INJURED: return get_theme_color("injured", "StatusColors")
		AgentData.Status.TRAINING: return get_theme_color("training", "StatusColors")
		AgentData.Status.KIA: return get_theme_color("kia", "StatusColors")
	return Color.WHITE
