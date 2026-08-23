extends PanelContainer
## SkillSlideout — secondary panel that slides out from the detail panel.
## Doubles as a drill-down for proficiency skills (clicking a proficiency
## bar), the squad picker for deploying a team to an event (clicking
## "Deploy Team"), and a vehicle info card (clicking a fleet vehicle in
## the HQ panel).

enum _Mode { NONE, PROFICIENCY, DEPLOY, VEHICLE }

var _content: VBoxContainer
var _mode: _Mode = _Mode.NONE
var _active_prof_key: String = ""
var _active_agent: AgentData
var _active_event: EventData
var _active_vehicle: VehicleData


func _ready() -> void:
	visible = false
	custom_minimum_size.x = 260

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	style.border_color = Color(0.2, 0.22, 0.28, 1.0)
	style.border_width_right = 1
	style.set_corner_radius_all(0)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func show_proficiency(agent: AgentData, prof_key: String) -> void:
	if _mode == _Mode.PROFICIENCY and _active_agent == agent and _active_prof_key == prof_key and visible:
		dismiss()
		return

	_mode = _Mode.PROFICIENCY
	_active_agent = agent
	_active_prof_key = prof_key
	_populate_proficiency()
	visible = true


func show_deploy_teams(ev: EventData) -> void:
	if _mode == _Mode.DEPLOY and _active_event == ev and visible:
		dismiss()
		return

	_mode = _Mode.DEPLOY
	_active_event = ev
	_populate_deploy()
	visible = true


func show_vehicle(vehicle: VehicleData) -> void:
	if _mode == _Mode.VEHICLE and _active_vehicle == vehicle and visible:
		dismiss()
		return

	_mode = _Mode.VEHICLE
	_active_vehicle = vehicle
	_populate_vehicle()
	visible = true


func dismiss() -> void:
	visible = false
	_mode = _Mode.NONE
	_active_prof_key = ""
	_active_agent = null
	_active_event = null
	_active_vehicle = null


func _populate_proficiency() -> void:
	for child in _content.get_children():
		child.queue_free()

	var color: Color = SkillData.PROFICIENCY_COLORS.get(_active_prof_key, Color.WHITE)

	var header := HBoxContainer.new()
	_content.add_child(header)

	var title := Label.new()
	title.text = _active_prof_key.capitalize()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(dismiss)
	header.add_child(close_btn)

	var prof_rank: int = _active_agent.get_proficiency_ranks()[_active_prof_key]
	var rank_row := HBoxContainer.new()
	rank_row.add_theme_constant_override("separation", 4)
	var rank_lbl := Label.new()
	rank_lbl.text = "Rank"
	rank_lbl.add_theme_font_size_override("font_size", 12)
	rank_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1.0))
	rank_row.add_child(rank_lbl)
	var visible_max: int = SkillData.VISIBLE_MAX_RANK
	for i in range(visible_max):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 14)
		if i < prof_rank:
			pip.color = color
		else:
			pip.color = Color(0.15, 0.16, 0.2, 1.0)
		rank_row.add_child(pip)
	_content.add_child(rank_row)

	var prof_enum: SkillData.Proficiency = SkillData.PROFICIENCY_KEYS.find(_active_prof_key)
	var prof_desc := _get_proficiency_description(prof_enum)
	if prof_desc != "":
		var desc := Label.new()
		desc.text = prof_desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1.0))
		_content.add_child(desc)

	_content.add_child(HSeparator.new())

	var matching_skills: Array[SkillData] = []
	for skill: SkillData in _active_agent.skills:
		if skill.get_proficiency_key() == _active_prof_key:
			matching_skills.append(skill)

	if matching_skills.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No skills in this proficiency."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		_content.add_child(none_lbl)
		return

	for skill: SkillData in matching_skills:
		_content.add_child(_make_skill_card(skill, color))


func _populate_deploy() -> void:
	for child in _content.get_children():
		child.queue_free()

	var header := HBoxContainer.new()
	_content.add_child(header)

	var title := Label.new()
	title.text = "Deploy Team"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(dismiss)
	header.add_child(close_btn)

	var subtitle := Label.new()
	subtitle.text = _active_event.title
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1.0))
	_content.add_child(subtitle)

	_content.add_child(HSeparator.new())

	var teams: Array[TeamData] = %TeamManager.teams
	var deployable := teams.filter(func(t: TeamData) -> bool: return not t.member_ids.is_empty())

	if deployable.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No squads to deploy."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		_content.add_child(none_lbl)
		return

	for team: TeamData in deployable:
		_content.add_child(_make_deploy_row(team))


