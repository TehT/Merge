extends Node3D

@export var globe_path: NodePath = ^"Globe"
@export var camera_path: NodePath = ^"Camera3D"

var globe: MeshInstance3D
var camera: Camera3D

@export_group("Rotation")
@export var drag_sensitivity: float = 0.008
@export var auto_rotate_speed: float = 0.0
@export var momentum_damping: float = 4.0

@export_group("Zoom")
@export var zoom_speed: float = 0.5
@export var min_distance: float = 1.6
@export var max_distance: float = 6.0
@export var zoom_smoothing: float = 8.0
var _pan_target := Vector2.ZERO

@export_group("Pan")
## Drag-to-pan speed while flattened (unfold mode). Scales with current
## zoom distance so panning feels consistent at any zoom level.
@export var pan_sensitivity: float = 1.0

@export_group("Legacy Detail View")
## Both disabled for now — superseded by the event detail panel's own map
## (DetailPanel._create_event_map). Left as toggles rather than deleted in
## case this in-scene hover/click system gets revisited later.
@export var enable_cell_selection: bool = false
@export var enable_detail_view: bool = false

@export_group("Sun / Time")
## Whether the sun/calendar sync to GameClock at all. Disable to freeze the
## sun wherever it currently sits (e.g. for a screenshot), independent of
## whether GameClock itself is paused.
@export var sun_advance_enabled: bool = true
@export_range(0.0, 45.0) var axial_tilt_deg: float = 23.5:
	set(value):
		axial_tilt_deg = value
		_axial_tilt_rad = deg_to_rad(value)
@export var show_night_shade: bool = true:
	set(value):
		show_night_shade = value
		if _material:
			_material.set_shader_parameter("enable_night", value)

## Calendar day-of-year at GameClock day 0 (i.e. the starting date). The
## live day_of_year below is computed each frame as this plus GameClock's
## elapsed days, so GameClock is the single authoritative day clock.
@export_range(0.0, 365.25) var start_day_of_year: float = 0.0

## Calendar year at GameClock day 0. get_current_year() advances it once
## start_day_of_year + elapsed days rolls past 365.25.
@export var start_year: int = 2025

## Current calendar day-of-year. Runtime only — driven by GameClock via
## _process_sun(), not hand-edited.
var day_of_year: float = 0.0:
	set(value):
		day_of_year = value
		_season_angle = (value / 365.25) * TAU

@export_group("Unfold")
@export var flatten: bool = false:
	set(value):
		flatten = value
		_apply_flatten()
@export var unfold_speed: float = 2.0

@export_group("References")
@export var geo: GeoData

signal globe_clicked(screen_position: Vector2)
@export var click_max_drag_px: float = 6.0

# --- Private state ---
var _material: ShaderMaterial
var _detail_material: ShaderMaterial
var _detail_mesh: MeshInstance3D
var _selected_cell := Vector2(-999.0, -999.0)

# --- Detail-view event markers ---
# Mirrors MarkerLayer's event markers onto the detail quad. Kept here rather
# than in MarkerLayer since only GeoscapeController owns the detail mesh/
# material and its cell_uv_min/max projection math.
var _detail_marker_layer: Node3D
var _detail_marker_geo: Dictionary = {}   # event_id -> {lat, lon, color}
var _detail_marker_nodes: Dictionary = {} # event_id -> MeshInstance3D

var _dragging := false
var _last_mouse_pos := Vector2.ZERO
var _drag_distance_px := 0.0
var _yaw_velocity := 0.0
var _pitch_velocity := 0.0
var _yaw_accum := 0.0
var _pitch_accum := 0.0
var _globe_basis := Basis.IDENTITY

var _target_distance: float
var _current_distance: float

var _sun_angle := 0.0
var _axial_tilt_rad := deg_to_rad(23.5)
var _season_angle := 0.0
var _flatten_amount := 0.0

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	globe = get_node_or_null(globe_path) as MeshInstance3D
	camera = get_node_or_null(camera_path) as Camera3D

	if globe == null or camera == null:
		push_error("GeoscapeController: globe and camera must resolve to valid nodes.")
		return

	_axial_tilt_rad = deg_to_rad(axial_tilt_deg)
	globe_clicked.connect(_on_globe_clicked)

	# Prime day_of_year from GameClock before the first _process_sun() frame
	# so get_date_string() isn't wrong for a frame at startup.
	day_of_year = fmod(start_day_of_year + %GameClock.current_day + %GameClock.get_day_progress(), 365.25)

	_current_distance = camera.position.length()
	_target_distance = _current_distance

	var mat := globe.get_surface_override_material(0)
	if mat == null and globe.mesh != null:
		mat = globe.mesh.surface_get_material(0)
	if mat is ShaderMaterial:
		_material = mat
		_material.set_shader_parameter("flatten", 0.0)
	else:
		push_warning("GeoscapeController: globe material is not ShaderMaterial.")

	if enable_detail_view:
		_create_detail_view()

	# Let WeatherController own weather uniforms
	var weather := get_node_or_null("Globe/WeatherController") as WeatherController
	if weather:
		weather.register_material(_material)
		if _detail_material:
			weather.register_material(_detail_material)

	if enable_detail_view:
		var marker_layer := globe.get_node_or_null("MarkerLayer")
		if marker_layer:
			marker_layer.event_marker_added.connect(_on_event_marker_added)
			marker_layer.event_marker_removed.connect(_on_event_marker_removed)


