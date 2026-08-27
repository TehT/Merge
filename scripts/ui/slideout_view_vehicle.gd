extends VBoxContainer
## SlideoutViewVehicle — full stat card for one fleet vehicle: image slot,
## mode, speed, range, capacity, operation cost, cooldown, description,
## plus a Relocate action for moving the vehicle to another base
## (instant, stand-in for a future in-world ferry — mirrors the
## Equipment popout's Transfer action).
##
## Layout lives in scenes/ui/views/slideout_vehicle.tscn (editable in
## the editor). Uses the shared %Header (slideout_header.tscn — title +
## ✕ button) and info_row instances for each stat; the cooldown row,
## the description block, and the Relocate section toggle visible per
## vehicle. Relocate is only shown when the caller passed the vehicle's
## current base id in `data` (a dict); when only the vehicle is passed
## (rare — no such caller today), Relocate stays hidden since there's
## no source base to move from.

var _vehicle: VehicleData
var _base_id: String = ""


func populate(data: Variant, on_close: Callable) -> void:
	# Accepts either {"vehicle": v, "base_id": id} — the current shape
	# from detail_view_hq — or a bare VehicleData for legacy/direct
	# callers. Only the dict shape enables the Relocate section.
	if data is Dictionary:
		_vehicle = data["vehicle"]
		_base_id = data.get("base_id", "")
	else:
		_vehicle = data
		_base_id = ""

	var v: VehicleData = _vehicle
	%Header.set_title(v.vehicle_name)
	%Header.close_requested.connect(on_close)

	_apply_image(v)

	%ModeRow.set_value(v.get_mode_name())

	if v.mode == VehicleData.Mode.TELEPORT:
		%SpeedRow.set_value("Instant")
	else:
		%SpeedRow.set_value("%d km/h" % int(round(v.speed_kmh)))

	%RangeRow.set_value("%d km" % int(v.max_range_km) if v.max_range_km > 0.0 else "Unlimited")
	%CapacityRow.set_value("%d agents" % v.capacity)
	%OperationCostRow.set_value("%d funding" % v.operation_cost if v.operation_cost > 0 else "None")

	if v.mode == VehicleData.Mode.TELEPORT and v.cooldown_days > 0:
		%CooldownRow.visible = true
		%CooldownRow.set_value("%d day(s)" % v.cooldown_days)

	if v.description != "":
		%Sep2.visible = true
		%Description.visible = true
		%Description.text = v.description

	_fill_relocate(on_close)


func _apply_image(v: VehicleData) -> void:
	var tex: Texture2D = load(v.image_path) if v.image_path != "" else null
	if tex:
		%ImageRect.texture = tex
		%ImageRect.visible = true
		%Placeholder.visible = false


## One destination row per other base (skips the vehicle's own current
## base). Each row shows distance + travel duration (or an out-of-range
## note in red) and disables the Send button when the vehicle can't
## reach — same range check begin_vehicle_transfer would apply, mirrored
## in the UI so the player can see why a destination isn't offered.
func _fill_relocate(on_close: Callable) -> void:
	if _base_id == "":
		return
	var others: Array[BaseData] = Game.base_manager.bases.filter(
			func(b: BaseData) -> bool: return b.id != _base_id)
	if others.is_empty():
		return

	%RelocateSep.visible = true
	%RelocateSection.visible = true
	var from_base := Game.base_manager.get_base_by_id(_base_id)
	for base: BaseData in others:
		%RelocateList.add_child(_make_destination_row(from_base, base, on_close))


func _make_destination_row(from_base: BaseData, dest: BaseData, on_close: Callable) -> Control:
	var distance := GeoData.haversine_km(from_base.location.y, from_base.location.x,
			dest.location.y, dest.location.x)
	var in_range := _vehicle.can_reach(distance)
	var has_facility := dest.supports(_vehicle)
	var can_send := in_range and has_facility
	var travel_hours := _vehicle.compute_travel_hours(distance)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	card.add_child(row)

	var lbl := Label.new()
	lbl.text = dest.base_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = "Send"
	btn.disabled = not can_send
	btn.focus_mode = Control.FOCUS_NONE
	if can_send:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func() -> void:
			var plan: Dictionary = Game.base_manager.begin_vehicle_transfer(
					_vehicle, _base_id, dest.id)
			if not plan.is_empty():
				on_close.call())
	row.add_child(btn)

	var info_lbl := Label.new()
	# Reason order: facility gate first (nothing else matters if it
	# can't land), then range. Range and facility are independent
	# constraints so both being wrong just reads as facility-first.
	if not has_facility:
		info_lbl.text = "no %s at destination" % _vehicle.get_facility_name()
		info_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	elif not in_range:
		info_lbl.text = "%d km  ·  out of range (max %d km)" % [
				int(round(distance)), int(_vehicle.max_range_km)]
		info_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 1.0))
	else:
		info_lbl.text = "%d km  ·  %s" % [
				int(round(distance)), VehicleData.format_duration(travel_hours)]
		info_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	info_lbl.add_theme_font_size_override("font_size", 11)
	card.add_child(info_lbl)

	return card
