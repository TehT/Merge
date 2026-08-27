extends "res://scripts/ui/detail_view_base.gd"
## DetailViewTravelConfirmation — the "Team Deployed" / "Team
## Transporting" en-route summary shown in the left detail panel right
## after a deploy or relocation click: status, per-leg route (if
## multi-leg), aggregate distance/time/arrival.
##
## Layout lives in scenes/ui/views/detail_travel_confirmation.tscn
## (editable in the editor). Per-leg route rows are built dynamically
## into %RouteList — each leg is a wrapped two-line shape that
## info_row's single-line label+value can't represent, so it stays in
## code as _make_leg_row().


func populate(data: Variant, on_close: Callable) -> void:
	var team_name: String = data["team_name"]
	var ev_title: String = data["ev_title"]
	var plan: Dictionary = data["plan"]
	var title: String = data.get("title", "Team Deployed")

	%Title.text = title
	%Subtitle.text = "%s  →  %s" % [team_name, ev_title]

	var arrival_time: float = plan.arrival_time
	var arrival_hour := int(fmod(arrival_time, 1.0) * 24.0)

	_fill_route(plan.get("legs", []))

	%DistanceRow.set_value("%d km" % int(round(float(plan.distance_km))))
	%TravelTimeRow.set_value(VehicleData.format_duration(plan.travel_hours))
	%ArrivingRow.set_value("Day %d, ~%02d:00" % [int(arrival_time), arrival_hour])

	# Base transport passes the team along in data so Close can route
	# back to the team's own detail sheet — the user was just looking at
	# it to open the transport picker, so returning there beats going to
	# the empty state. Mission deploys don't pass a team, and fall through
	# to the standard dismiss (empty view).
	if data.has("team"):
		var team: TeamData = data["team"]
		%CloseButton.pressed.connect(func() -> void:
				Game.left_detail.show_view("team", team))
	else:
		%CloseButton.pressed.connect(on_close)


func _fill_route(legs: Array) -> void:
	var multi_leg := legs.size() > 1
	%RouteSep.visible = multi_leg
	%RouteSection.visible = multi_leg
	for child in %RouteList.get_children():
		child.queue_free()
	if not multi_leg:
		return
	for i in range(legs.size()):
		var leg: Dictionary = legs[i]
		%RouteList.add_child(_make_leg_row(i + 1, leg))


## One leg of a multi-leg route: "1. From → To" (wrapped — a base's full
## name plus another's can run long, and this sidebar has a fixed width)
## on its own line, then a dimmer "duration via vehicle" line under it.
## info_row's single-line label+value shape doesn't fit this; an
## unwrapped long label there was exactly what pushed the sidebar wider
## than its intended width in the first place.
func _make_leg_row(index: int, leg: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)

	var route_lbl := Label.new()
	route_lbl.text = "%d. %s → %s" % [index, leg["from_name"], leg["to_name"]]
	route_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(route_lbl)

	var detail_lbl := Label.new()
	detail_lbl.text = "%s via %s" % [
			VehicleData.format_duration(leg["travel_hours"]),
			(leg["vehicle"] as VehicleData).vehicle_name]
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.add_theme_font_size_override("font_size", 11)
	detail_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	col.add_child(detail_lbl)

	return col
