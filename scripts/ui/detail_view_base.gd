extends VBoxContainer
## DetailViewBase — shared building blocks for the left-sidebar detail
## views (Agent/Team/Event/Result/HQ). Each concrete view extends this by
## path (`extends "res://scripts/ui/detail_view_base.gd"`) rather than via
## class_name, so instantiating them needs no global-class-cache
## registration — PanelHost (Game.left_detail) just instantiates the
## registered script and calls populate(data, dismiss) on it.

func _add_title(text: String, font_size: int = 18) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	add_child(lbl)


func _add_subtitle(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	add_child(lbl)


func _add_section(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	add_child(lbl)


## parent lets a converted-to-tscn view drop rows into a specific mount
## point (e.g. %SquadList) instead of the view's own root; null keeps
## the pre-conversion behavior of adding to self.
func _add_info_row(label: String, value: String, parent: Node = null) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	row.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(val_lbl)

	(parent if parent != null else self).add_child(row)


func _add_close_button(on_close: Callable) -> void:
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(on_close)
	add_child(close_btn)


func _add_placeholder_row(text: String, parent: Node = null) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
	(parent if parent != null else self).add_child(lbl)


## Non-clickable proficiency rank pips — used for event requirements and
## team proficiencies. DetailViewAgent has its own clickable variant that
## opens the skill drill-down slideout.
func _add_prof_rank_row(prof_key: String, rank: int, color: Color, parent: Node = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = prof_key.capitalize()
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var visible_max: int = SkillData.VISIBLE_MAX_RANK
	for i in range(visible_max):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 16)
		if i < rank:
			pip.color = color
		else:
			pip.color = Color(0.15, 0.16, 0.2, 1.0)
		pips.add_child(pip)
	row.add_child(pips)

	(parent if parent != null else self).add_child(row)


func _status_color(status: AgentData.Status) -> Color:
	match status:
		AgentData.Status.AVAILABLE: return get_theme_color("available", "StatusColors")
		AgentData.Status.DEPLOYED: return get_theme_color("deployed", "StatusColors")
		AgentData.Status.INJURED: return get_theme_color("injured", "StatusColors")
		AgentData.Status.TRAINING: return get_theme_color("training", "StatusColors")
		AgentData.Status.KIA: return get_theme_color("kia", "StatusColors")
	return Color.WHITE


static func _status_name_for(status: AgentData.Status) -> String:
	match status:
		AgentData.Status.AVAILABLE: return "Available"
		AgentData.Status.DEPLOYED: return "Deployed"
		AgentData.Status.INJURED: return "Injured"
		AgentData.Status.TRAINING: return "Training"
		AgentData.Status.KIA: return "KIA"
	return "Unknown"
