extends "res://scripts/ui/detail_view_base.gd"
## DetailViewEvent — event sheet: deploy entry point, satellite mini-map,
## location, requirement rank pips, stakes, rewards.

var _map_shader: Shader
var _satellite_tex: Texture2D


func populate(ev: EventData) -> void:
	_map_shader = load("res://shaders/detail_map_2d.gdshader")
	_satellite_tex = load("res://textures/satellite_map_4096.png")

	_add_title(ev.title)
	_add_subtitle("%s  —  %s" % [ev.get_type_name(), ev.get_urgency_name()], ev.get_urgency_color())

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
