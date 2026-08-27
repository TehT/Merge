extends Control
class_name MissionChoiceDialog
## MissionChoiceDialog — full-screen modal for ChoicePhase's PLAYER_CHOICE
## trigger. Referenced elsewhere via Game.mission_choice_dialog (registers
## itself in _ready(), same pattern as PanelHost's `register_as`).
## request_choice() is the only entry point ChoicePhase calls: it
## populates the dialogue, shows it, suspends until the player clicks an
## option, then hides itself and returns the chosen MissionCheck — the
## caller (ChoicePhase._pick_check, via `await`) resumes mission
## resolution from there.

signal _choice_made(check: MissionCheck)

var _content: VBoxContainer
var _log_label: Label


func _ready() -> void:
	Game.mission_choice_dialog = self
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.6)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.14, 1.0)
	style.border_color = Color(0.25, 0.28, 0.36, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_top = 14.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	panel.add_child(_content)


## Populates and shows the dialogue for the given ChoicePhase, then
## suspends until the player picks an option. log_so_far is everything
## MissionPhaseRunner has logged for this mission before this phase — shown
## so the player can see how things have gone before deciding. Returns the
## chosen MissionCheck.
func request_choice(phase: ChoicePhase, log_so_far: PackedStringArray) -> MissionCheck:
	_populate(phase, log_so_far)
	visible = true
	var chosen: MissionCheck = await _choice_made
	visible = false
	return chosen


func _populate(phase: ChoicePhase, log_so_far: PackedStringArray) -> void:
	for child in _content.get_children():
		child.queue_free()

	var title_lbl := Label.new()
	title_lbl.text = phase.phase_name if phase.phase_name != "" else "Choose how to proceed"
	title_lbl.add_theme_font_size_override("font_size", 16)
	_content.add_child(title_lbl)

	if not log_so_far.is_empty():
		var log_scroll := ScrollContainer.new()
		log_scroll.custom_minimum_size = Vector2(0, 90)
		log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_content.add_child(log_scroll)

		var log_lbl := Label.new()
		log_lbl.text = "\n".join(log_so_far)
		log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_lbl.add_theme_font_size_override("font_size", 11)
		log_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
		log_scroll.add_child(log_lbl)

		_content.add_child(HSeparator.new())

	var prompt_lbl := Label.new()
	prompt_lbl.text = "Choose an approach:"
	prompt_lbl.add_theme_font_size_override("font_size", 13)
	prompt_lbl.add_theme_color_override("font_color", Color(0.75, 0.77, 0.85, 1.0))
	_content.add_child(prompt_lbl)

	for check: MissionCheck in phase.checks:
		_content.add_child(_make_option_row(check))


func _make_option_row(check: MissionCheck) -> Control:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.19, 1.0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var name_lbl := Label.new()
	name_lbl.text = check.check_name if check.check_name != "" else "Unnamed"
	name_lbl.add_theme_font_size_override("font_size", 14)
	box.add_child(name_lbl)

	var reqs := check.get_proficiency_requirements()
	var any_req := false
	for key: String in SkillData.PROFICIENCY_KEYS:
		var rank: int = reqs[key]
		if rank > 0:
			any_req = true
			box.add_child(_make_pip_row(key, rank, SkillData.PROFICIENCY_COLORS[key]))
	if not any_req:
		var none_lbl := Label.new()
		none_lbl.text = "No proficiency requirement"
		none_lbl.add_theme_font_size_override("font_size", 11)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		box.add_child(none_lbl)

	panel.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT:
			_choice_made.emit(check))

	return panel


func _make_pip_row(prof_key: String, rank: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = prof_key.capitalize()
	lbl.custom_minimum_size.x = 76
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	var visible_max: int = SkillData.VISIBLE_MAX_RANK
	for i in range(visible_max):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.color = color if i < rank else Color(0.2, 0.21, 0.26, 1.0)
		pips.add_child(pip)
	row.add_child(pips)

	return row
