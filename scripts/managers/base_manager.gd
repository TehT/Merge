extends Node
class_name BaseManager
## BaseManager — a persistent node in Main.tscn, referenced elsewhere via
## Game.base_manager (registers itself in _ready() — see game.gd; must be
## listed BEFORE TeamManager as a sibling, since TeamManager's starting
## team is placed at the primary base in its own _ready()). Owns every
## base/hideout — each with its own local vehicle fleet and base-local
## equipment (see BaseData) — plus the equipment usable from anywhere
## regardless of base.
##
## Seeds itself with HQ + one field base if left empty (two bases, to have
## a real second one for base/transport features to work against).
## Vehicles are exclusive per-base assets now (TravelRouter only ever
## searches a specific base's own `vehicles`, never a global pool — see
## TeamManager._pickup_vehicle/_release_vehicle for how a vehicle moves
## between a base and whichever team currently has it in transit).
## get_all_equipment() below is still a genuine pooled stand-in, though —
## there's no agent-to-base link for equipment the way travel routing now
## has for vehicles; see its own doc comment.

@export var bases: Array[BaseData] = []

## Equipment usable by any agent from any base, as opposed to a BaseData's
## own local_equipment. Empty by default; populate via the Inspector.
@export var global_equipment: Array[EquipmentData] = []

## Adds four temporary bases arranged specifically to stress-test the
## great-circle routing across geographic edge cases: two in Oceania
## bracketing the antimeridian (Suva ↔ Apia is a ~1200km hop the router
## should send across ±180° rather than the long way through 0°), and
## two in the high Arctic bracketing the pole (Svalbard ↔ Alert is a
## ~1250km hop the router should send over the pole rather than around
## it). Each also comes with a C-130J-A copy so the router has an
## actual TRANSPORT to use, and HQ gets a debug ultra-long-range
## GlobeHopper so a team based in Berlin can actually reach these test
## bases via a single relay hop without needing an intermediate real
## base built first. Off by default.
@export var spawn_stress_test_bases: bool = true

## Fires whenever transfer_equipment() actually moves something, so
## location-aware UI (EquipmentTab) knows to redraw.
signal equipment_changed()

func _ready() -> void:
	Game.base_manager = self
	if bases.is_empty():
		bases.append(_create_hq())
		bases.append(_create_east_coast_base())
		if spawn_stress_test_bases:
			_add_stress_test_bases()

func _create_hq() -> BaseData:
	var hq := BaseData.new().setup("HQ (Berlin, Germany)", Vector2(13.405, 52.52))
	hq.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres").duplicate(),
		preload("res://data/vehicles/x9_nightfall.tres"),
	]
	return hq

## Second base, purely so base/transport features (per-base fleets, fast
## travel between fixed bases, founding/upgrading additional bases — see
## GDD §12) have a real second base to work against instead of a
## hypothetical. Its own long-hauler (rather than a second Nightfall)
## gives each base a distinct fleet instead of a mirrored one. Its own
## Eurocopter is a .duplicate() of HQ's, not the same shared resource —
## vehicles are exclusive, physical-instance resources now (see
## TeamManager._pickup_vehicle/_release_vehicle): erasing one from a
## base's `vehicles` array wouldn't remove a second reference to the same
## object sitting in a different base's array too, so two bases can never
## share one vehicle instance, only the same *kind* of vehicle.
func _create_east_coast_base() -> BaseData:
	var base := BaseData.new().setup("Field Station (New York, USA)", Vector2(-74.006, 40.7128))
	base.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres").duplicate(),
		preload("res://data/vehicles/c130j_a.tres"),
	]
	return base


## Two paired test bases on either side of the antimeridian and two on
## either side of the north pole — see the doc comment on
## spawn_stress_test_bases above for exactly what these are testing.
## Also drops the debug GlobeHopper into HQ so Berlin can actually
## reach any of them in one relay hop for testing.
func _add_stress_test_bases() -> void:
	# Antimeridian pair: Suva and Apia sit ~1180km apart across the date
	# line — the router should pick the short crossing (±180°), not the
	# long way around through 0°.
	var suva := BaseData.new().setup("TEST — Suva (Fiji)", Vector2(178.4, -18.1))
	suva.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres").duplicate(),
		preload("res://data/vehicles/c130j_a.tres").duplicate(),
	]
	bases.append(suva)

	var apia := BaseData.new().setup("TEST — Apia (Samoa)", Vector2(-171.75, -13.8))
	apia.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres").duplicate(),
		preload("res://data/vehicles/c130j_a.tres").duplicate(),
	]
	bases.append(apia)

	# Polar pair: Svalbard and Alert sit ~1250km apart with the pole
	# between them — the router should pick the polar crossing, not a
	# ~15000km trip around the Arctic Circle.
	var svalbard := BaseData.new().setup("TEST — Longyearbyen (Svalbard)", Vector2(15.6, 78.2))
	svalbard.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres").duplicate(),
		preload("res://data/vehicles/c130j_a.tres").duplicate(),
	]
	bases.append(svalbard)

	var alert := BaseData.new().setup("TEST — Alert (Nunavut)", Vector2(-62.3, 82.5))
	alert.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres").duplicate(),
		preload("res://data/vehicles/c130j_a.tres").duplicate(),
	]
	bases.append(alert)

	# Give HQ a debug ultra-long-range Transport so Berlin can reach any
	# of the four test bases in a single relay hop for testing, without
	# first having to build a real Pacific or Arctic base to hop
	# through. Delete this + the flag once stress testing is done.
	var hopper: VehicleData = preload("res://data/vehicles/test_globehopper.tres").duplicate()
	bases[0].vehicles.append(hopper)

