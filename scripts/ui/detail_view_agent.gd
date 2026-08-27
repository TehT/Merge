extends "res://scripts/ui/detail_view_base.gd"
## DetailViewAgent — full agent sheet: proficiency ranks (clickable, opens
## the skill drill-down slideout), equipment, condition, personality
## (just the Archetype readout — clickable, opens the five-axis
## breakdown in SlideoutViewPersonality), team, supernatural info.
##
## Layout lives in scenes/ui/views/detail_agent.tscn (editable in the
## editor). The three equipment slot rows are always the same three
## (Weapon/Armor/Gadget); the three optional sections (Team/Cohesion,
## Supernatural) live in the .tscn hidden-by-default and switch on when
## the agent actually has that data. Proficiency rows are dynamic in
## count (one per proficiency with rank>0 or score>0), so they're
## built in code into the %ProficienciesList mount.

const SLOT_TYPES: Array[String] = ["Weapon", "Armor", "Gadget"]


func populate(data: Variant, _dismiss: Callable) -> void:
	var agent: AgentData = data

	%Title.text = agent.agent_name
	%Subtitle.text = "%s  —  %s" % [agent.get_status_name(), agent.get_type_name()]
	%Subtitle.add_theme_color_override("font_color", _status_color(agent.status))

	_fill_proficiencies(agent)
	_apply_equipment(agent)

	%HealthRow.set_value("%d / %d" % [int(agent.health), int(agent.max_health)])
	%MoraleRow.set_value("%d" % int(agent.morale))

	%ArchetypeRow.set_value(agent.get_archetype())
	%ArchetypeRow.clicked.connect(func() -> void:
			Game.left_popout.toggle_showing("personality", agent))

	_apply_team(agent)
	_apply_supernatural(agent)


func _fill_proficiencies(agent: AgentData) -> void:
	for child in %ProficienciesList.get_children():
		child.queue_free()
	var ranks := agent.get_proficiency_ranks()
	var scores := agent.get_proficiency_scores()
	for key: String in SkillData.PROFICIENCY_KEYS:
		if ranks[key] > 0 or scores[key] > 0.0:
			_add_clickable_prof_rank(key, ranks[key], scores[key],
					SkillData.PROFICIENCY_COLORS[key], agent)


func _apply_equipment(agent: AgentData) -> void:
	var slot_rows := {
		"Weapon": %WeaponRow,
		"Armor": %ArmorRow,
		"Gadget": %GadgetRow,
	}
	var equipped_by_slot := {
		"Weapon": agent.equipped_weapon,
		"Armor": agent.equipped_armor,
		"Gadget": agent.equipped_gadget,
	}
	for slot_type in SLOT_TYPES:
		var row = slot_rows[slot_type]
		var item = equipped_by_slot[slot_type]
		row.set_value(item.equipment_name if item != null else "Empty")
		row.set_value_dim(item == null)
		row.clicked.connect(func() -> void:
				Game.left_popout.toggle_showing("equip_slot",
						{"agent": agent, "slot_type": slot_type}))


func _apply_team(agent: AgentData) -> void:
	var team: TeamData = Game.team_manager.get_team_of_agent(agent.id)
	if team == null:
		return
	%TeamSep.visible = true
	%TeamRow.visible = true
	%TeamRow.set_value(team.team_name)
	%CohesionRow.visible = true
	%CohesionRow.set_value("%.0f%%" % team.cohesion)


func _apply_supernatural(agent: AgentData) -> void:
	if agent.supernatural_type == AgentData.SupernaturalType.NONE:
		return
	%SupernaturalSep.visible = true
	%SupernaturalSection.visible = true
	%SupernaturalTypeRow.visible = true
	%SupernaturalTypeRow.set_value(agent.get_type_name())
	%SupernaturalPowerRow.visible = true
	%SupernaturalPowerRow.set_value("%.0f" % agent.supernatural_power)


## Clickable proficiency rank row — key + pips + raw score + arrow. Kept
## in code (rather than a row template) because pip generation is
## variable-count and index-dependent, and the score label wants a
## right-aligned fixed-width slot that's a bit specific to this row.
## Same shape as detail_view_base._add_prof_rank_row plus the score
## slot, the arrow, and click wiring.
func _add_clickable_prof_rank(prof_key: String, rank: int, score: float,
		color: Color, agent: AgentData) -> void:
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

	%ProficienciesList.add_child(row)
