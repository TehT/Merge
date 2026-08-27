extends "res://scripts/ui/detail_view_base.gd"
## DetailViewTravelConfirmation — the "Team Deployed" / "Team
## Transporting" en-route summary shown in the left detail panel right
## after a deploy or relocation click: status, per-leg route (if
## multi-leg), aggregate distance/time/arrival. Split off from the older
## combined detail_view_result.gd once each PanelHost view had a single
## populate() — see detail_view_mission_result.gd for the post-arrival
## report side.

func populate(data: Variant, on_close: Callable) -> void:
	var team_name: String = data["team_name"]
	var ev_title: String = data["ev_title"]
	var plan: Dictionary = data["plan"]
	var title: String = data.get("title", "Team Deployed")

	_add_title(title)
	_add_subtitle("%s  →  %s" % [team_name, ev_title], Color(0.55, 0.55, 0.6, 1.0))

	add_child(HSeparator.new())

	var status_lbl := Label.new()
	status_lbl.text = "En route"
	status_lbl.add_theme_font_size_override("font_size", 16)
	status_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 1.0))
	add_child(status_lbl)

	var arrival_time: float = plan.arrival_time
	var arrival_hour := int(fmod(arrival_time, 1.0) * 24.0)

	var legs: Array = plan.get("legs", [])
	if legs.size() > 1:
		add_child(HSeparator.new())
		_add_section("Route")
		for i in range(legs.size()):
			var leg: Dictionary = legs[i]
			add_child(_make_leg_row(i + 1, leg))

	_add_info_row("Distance", "%d km" % int(round(float(plan.distance_km))))
	_add_info_row("Travel Time", VehicleData.format_duration(plan.travel_hours))
	_add_info_row("Arriving", "Day %d, ~%02d:00" % [int(arrival_time), arrival_hour])

	add_child(HSeparator.new())
	_add_close_button(on_close)


## One leg of a multi-leg route: "1. From → To" (wrapped — a base's full
## name plus another's can run long, and this sidebar has a fixed width)
## on its own line, then a dimmer "duration via vehicle" line under it.
## _add_info_row's single-line label+value shape doesn't fit this; an
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
		VehicleData.format_duration(leg["travel_hours"]), (leg["vehicle"] as VehicleData).vehicle_name]
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.add_theme_font_size_override("font_size", 11)
	detail_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	col.add_child(detail_lbl)

	return col
