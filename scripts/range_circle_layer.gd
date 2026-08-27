extends Node3D
class_name RangeCircleLayer
## RangeCircleLayer — draws a small-circle around every base at the
## radius of its longest TACTICAL vehicle's max range, showing at a
## glance how far the base can deploy a team without needing a
## transport relay. Sibling of MarkerLayer / TravelPathLayer under
## Globe, so it inherits the planet's rotation for free.
##
## Small-circle sampling (constant great-circle distance from center)
## is the "point-at-bearing-and-distance" formula — asin/atan2 in
## spherical coords, sampled at SAMPLE_COUNT bearings around the
## center. In flat mode each sample projects through sphere_to_flat
## just like TravelPathLayer's travel arcs, so ranges near the
## antimeridian wrap correctly (line strip split at the u
## discontinuity, same as travel paths).
##
## Rebuilt every frame — cheap at this scale (~64 samples × ~6 bases),
## and mobile bases + vehicle transfers change what needs drawing
## more often than any obvious cache-invalidation trigger, so
## always-recompute beats tracking dirty flags.

const SAMPLE_COUNT := 64
const CIRCLE_COLOR := Color(0.55, 0.7, 0.9, 0.35)
const CIRCLE_SURFACE_OFFSET := 1.005
const CIRCLE_FLAT_OFFSET := 0.005
const EARTH_RADIUS_KM := 6371.0

## ALL — every base's circle is drawn. SELECTED_ONLY — only the base
## currently open in the left detail sheet gets one (nothing if the
## detail view is showing an agent/team/event/empty state instead of
## a base). NONE — layer is silent. Cycled by the toggle button on
## the left sidebar's toggle rail.
enum Mode { ALL, SELECTED_ONLY, NONE }

signal mode_changed(mode: Mode)

var mode: Mode = Mode.ALL :
	set(value):
		if value == mode:
			return
		mode = value
		mode_changed.emit(mode)

var flatten: float = 0.0
var _circles: Dictionary = {}  # base_id -> MeshInstance3D
var _geoscape: Node


func _ready() -> void:
	_geoscape = get_tree().current_scene


func _process(_delta: float) -> void:
	if _geoscape and _geoscape.has_method("get_flatten_amount"):
		flatten = _geoscape.get_flatten_amount()
	_sync_circles()


## Ensures a circle exists for every qualifying base under the
## current mode, and none exists for bases that no longer qualify
## (no tactical vehicle, unlimited-range vehicle that doesn't render
## as a circle, or the selection filter excludes them).
func _sync_circles() -> void:
	var seen: Dictionary = {}
	if mode != Mode.NONE:
		var selected_base_id := _selected_base_id() if mode == Mode.SELECTED_ONLY else ""
		for base: BaseData in Game.base_manager.bases:
			if mode == Mode.SELECTED_ONLY and base.id != selected_base_id:
				continue
			var range_km := _longest_tactical_range(base)
			if range_km <= 0.0:
				continue
			_update_circle(base, range_km)
			seen[base.id] = true
	for base_id: String in _circles.keys():
		if not seen.has(base_id):
			_remove_circle(base_id)


## Reads the base id currently shown in the left detail panel (empty
## string if the panel is showing an agent/team/event/empty state
## instead). Uses PanelHost's exposed view id + data — the "hq" view
## is populated with a BaseData, so pulling `.id` off it gives the
## selection.
func _selected_base_id() -> String:
	if Game.left_detail == null:
		return ""
	if Game.left_detail.get_current_view_id() != "hq":
		return ""
	var data: Variant = Game.left_detail.get_current_view_data()
	if data is BaseData:
		return (data as BaseData).id
	return ""


## Advances mode ALL → SELECTED_ONLY → NONE → ALL. The button on the
## sidebar's toggle rail wires straight to this.
func cycle_mode() -> void:
	match mode:
		Mode.ALL:
			mode = Mode.SELECTED_ONLY
		Mode.SELECTED_ONLY:
			mode = Mode.NONE
		_:
			mode = Mode.ALL


func _longest_tactical_range(base: BaseData) -> float:
	var best := 0.0
	for v: VehicleData in base.vehicles:
		if v.role != VehicleData.Role.TACTICAL:
			continue
		# max_range_km == 0 means "unlimited" — that's a full-planet
		# reach with no meaningful circle to draw, so we skip it
		# (the base still shows every other tactical vehicle's
		# range in the max, if any).
		if v.max_range_km <= 0.0:
			continue
		best = maxf(best, v.max_range_km)
	return best


func _update_circle(base: BaseData, range_km: float) -> void:
	if not _circles.has(base.id):
		_create_circle(base.id)
	var mesh_inst: MeshInstance3D = _circles[base.id]

	var angular_radius := range_km / EARTH_RADIUS_KM
	var center_lat_rad := deg_to_rad(base.location.y)
	var center_lon_rad := deg_to_rad(base.location.x)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var prev_point := Vector3.INF
	# Sample SAMPLE_COUNT+1 bearings so bearing=TAU closes the loop
	# back to bearing=0 (last point == first point).
	for i in range(SAMPLE_COUNT + 1):
		var bearing := TAU * float(i) / float(SAMPLE_COUNT)
		var sample_lat_rad := asin(clampf(
				sin(center_lat_rad) * cos(angular_radius)
				+ cos(center_lat_rad) * sin(angular_radius) * cos(bearing),
				-1.0, 1.0))
		var sample_lon_rad := center_lon_rad + atan2(
				sin(bearing) * sin(angular_radius) * cos(center_lat_rad),
				cos(angular_radius) - sin(center_lat_rad) * sin(sample_lat_rad))
		var sphere_sample := SurfaceMarker.latlon_to_position(
				rad_to_deg(sample_lat_rad), rad_to_deg(sample_lon_rad), 1.0)
		var sphere_pos := sphere_sample * CIRCLE_SURFACE_OFFSET
		var flat_pos := SurfaceMarker.sphere_to_flat_position(sphere_sample)
		flat_pos.z -= CIRCLE_FLAT_OFFSET
		var point := sphere_pos.lerp(flat_pos, flatten)
		# Same antimeridian-wrap fix as TravelPathLayer's line strips —
		# a range circle near the date line has samples that jump
		# ±π in x on the flat map; split the strip so it doesn't
		# draw a chord across the whole map.
		if flatten > 0.5 and prev_point.x != INF:
			if absf(point.x - prev_point.x) > PI:
				im.surface_end()
				im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im.surface_add_vertex(point)
		prev_point = point
	im.surface_end()
	mesh_inst.mesh = im


func _create_circle(base_id: String) -> void:
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = CIRCLE_COLOR
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	_circles[base_id] = mesh_inst


func _remove_circle(base_id: String) -> void:
	if not _circles.has(base_id):
		return
	(_circles[base_id] as MeshInstance3D).queue_free()
	_circles.erase(base_id)
