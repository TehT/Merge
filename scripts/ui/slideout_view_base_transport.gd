extends VBoxContainer
## SlideoutViewBaseTransport — relocate a team to a different base,
## possibly via relay bases: pick a destination base, see every viable
## route there (direct or relayed, via TravelRouter, ranked fastest
## first, auto-selects the fastest but overridable), and confirm.
## Opened by clicking a stationary team's Location row on its detail
## sheet. Mirrors SlideoutViewDeploy's shape, but for
## TeamManager.begin_base_transfer_route() instead of a mission
## deployment — only one team to consider (whichever page this was
## opened from) and the destination is a base picker instead of fixed
## to one event.
##
## Layout lives in scenes/ui/views/slideout_base_transport.tscn
## (editable in the editor). The two dropdowns + travel label + confirm
## button are all direct scene nodes; the script only fills the
## destination options and reacts to selection changes.

var _team: TeamData


func populate(data: Variant, on_close: Callable) -> void:
	_team = data

	%Header.set_title("Transport: %s" % _team.team_name)
	%Header.close_requested.connect(on_close)
	%Subtitle.text = "Currently at %s" % _team.location_name

	var destinations: Array[BaseData] = Game.base_manager.bases.filter(
			func(b: BaseData) -> bool: return b.location != _team.location)

	if destinations.is_empty():
		%EmptyLabel.visible = true
		%DestinationDropdown.visible = false
		%TravelLine.visible = false
		%RouteDropdown.visible = false
		%Sep2.visible = false
		%ConfirmBtn.get_parent().visible = false
		return

	for i in range(destinations.size()):
		%DestinationDropdown.add_item(destinations[i].base_name)
		%DestinationDropdown.set_item_metadata(i, destinations[i])
	%DestinationDropdown.item_selected.connect(func(_idx: int) -> void: _refresh_routes())
	%RouteDropdown.item_selected.connect(func(_idx: int) -> void: _update_travel_label())
	%ConfirmBtn.pressed.connect(_on_transport_pressed.bind(on_close))

	_refresh_routes()


func _current_destination() -> BaseData:
	return %DestinationDropdown.get_item_metadata(%DestinationDropdown.get_selected())


## Rebuilds the route dropdown for whichever destination is now selected
## — every viable route TravelRouter finds, ranked fastest first (item 0
## pre-selected), same pattern as SlideoutViewDeploy's route dropdown.
func _refresh_routes() -> void:
	var dest := _current_destination()
	var team_size := _team.member_ids.size()

	%RouteDropdown.clear()
	var routes: Array = TravelRouter.find_routes(_team.location, _team.location_name,
			dest.location, dest.base_name, team_size, VehicleData.Role.TRANSPORT,
			Game.base_manager.bases, _team.current_vehicle)
	for i in range(routes.size()):
		var route: Array = routes[i]
		%RouteDropdown.add_item(TravelRouter.describe(route))
		%RouteDropdown.set_item_metadata(i, route)
	if routes.size() > 0:
		%RouteDropdown.select(0)

	_update_travel_label()


func _update_travel_label() -> void:
	var dest := _current_destination()
	var route: Array = %RouteDropdown.get_item_metadata(%RouteDropdown.get_selected()) \
			if %RouteDropdown.item_count > 0 else []

	if route.is_empty():
		var distance := GeoData.haversine_km(_team.location.y, _team.location.x,
				dest.location.y, dest.location.x)
		%TravelLine.text = "%d km — no Transport route reaches this" % int(round(distance))
		%ConfirmBtn.disabled = true
		return

	%TravelLine.text = "%d km — %s" % [
			int(round(TravelRouter.total_distance_km(route))), TravelRouter.describe(route)]
	%ConfirmBtn.disabled = false


func _on_transport_pressed(on_close: Callable) -> void:
	var dest := _current_destination()
	var selected_route: Array = %RouteDropdown.get_item_metadata(%RouteDropdown.get_selected())
	var plan: Dictionary = Game.team_manager.begin_base_transfer_route(_team.id, selected_route)
	if plan.is_empty():
		return
	var team_name := _team.team_name
	on_close.call()
	Game.left_detail.show_view("travel_confirmation",
			{"team_name": team_name, "ev_title": dest.base_name, "plan": plan,
			"title": "Team Transporting", "team": _team})