func _process(delta: float) -> void:
	_process_rotation(delta)
	_process_camera(delta)
	_process_sun(delta)
	_process_flatten(delta)
	_process_hover()


# =============================================================================
# Per-frame subsystems
# =============================================================================

func _process_rotation(delta: float) -> void:
	if not _dragging and not flatten:
		if absf(_yaw_velocity) > 0.0001 or absf(_pitch_velocity) > 0.0001:
			_apply_rotation(_yaw_velocity, _pitch_velocity)
			var damp :Variant = clamp(1.0 - momentum_damping * delta, 0.0, 1.0)
			_yaw_velocity *= damp
			_pitch_velocity *= damp
		elif auto_rotate_speed != 0.0:
			_apply_rotation(auto_rotate_speed * delta, 0.0)

	_globe_basis = Basis(camera.global_transform.basis.x, _pitch_accum) * Basis(Vector3.UP, _yaw_accum)
	globe.transform.basis = _globe_basis

func _process_camera(delta: float) -> void:
	_current_distance = lerp(_current_distance, _target_distance, clamp(zoom_smoothing * delta, 0.0, 1.0))

	if flatten:
		camera.position.z = -_current_distance
		# Map extents are PI wide and PI/2 tall (from the unfold shader)
		_pan_target.x = clamp(_pan_target.x, -PI, PI)
		_pan_target.y = clamp(_pan_target.y, -PI * 0.5, PI * 0.5)
		camera.position.x = lerp(camera.position.x, _pan_target.x, clamp(zoom_smoothing * delta, 0.0, 1.0))
		camera.position.y = lerp(camera.position.y, _pan_target.y, clamp(zoom_smoothing * delta, 0.0, 1.0))
	else:
		if camera.position.length() > 0.0001:
			camera.position = camera.position.normalized() * _current_distance
		else:
			camera.position = Vector3(0, 0, -_current_distance)
		camera.look_at(Vector3.ZERO, Vector3.UP)

## Future candidate: SunController
func _process_sun(_delta: float) -> void:
	if sun_advance_enabled:
		_sun_angle = %GameClock.get_day_progress() * TAU
		day_of_year = fmod(start_day_of_year + %GameClock.current_day + %GameClock.get_day_progress(), 365.25)

	if not _material:
		return

	var declination := _axial_tilt_rad * sin(_season_angle)
	var sun_local := Vector3(
		cos(declination) * cos(_sun_angle),
		sin(declination),
		cos(declination) * sin(_sun_angle)
	)
	_material.set_shader_parameter("sun_direction", sun_local)
	if _detail_material and _detail_mesh.visible:
		_detail_material.set_shader_parameter("sun_direction", sun_local)
		_detail_material.set_shader_parameter("enable_night", show_night_shade)


func _process_flatten(delta: float) -> void:
	var target := 1.0 if flatten else 0.0
	_flatten_amount = move_toward(_flatten_amount, target, unfold_speed * delta)
	if _material:
		_material.set_shader_parameter("flatten", _flatten_amount)

## The smooth 0..1 sphere/flat blend (unlike `flatten`, which is just the
## on/off toggle). Other layers whose visuals need to match the globe's
## own unfold state (e.g. TravelPathLayer) should read this directly
## rather than re-deriving it from the shader material.
func get_flatten_amount() -> float:
	return _flatten_amount


## Future candidate: HoverController / SelectionController
## Only drives the shader's hover-highlight overlay now. The old grid-coord
## text readout was retired along with the other corner labels; hover/click
## location info is slated to reappear attached to the detail view instead
## (not yet done — see the "detail view caption" note from UI planning).
func _process_hover() -> void:
	if not _material:
		return
	if not enable_cell_selection:
		_material.set_shader_parameter("hovered_cell", Vector2(-999.0, -999.0))
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var cell: Variant = _get_hovered_cell(mouse_pos)
	if cell != null:
		_material.set_shader_parameter("hovered_cell", cell)
	else:
		_material.set_shader_parameter("hovered_cell", Vector2(-999.0, -999.0))


