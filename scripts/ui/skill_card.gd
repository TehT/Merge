extends VBoxContainer
## SkillCard — one skill inside a Proficiency drill-down: name (colored
## by proficiency), rank pips + scaled value, and an optional tag flow.
## Static-shape parts (name, five rank pips, scaled-value label) live
## as real nodes in scenes/ui/rows/skill_card.tscn; the tag pills are
## dynamic (variable count per skill, each is its own styled panel) and
## get built into %TagFlow at populate() time.

const MAX_RANK := 5


func populate(skill: SkillData, color: Color) -> void:
	%Name.text = skill.skill_name
	%Name.add_theme_color_override("font_color", color)

	for i in range(MAX_RANK):
		var pip: ColorRect = get_node("RankRow/Pips/Pip%d" % (i + 1))
		pip.color = color if i < skill.rank else Color(0.15, 0.16, 0.2, 1.0)

	%ScaledValue.text = "  → %d" % skill.get_scaled_rank()

	for child in %TagFlow.get_children():
		child.queue_free()
	%TagFlow.visible = not skill.tags.is_empty()
	for tag: String in skill.tags:
		%TagFlow.add_child(_make_tag_pill(tag, color))


func _make_tag_pill(tag: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.15)
	style.border_color = Color(color, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0
	style.content_margin_top = 2.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = tag
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(color, 0.8))
	panel.add_child(lbl)

	return panel
