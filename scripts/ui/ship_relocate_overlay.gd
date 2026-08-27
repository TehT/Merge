extends Control
class_name ShipRelocateOverlay
## ShipRelocateOverlay — the "click on ocean to set course for RV
## Falkor Too" mode. Activated by the Relocate button on a mobile
## base's HQ detail sheet. Banner at the top of the screen holds the
## instruction, a distance/duration readout, and Set Course / Cancel
## buttons. Everywhere else on the screen still receives clicks, and
## each one is routed through GeoscapeController._get_hit_lonlat() to
## get the picked (lon, lat); ocean vs. land is checked via
## GeoData.get_country_at (null = ocean). A preview line + dot are
## added as children of Globe for the duration of the pick so the
## player sees where the ship would go before committing.
##
## Coordinates with other click subscribers via is_picking(): MarkerLayer
## and TravelPathLayer both check it and skip their normal
## marker/dot selection while a pick is active, so a click on the map
## doesn't also try to open some other detail view mid-pick.

signal picking_started
signal picking_ended

const PREVIEW_LINE_COLOR := Color(0.6, 1.0, 0.9, 0.8)
const PREVIEW_DOT_COLOR := Color(0.7, 1.0, 0.95, 1.0)
const PREVIEW_DOT_RADIUS := 0.028
const LINE_SURFACE_OFFSET := 1.01
const LINE_FLAT_OFFSET := 0.01
const SEGMENT_COUNT := 40

var _base: BaseData
var _picking: bool = false
## Vector2.INF means "no valid destination picked yet"; INF's a
## sentinel because Vector2.ZERO is a real lon/lat (equator + prime
## meridian) and would cause a false negative on "have we picked yet".
var _picked_dest: Vector2 = Vector2.INF
var _preview_line: MeshInstance3D
var _preview_dot: MeshInstance3D
var _geoscape: Node
var _globe: Node3D


func _ready() -> void:
	Game.ship_relocate_overlay = self
	visible = false
	_geoscape = get_tree().current_scene
	if _geoscape and _geoscape.has_node("Globe"):
		_globe = _geoscape.get_node("Globe") as Node3D
	if _geoscape and _geoscape.has_signal("globe_clicked"):
		_geoscape.globe_clicked.connect(_on_globe_clicked)
	%SetCourseBtn.pressed.connect(_on_set_course_pressed)
	%CancelBtn.pressed.connect(cancel_picking)


## Public — flipped on by other subscribers (MarkerLayer,
## TravelPathLayer) to skip their normal picking while a course is
## being chosen, so clicking the ocean doesn't also try to open some
## marker's detail sheet.
func is_picking() -> bool:
	return _picking


func start_picking(base: BaseData) -> void:
	if not base.is_mobile:
		push_warning("[ShipRelocateOverlay] start_picking called on a non-mobile base")
		return
	_base = base
	_picking = true
	_picked_dest = Vector2.INF
	%Instruction.text = "Click on the ocean to set course for %s" % base.base_name
	%Info.text = "No destination picked."
	%SetCourseBtn.disabled = true
	_ensure_preview_nodes()
	_preview_line.visible = false
	_preview_dot.visible = false
	visible = true
	picking_started.emit()


func cancel_picking() -> void:
	if not _picking:
		return
	_picking = false
	_picked_dest = Vector2.INF
	if _preview_line:
		_preview_line.visible = false
	if _preview_dot:
		_preview_dot.visible = false
	visible = false
	picking_ended.emit()


func _on_globe_clicked(screen_pos: Vector2) -> void:
	if not _picking:
		return
	if not _geoscape.has_method("_get_hit_lonlat"):
		return
	var hit: Variant = _geoscape._get_hit_lonlat(screen_pos)
	if hit == null:
		return
	var lonlat: Vector2 = hit
	# get_country_at returns null for ocean tiles (nothing under the
	# cursor in the country index map); anything else is land.
	var country: Variant = Game.geo_data.get_country_at(lonlat.x, lonlat.y)
	if country != null:
		%Info.text = "Ships can't sail to land — try open water."
		%SetCourseBtn.disabled = true
		_preview_line.visible = false
		_preview_dot.visible = false
		return

	_picked_dest = lonlat
	var distance := GeoData.haversine_km(_base.location.y, _base.location.x, lonlat.y, lonlat.x)
	var hours := 0.0 if _base.cruise_speed_kmh <= 0.0 else distance / _base.cruise_speed_kmh
	%Info.text = "%d km  ·  %s" % [int(round(distance)), VehicleData.format_duration(hours)]
	%SetCourseBtn.disabled = false
	_update_preview()