# =============================================================================
# Input
# =============================================================================

## _input() fires before Godot's GUI system processes the event, so this
## global hotkey keeps working no matter what Control currently has focus —
## in particular, Tab is also Godot's default "focus next control" key, and
## UI panels (e.g. the Agents TabContainer) would otherwise swallow it
## during GUI input handling, which happens before _unhandled_input() runs.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		flatten = not flatten
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = mb.pressed
				_last_mouse_pos = mb.position
				if mb.pressed:
					_yaw_velocity = 0.0
					_pitch_velocity = 0.0
					_drag_distance_px = 0.0
				elif _drag_distance_px <= click_max_drag_px:
					globe_clicked.emit(mb.position)
			MOUSE_BUTTON_WHEEL_UP:
				var new_dist : Variant= clamp(_target_distance - zoom_speed, min_distance, max_distance)
				if flatten and new_dist < _target_distance:
					_zoom_toward_cursor(mb.position, _target_distance, new_dist)
				_target_distance = new_dist
			MOUSE_BUTTON_WHEEL_DOWN:
				var new_dist : Variant = clamp(_target_distance + zoom_speed, min_distance, max_distance)
				if flatten and new_dist > _target_distance:
					_zoom_toward_cursor(mb.position, _target_distance, new_dist)
				_target_distance = new_dist

	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position
		_drag_distance_px += delta.length()
		if flatten:
			_pan_drag(delta)
		else:
			_yaw_velocity = -delta.x * drag_sensitivity
			_pitch_velocity = -delta.y * drag_sensitivity
			_apply_rotation(_yaw_velocity, _pitch_velocity)


# =============================================================================
# Globe interaction
# =============================================================================

func _apply_rotation(yaw_amount: float, pitch_amount: float) -> void:
	_yaw_accum = wrapf(_yaw_accum - yaw_amount, -PI, PI)
	_pitch_accum = clamp(_pitch_accum - pitch_amount, -1.4, 1.4)


func _get_hit_lonlat(mouse_pos: Vector2) -> Variant:
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var inv := globe.global_transform.affine_inverse()
	var local_from := inv * from
	var local_dir := (inv.basis * dir).normalized()
	var hit_local: Vector3

	if _flatten_amount < 0.01:
		# Sphere intersection
		var a := local_dir.dot(local_dir)
		var b := 2.0 * local_from.dot(local_dir)
		var c := local_from.dot(local_from) - 1.0
		var disc := b * b - 4.0 * a * c
		if disc < 0.0:
			return null
		var t := (-b - sqrt(disc)) / (2.0 * a)
		if t < 0.0:
			return null
		hit_local = local_from + local_dir * t
	elif _flatten_amount > 0.99:
		# Flat plane intersection
		if abs(local_dir.z) < 0.0001:
			return null
		var t := (-1.0 - local_from.z) / local_dir.z
		if t < 0.0:
			return null
		hit_local = local_from + local_dir * t
	else:
		return null  # mid-animation

	var lon_deg: float
	var lat_deg: float
	if _flatten_amount < 0.01:
		var u := fmod(atan2(hit_local.x, hit_local.z) / TAU + 1.0, 1.0)
		var v := acos(clamp(hit_local.y, -1.0, 1.0)) / PI
		lon_deg = (u - 0.5) * 360.0
		lat_deg = (0.5 - v) * 180.0
	else:
		lon_deg = (-hit_local.x / PI) * 180.0
		lat_deg = (hit_local.y / (PI / 2.0)) * 90.0

	return Vector2(lon_deg, lat_deg)


func _get_hovered_cell(mouse_pos: Vector2) -> Variant:
	var hit: Variant = _get_hit_lonlat(mouse_pos)
	if hit == null:
		return null
	var step: float = _material.get_shader_parameter("graticule_step_deg")
	return Vector2(floor(hit.x / step), floor(hit.y / step))


# =============================================================================
# Detail view
# =============================================================================

