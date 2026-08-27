## BaseData — one base/hideout: a location, its own vehicle fleet, and
## equipment that's only available there (as opposed to BaseManager's
## global_equipment, usable from anywhere). A helicopter or a piece of
## gear physically sits at exactly one base, so both live here rather
## than in one org-wide pool.
class_name BaseData
extends Resource

@export var id: String = ""
@export var base_name: String = ""
@export var location: Vector2 = Vector2.ZERO  # (lon, lat), matches GeoData's convention

## Which vehicles can land here. Existing bases default to having
## both — no behavior change for the current fleet — but new base
## kinds (ships, small outposts, drop points) can leave one or the
## other off to gate what fleet types can reach them via
## TravelRouter's facility check.
@export_group("Facilities")
@export var has_helipad: bool = true
@export var has_airfield: bool = true

## Mobile bases (research ships, mobile ops centers) can be told to
## sail/drive to a new location — BaseManager advances their `location`
## each frame while relocating, and TravelRouter treats them as
## endpoints only while in motion (a moving ship isn't a stable relay
## point). is_mobile=false is the default and keeps existing bases
## rooted; cruise_speed_kmh is only meaningful when is_mobile is true
## (Falkor Too ships at ~10 knots = 18.52 km/h; a mobile ground base
## would be much faster).
@export_group("Mobility")
@export var is_mobile: bool = false
@export var cruise_speed_kmh: float = 0.0

@export_group("Fleet & Equipment")
@export var vehicles: Array[VehicleData] = []
@export var local_equipment: Array[EquipmentData] = []

## Relocation state — set by BaseManager.begin_base_relocation() when
## the player picks a new destination. `location` remains the source of
## truth (BaseManager rewrites it every frame while is_relocating), so
## anything reading base.location gets the CURRENT position without
## caring about the relocation machinery. from_location is preserved
## for the great-circle interpolation and for path visualization; the
## line runs from there to travel_destination for the whole trip.
var is_relocating: bool = false
var travel_from_location: Vector2 = Vector2.ZERO
var travel_destination: Vector2 = Vector2.ZERO
var travel_destination_name: String = ""
var travel_departure_day: float = 0.0
var travel_arrival_day: float = 0.0

func setup(p_name: String, p_location: Vector2) -> BaseData:
	id = _generate_id()
	base_name = p_name
	location = p_location
	return self

static func _generate_id() -> String:
	return "base_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]


## Whether this base has the facility the given vehicle needs to land.
## Vehicles requiring Facility.NONE (teleporters, drones, debug tools)
## are landable anywhere. Called by TravelRouter when filtering
## candidates at each leg's destination.
func supports(vehicle: VehicleData) -> bool:
	match vehicle.required_facility:
		VehicleData.Facility.NONE: return true
		VehicleData.Facility.HELIPAD: return has_helipad
		VehicleData.Facility.AIRFIELD: return has_airfield
	return false


## Sets this base up for a relocation to `destination` — computes the
## arrival day from cruise speed, snapshots from_location for the
## visualization, flips is_relocating. Called by BaseManager.
## begin_base_relocation, which does the outer validation (is_mobile,
## no inbound traffic, etc.).
func begin_relocation(destination: Vector2, destination_name: String, now_days: float) -> void:
	travel_from_location = location
	travel_destination = destination
	travel_destination_name = destination_name
	travel_departure_day = now_days
	var distance_km := _haversine_km(location.y, location.x, destination.y, destination.x)
	var travel_hours := 0.0 if cruise_speed_kmh <= 0.0 else distance_km / cruise_speed_kmh
	travel_arrival_day = now_days + travel_hours / 24.0
	is_relocating = true


## Where the base sits at a given day along its current relocation —
## great-circle slerp between travel_from_location and travel_destination
## by elapsed / total. Returns the destination if the trip is complete;
## returns the current location if not relocating (defensive — callers
## shouldn't call this outside a relocation, but no reason to punish
## them). Called by BaseManager._process each frame to advance
## `location` while in motion.
func location_at(day: float) -> Vector2:
	if not is_relocating:
		return location
	if day >= travel_arrival_day:
		return travel_destination
	var total_days := maxf(0.001, travel_arrival_day - travel_departure_day)
	var t := clampf((day - travel_departure_day) / total_days, 0.0, 1.0)
	# Slerp on sphere positions matches how TravelPathLayer draws the
	# path — same great-circle interpolation so marker and line stay
	# together. Then invert back to lat/lon.
	var from_sphere := SurfaceMarker.latlon_to_position(
			travel_from_location.y, travel_from_location.x, 1.0)
	var to_sphere := SurfaceMarker.latlon_to_position(
			travel_destination.y, travel_destination.x, 1.0)
	var pos := from_sphere.slerp(to_sphere, t)
	var lat := rad_to_deg(asin(clampf(pos.y, -1.0, 1.0)))
	var lon := rad_to_deg(atan2(pos.x, pos.z))
	return Vector2(lon, lat)


## Clears relocation state after arrival — called by BaseManager once
## location has been set to travel_destination.
func complete_relocation() -> void:
	is_relocating = false
	travel_from_location = Vector2.ZERO


## Duplicates GeoData.haversine_km's exact math rather than calling it —
## same reason TravelRouter does: keeps BaseData free of Game references
## so it can be reasoned about in isolation.
static func _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var r := 6371.0
	var dlat := deg_to_rad(lat2 - lat1)
	var dlon := deg_to_rad(lon2 - lon1)
	var a := sin(dlat / 2.0) * sin(dlat / 2.0) + \
			cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * \
			sin(dlon / 2.0) * sin(dlon / 2.0)
	var c := 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return r * c
