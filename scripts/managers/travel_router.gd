## TravelRouter — plans a team's journey from one location to another,
## chaining multiple vehicles when no single one covers the whole
## distance: a Transport hop (or several) between bases, then a final
## hop of whatever role the trip actually needs (TACTICAL to reach a
## mission, TRANSPORT to reach a base). Pure and Game-free — bases are
## passed in explicitly rather than read from Game.base_manager, so this
## is reliably isolated-testable via --script (unlike the Node-based
## managers that consume it).
##
## Vehicles are never pooled globally: a candidate for a leg departing
## some base comes only from that base's own `vehicles` array (mirroring
## reality — a plane can't fly out of a base it isn't parked at), plus
## `held_vehicle` for the very first leg only, representing a vehicle the
## team already has with them (e.g. resuming a return trip from a mission
## site, which owns no fleet of its own). See TeamManager._pickup_vehicle/
## _release_vehicle for how execution keeps this consistent — a vehicle in
## transit is attached to exactly one team and isn't sitting in any base's
## array for a different team's search to find.
class_name TravelRouter
extends RefCounted

## Cap on relay hops before the final leg. Bases will stay in the single
## digits for a long time, so a bounded DFS enumeration of simple paths
## is simpler and more transparent than a real k-shortest-paths
## algorithm, and cheap enough at this scale.
const MAX_RELAY_HOPS := 3


## Every viable route from start_location to target_location, ranked
## fastest (lowest total travel_hours) first. Each route is an Array of
## leg dicts: {"vehicle": VehicleData, "from": Vector2, "from_name":
## String, "to": Vector2, "to_name": String, "distance_km": float,
## "travel_hours": float}. Every leg except the last is always a
## TRANSPORT hop between two bases; the last leg uses final_role
## (TACTICAL for a mission deploy, TRANSPORT for a relocation or a
## return trip).
##
## held_vehicle is only meaningful for the very first leg — a vehicle the
## team already physically has with them right now (e.g. resuming a
## return trip from a mission site, which owns no fleet of its own to
## draw from otherwise). It's checked purely on capability (range/
## capacity), ignoring its own role: it isn't a planned choice from a
## category the way a base's fleet vehicles are, it's just what's on
## hand. Every leg after the first is chosen fresh from whichever base it
## departs, under the normal role rules. Returns [] if nothing reaches
## the target at all.
static func find_routes(start_location: Vector2, start_name: String,
		target_location: Vector2, target_name: String, team_size: int,
		final_role: VehicleData.Role, bases: Array[BaseData], held_vehicle: VehicleData = null,
		max_results: int = 5) -> Array:
	var routes: Array = []
	var visited: Dictionary = {}
	var start_available: Array[VehicleData] = []
	for base: BaseData in bases:
		if base.location == start_location:
			visited[base.id] = true  # never usefully hop back through the start
			start_available.append_array(base.vehicles)

	_search(start_location, start_name, [], target_location, target_name,
			team_size, final_role, bases, visited, 0, start_available, held_vehicle, routes)

	routes.sort_custom(func(a: Array, b: Array) -> bool: return total_hours(a) < total_hours(b))
	if routes.size() > max_results:
		routes.resize(max_results)
	return routes


static func _search(current: Vector2, current_name: String, legs_so_far: Array,
		target: Vector2, target_name: String, team_size: int, final_role: VehicleData.Role,
		bases: Array[BaseData], visited: Dictionary, depth: int,
		available_vehicles: Array[VehicleData], held_vehicle: VehicleData, routes_out: Array) -> void:
	var dist_to_target := _haversine_km(current.y, current.x, target.y, target.x)
	var final_vehicle := pick_best_vehicle(dist_to_target, team_size, final_role, available_vehicles)
	final_vehicle = _prefer_held(final_vehicle, held_vehicle, depth, dist_to_target, team_size)
	if final_vehicle != null:
		var complete: Array = legs_so_far + [_make_leg(
				final_vehicle, current, current_name, target, target_name, dist_to_target)]
		routes_out.append(complete)

	if depth >= MAX_RELAY_HOPS:
		return

	for base: BaseData in bases:
		if visited.has(base.id) or base.location == current:
			continue
		var dist := _haversine_km(current.y, current.x, base.location.y, base.location.x)
		var relay_vehicle := pick_best_vehicle(dist, team_size, VehicleData.Role.TRANSPORT, available_vehicles)
		relay_vehicle = _prefer_held(relay_vehicle, held_vehicle, depth, dist, team_size)
		if relay_vehicle == null:
			continue

		visited[base.id] = true
		var extended: Array = legs_so_far + [_make_leg(
				relay_vehicle, current, current_name, base.location, base.base_name, dist)]
		# From the relay base onward, only ITS OWN fleet is available —
		# execution drops the vehicle off there on arrival (see
		# TeamManager._complete_travel), so the next leg picks fresh from
		# whatever's actually parked at this base, same as reality. The
		# held vehicle no longer applies past the first leg either way.
		_search(base.location, base.base_name, extended, target, target_name,
				team_size, final_role, bases, visited, depth + 1, base.vehicles, null, routes_out)
		visited.erase(base.id)


