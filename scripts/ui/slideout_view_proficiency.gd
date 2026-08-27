extends VBoxContainer
## SlideoutViewProficiency — drill-down for one proficiency: rank pips,
## category description, and a card per underlying skill (rank, tags).
##
## Layout lives in scenes/ui/views/slideout_proficiency.tscn (editable
## in the editor). Header title + accent color, description text, and
## the rank pips (variable count via SkillData.VISIBLE_MAX_RANK) are all
## dynamic per-proficiency; skill cards are instantiated from
## scenes/ui/rows/skill_card.tscn into %SkillList.

@export var skill_card_scene: PackedScene


func populate(data: Variant, on_close: Callable) -> void:
	var agent: AgentData = data["agent"]
	var prof_key: String = data["prof_key"]
	var color: Color = SkillData.PROFICIENCY_COLORS.get(prof_key, Color.WHITE)

	%Header.set_title(prof_key.capitalize())
	%Header.set_title_color(color)
	%Header.close_requested.connect(on_close)

	var prof_rank: int = agent.get_proficiency_ranks()[prof_key]
	var prof_score: float = agent.get_proficiency_scores()[prof_key]
	_fill_rank_pips(prof_rank, color)
	# Raw 0-200 score alongside the tier — moves with every equipment
	# effect even when the tier itself doesn't cross a threshold.
	%Score.text = "%d" % int(round(prof_score))

	var prof_enum: SkillData.Proficiency = SkillData.PROFICIENCY_KEYS.find(prof_key) as SkillData.Proficiency
	var prof_desc := _get_proficiency_description(prof_enum)
	%Description.visible = prof_desc != ""
	%Description.text = prof_desc

	_fill_skills(agent, prof_key, color)


func _fill_rank_pips(rank: int, color: Color) -> void:
	for child in %Pips.get_children():
		child.queue_free()
	var visible_max: int = SkillData.VISIBLE_MAX_RANK
	for i in range(visible_max):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.color = color if i < rank else Color(0.15, 0.16, 0.2, 1.0)
		%Pips.add_child(pip)


func _fill_skills(agent: AgentData, prof_key: String, color: Color) -> void:
	# Equipment-aware (EquipmentHandler.get_effective_skills), not
	# agent.skills directly — a gear-granted virtual skill needs its own
	# card here, and a gear-modified skill (tag/rank changes) should show
	# its effective values, not the un-modified sheet ones.
	var matching_skills: Array[SkillData] = []
	for skill: SkillData in EquipmentHandler.get_effective_skills(agent):
		if skill.get_proficiency_key() == prof_key:
			matching_skills.append(skill)

	%EmptyLabel.visible = matching_skills.is_empty()

	for skill in matching_skills:
		var card := skill_card_scene.instantiate()
		%SkillList.add_child(card)
		card.populate(skill, color)


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
