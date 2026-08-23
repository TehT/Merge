## VehicleData — a generic transport template. The base's actual fleet is
## built from saved instances of this resource (see res://data/vehicles/),
## not from code — e.g. eurocopter_h225.tres holds the starting transport
## helicopter's stats. Adding a new vehicle to the game is authoring a new
## .tres, not editing this script. CONTINUOUS (speed-based) is the only
## mode wired up so far; TELEPORT is the seam for future teleportation
## (instant, but range-limited and cooldown-gated).
##
## max_range_km applies to both modes: it's "how far this transport can
## reach in one hop," full stop — a CONTINUOUS vehicle's range is its
## operational range before it'd need a leg no game system models yet
## (refueling stops, forward bases), so distant events are simply out of
## reach until a longer-ranged transport comes online, not just slow to
## get to.
##
## TeamManager owns the fleet (Array[VehicleData]) and picks the best fit
## per deployment (see get_best_vehicle) — vehicles aren't tied to one
## team.
class_name VehicleData
extends Resource

enum Mode { CONTINUOUS, TELEPORT }

@export var vehicle_name: String = "Unnamed Vehicle"
@export var mode: Mode = Mode.CONTINUOUS
@export_multiline var description: String = ""

## CONTINUOUS only: cruising speed in km/h.
@export var speed_kmh: float = 0.0

## Max distance reachable in one hop (0 = unlimited). TELEPORT also uses
## this as its per-jump range.
@export var max_range_km: float = 0.0
## TELEPORT only: days before reuse.
@export var cooldown_days: int = 0

## Max agents it can carry in one trip. Squads are 3-5.
@export var capacity: int = 5

## Funding cost per dispatch. Informational for now — not yet deducted
## when a team departs; see TeamManager.begin_travel if that changes.
@export var operation_cost: int = 0

## Optional res:// path to an image/icon shown on the vehicle's info card.
## Empty is fine — the card just shows a placeholder.
@export_file("*.png", "*.jpg", "*.jpeg", "*.svg") var image_path: String = ""


## Travel duration in hours. CONTINUOUS scales directly with distance and
## speed, floored at half an hour (takeoff/landing overhead) so a trip
## never reads as literally instant. TELEPORT is instant (0 hours) —
## callers should check can_reach() first.
func compute_travel_hours(distance_km: float) -> float:
	match mode:
		Mode.TELEPORT:
			return 0.0
		_:
			if speed_kmh <= 0.0:
				return 24.0
			return maxf(0.5, distance_km / speed_kmh)


## Formats an hour count for display, e.g. "5 hours", "1 hour", "<1 hour".
static func format_duration(hours: float) -> String:
	if hours < 1.0:
		return "<1 hour"
	var h := int(round(hours))
	return "%d hour%s" % [h, "" if h == 1 else "s"]


func can_reach(distance_km: float) -> bool:
	return max_range_km <= 0.0 or distance_km <= max_range_km


func can_carry(team_size: int) -> bool:
	return team_size <= capacity


func get_mode_name() -> String:
	match mode:
		Mode.TELEPORT: return "Teleport"
		_: return "Continuous"