## At depth 0 only, lets a role-filtered pick (which may be null) be
## overridden by held_vehicle if it can physically make this specific hop
## and is at least as fast — held_vehicle bypasses the role check
## entirely, per find_routes's docs.
static func _prefer_held(current_best: VehicleData, held_vehicle: VehicleData, depth: int,
		distance_km: float, team_size: int) -> VehicleData:
	if depth != 0 or held_vehicle == null:
		return current_best
	if not held_vehicle.can_reach(distance_km) or not held_vehicle.can_carry(team_size):
		return current_best
	if current_best == null or held_vehicle.compute_travel_hours(distance_km) < current_best.compute_travel_hours(distance_km):
		return held_vehicle
	return current_best


## Duplicates GeoData.haversine_km's exact math rather than calling it —
## GeoData.gd references the Game autoload elsewhere in its own body, so
## depending on it would make this whole module fail to compile in
## isolated --script tests (confirmed: any script that even transitively
## references Game can't compile there — see this project's testing-
## workflow memory). This keeps TravelRouter genuinely Game-free.
static func _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var r := 6371.0
	var dlat := deg_to_rad(lat2 - lat1)
	var dlon := deg_to_rad(lon2 - lon1)
	var a := sin(dlat / 2.0) * sin(dlat / 2.0) + \
			cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * \
			sin(dlon / 2.0) * sin(dlon / 2.0)
	var c := 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return r * c


static func _make_leg(vehicle: VehicleData, from: Vector2, from_name: String,
		to: Vector2, to_name: String, distance_km: float) -> Dictionary:
	return {
		"vehicle": vehicle, "from": from, "from_name": from_name,
		"to": to, "to_name": to_name, "distance_km": distance_km,
		"travel_hours": vehicle.compute_travel_hours(distance_km),
	}


## The fastest vehicle of `role` that can reach distance_km and carry
## team_size, tie-broken by lowest operation_cost. Used by the relay
## search above for both relay hops and the final leg.
static func pick_best_vehicle(distance_km: float, team_size: int,
		role: VehicleData.Role, vehicles: Array[VehicleData]) -> VehicleData:
	var best: VehicleData = null
	var best_hours := INF
	for v: VehicleData in vehicles:
		if v.role != role:
			continue
		if not v.can_reach(distance_km) or not v.can_carry(team_size):
			continue
		var hours := v.compute_travel_hours(distance_km)
		if best == null or hours < best_hours or (hours == best_hours and v.operation_cost < best.operation_cost):
			best = v
			best_hours = hours
	return best


static func total_hours(route: Array) -> float:
	var total := 0.0
	for leg: Dictionary in route:
		total += leg["travel_hours"]
	return total


static func total_distance_km(route: Array) -> float:
	var total := 0.0
	for leg: Dictionary in route:
		total += leg["distance_km"]
	return total


## "Direct via <vehicle> — <Xh>" for a 1-leg route; "Via <relay bases> —
## <vehicle names> — <Xh total>" for a multi-leg one.
static func describe(route: Array) -> String:
	if route.size() == 1:
		var leg: Dictionary = route[0]
		return "Direct via %s — %s" % [
			(leg["vehicle"] as VehicleData).vehicle_name, VehicleData.format_duration(leg["travel_hours"])]

	var relays: PackedStringArray = []
	var vehicle_names: PackedStringArray = []
	for i in range(route.size()):
		var leg: Dictionary = route[i]
		vehicle_names.append((leg["vehicle"] as VehicleData).vehicle_name)
		if i < route.size() - 1:
			relays.append(leg["to_name"])
	return "Via %s — %s — %s" % [
		", ".join(relays), ", ".join(vehicle_names), VehicleData.format_duration(total_hours(route))]
