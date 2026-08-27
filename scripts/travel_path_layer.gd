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
## How far in front of the flat plane (toward the camera, i.e. more
## negative Z since the flat-mode camera sits at -Z looking toward +Z)
## the line and dot sit. Without this the geometry would land AT the
## plane's z, get z-fought/occluded by it, and read as invisible on
## the flat map — the sphere-mode analog is LINE_SURFACE_OFFSET, which
## does the same job multiplicatively.
const LINE_FLAT_OFFSET := 0.01
## Team travel colors — blueish, matches the "En route" accent
## elsewhere in the UI (deploy row status, travel confirmation status).
const LINE_COLOR := Color(0.45, 0.75, 1.0, 0.85)
const DOT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
## Empty-cabin vehicle ferry colors — amber, deliberately distinct from
## the team blue so a player glancing at the map can tell squad
## deployments apart from logistics traffic without hovering to check.
const VEHICLE_LINE_COLOR := Color(1.0, 0.75, 0.35, 0.85)
const VEHICLE_DOT_COLOR := Color(1.0, 0.9, 0.6, 1.0)
## Mobile base (ship) relocation colors — teal, the third distinct
## channel: team blue, vehicle amber, ship teal.
const SHIP_LINE_COLOR := Color(0.4, 0.85, 0.75, 0.85)
const SHIP_DOT_COLOR := Color(0.7, 0.95, 0.9, 1.0)
const DOT_RADIUS := 0.022

## Screen-space radius (in pixels) within which a click on the map
## counts as picking a traveling team's dot. Matches MarkerLayer's
## pick_radius_px in intent — same "fat clickable target" behavior
## since the dot itself is small.
const PICK_RADIUS_PX := 30.0

## Fired when the player clicks near a traveling team's dot on the
## map, so UI can open that team's detail sheet — same routing shape
## as MarkerLayer's event_marker_clicked / base_marker_clicked.
signal team_marker_clicked(team: TeamData)

var flatten: float = 0.0
var _paths: Dictionary = {} # team_id -> {line: MeshInstance3D, dot: MeshInstance3D}
## Vehicle ferry entries (empty-cabin transfers between bases) — keyed
## by VehicleData reference since each vehicle can only be in one
## transfer at a time. Separate from _paths so the two can render in
## different colors (team blue vs vehicle amber).
var _vehicle_paths: Dictionary = {}
## Mobile base (ship) relocation paths — keyed by BaseData reference.
## A ship can only be in one relocation at a time.
var _ship_paths: Dictionary = {}
var _camera: Camera3D


func _ready() -> void:
	Game.team_manager.team_departed.connect(_on_team_departed)
	Game.team_manager.team_arrived.connect(_on_team_arrived)
	Game.base_manager.vehicle_transfer_started.connect(_on_vehicle_transfer_started)
	Game.base_manager.vehicle_transfer_completed.connect(_on_vehicle_transfer_completed)
	Game.base_manager.base_relocation_started.connect(_on_base_relocation_started)
	Game.base_manager.base_relocation_completed.connect(_on_base_relocation_completed)

	# Same globe_clicked stream MarkerLayer subscribes to — the two
	# picking passes run independently; if a click lands near both a
	# base/event marker and a travel dot, both signals fire and the
	# last one wins in the detail panel. Cases where they overlap are
	# rare enough to accept this rather than force an ordering.
	var geoscape: Node = get_tree().current_scene
	if geoscape and geoscape.has_signal("globe_clicked"):
		geoscape.globe_clicked.connect(_on_globe_clicked)
	if geoscape and "camera" in geoscape:
		_camera = geoscape.camera

	for team: TeamData in Game.team_manager.teams:
		if team.is_traveling:
			_ensure_path(team.id)
	# Restore visuals for any vehicle ferries already in transit (e.g.
	# after a save/load, once that exists). Live at boot today too,
	# though the game currently starts with none.
	for entry: Dictionary in Game.base_manager.in_transit_vehicles:
		_ensure_vehicle_path(entry)
	# Same restore for mobile bases mid-relocation.
	for base: BaseData in Game.base_manager.bases:
		if base.is_relocating:
			_ensure_ship_path(base)


func _on_team_departed(team_id: String) -> void:
	_ensure_path(team_id)


func _on_team_arrived(team_id: String, _event_id: String) -> void:
	var team: TeamData = Game.team_manager.get_team(team_id)
	if team and team.is_traveling:
		return # immediately started another leg (e.g. the return trip) - keep showing it
	_remove_path(team_id)


func _on_vehicle_transfer_started(vehicle: VehicleData, _from_base_id: String,
		_to_base_id: String, _arrival_day: float) -> void:
	# Look up the freshly-appended entry — the signal payload is
	# missing the timing fields we need, but the entry in
	# in_transit_vehicles has everything.
	for entry: Dictionary in Game.base_manager.in_transit_vehicles:
		if entry.vehicle == vehicle:
			_ensure_vehicle_path(entry)
			return


