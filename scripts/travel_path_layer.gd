extends Node3D
## TravelPathLayer — draws each traveling team's route as a line from
## origin to destination, plus a small dot at their approximate current
## position along it. A geodesic arc on the sphere, a straight line once
## flattened — sibling of MarkerLayer under Globe, so it inherits the
## planet's rotation the same way markers do.
##
## Simplification: each sample point is computed independently in both
## the sphere (great-circle slerp) and flat (linear interpolation)
## representations, then lerped by the globe's own `flatten` value. That's
## exact at flatten=0 and flatten=1 (which is ~99% of play time) but,
## unlike SurfaceMarker's per-vertex cylinder-unroll stage, doesn't
## perfectly track the mid-unfold animation — an acceptable trade-off for
## a thin secondary visual that's only mid-transition for a fraction of a
## second.

const SEGMENT_COUNT := 40
const LINE_SURFACE_OFFSET := 1.01
const LINE_COLOR := Color(0.45, 0.75, 1.0, 0.85)
const DOT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const DOT_RADIUS := 0.022

var flatten: float = 0.0
var _paths: Dictionary = {} # team_id -> {line: MeshInstance3D, dot: MeshInstance3D}


func _ready() -> void:
	Game.team_manager.team_departed.connect(_on_team_departed)
	Game.team_manager.team_arrived.connect(_on_team_arrived)

	for team: TeamData in Game.team_manager.teams:
		if team.is_traveling:
			_ensure_path(team.id)


func _on_team_departed(team_id: String) -> void:
	_ensure_path(team_id)


func _on_team_arrived(team_id: String, _event_id: String) -> void:
	var team: TeamData = Game.team_manager.get_team(team_id)
	if team and team.is_traveling:
		return # immediately started another leg (e.g. the return trip) - keep showing it
	_remove_path(team_id)


func _ensure_path(team_id: String) -> void:
	if _paths.has(team_id):
		return

	var line := MeshInstance3D.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color = LINE_COLOR
	line_mat.vertex_color_use_as_albedo = false
	line.material_override = line_mat
	add_child(line)

	var dot := MeshInstance3D.new()
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = DOT_RADIUS
	dot_mesh.height = DOT_RADIUS * 2.0
	dot.mesh = dot_mesh
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = DOT_COLOR
	dot.material_override = dot_mat
	add_child(dot)

	_paths[team_id] = {"line": line, "dot": dot}


func _remove_path(team_id: String) -> void:
	var entry: Dictionary = _paths.get(team_id, {})
	if entry.is_empty():
		return
	entry.line.queue_free()
	entry.dot.queue_free()
	_paths.erase(team_id)


func _process(_delta: float) -> void:
	if _paths.is_empty():
		return

	var geoscape: Node = get_tree().current_scene
	if geoscape and geoscape.has_method("get_flatten_amount"):
		flatten = geoscape.get_flatten_amount()

	for team_id: String in _paths.keys():
		var team: TeamData = Game.team_manager.get_team(team_id)
		if team == null or not team.is_traveling:
			_remove_path(team_id)
			continue
		_update_path(team, _paths[team_id])


func _update_path(team: TeamData, entry: Dictionary) -> void:
	var origin: Vector2 = team.location          # (lon, lat)
	var dest: Vector2 = team.travel_destination  # (lon, lat)

	var total_days := maxf(0.001, team.travel_arrival_day - team.travel_departure_day)
	var now: float = Game.game_clock.get_current_time_days()
	var elapsed := now - team.travel_departure_day
	var progress := clampf(elapsed / total_days, 0.0, 1.0)

	var origin_sphere := SurfaceMarker.latlon_to_position(origin.y, origin.x, 1.0)
	var dest_sphere := SurfaceMarker.latlon_to_position(dest.y, dest.x, 1.0)
	var origin_flat := SurfaceMarker.latlon_to_flat_position(origin.y, origin.x)
	var dest_flat := SurfaceMarker.latlon_to_flat_position(dest.y, dest.x)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(SEGMENT_COUNT + 1):
		var t := float(i) / float(SEGMENT_COUNT)
		im.surface_add_vertex(_sample_point(origin_sphere, dest_sphere, origin_flat, dest_flat, t))
	im.surface_end()
	(entry.line as MeshInstance3D).mesh = im

	(entry.dot as MeshInstance3D).position = _sample_point(
			origin_sphere, dest_sphere, origin_flat, dest_flat, progress)


func _sample_point(origin_sphere: Vector3, dest_sphere: Vector3,
		origin_flat: Vector3, dest_flat: Vector3, t: float) -> Vector3:
	var sphere_pos := origin_sphere.slerp(dest_sphere, t) * LINE_SURFACE_OFFSET
	var flat_pos := origin_flat.lerp(dest_flat, t)
	return sphere_pos.lerp(flat_pos, flatten)
