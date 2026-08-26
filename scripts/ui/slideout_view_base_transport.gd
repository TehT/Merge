extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewBaseTransport — relocate a team to a different base via a
## TRANSPORT-role vehicle: pick a destination base, see distance/travel
## time, pick an aircraft (auto-selects the best fit, overridable), and
## confirm. Opened by clicking a stationary team's Location row on its
## detail sheet. Mirrors SlideoutViewDeploy's shape, but for
## TeamManager.begin_base_transfer() instead of a mission deployment —
## only one team to consider (whichever page this was opened from) and
## the destination is a base picker instead of fixed to one event.

var _team: TeamData
var _destination_dropdown: OptionButton
var _vehicle_dropdown: OptionButton
var _travel_lbl: Label
var _confirm_btn: Button


func populate(team: TeamData, on_close: Callable) -> void:
	_team = team

	_add_header("Transport: %s" % team.team_name, on_close)

	var subtitle := Label.new()
	subtitle.text = "Currently at %s" % team.location_name
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1.0))
	add_child(subtitle)

	add_child(HSeparator.new())

	var destinations: Array[BaseData] = Game.base_manager.bases.filter(
		func(b: BaseData) -> bool: return b.location != team.location)

	if destinations.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No other bases to transport to."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(none_lbl)
		return

	_destination_dropdown = OptionButton.new()
	_destination_dropdown.focus_mode = Control.FOCUS_NONE
	_destination_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(destinations.size()):
		_destination_dropdown.add_item(destinations[i].base_name)
		_destination_dropdown.set_item_metadata(i, destinations[i])
	_destination_dropdown.item_selected.connect(func(_idx: int) -> void: _refresh_options())
	add_child(_destination_dropdown)

	_travel_lbl = Label.new()
	_travel_lbl.add_theme_font_size_override("font_size", 11)
	_travel_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	add_child(_travel_lbl)

	_vehicle_dropdown = OptionButton.new()
	_vehicle_dropdown.focus_mode = Control.FOCUS_NONE
	_vehicle_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicle_dropdown.item_selected.connect(func(_idx: int) -> void: _update_travel_label())
	add_child(_vehicle_dropdown)

	add_child(HSeparator.new())

	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Transport"
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_confirm_btn.pressed.connect(_on_transport_pressed.bind(on_close))
	row.add_child(_confirm_btn)
	add_child(row)

	_refresh_options()


func _current_destination() -> BaseData:
	return _destination_dropdown.get_item_metadata(_destination_dropdown.get_selected())


## Rebuilds the vehicle dropdown for whichever destination is now
## selected — eligible Transport vehicles selectable (best fit
## pre-picked), ineligible ones shown disabled with why, same pattern as
## SlideoutViewDeploy's vehicle dropdown.
func _refresh_options() -> void:
	var dest := _current_destination()
	var distance := GeoData.haversine_km(_team.location.y, _team.location.x, dest.location.y, dest.location.x)
	var team_size := _team.member_ids.size()

	_vehicle_dropdown.clear()
	var fleet: Array[VehicleData] = Game.base_manager.get_all_vehicles().filter(
		func(v: VehicleData) -> bool: return v.role == VehicleData.Role.TRANSPORT)
	var best := Game.team_manager.get_best_vehicle(distance, team_size, VehicleData.Role.TRANSPORT)
	var default_idx := 0
	for i in range(fleet.size()):
		var v: VehicleData = fleet[i]
		var eligible := v.can_reach(distance) and v.can_carry(team_size)
		var label := v.vehicle_name
		if not eligible:
			label += " — out of range" if not v.can_reach(distance) else " — over capacity"
		_vehicle_dropdown.add_item(label)
		_vehicle_dropdown.set_item_metadata(i, v)
		_vehicle_dropdown.set_item_disabled(i, not eligible)
		if v == best:
			default_idx = i
	if fleet.size() > 0:
		_vehicle_dropdown.select(default_idx)

	_update_travel_label()


func _update_travel_label() -> void:
	var dest := _current_destination()
	var distance := GeoData.haversine_km(_team.location.y, _team.location.x, dest.location.y, dest.location.x)
	var vehicle: VehicleData = _vehicle_dropdown.get_item_metadata(_vehicle_dropdown.get_selected()) \
			if _vehicle_dropdown.item_count > 0 else null

	if vehicle == null:
		_travel_lbl.text = "%d km — no Transport vehicle can reach this" % int(round(distance))
		_confirm_btn.disabled = true
		return

	var hours := vehicle.compute_travel_hours(distance)
	_travel_lbl.text = "%d km — ~%s via %s" % [
		int(round(distance)), VehicleData.format_duration(hours), vehicle.vehicle_name]
	_confirm_btn.disabled = not vehicle.can_reach(distance) or not vehicle.can_carry(_team.member_ids.size())


func _on_transport_pressed(on_close: Callable) -> void:
	var dest := _current_destination()
	var vehicle: VehicleData = _vehicle_dropdown.get_item_metadata(_vehicle_dropdown.get_selected())
	var plan: Dictionary = Game.team_manager.begin_base_transfer(_team.id, dest, vehicle)
	if plan.is_empty():
		return
	var team_name := _team.team_name
	on_close.call()
	Game.detail_sidebar.show_travel_confirmation(team_name, dest.base_name, plan, "Team Transporting")
