extends "res://scripts/ui/detail_view_base.gd"
## DetailViewEvent — event sheet: deploy entry point, satellite mini-map,
## location, requirement rank pips, stakes, rewards.
##
## Layout lives in scenes/ui/views/detail_event.tscn (editable in the
## editor). This script sets label values and toggles the two
## conditional rows (%LocationRow / %CoordsRow / %ItemRow) visible when
## the event actually carries that data. The Requirements section is
## still built dynamically per-phase from code — the shape is genuinely
## variable (variable phase count, variable check count per phase,
## variable rank rows per check) — into the %RequirementsList mount.


func populate(data: Variant, _dismiss: Callable) -> void:
	var ev: EventData = data

	%Title.text = ev.title
	%Subtitle.text = "%s  —  %s" % [ev.get_type_name(), ev.get_urgency_name()]
	%Subtitle.add_theme_color_override("font_color", ev.get_urgency_color())

	%DeployRow.gui_input.connect(func(input_event: InputEvent) -> void:
			if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
				Game.left_popout.toggle_showing("deploy", ev))

	# Map only meaningful when the event has real coords.
	%MapPanel.visible = ev.geo_coordinates != Vector2.ZERO
	if %MapPanel.visible:
		_apply_map_shader(ev.geo_coordinates)

	if ev.location_city != "":
		var loc_parts: PackedStringArray = [ev.location_city]
		if ev.location_country != "":
			loc_parts.append(ev.location_country)
		%LocationRow.visible = true
		%LocationRow.set_value(", ".join(loc_parts))

	if ev.geo_coordinates != Vector2.ZERO:
		var lon: float = ev.geo_coordinates.x
		var lat: float = ev.geo_coordinates.y
		var lat_str := "%.1f°%s" % [absf(lat), "N" if lat >= 0.0 else "S"]
		var lon_str := "%.1f°%s" % [absf(lon), "E" if lon >= 0.0 else "W"]
		%CoordsRow.visible = true
		%CoordsRow.set_value("%s, %s" % [lat_str, lon_str])

	%DaysRow.set_value("%d" % ev.days_remaining)
	%PhasesRow.set_value("%d" % ev.phases.size())

	%RequirementsSection.text = "Requirements  (%d phase%s)" % [
			ev.phases.size(), "" if ev.phases.size() == 1 else "s"]
	_fill_requirements(ev)

	%OnFailRow.set_value("+%.0f concealment" % ev.concealment_on_fail)
	%OnPartialRow.set_value("+%.0f concealment" % ev.concealment_on_partial)
	%OnSuccessRow.set_value("%+.0f concealment" % ev.concealment_on_success)

	%FundingRow.set_value("+%d" % ev.reward_funding)
	%IntelRow.set_value("+%d" % ev.reward_intel)
	if ev.reward_item != "":
		%ItemRow.visible = true
		%ItemRow.set_value(ev.reward_item)


## Applies event-specific parameters to the shared map ShaderMaterial
## (set up as a SubResource on %MapRect in the .tscn — shader + texture
## + fixed aspect are baked in; only uv_min, uv_max and marker_uv vary
## per event, so those are all that need setting here).
func _apply_map_shader(coords: Vector2) -> void:
	var lon: float = coords.x
	var lat: float = coords.y

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

	var mat: ShaderMaterial = %MapRect.material
	mat.set_shader_parameter("uv_min", uv_min)
	mat.set_shader_parameter("uv_max", uv_max)
	mat.set_shader_parameter("marker_uv", Vector2(center_u, center_v))


## Per-phase requirement breakdown — each phase gets its own header (with
## a trigger note for ChoicePhase), and each of its checks (just one for
## SinglePhase, every option for ChoicePhase since only one runs and
## which isn't known ahead of time) gets its own labeled proficiency-
## rank rows. Fully dynamic in shape (variable phase count, variable
## checks per phase, variable rank rows per check) so this stays in code
## rather than living in the .tscn.
func _fill_requirements(ev: EventData) -> void:
	for child in %RequirementsList.get_children():
		child.queue_free()

	if ev.phases.is_empty():
		_add_placeholder_row("No phases configured", %RequirementsList)
		return

	for i in range(ev.phases.size()):
		var phase: MissionPhase = ev.phases[i]
		var phase_label := phase.phase_name if phase.phase_name != "" else "Phase %d" % (i + 1)

		var phase_lbl := Label.new()
		phase_lbl.text = "%d. %s%s" % [i + 1, phase_label, _phase_trigger_note(phase)]
		phase_lbl.add_theme_font_size_override("font_size", 13)
		phase_lbl.add_theme_color_override("font_color", Color(0.75, 0.77, 0.85, 1.0))
		%RequirementsList.add_child(phase_lbl)

		var checks := phase.get_checks()
		if checks.is_empty():
			_add_placeholder_row("No checks configured", %RequirementsList)
			continue

		for check: MissionCheck in checks:
			if checks.size() > 1:
				var opt_lbl := Label.new()
				opt_lbl.text = "Option: %s" % (check.check_name if check.check_name != "" else "Unnamed")
				opt_lbl.add_theme_font_size_override("font_size", 12)
				opt_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
				%RequirementsList.add_child(opt_lbl)

			var reqs := check.get_proficiency_requirements()
			var any_req := false
			for key: String in SkillData.PROFICIENCY_KEYS:
				if reqs[key] > 0:
					any_req = true
					_add_prof_rank_row(key, reqs[key], SkillData.PROFICIENCY_COLORS[key], %RequirementsList)
			if not any_req:
				_add_placeholder_row("No proficiency requirement", %RequirementsList)


func _phase_trigger_note(phase: MissionPhase) -> String:
	if phase is ChoicePhase:
		match (phase as ChoicePhase).trigger:
			ChoicePhase.Trigger.FAILURE: return "  (if previous phase fails)"
			ChoicePhase.Trigger.RANDOM: return "  (random choice)"
			ChoicePhase.Trigger.PLAYER_CHOICE: return "  (player choice)"
	return ""
