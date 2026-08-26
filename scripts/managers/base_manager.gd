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
## a real second one for base/transport features to work against). But
## get_primary_base()/get_all_vehicles()/get_all_equipment() below are
## still explicitly stand-ins for "which base is this team/agent actually
## at" — there's no such link yet (teams don't have a home base), so
## everything still pools across all bases indiscriminately regardless of
## how many exist. Wiring real per-base availability is a separate pass.

@export var bases: Array[BaseData] = []

## Equipment usable by any agent from any base, as opposed to a BaseData's
## own local_equipment. Empty by default; populate via the Inspector.
@export var global_equipment: Array[EquipmentData] = []

## Fires whenever transfer_equipment() actually moves something, so
## location-aware UI (EquipmentTab) knows to redraw.
signal equipment_changed()

func _ready() -> void:
	Game.base_manager = self
	if bases.is_empty():
		bases.append(_create_hq())
		bases.append(_create_east_coast_base())

func _create_hq() -> BaseData:
	var hq := BaseData.new().setup("HQ (Berlin, Germany)", Vector2(13.405, 52.52))
	hq.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres"),
		preload("res://data/vehicles/x9_nightfall.tres"),
	]
	return hq

## Second base, purely so base/transport features (per-base fleets, fast
## travel between fixed bases, founding/upgrading additional bases — see
## GDD §12) have a real second base to work against instead of a
## hypothetical. Shares the same preloaded vehicle resources as the HQ
## where they overlap (the Eurocopter) — safe since nothing anywhere
## mutates a VehicleData at runtime (TeamManager only reads it). Its own
## long-hauler (rather than a second Nightfall) gives each base a
## distinct fleet instead of a mirrored one.
func _create_east_coast_base() -> BaseData:
	var base := BaseData.new().setup("Field Station (New York, USA)", Vector2(-74.006, 40.7128))
	base.vehicles = [
		preload("res://data/vehicles/eurocopter_h225.tres"),
		preload("res://data/vehicles/c130j_a.tres"),
	]
	return base

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
