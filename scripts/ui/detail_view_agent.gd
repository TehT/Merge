extends "res://scripts/ui/detail_view_base.gd"
## DetailViewAgent — full agent sheet: proficiency ranks (clickable, opens
## the skill drill-down slideout), equipment, condition, personality
## (just the Archetype readout — clickable, opens the five-axis
## breakdown in SlideoutViewPersonality), team, supernatural info.

func populate(data: Variant, _dismiss: Callable) -> void:
	var agent: AgentData = data
	_add_title(agent.agent_name)
	_add_subtitle("%s  —  %s" % [agent.get_status_name(), agent.get_type_name()], _status_color(agent.status))

	add_child(HSeparator.new())

	_add_section("Proficiencies")
	var ranks := agent.get_proficiency_ranks()
	var scores := agent.get_proficiency_scores()
	for key: String in SkillData.PROFICIENCY_KEYS:
		if ranks[key] > 0 or scores[key] > 0.0:
			_add_clickable_prof_rank(key, ranks[key], scores[key], SkillData.PROFICIENCY_COLORS[key], agent)

	add_child(HSeparator.new())

	_add_section("Equipment")
	_add_clickable_slot("Weapon", agent.equipped_weapon, agent)
	_add_clickable_slot("Armor", agent.equipped_armor, agent)
	_add_clickable_slot("Gadget", agent.equipped_gadget, agent)

	add_child(HSeparator.new())

	_add_section("Condition")
	_add_info_row("Health", "%d / %d" % [int(agent.health), int(agent.max_health)])
	_add_info_row("Morale", "%d" % int(agent.morale))

	add_child(HSeparator.new())

	_add_section("Personality")
	_add_clickable_archetype_row(agent)

	var team: TeamData = Game.team_manager.get_team_of_agent(agent.id)
	if team:
		add_child(HSeparator.new())
		_add_info_row("Team", team.team_name)
		_add_info_row("Cohesion", "%.0f%%" % team.cohesion)

	if agent.supernatural_type != AgentData.SupernaturalType.NONE:
		add_child(HSeparator.new())
		_add_section("Supernatural")
		_add_info_row("Type", agent.get_type_name())
		_add_info_row("Power", "%.0f" % agent.supernatural_power)


## Just the Archetype name — the five underlying axis bars live in
## SlideoutViewPersonality (Game.left_popout.show("personality", ...)), same
## drill-down pattern as a clickable proficiency row.
func _add_clickable_archetype_row(agent: AgentData) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "Archetype"
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = agent.get_archetype()
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_lbl)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Game.left_popout.toggle_showing("personality", agent))

	add_child(row)


func _add_clickable_slot(slot_type: String, equipped: EquipmentData, agent: AgentData) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = slot_type
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = equipped.equipment_name if equipped != null else "Empty"
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.add_theme_font_size_override("font_size", 13)
	if equipped == null:
		val_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_lbl)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Game.left_popout.toggle_showing("equip_slot", {"agent": agent, "slot_type": slot_type}))

	add_child(row)


func _add_clickable_prof_rank(prof_key: String, rank: int, score: float, color: Color, agent: AgentData) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = prof_key.capitalize()
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visible_max: int = SkillData.VISIBLE_MAX_RANK
	for i in range(visible_max):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 16)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < rank:
			pip.color = color
		else:
			pip.color = Color(0.15, 0.16, 0.2, 1.0)
		pips.add_child(pip)
	row.add_child(pips)

	# Raw 0-200 score alongside the Tier pips — the pips only move when a
	# rank threshold is crossed, so a modest equipment bonus (a +4 stat
	# boost, say) can otherwise be completely invisible here even though
	# it's already affecting suitability. The number always moves.
	var score_lbl := Label.new()
	score_lbl.text = "%d" % int(round(score))
	score_lbl.custom_minimum_size.x = 32
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_font_size_override("font_size", 12)
	score_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(score_lbl)

	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.42, 0.48, 1.0))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Game.left_popout.toggle_showing("proficiency", {"agent": agent, "prof_key": prof_key}))

	add_child(row)
