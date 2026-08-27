extends VBoxContainer
## SlideoutViewVehicle — full stat card for one fleet vehicle: image slot,
## mode, speed, range, capacity, operation cost, cooldown, description.
##
## Layout lives in scenes/ui/views/slideout_vehicle.tscn (editable in
## the editor). Uses the shared %Header (slideout_header.tscn — title +
## ✕ button) and info_row instances for each stat; the cooldown row +
## the description block toggle visible per vehicle.

func populate(data: Variant, on_close: Callable) -> void:
	var v: VehicleData = data

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


func _apply_image(v: VehicleData) -> void:
	var tex: Texture2D = load(v.image_path) if v.image_path != "" else null
	if tex:
		%ImageRect.texture = tex
		%ImageRect.visible = true
		%Placeholder.visible = false
