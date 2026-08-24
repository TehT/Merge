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

@export_group("Fleet & Equipment")
@export var vehicles: Array[VehicleData] = []
@export var local_equipment: Array[EquipmentData] = []

func setup(p_name: String, p_location: Vector2) -> BaseData:
	id = _generate_id()
	base_name = p_name
	location = p_location
	return self

static func _generate_id() -> String:
	return "base_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]
