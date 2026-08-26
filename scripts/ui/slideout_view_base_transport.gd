extends "res://scripts/ui/slideout_view_base.gd"
## SlideoutViewBaseTransport — relocate a team to a different base,
## possibly via relay bases: pick a destination base, see every viable
## route there (direct or relayed, via TravelRouter, ranked fastest
## first, auto-selects the fastest but overridable), and confirm. Opened
## by clicking a stationary team's Location row on its detail sheet.
## Mirrors SlideoutViewDeploy's shape, but for
## TeamManager.begin_base_transfer_route() instead of a mission
## deployment — only one team to consider (whichever page this was
## opened from) and the destination is a base picker instead of fixed to
## one event.

var _team: TeamData
var _destination_dropdown: OptionButton
var _route_dropdown: OptionButton
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
	_destination_dropdown.clip_text = true
	for i in range(destinations.size()):
		_destination_dropdown.add_item(destinations[i].base_name)
		_destination_dropdown.set_item_metadata(i, destinations[i])
	_destination_dropdown.item_selected.connect(func(_idx: int) -> void: _refresh_options())
	add_child(_destination_dropdown)

	_travel_lbl = Label.new()
	_travel_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_travel_lbl.add_theme_font_size_override("font_size", 11)
	_travel_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	add_child(_travel_lbl)

	_route_dropdown = OptionButton.new()
	_route_dropdown.focus_mode = Control.FOCUS_NONE
	_route_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_dropdown.clip_text = true  # long route descriptions must truncate, not force the panel wider -- see the matching note in slideout_view_deploy.gd
	_route_dropdown.item_selected.connect(func(_idx: int) -> void: _update_travel_label())
	add_child(_route_dropdown)

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


## Rebuilds the route dropdown for whichever destination is now selected —
## every viable route TravelRouter finds, ranked fastest first (item 0
## pre-selected), same pattern as SlideoutViewDeploy's route dropdown.
func _refresh_options() -> void:
	var dest := _current_destination()
	var team_size := _team.member_ids.size()

	_route_dropdown.clear()
	var routes: Array = TravelRouter.find_routes(_team.location, _team.location_name,
			dest.location, dest.base_name, team_size, VehicleData.Role.TRANSPORT,
			Game.base_manager.bases, _team.current_vehicle)
	for i in range(routes.size()):
		var route: Array = routes[i]
		_route_dropdown.add_item(TravelRouter.describe(route))
		_route_dropdown.set_item_metadata(i, route)
	if routes.size() > 0:
		_route_dropdown.select(0)

	_update_travel_label()


func _update_travel_label() -> void:
	var dest := _current_destination()
	var route: Array = _route_dropdown.get_item_metadata(_route_dropdown.get_selected()) \
			if _route_dropdown.item_count > 0 else []

	if route.is_empty():
		var distance := GeoData.haversine_km(_team.location.y, _team.location.x, dest.location.y, dest.location.x)
		_travel_lbl.text = "%d km — no Transport route reaches this" % int(round(distance))
		_confirm_btn.disabled = true
		return

	_travel_lbl.text = "%d km — %s" % [
		int(round(TravelRouter.total_distance_km(route))), TravelRouter.describe(route)]
	_confirm_btn.disabled = false


func _on_transport_pressed(on_close: Callable) -> void:
	var dest := _current_destination()
	var selected_route: Array = _route_dropdown.get_item_metadata(_route_dropdown.get_selected())
	var plan: Dictionary = Game.team_manager.begin_base_transfer_route(_team.id, selected_route)
	if plan.is_empty():
		return
	var team_name := _team.team_name
	on_close.call()
	Game.detail_sidebar.show_travel_confirmation(team_name, dest.base_name, plan, "Team Transporting")