func _get_available_team_members(team: TeamData) -> Array[AgentData]:
	var members: Array[AgentData] = []
	for agent_id in team.member_ids:
		var a: AgentData = %AgentManager.get_agent_by_id(agent_id)
		if a != null and a.is_available():
			members.append(a)
	return members


func _make_deploy_row(team: TeamData) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)

	var available := _get_available_team_members(team)
	var distance := GeoData.haversine_km(team.location.y, team.location.x,
			_active_event.geo_coordinates.y, _active_event.geo_coordinates.x)
	var vehicle: VehicleData = %TeamManager.get_best_vehicle(distance, available.size())
	var in_range := vehicle != null
	var can_deploy := not available.is_empty() and not team.is_traveling and in_range

	var name_lbl := Label.new()
	name_lbl.text = "%s  (%d/%d available)" % [team.team_name, available.size(), team.member_ids.size()]
	name_lbl.add_theme_font_size_override("font_size", 13)
	card.add_child(name_lbl)

	if team.is_traveling:
		var hours_left := maxf(0.0, (team.travel_arrival_day - %GameClock.get_current_time_days()) * 24.0)
		var travel_lbl := Label.new()
		travel_lbl.text = "En route to %s — %s left" % [
			team.travel_destination_name, VehicleData.format_duration(hours_left)]
		travel_lbl.add_theme_font_size_override("font_size", 12)
		travel_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
		card.add_child(travel_lbl)
		card.add_child(HSeparator.new())
		return card

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_col)

	var match_lbl := Label.new()
	if not in_range:
		match_lbl.text = "No vehicle can reach this (range or capacity)"
		match_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	elif available.is_empty():
		match_lbl.text = "No members available"
		match_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	else:
		var suitability := MissionResolver.compute_team_suitability(_active_event, available, team)
		var pct := int(round(suitability * 100.0))
		match_lbl.text = "Match: %d%%" % pct
		if suitability >= 1.0:
			match_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.45, 1.0))
		elif suitability >= 0.6:
			match_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2, 1.0))
		else:
			match_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	match_lbl.add_theme_font_size_override("font_size", 12)
	info_col.add_child(match_lbl)

	var travel_lbl := Label.new()
	if in_range:
		var travel_hours := vehicle.compute_travel_hours(distance)
		travel_lbl.text = "%s km — ~%s via %s" % [
			_format_distance(distance), VehicleData.format_duration(travel_hours), vehicle.vehicle_name]
	else:
		travel_lbl.text = "%s km" % _format_distance(distance)
	travel_lbl.add_theme_font_size_override("font_size", 11)
	travel_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	info_col.add_child(travel_lbl)

	var deploy_btn := Button.new()
	deploy_btn.text = "Deploy"
	deploy_btn.disabled = not can_deploy
	deploy_btn.focus_mode = Control.FOCUS_NONE
	if can_deploy:
		deploy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	deploy_btn.pressed.connect(_on_deploy_pressed.bind(team))
	row.add_child(deploy_btn)

	card.add_child(HSeparator.new())

	return card


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


func _on_deploy_pressed(team: TeamData) -> void:
	var team_name := team.team_name
	var ev_title := _active_event.title
	var plan: Dictionary = %EventManager.deploy_team(_active_event.id, team.id)
	if plan.is_empty():
		return
	dismiss()
	%DetailPanel.show_travel_confirmation(team_name, ev_title, plan)


