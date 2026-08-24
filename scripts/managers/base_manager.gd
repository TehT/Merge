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
## Single-base for now: bases seeds itself with just the current HQ if
## left empty, and get_primary_base()/get_all_vehicles()/get_all_equipment()
## below are explicitly stand-ins for "which base is this team/agent
## actually at" — there's no such link yet (teams don't have a home base),
## so everything pools across all bases indiscriminately. Adding a second
## base is just another BaseData in `bases`; wiring real per-base
## availability is a separate pass once something needs it.

@export var bases: Array[BaseData] = []

## Equipment usable by any agent from any base, as opposed to a BaseData's
## own local_equipment. Empty by default; populate via the Inspector.
@export var global_equipment: Array[EquipmentData] = []

func _ready() -> void:
	Game.base_manager = self
	if bases.is_empty():
		bases.append(_create_hq())

func _create_hq() -> BaseData:
	var hq := BaseData.new().setup("HQ (Berlin, Germany)", Vector2(13.405, 52.52))
	hq.vehicles = [preload("res://data/vehicles/eurocopter_h225.tres")]
	return hq

## The base new teams start at and travel returns to. Single-base stand-in
## for a real per-team home base — see class comment.
func get_primary_base() -> BaseData:
	return bases[0] if not bases.is_empty() else null

## Every vehicle across every base, pooled. Stand-in for a team looking up
## its own base's fleet specifically — see class comment.
func get_all_vehicles() -> Array[VehicleData]:
	var out: Array[VehicleData] = []
	for base: BaseData in bases:
		out.append_array(base.vehicles)
	return out

## Every equipment item available anywhere: global_equipment plus every
## base's local_equipment, pooled. Stand-in for filtering by which base an
## agent can actually reach — see class comment.
func get_all_equipment() -> Array[EquipmentData]:
	var out: Array[EquipmentData] = global_equipment.duplicate()
	for base: BaseData in bases:
		out.append_array(base.local_equipment)
	return out
