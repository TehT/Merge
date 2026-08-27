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

## Fires whenever any base's `vehicles` array changes — either a
## begin_vehicle_transfer() departure (vehicle removed from source)
## or a transit-arrival (vehicle added to destination). Kept separate
## from equipment_changed since neither triggers the other, and their
## listeners are different views. Fired for team pickups/releases too
## via TeamManager, if you extend those to emit it.
signal vehicles_changed()

## Fired when a vehicle-only transfer actually starts (source removed,
## in_transit_vehicles appended) so log/UI can react to the departure
## specifically, distinct from the generic vehicles_changed.
signal vehicle_transfer_started(vehicle: VehicleData, from_base_id: String, to_base_id: String, arrival_day: float)

## Fired when a vehicle-only transfer's arrival day is reached and the
## vehicle lands in the destination base's fleet.
signal vehicle_transfer_completed(vehicle: VehicleData, to_base_id: String)

## Fired when a mobile base sets sail for a new location — kicks off
## the visualization (TravelPathLayer draws the base's own path) and
## event log entry.
signal base_relocation_started(base: BaseData)

## Fired when a mobile base arrives at its target — same as
## _started but on completion.
signal base_relocation_completed(base: BaseData)

## Fired every frame that a mobile base's `location` changes while
## relocating — MarkerLayer subscribes so the base's map marker
## follows the ship rather than staying frozen at the departure port.
signal base_moved(base: BaseData)

## Vehicles currently ferrying themselves between bases without a team
## on board — each entry is {vehicle, from_base_id, to_base_id,
## departure_day, arrival_day, distance_km, travel_hours}. Separate
## from any team's `current_vehicle` (which represents in-transit
## possession by a squad); this list is empty-cabin logistics only.
var in_transit_vehicles: Array[Dictionary] = []

func _ready() -> void:
	Game.base_manager = self
	if bases.is_empty():
		bases.append(_create_hq())
		bases.append(_create_east_coast_base())
		bases.append(_create_falkor_too())
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


## Research vessel "Falkor Too" — first mobile base. Starts in
## international waters between Hawaii and the Line Islands. Ships at
## ~10 knots (18.52 km/h — midpoint of the real Falkor's 8.5kt cruise
## and 13kt top speed, matching what the player asked for). Has a
## helipad, no airfield — helicopters can land/refuel here, planes
## can't. Starting fleet is one Eurocopter, which sails with the ship
## as base.vehicles moves with base.
func _create_falkor_too() -> BaseData:
	var ship := BaseData.new().setup("RV Falkor Too", Vector2(-160.0, -5.0))
	ship.is_mobile = true
	ship.cruise_speed_kmh = 18.52
	ship.has_helipad = true
	ship.has_airfield = false
	ship.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres").duplicate(),
	]
	return ship


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

## Kicks off an empty-cabin ferry of `vehicle` from one base's fleet
## to another. Unlike transfer_equipment (instant logistics stand-in),
## a vehicle transfer takes real travel time — the vehicle leaves the
## source base immediately (removed from its `vehicles`), sits in
## in_transit_vehicles for compute_travel_hours() hours, and lands in
## the destination base's `vehicles` at arrival_day. Refuses if:
##  - from and to are the same base
##  - the vehicle isn't currently at from_base (someone else has it —
##    a team currently in transit erases it from its base's fleet via
##    TeamManager's possession model, or it's already ferrying itself)
##  - the vehicle's max_range_km can't cover the great-circle distance
## Returns the transit entry on success (matching in_transit_vehicles'
## shape so the caller can display the arrival time), or {} on
## failure so the caller can distinguish success without re-checking
## every condition.
func begin_vehicle_transfer(vehicle: VehicleData, from_base_id: String, to_base_id: String) -> Dictionary:
	if from_base_id == to_base_id:
		return {}
	var from_base := get_base_by_id(from_base_id)
	var to_base := get_base_by_id(to_base_id)
	if from_base == null or to_base == null:
		return {}

	var idx: int = from_base.vehicles.find(vehicle)
	if idx == -1:
		return {}

	var distance := GeoData.haversine_km(from_base.location.y, from_base.location.x,
			to_base.location.y, to_base.location.x)
	if not vehicle.can_reach(distance):
		return {}

	var travel_hours := vehicle.compute_travel_hours(distance)
	var now: float = Game.game_clock.get_current_time_days()
	var arrival_day := now + travel_hours / 24.0

	from_base.vehicles.remove_at(idx)
	var entry := {
		"vehicle": vehicle,
		"from_base_id": from_base_id,
		"to_base_id": to_base_id,
		"departure_day": now,
		"arrival_day": arrival_day,
		"distance_km": distance,
		"travel_hours": travel_hours,
	}
	in_transit_vehicles.append(entry)

	vehicles_changed.emit()
	vehicle_transfer_started.emit(vehicle, from_base_id, to_base_id, arrival_day)
	print("[BaseManager] %s ferrying %s → %s (%s)" % [
			vehicle.vehicle_name, from_base.base_name, to_base.base_name,
			VehicleData.format_duration(travel_hours)])
	return entry