func _on_vehicle_transfer_completed(vehicle: VehicleData, _to_base_id: String) -> void:
	_remove_vehicle_path(vehicle)


func _on_base_relocation_started(base: BaseData) -> void:
	_ensure_ship_path(base)


func _on_base_relocation_completed(base: BaseData) -> void:
	_remove_ship_path(base)


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


## Same shape as _ensure_path but colored amber and keyed by the
## VehicleData instance. The `transfer_entry` payload is the same
## Dictionary BaseManager stores in in_transit_vehicles — held here so
## _process can read progress/endpoints without a lookup each frame.
func _ensure_vehicle_path(transfer_entry: Dictionary) -> void:
	var vehicle: VehicleData = transfer_entry.vehicle
	if _vehicle_paths.has(vehicle):
		return

	var line := MeshInstance3D.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color = VEHICLE_LINE_COLOR
	line.material_override = line_mat
	add_child(line)

	var dot := MeshInstance3D.new()
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = DOT_RADIUS
	dot_mesh.height = DOT_RADIUS * 2.0
	dot.mesh = dot_mesh
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = VEHICLE_DOT_COLOR
	dot.material_override = dot_mat
	add_child(dot)

	_vehicle_paths[vehicle] = {"line": line, "dot": dot, "entry": transfer_entry}


func _remove_vehicle_path(vehicle: VehicleData) -> void:
	var path: Dictionary = _vehicle_paths.get(vehicle, {})
	if path.is_empty():
		return
	path.line.queue_free()
	path.dot.queue_free()
	_vehicle_paths.erase(vehicle)


## Ship relocation path — same shape as _ensure_vehicle_path but keyed
## by BaseData and colored teal. `dot` here just marks the destination;
## the base's own map marker already tracks the ship's current position
## (see MarkerLayer._on_base_moved), so we don't need a second dot for
## "where the ship is right now."
func _ensure_ship_path(base: BaseData) -> void:
	if _ship_paths.has(base):
		return

	var line := MeshInstance3D.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color = SHIP_LINE_COLOR
	line.material_override = line_mat
	add_child(line)

	var dot := MeshInstance3D.new()
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = DOT_RADIUS
	dot_mesh.height = DOT_RADIUS * 2.0
	dot.mesh = dot_mesh
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = SHIP_DOT_COLOR
	dot.material_override = dot_mat
	add_child(dot)

	_ship_paths[base] = {"line": line, "dot": dot}


func _remove_ship_path(base: BaseData) -> void:
	var path: Dictionary = _ship_paths.get(base, {})
	if path.is_empty():
		return
	path.line.queue_free()
	path.dot.queue_free()
	_ship_paths.erase(base)


func _process(_delta: float) -> void:
	if _paths.is_empty() and _vehicle_paths.is_empty() and _ship_paths.is_empty():
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

	for vehicle: VehicleData in _vehicle_paths.keys():
		_update_vehicle_path(_vehicle_paths[vehicle])

	for base: BaseData in _ship_paths.keys():
		_update_ship_path(base, _ship_paths[base])


func _update_path(team: TeamData, entry: Dictionary) -> void:
	var origin: Vector2 = team.location          # (lon, lat)
	var dest: Vector2 = team.travel_destination  # (lon, lat)

	var total_days := maxf(0.001, team.travel_arrival_day - team.travel_departure_day)
	var now: float = Game.game_clock.get_current_time_days()
	var elapsed := now - team.travel_departure_day
	var progress := clampf(elapsed / total_days, 0.0, 1.0)

	var origin_sphere := SurfaceMarker.latlon_to_position(origin.y, origin.x, 1.0)
	var dest_sphere := SurfaceMarker.latlon_to_position(dest.y, dest.x, 1.0)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var prev_point := Vector3.INF
	for i in range(SEGMENT_COUNT + 1):
		var t := float(i) / float(SEGMENT_COUNT)
		var point := _sample_point(origin_sphere, dest_sphere, t)
		# When the great circle crosses the antimeridian on the flat map,
		# consecutive samples' x jumps from about -π to about +π (or vice
		# versa) — a straight line between them would draw across the
		# entire map rather than wrapping at the edge. Split the line
		# strip at that jump so it renders as two segments hitting the
		# ±π edges instead. Only relevant while flat (in sphere mode the
		# geodesic is a continuous arc through the sphere, no wrap).
		if flatten > 0.5 and prev_point.x != INF:
			if absf(point.x - prev_point.x) > PI:
				im.surface_end()
				im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im.surface_add_vertex(point)
		prev_point = point
	im.surface_end()
	(entry.line as MeshInstance3D).mesh = im

	(entry.dot as MeshInstance3D).position = _sample_point(
			origin_sphere, dest_sphere, progress)