## Future candidate: DetailViewController
func _create_detail_view() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.65, 0.65)

	_detail_material = ShaderMaterial.new()
	_detail_material.shader = _material.shader

	for param in ["land_mask", "land_mask_detailed", "lights_mask", "heightmap",
				   "moisture_map", "satellite_map", "sun_direction", "enable_night"]:
		_detail_material.set_shader_parameter(param, _material.get_shader_parameter(param))

	_detail_material.set_shader_parameter("detail_mode", true)
	_detail_material.set_shader_parameter("height_scale", 0.3)
	_detail_material.set_shader_parameter("hillshade_strength", 0.8)
	# get_shader_parameter() returns Nil until a value has been explicitly
	# set on this ShaderMaterial (it does not fall back to the shader's own
	# uniform defaults) — set these now so _update_detail_marker() can safely
	# read them even before the player's first globe click.
	_detail_material.set_shader_parameter("cell_uv_min", Vector2(0.0, 0.0))
	_detail_material.set_shader_parameter("cell_uv_max", Vector2(1.0, 1.0))

	_detail_mesh = MeshInstance3D.new()
	_detail_mesh.mesh = quad
	_detail_mesh.set_surface_override_material(0, _detail_material)
	_detail_mesh.visible = false
	camera.add_child(_detail_mesh)
	# Left side of the screen: the right side is reserved for UI panels
	# (e.g. the Agents tab), which would otherwise overlap this.
	_detail_mesh.position = Vector3(-1.0, -0.55, -1.8)

	# Holds mirrored event-marker dots for the currently zoomed cell. A small
	# +z offset (toward the camera, since _detail_mesh sits at local -z) keeps
	# them from z-fighting with the quad's own opaque surface.
	_detail_marker_layer = Node3D.new()
	_detail_marker_layer.position = Vector3(0.0, 0.0, 0.01)
	_detail_mesh.add_child(_detail_marker_layer)


func _on_globe_clicked(screen_pos: Vector2) -> void:
	if not enable_cell_selection and not enable_detail_view:
		return

	var hit: Variant = _get_hit_lonlat(screen_pos)
	if hit == null:
		if enable_detail_view and _detail_mesh:
			_detail_mesh.visible = false
		_selected_cell = Vector2(-999.0, -999.0)
		return

	var step: float = _material.get_shader_parameter("graticule_step_deg")
	var cell := Vector2(floor(hit.x / step), floor(hit.y / step))
	if enable_cell_selection:
		_selected_cell = cell

	if enable_detail_view and _detail_mesh:
		_detail_mesh.visible = true

		var lon_min := (cell.x - 0.5) * step
		var lat_min := (cell.y - 0.5) * step
		var lon_max := (cell.x + 1.5) * step
		var lat_max := (cell.y + 1.5) * step

		_detail_material.set_shader_parameter("cell_uv_min", Vector2((lon_min / 360.0) + 0.5, 0.5 - (lat_max / 180.0)))
		_detail_material.set_shader_parameter("cell_uv_max", Vector2((lon_max / 360.0) + 0.5, 0.5 - (lat_min / 180.0)))

		_update_all_detail_markers()


# =============================================================================
# Detail-view event markers
# =============================================================================
# Mirrors MarkerLayer's globe event markers onto the detail quad. The quad
# only ever shows a static "zoomed flat" crop (no sphere/flatten animation),
# so these are plain positioned dots, recomputed only when the selected cell
# changes or a marker is added/removed - no per-frame work needed.

func _on_event_marker_added(event_id: String, lat: float, lon: float, color: Color) -> void:
	_detail_marker_geo[event_id] = {"lat": lat, "lon": lon, "color": color}
	_update_detail_marker(event_id)


func _on_event_marker_removed(event_id: String) -> void:
	_detail_marker_geo.erase(event_id)
	var node: MeshInstance3D = _detail_marker_nodes.get(event_id)
	if node:
		node.queue_free()
		_detail_marker_nodes.erase(event_id)


func _update_all_detail_markers() -> void:
	for event_id in _detail_marker_geo.keys():
		_update_detail_marker(event_id)


## Repositions (or hides) one detail-view marker based on the current
## cell_uv_min/max, i.e. whether/where it falls within the zoomed-in crop.
func _update_detail_marker(event_id: String) -> void:
	var info: Dictionary = _detail_marker_geo[event_id]
	var uv := Vector2(info.lon / 360.0 + 0.5, 0.5 - info.lat / 180.0)
	var cell_min: Vector2 = _detail_material.get_shader_parameter("cell_uv_min")
	var cell_max: Vector2 = _detail_material.get_shader_parameter("cell_uv_max")
	var span := cell_max - cell_min
	if span.x <= 0.0 or span.y <= 0.0:
		return
	var local_uv := (uv - cell_min) / span

	var node: MeshInstance3D = _detail_marker_nodes.get(event_id)
	if local_uv.x < 0.0 or local_uv.x > 1.0 or local_uv.y < 0.0 or local_uv.y > 1.0:
		if node:
			node.visible = false
		return

	if node == null:
		node = _make_detail_marker_node(info.color)
		_detail_marker_layer.add_child(node)
		_detail_marker_nodes[event_id] = node

	node.visible = true
	var quad_size: Vector2 = (_detail_mesh.mesh as QuadMesh).size
	node.position = Vector3(
		(local_uv.x - 0.5) * quad_size.x,
		(0.5 - local_uv.y) * quad_size.y,
		0.0
	)