## Every-frame arrival check — same pattern TeamManager uses for team
## travel. Iterates back-to-front so removing mid-loop doesn't skip
## entries. Also advances any mobile base that's currently relocating.
func _process(_delta: float) -> void:
	var now: float = Game.game_clock.get_current_time_days()

	for i in range(in_transit_vehicles.size() - 1, -1, -1):
		var entry: Dictionary = in_transit_vehicles[i]
		if now >= entry.arrival_day:
			_complete_vehicle_transfer(i)

	for base: BaseData in bases:
		if not base.is_relocating:
			continue
		if now >= base.travel_arrival_day:
			_complete_base_relocation(base)
		else:
			# Recompute along the great-circle each frame — cheap
			# (asin + atan2) and matches TravelPathLayer's own slerp
			# so line + marker stay glued together visually.
			base.location = base.location_at(now)
			base_moved.emit(base)


func _complete_vehicle_transfer(idx: int) -> void:
	var entry: Dictionary = in_transit_vehicles[idx]
	in_transit_vehicles.remove_at(idx)
	var to_base := get_base_by_id(entry.to_base_id)
	if to_base != null:
		to_base.vehicles.append(entry.vehicle)
	vehicles_changed.emit()
	vehicle_transfer_completed.emit(entry.vehicle, entry.to_base_id)
	print("[BaseManager] %s arrived at %s" % [
			(entry.vehicle as VehicleData).vehicle_name,
			to_base.base_name if to_base else "?"])


## Public entry point for the "click Relocate on a ship's detail
## sheet" flow. Validates that this base actually can relocate
## (is_mobile + cruise_speed_kmh > 0), delegates the state setup to
## BaseData.begin_relocation, fires signals so path visuals and event
## log kick in. Returns true on success. UI upstream is responsible
## for the destination-picker (map click on a sea tile).
func begin_base_relocation(base: BaseData, destination: Vector2, destination_name: String) -> bool:
	if not base.is_mobile:
		push_warning("[BaseManager] begin_base_relocation: %s isn't a mobile base." % base.base_name)
		return false
	if base.cruise_speed_kmh <= 0.0:
		push_warning("[BaseManager] begin_base_relocation: %s has no cruise speed set." % base.base_name)
		return false
	if base.is_relocating:
		# For MVP we don't allow retargeting mid-voyage; the ship
		# finishes its current leg first. The picker UI grays out
		# Relocate while is_relocating is true, so this is a
		# double-check rather than a user-facing error path.
		push_warning("[BaseManager] begin_base_relocation: %s is already underway." % base.base_name)
		return false

	base.begin_relocation(destination, destination_name, Game.game_clock.get_current_time_days())
	base_relocation_started.emit(base)
	print("[BaseManager] %s setting course for %s (%s)" % [
			base.base_name, destination_name,
			VehicleData.format_duration((base.travel_arrival_day - base.travel_departure_day) * 24.0)])
	return true


func _complete_base_relocation(base: BaseData) -> void:
	base.location = base.travel_destination
	var dest_name := base.travel_destination_name
	base.complete_relocation()
	base_moved.emit(base)
	base_relocation_completed.emit(base)
	print("[BaseManager] %s moored at %s" % [base.base_name, dest_name])


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