## Same shape as _update_path but reads endpoints/timing from a stored
## BaseManager.in_transit_vehicles entry rather than a TeamData. The
## amber team-agnostic materials the path was set up with in
## _ensure_vehicle_path stay, so the line/dot render distinctly.
func _update_vehicle_path(path: Dictionary) -> void:
	var transfer_entry: Dictionary = path.entry
	var from_base := Game.base_manager.get_base_by_id(transfer_entry.from_base_id)
	var to_base := Game.base_manager.get_base_by_id(transfer_entry.to_base_id)
	if from_base == null or to_base == null:
		return

	var arrival_day: float = transfer_entry.arrival_day
	var departure_day: float = transfer_entry.departure_day
	var total_days := maxf(0.001, arrival_day - departure_day)
	var now: float = Game.game_clock.get_current_time_days()
	var elapsed := now - departure_day
	var progress := clampf(elapsed / total_days, 0.0, 1.0)

	var origin_sphere := SurfaceMarker.latlon_to_position(from_base.location.y, from_base.location.x, 1.0)
	var dest_sphere := SurfaceMarker.latlon_to_position(to_base.location.y, to_base.location.x, 1.0)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var prev_point := Vector3.INF
	for i in range(SEGMENT_COUNT + 1):
		var t := float(i) / float(SEGMENT_COUNT)
		var point := _sample_point(origin_sphere, dest_sphere, t)
		if flatten > 0.5 and prev_point.x != INF:
			if absf(point.x - prev_point.x) > PI:
				im.surface_end()
				im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im.surface_add_vertex(point)
		prev_point = point
	im.surface_end()
	(path.line as MeshInstance3D).mesh = im

	(path.dot as MeshInstance3D).position = _sample_point(origin_sphere, dest_sphere, progress)


## Ship relocation path — line runs from the departure port to the
## destination for the whole trip (unlike team/vehicle paths, ships
## don't hop between endpoints; there's no intermediate leg switching
## to reveal). Dot sits at the destination as a target marker.
func _update_ship_path(base: BaseData, path: Dictionary) -> void:
	var origin_sphere := SurfaceMarker.latlon_to_position(
			base.travel_from_location.y, base.travel_from_location.x, 1.0)
	var dest_sphere := SurfaceMarker.latlon_to_position(
			base.travel_destination.y, base.travel_destination.x, 1.0)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var prev_point := Vector3.INF
	for i in range(SEGMENT_COUNT + 1):
		var t := float(i) / float(SEGMENT_COUNT)
		var point := _sample_point(origin_sphere, dest_sphere, t)
		if flatten > 0.5 and prev_point.x != INF:
			if absf(point.x - prev_point.x) > PI:
				im.surface_end()
				im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		im.surface_add_vertex(point)
		prev_point = point
	im.surface_end()
	(path.line as MeshInstance3D).mesh = im

	(path.dot as MeshInstance3D).position = _sample_point(origin_sphere, dest_sphere, 1.0)


## Picks the nearest traveling team's dot within PICK_RADIUS_PX of the
## click and fires team_marker_clicked. Camera-behind check and (in
## sphere mode) far-side check mirror MarkerLayer's pick logic so a
## dot hidden behind the globe doesn't get selected through it. In
## flat mode there's no far side so the far-side check is skipped.
func _on_globe_clicked(screen_pos: Vector2) -> void:
	if _camera == null or _paths.is_empty():
		return

	var best_team: TeamData = null
	var best_dist := PICK_RADIUS_PX
	for team_id: String in _paths.keys():
		var team: TeamData = Game.team_manager.get_team(team_id)
		if team == null:
			continue
		var dot: MeshInstance3D = _paths[team_id].dot
		var world_pos := dot.global_position
		if _camera.is_position_behind(world_pos):
			continue
		if flatten < 0.5 and world_pos.normalized().dot(
				(_camera.global_position - Vector3.ZERO).normalized()) <= 0.0:
			continue  # dot is on far side of sphere
		var d := _camera.unproject_position(world_pos).distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best_team = team

	if best_team != null:
		team_marker_clicked.emit(best_team)


func _sample_point(origin_sphere: Vector3, dest_sphere: Vector3, t: float) -> Vector3:
	# Sample on the sphere first (great-circle interpolation via slerp),
	# then project that sample down to flat — that way a polar path
	# actually curves through higher latitudes on the flat map instead
	# of being a straight linear-lerp between the two flat endpoints,
	# and an antimeridian crossing produces the u-jump the strip
	# splitter above expects.
	var sphere_sample := origin_sphere.slerp(dest_sphere, t)
	var sphere_pos := sphere_sample * LINE_SURFACE_OFFSET
	var flat_pos := SurfaceMarker.sphere_to_flat_position(sphere_sample)
	flat_pos.z -= LINE_FLAT_OFFSET  # sit fractionally in front of the plane
	return sphere_pos.lerp(flat_pos, flatten)