func _on_set_course_pressed() -> void:
	if _picked_dest == Vector2.INF:
		return
	var dest_name := _describe_destination(_picked_dest)
	Game.base_manager.begin_base_relocation(_base, _picked_dest, dest_name)
	cancel_picking()


## Best-effort readable name for a picked ocean point — the nearest
## named coastal city, if any, so the event log entry reads better
## than "13.4°, -52.1°". Falls back to raw coordinates when
## GeoData can't find a city nearby.
func _describe_destination(coords: Vector2) -> String:
	var city: Variant = Game.geo_data.get_nearest_city(coords.y, coords.x)
	if city != null and city.has("name"):
		return "waters near %s" % city["name"]
	return "%.1f°%s, %.1f°%s" % [
			absf(coords.y), "N" if coords.y >= 0 else "S",
			absf(coords.x), "E" if coords.x >= 0 else "W"]


func _ensure_preview_nodes() -> void:
	if _preview_line == null:
		_preview_line = MeshInstance3D.new()
		var line_mat := StandardMaterial3D.new()
		line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line_mat.albedo_color = PREVIEW_LINE_COLOR
		_preview_line.material_override = line_mat
		_globe.add_child(_preview_line)
	if _preview_dot == null:
		_preview_dot = MeshInstance3D.new()
		var dot_mesh := SphereMesh.new()
		dot_mesh.radius = PREVIEW_DOT_RADIUS
		dot_mesh.height = PREVIEW_DOT_RADIUS * 2.0
		_preview_dot.mesh = dot_mesh
		var dot_mat := StandardMaterial3D.new()
		dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot_mat.albedo_color = PREVIEW_DOT_COLOR
		_preview_dot.material_override = dot_mat
		_globe.add_child(_preview_dot)


## Same-shape line as TravelPathLayer's — sphere sample slerped
## between the endpoints, projected to flat when flatten>0, with the
## antimeridian split so the strip doesn't run across the whole map
## when it wraps.
func _update_preview() -> void:
	var flatten: float = _geoscape.get_flatten_amount() if _geoscape.has_method("get_flatten_amount") else 0.0
	var origin_sphere := SurfaceMarker.latlon_to_position(_base.location.y, _base.location.x, 1.0)
	var dest_sphere := SurfaceMarker.latlon_to_position(_picked_dest.y, _picked_dest.x, 1.0)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var prev_point := Vector3.INF
	for i in range(SEGMENT_COUNT + 1):
		var t := float(i) / float(SEGMENT_COUNT)
		var sphere_sample := origin_sphere.slerp(dest_sphere, t)
		var sphere_pos := sphere_sample * LINE_SURFACE_OFFSET
		var flat_pos := SurfaceMarker.sphere_to_flat_position(sphere_sample)
		flat_pos.z -= LINE_FLAT_OFFSET
		var point := sphere_pos.lerp(flat_pos, flatten)
		if flatten > 0.5 and prev_point.x != INF:
			if absf(point.x - prev_point.x) > PI:
				im.surface_end()
				im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im.surface_add_vertex(point)
		prev_point = point
	im.surface_end()
	_preview_line.mesh = im
	_preview_line.visible = true

	var end_sphere := origin_sphere.slerp(dest_sphere, 1.0)
	var end_sphere_pos := end_sphere * LINE_SURFACE_OFFSET
	var end_flat := SurfaceMarker.sphere_to_flat_position(end_sphere)
	end_flat.z -= LINE_FLAT_OFFSET
	_preview_dot.position = end_sphere_pos.lerp(end_flat, flatten)
	_preview_dot.visible = true
