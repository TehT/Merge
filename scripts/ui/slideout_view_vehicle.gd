extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewVehicle — full stat card for one fleet vehicle: image slot,
## mode, speed, range, capacity, operation cost, cooldown, description.

func populate(data: Variant, on_close: Callable) -> void:
	var v: VehicleData = data
	var accent := Color(0.5, 0.6, 0.8, 1.0)

	_add_header(v.vehicle_name, on_close, accent, 15)

	add_child(_make_vehicle_image(v))

	add_child(HSeparator.new())

	_add_vehicle_stat("Mode", v.get_mode_name())
	if v.mode == VehicleData.Mode.TELEPORT:
		_add_vehicle_stat("Speed", "Instant")
	else:
		_add_vehicle_stat("Speed", "%d km/h" % int(round(v.speed_kmh)))
	_add_vehicle_stat("Range", "%d km" % int(v.max_range_km) if v.max_range_km > 0.0 else "Unlimited")
	_add_vehicle_stat("Capacity", "%d agents" % v.capacity)
	_add_vehicle_stat("Operation Cost", "%d funding" % v.operation_cost if v.operation_cost > 0 else "None")
	if v.mode == VehicleData.Mode.TELEPORT and v.cooldown_days > 0:
		_add_vehicle_stat("Cooldown", "%d day(s)" % v.cooldown_days)

	if v.description != "":
		add_child(HSeparator.new())
		var desc := Label.new()
		desc.text = v.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
		add_child(desc)


func _make_vehicle_image(v: VehicleData) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	style.border_color = Color(0.2, 0.22, 0.28, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(0, 120)

	var tex: Texture2D = load(v.image_path) if v.image_path != "" else null
	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.add_child(rect)
	else:
		var placeholder := Label.new()
		placeholder.text = "No image yet"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 1.0))
		frame.add_child(placeholder)

	return frame


func _add_vehicle_stat(label: String, value: String) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	row.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)

	add_child(row)