## The base new teams start at and travel returns to. Single-base stand-in
## for a real per-team home base — see class comment.
func get_primary_base() -> BaseData:
	return bases[0] if not bases.is_empty() else null

## Every equipment item available anywhere: global_equipment plus every
## base's local_equipment, pooled. Stand-in for filtering by which base an
## agent can actually reach — see class comment. Still used by agent/team
## equip-picking (slideout_view_equip_slot.gd), since there's no agent-to-
## base link yet to filter by; EquipmentTab uses get_equipment_by_location()
## below instead, now that its UI actually distinguishes where things are.
func get_all_equipment() -> Array[EquipmentData]:
	var out: Array[EquipmentData] = global_equipment.duplicate()
	for base: BaseData in bases:
		out.append_array(base.local_equipment)
	return out

## Every location equipment can live in: "Global" (org-wide, base_id "")
## plus one entry per base — {"label": String, "base_id": String}. Shared
## by get_equipment_by_location() and the transfer destination picker
## (SlideoutViewEquipment) so "what counts as a location" is defined once.
func get_all_locations() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"label": "Global", "base_id": ""}]
	for base: BaseData in bases:
		out.append({"label": base.base_name, "base_id": base.id})
	return out

## Every equipment item grouped by where it actually is, instead of pooled
## flat: one entry per non-empty location — {"label": String, "base_id":
## String, "items": Array[EquipmentData]}. First de-pooling step:
## EquipmentTab uses this to show equipment under the base it's actually
## at, rather than one location-blind list.
func get_equipment_by_location() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for loc: Dictionary in get_all_locations():
		var items = _equipment_list_for(loc["base_id"])
		if items != null and not items.is_empty():
			out.append({"label": loc["label"], "base_id": loc["base_id"], "items": items})
	return out

## Instant equipment transfer between two locations (a base's
## local_equipment, or "" for the org-wide global_equipment pool) — a
## stand-in for the eventual logistics system (aircraft or magical
## transport, presumably with real travel time and/or cost once that's
## built — see the GDD's base/vehicle-fleet roadmap items). "Instant" is
## deliberate scope for now, not an oversight. Returns true if item was
## actually found at from_base_id and moved.
func transfer_equipment(item: EquipmentData, from_base_id: String, to_base_id: String) -> bool:
	if from_base_id == to_base_id:
		return false

	var from_list = _equipment_list_for(from_base_id)
	var to_list = _equipment_list_for(to_base_id)
	if from_list == null or to_list == null:
		return false

	var idx: int = from_list.find(item)
	if idx == -1:
		return false
	from_list.remove_at(idx)
	to_list.append(item)
	equipment_changed.emit()
	return true

## Returns the actual Array[EquipmentData] backing one location (by
## reference — mutating it mutates the real field), or null if base_id
## doesn't resolve to global ("") or any known base.
func _equipment_list_for(base_id: String):
	if base_id == "":
		return global_equipment
	var base := get_base_by_id(base_id)
	return base.local_equipment if base else null

func get_base_by_id(base_id: String) -> BaseData:
	for base: BaseData in bases:
		if base.id == base_id:
			return base
	return null

## The base sitting at exactly this location, or null if nothing matches
## (e.g. a team out traveling or on-site at a mission, away from every
## base — nothing base-local is reachable there, by design). Used by
## TeamManager.get_agent_base() to resolve "where is this agent right
## now" down to a specific base for local-inventory filtering.
func get_base_at(location: Vector2) -> BaseData:
	for base: BaseData in bases:
		if base.location == location:
			return base
	return null

## The base nearest this location (straight-line haversine distance).
## Used by TeamManager.begin_return_travel() to pick a divert-to-nearest-
## base target when an agent came back injured/KIA, instead of routing
## all the way home. Returns null only if bases is empty.
func get_nearest_base(location: Vector2) -> BaseData:
	var best: BaseData = null
	var best_dist := INF
	for base: BaseData in bases:
		var d := GeoData.haversine_km(location.y, location.x, base.location.y, base.location.x)
		if d < best_dist:
			best_dist = d
			best = base
	return best