func _make_detail_marker_node(color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	mesh_inst.mesh = quad

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/marker.gdshader")
	mat.set_shader_parameter("base_color", Vector3(color.r, color.g, color.b))
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_inst


# =============================================================================
# Calendar
# =============================================================================

const _DAYS_IN_MONTH := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const _MONTH_NAMES := ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
const _MARCH_EQUINOX_ORDINAL := 79

## Jumps the calendar to a specific date "now". Since day_of_year is
## computed each frame from start_day_of_year + GameClock's elapsed days,
## this solves for the start_day_of_year that makes that true today
## (ignoring the current day's fractional progress, which is negligible).
func set_date(month: int, day: int) -> void:
	var ordinal := day
	for m in range(month - 1):
		ordinal += _DAYS_IN_MONTH[m]
	var target := fmod(ordinal - _MARCH_EQUINOX_ORDINAL + 365.25, 365.25)
	start_day_of_year = fmod(target - %GameClock.current_day + 365.25, 365.25)
	day_of_year = fmod(start_day_of_year + %GameClock.current_day + %GameClock.get_day_progress(), 365.25)

func get_date_string() -> String:
	var ordinal := int(round(fmod(day_of_year + _MARCH_EQUINOX_ORDINAL, 365.25)))
	if ordinal <= 0:
		ordinal += 365
	var month := 0
	while month < 11 and ordinal > _DAYS_IN_MONTH[month]:
		ordinal -= _DAYS_IN_MONTH[month]
		month += 1
	return "%s %d, %d" % [_MONTH_NAMES[month], ordinal, get_current_year()]

## Calendar year "now" — start_year plus however many full 365.25-day
## cycles have elapsed since start_day_of_year (used by get_date_string();
## the top bar reads that rather than tracking the calendar itself).
func get_current_year() -> int:
	var total_days: float = start_day_of_year + %GameClock.current_day + %GameClock.get_day_progress()
	return start_year + int(floor(total_days / 365.25))


# =============================================================================
# Flatten / unfold
# =============================================================================

func _apply_flatten() -> void:
	if flatten:
		_pan_target = Vector2.ZERO
		_dragging = false
		_yaw_velocity = 0.0
		_pitch_velocity = 0.0
		_yaw_accum = 0.0
		_pitch_accum = 0.0
		_globe_basis = Basis.IDENTITY
		globe.transform.basis = _globe_basis
		camera.position = Vector3(0, 0, -_current_distance)
		camera.look_at(Vector3.ZERO, Vector3.UP)
	else:
		_pan_target = Vector2.ZERO
		camera.position = Vector3(0, 0, -_current_distance)
		camera.look_at(Vector3.ZERO, Vector3.UP)

	var layer := globe.get_node_or_null("MarkerLayer")
	if layer and layer.has_method("set_flatten"):
		layer.set_flatten(flatten)

# =============================================================================
# Helper Functions
# =============================================================================

## Click-and-drag panning while flattened — content follows the cursor,
## like a standard map-drag. Uses the same NDC-scaled-by-distance approach
## as _zoom_toward_cursor so panning speed matches zoom level.
func _pan_drag(delta: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var ndc_delta := delta / viewport_size
	_pan_target.x += ndc_delta.x * _current_distance * pan_sensitivity * 1
	_pan_target.y += ndc_delta.y * _current_distance * pan_sensitivity * 1.5


func _zoom_toward_cursor(screen_pos: Vector2, old_dist: float, new_dist: float) -> void:
	if new_dist < old_dist:
		# Zooming in: pan toward cursor
		var viewport_size := get_viewport().get_visible_rect().size
		var ndc := (screen_pos - viewport_size * 0.5) / viewport_size
		var scale_change := 1.0 - (new_dist / old_dist)
		_pan_target.x -= ndc.x * _current_distance * scale_change * 2.0
		_pan_target.y -= ndc.y * _current_distance * scale_change * 1.5
	else:
		# Zooming out: drift back toward center
		var return_factor := 1.0 - (old_dist / new_dist)
		_pan_target = _pan_target.lerp(Vector2.ZERO, return_factor)
