extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewPersonality — drill-down for one agent's full Personality
## Matrix: the Archetype readout plus a center-filled bar per axis. Each
## axis is stored 0-100 (unchanged), but reads visually as two 0-50 scales
## back to back — the fill starts at the middle and grows toward whichever
## pole the value leans, so "50" always means dead-center/neutral and the
## bar's two halves are each pole's own 0-50 reach, not one 0-100 track.

const BAR_W := 140.0
const BAR_H := 14.0
const FILL_COLOR := Color(0.75, 0.68, 0.5, 1.0)


func populate(data: Variant, on_close: Callable) -> void:
	var agent: AgentData = data
	_add_header("Personality", on_close)

	var archetype_lbl := Label.new()
	archetype_lbl.text = agent.get_archetype()
	archetype_lbl.add_theme_font_size_override("font_size", 18)
	archetype_lbl.add_theme_color_override("font_color", FILL_COLOR)
	add_child(archetype_lbl)

	add_child(HSeparator.new())

	for axis_key: String in PersonalityHandler.AXIS_KEYS:
		var value: int = agent.get(axis_key)
		add_child(_make_axis_row(axis_key, value))


func _make_axis_row(axis_key: String, value: int) -> Control:
	var poles: Dictionary = PersonalityHandler.POLE_NAMES[axis_key]

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = axis_key.capitalize()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	header.add_child(name_lbl)

	# Shown as signed deviation from center (e.g. "+22"/"-30"/"0"), matching
	# the bar's own "0-50 in both directions" framing — the raw 0-100
	# storage value would read as inconsistent with a bar that's empty at
	# the middle rather than at zero.
	var value_lbl := Label.new()
	value_lbl.text = _format_deviation(value - 50)
	value_lbl.add_theme_font_size_override("font_size", 12)
	value_lbl.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68, 1.0))
	header.add_child(value_lbl)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	col.add_child(bar_row)

	var low_lbl := Label.new()
	low_lbl.text = poles["low"]
	low_lbl.custom_minimum_size.x = 88
	low_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	low_lbl.add_theme_font_size_override("font_size", 11)
	low_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	bar_row.add_child(low_lbl)

	bar_row.add_child(_make_bar(value))

	var high_lbl := Label.new()
	high_lbl.text = poles["high"]
	high_lbl.custom_minimum_size.x = 88
	high_lbl.add_theme_font_size_override("font_size", 11)
	high_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	bar_row.add_child(high_lbl)

	return col


## "+22" / "-30" / "0" — deviation is already value-50, so just needs an
## explicit "+" for the non-negative case (negative numbers already print
## their own "-" via %d).
func _format_deviation(deviation: int) -> String:
	if deviation > 0:
		return "+%d" % deviation
	return "%d" % deviation


## A fixed-width track with a center tick and a fill that grows from the
## middle toward whichever side `value` leans — never from the left edge
## the way a plain 0-100 bar would.
func _make_bar(value: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(BAR_W, BAR_H)

	var track := ColorRect.new()
	track.color = Color(0.15, 0.16, 0.2, 1.0)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(track)

	var half := BAR_W / 2.0
	var delta := value - 50
	var frac := clampf(absf(float(delta)) / 50.0, 0.0, 1.0)
	var fill_w := half * frac
	var fill_x := half if delta >= 0 else half - fill_w

	if fill_w > 0.0:
		var fill := ColorRect.new()
		fill.color = FILL_COLOR
		fill.position = Vector2(fill_x, 1.0)
		fill.size = Vector2(fill_w, BAR_H - 2.0)
		wrap.add_child(fill)

	# Drawn after the fill so it stays visible even at full deflection.
	var center_tick := ColorRect.new()
	center_tick.color = Color(0.4, 0.42, 0.48, 1.0)
	center_tick.position = Vector2(half - 1.0, 0.0)
	center_tick.size = Vector2(2.0, BAR_H)
	wrap.add_child(center_tick)

	return wrap
