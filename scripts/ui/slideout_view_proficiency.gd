extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewProficiency — drill-down for one proficiency: rank pips,
## category description, and a card per underlying skill (rank, tags).

func populate(agent: AgentData, prof_key: String, on_close: Callable) -> void:
	var color: Color = SkillData.PROFICIENCY_COLORS.get(prof_key, Color.WHITE)

	_add_header(prof_key.capitalize(), on_close, color, 16)

	var prof_rank: int = agent.get_proficiency_ranks()[prof_key]
	var prof_score: float = agent.get_proficiency_scores()[prof_key]
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

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_child(spacer)

	# Raw 0-200 score alongside the Tier — moves with every equipment
	# effect even when the Tier itself doesn't cross a threshold.
	var score_lbl := Label.new()
	score_lbl.text = "%d" % int(round(prof_score))
	score_lbl.add_theme_font_size_override("font_size", 13)
	score_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	rank_row.add_child(score_lbl)

	add_child(rank_row)

	var prof_enum: SkillData.Proficiency = SkillData.PROFICIENCY_KEYS.find(prof_key)
	var prof_desc := _get_proficiency_description(prof_enum)
	if prof_desc != "":
		var desc := Label.new()
		desc.text = prof_desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1.0))
		add_child(desc)

	add_child(HSeparator.new())

	# Equipment-aware (EquipmentHandler.get_effective_skills), not
	# agent.skills directly — a gear-granted virtual skill needs its own
	# card here, and a gear-modified skill (tag/rank changes) should show
	# its effective values, not the un-modified sheet ones.
	var matching_skills: Array[SkillData] = []
	for skill: SkillData in EquipmentHandler.get_effective_skills(agent):
		if skill.get_proficiency_key() == prof_key:
			matching_skills.append(skill)

	if matching_skills.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No skills in this proficiency."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(none_lbl)
		return

	for skill: SkillData in matching_skills:
		add_child(_make_skill_card(skill, color))


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
