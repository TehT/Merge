extends PanelContainer
## RecruitRow — one candidate in the hiring pool: name + type + archetype
## + a compact proficiency-rank readout + Hire button. Whole panel is
## clickable outside the Hire button (opens the recruit's full agent
## sheet on the left detail panel — a preview before committing
## funding). Emits signals for both actions rather than knowing about
## Game directly, so the enclosing view (RightSlideoutViewHire)
## coordinates the actual hire / detail-open.

signal hire_pressed(recruit: AgentData)
signal preview_requested(recruit: AgentData)

var _recruit: AgentData


func populate(recruit: AgentData, hire_cost: int, funding: int) -> void:
	_recruit = recruit
	%Name.text = "%s  (%s)" % [recruit.agent_name, recruit.get_type_name()]
	%Archetype.text = recruit.get_archetype()

	var ranks := recruit.get_proficiency_ranks()
	%Stats.text = "C %d  Su %d  At %d  Er %d  In %d  Ig %d" % [
			ranks["combat"], ranks["subterfuge"],
			ranks["attunement"], ranks["erudition"],
			ranks["influence"], ranks["ingenuity"]]

	%HireBtn.text = "Hire (%d)" % hire_cost
	%HireBtn.disabled = funding < hire_cost
	%HireBtn.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if not %HireBtn.disabled else Control.CURSOR_ARROW)
	%HireBtn.pressed.connect(func() -> void: hire_pressed.emit(_recruit))


func _gui_input(event: InputEvent) -> void:
	# Hire button (default MOUSE_FILTER_STOP) consumes its own clicks
	# before they reach here — the rest of the row (labels set to
	# IGNORE in the scene) falls through and triggers the preview.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		preview_requested.emit(_recruit)