func _populate_vehicle() -> void:
	for child in _content.get_children():
		child.queue_free()

	var v := _active_vehicle
	var accent := Color(0.5, 0.6, 0.8, 1.0)

	var header := HBoxContainer.new()
	_content.add_child(header)

	var title := Label.new()
	title.text = v.vehicle_name
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", accent)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(dismiss)
	header.add_child(close_btn)

	_content.add_child(_make_vehicle_image(v))

	_content.add_child(HSeparator.new())

	_add_vehicle_stat("Mode", v.get_mode_name())
	_add_vehicle_stat("Speed", "%d km/day" % int(v.speed_km_per_day))
	_add_vehicle_stat("Range", "%d km" % int(v.max_range_km) if v.max_range_km > 0.0 else "Unlimited")
	_add_vehicle_stat("Capacity", "%d agents" % v.capacity)
	_add_vehicle_stat("Operation Cost", "%d funding" % v.operation_cost if v.operation_cost > 0 else "None")
	if v.mode == VehicleData.Mode.TELEPORT and v.cooldown_days > 0:
		_add_vehicle_stat("Cooldown", "%d day(s)" % v.cooldown_days)

	if v.description != "":
		_content.add_child(HSeparator.new())
		var desc := Label.new()
		desc.text = v.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
		_content.add_child(desc)


func _make_vehicle_image(v: VehicleData) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	style.border_color = Color(0.2, 0.22, 0.28, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(0, 120)

	var tex: Texture2D = load(v.image_path) if v.image_path != "" else null
	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.add_child(rect)
	else:
		var placeholder := Label.new()
		placeholder.text = "No image yet"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 1.0))
		frame.add_child(placeholder)

	return frame


func _add_vehicle_stat(label: String, value: String) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	row.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)

	_content.add_child(row)


func _make_skill_card(skill: SkillData, color: Color) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)

	var name_row := HBoxContainer.new()
	card.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = skill.skill_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var rank_row := HBoxContainer.new()
	card.add_child(rank_row)

	var rank_lbl := Label.new()
	rank_lbl.text = "Rank"
	rank_lbl.add_theme_font_size_override("font_size", 12)
	rank_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	rank_row.add_child(rank_lbl)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.alignment = BoxContainer.ALIGNMENT_END
	for i in range(5):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 14)
		if i < skill.rank:
			pip.color = color
		else:
			pip.color = Color(0.15, 0.16, 0.2, 1.0)
		pips.add_child(pip)
	rank_row.add_child(pips)

	var value_lbl := Label.new()
	value_lbl.text = "  → %d" % skill.get_scaled_rank()
	value_lbl.add_theme_font_size_override("font_size", 12)
	value_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	rank_row.add_child(value_lbl)

	if not skill.tags.is_empty():
		var tag_flow := HFlowContainer.new()
		tag_flow.add_theme_constant_override("h_separation", 4)
		tag_flow.add_theme_constant_override("v_separation", 3)
		card.add_child(tag_flow)

		for tag: String in skill.tags:
			var tag_panel := PanelContainer.new()
			var tag_style := StyleBoxFlat.new()
			tag_style.bg_color = Color(color, 0.15)
			tag_style.border_color = Color(color, 0.3)
			tag_style.set_border_width_all(1)
			tag_style.set_corner_radius_all(3)
			tag_style.content_margin_left = 6.0
			tag_style.content_margin_top = 2.0
			tag_style.content_margin_right = 6.0
			tag_style.content_margin_bottom = 2.0
			tag_panel.add_theme_stylebox_override("panel", tag_style)

			var tag_lbl := Label.new()
			tag_lbl.text = tag
			tag_lbl.add_theme_font_size_override("font_size", 11)
			tag_lbl.add_theme_color_override("font_color", Color(color, 0.8))
			tag_panel.add_child(tag_lbl)

			tag_flow.add_child(tag_panel)

	return card


func _get_proficiency_description(prof: SkillData.Proficiency) -> String:
	match prof:
		SkillData.Proficiency.COMBAT:
			return "Direct physical intervention, containment, brute force."
		SkillData.Proficiency.SUBTERFUGE:
			return "Infiltration, misdirection, bypassing hazards unnoticed."
		SkillData.Proficiency.ATTUNEMENT:
			return "Raw magical manipulation, warding, sensing auras."
		SkillData.Proficiency.ERUDITION:
			return "Occult knowledge, ancient languages, anomaly behaviors."
		SkillData.Proficiency.INFLUENCE:
			return "Social engineering, crowd control, diplomatic maneuvering."
		SkillData.Proficiency.INGENUITY:
			return "Modern technology, equipment deployment, tactical adaptation."
	return ""
