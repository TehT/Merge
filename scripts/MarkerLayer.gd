extends Node3D
## Holds all surface markers and resolves clicks to a selection.
## Should be a child of the Globe node so markers inherit planet rotation.

signal marker_selected(marker: SurfaceMarker)
signal selection_cleared()
signal marker_hovered(marker: SurfaceMarker)
signal marker_unhovered(marker: SurfaceMarker)

## Fired when a marker representing an event is clicked, so UI can open
## that event's details the same way clicking its map label does.
signal event_marker_clicked(ev: EventData)

## Fired when the HQ marker is clicked, so UI can open the base info panel.
signal hq_marker_clicked()

## Fired whenever an event marker is added/removed, so other views (e.g.
## GeoscapeController's detail quad) can mirror the same markers without
## each subscribing to EventManager separately.
signal event_marker_added(event_id: String, lat: float, lon: float, color: Color)
signal event_marker_removed(event_id: String)

## How close (in pixels) a click must land to a marker to select it.
@export var pick_radius_px: float = 30.0

## Separate, usually tighter, radius for hover so the highlight doesn't feel
## trigger-happy while the player is just moving the mouse across the globe.
@export var hover_radius_px: float = 22.0

## Hide markers on the far side of the planet. Also prevents clicking through it.
@export var hide_far_side: bool = true

var markers: Array[SurfaceMarker] = []
var selected_marker: SurfaceMarker = null
var hovered_marker: SurfaceMarker = null
var flatten: float = 0

## event id -> its SurfaceMarker, for events placed via EventManager signals.
var _event_markers: Dictionary = {}


## Mirrors GeoscapeController's flatten onto every marker so pins jump to the
## map's flat positions at the same moment the coastlines do.
func set_flatten(value: float) -> void:
	flatten = value
	for marker in markers:
		if is_instance_valid(marker):
			marker.flatten = value
			
var _controller: Node
var _camera: Camera3D


## Resolved lazily: this node is a child of Globe, so its _ready() runs BEFORE the
## controller's (Godot readies children first) and controller.camera isn't set yet.
func _get_camera() -> Camera3D:
	if _camera == null and _controller:
		_camera = _controller.camera
	return _camera

## Starting sites. Replace/extend at runtime with add_site().
const DEFAULT_SITES := [
]


func _ready() -> void:
	_controller = _find_controller()
	if _controller:
		if _controller.has_signal("globe_clicked"):
			_controller.globe_clicked.connect(_on_globe_clicked)
	else:
		push_warning("MarkerLayer: no GeoscapeController found; selection disabled.")

	for site in DEFAULT_SITES:
		add_site(site["name"], site["lat"], site["lon"])

	_create_hq_marker()

	# The whole scene tree (including Game.event_manager) already exists by the
	# time any node's _ready() runs, so this is always safe regardless of
	# sibling order.
	Game.event_manager.event_spawned.connect(_on_event_spawned)
	Game.event_manager.event_expired.connect(_on_event_expired)
	Game.event_manager.event_resolved.connect(_on_event_resolved)


## Permanent diamond icon at HQ's location. Not tied to the event
## lifecycle, so it's created once here rather than via add/remove signals.
func _create_hq_marker() -> void:
	var hq_marker := add_site(Game.team_manager.HQ_NAME, Game.team_manager.HQ_LOCATION.y, Game.team_manager.HQ_LOCATION.x)
	hq_marker.marker_size = 0.09
	hq_marker.is_base = true
	hq_marker.set_color(Color(0.95, 0.9, 0.6))
	hq_marker.data = {"is_hq": true}


## Places a marker for a newly spawned event, colored by urgency. Escalation
## needs no special handling: the expiring parent event fires event_expired
## (removing its marker below) and the escalated child fires its own
## event_spawned (adding a new one), both already covered generically.
func _on_event_spawned(event: EventData) -> void:
	if event.location_city == "":
		return  # no real-world location resolved (e.g. GeoData unavailable)

	var color := event.get_urgency_color()
	var marker := add_site(event.title, event.geo_coordinates.y, event.geo_coordinates.x)
	marker.data = {"event_id": event.id}
	marker.set_color(color)
	_event_markers[event.id] = marker
	event_marker_added.emit(event.id, event.geo_coordinates.y, event.geo_coordinates.x, color)


func _on_event_expired(event: EventData) -> void:
	_remove_event_marker(event.id)


func _on_event_resolved(event: EventData, _team_name: String, _result: MissionResolutionResult) -> void:
	_remove_event_marker(event.id)


func get_event_marker(event_id: String) -> SurfaceMarker:
	return _event_markers.get(event_id)


func _remove_event_marker(event_id: String) -> void:
	var marker: SurfaceMarker = _event_markers.get(event_id)
	if marker == null:
		return
	remove_site(marker)
	_event_markers.erase(event_id)
	event_marker_removed.emit(event_id)


func _find_controller() -> Node:
	# Walk up until we find the node holding the geoscape controller script.
	var n: Node = get_parent()
	while n:
		if n.has_method("_apply_rotation"):
			return n
		n = n.get_parent()
	return null


## Spawns a marker at the given lat/lon. Returns it so callers can attach data.
func add_site(site_name: String, lat: float, lon: float) -> SurfaceMarker:
	var marker := SurfaceMarker.new()
	marker.site_name = site_name
	marker.latitude = lat
	marker.longitude = lon
	add_child(marker)
	marker.flatten = flatten # match whatever state we're currently in
	markers.append(marker)
	return marker


func remove_site(marker: SurfaceMarker) -> void:
	if marker == selected_marker:
		clear_selection()
	if marker == hovered_marker:
		_set_hovered(null)
	markers.erase(marker)
	marker.queue_free()


func select(marker: SurfaceMarker) -> void:
	if selected_marker == marker:
		return
	if selected_marker:
		selected_marker.selected = false
	selected_marker = marker
	if marker:
		marker.selected = true
		marker_selected.emit(marker)
	else:
		selection_cleared.emit()


func clear_selection() -> void:
	select(null)


func _on_globe_clicked(screen_pos: Vector2) -> void:
	var hit := _pick_marker(screen_pos, pick_radius_px)
	select(hit) # null clears
	if hit and hit.data.has("event_id"):
		var ev: EventData = Game.event_manager.get_event_by_id(hit.data["event_id"])
		if ev:
			event_marker_clicked.emit(ev)
	elif hit and hit.data.has("is_hq"):
		hq_marker_clicked.emit()


func _set_hovered(marker: SurfaceMarker) -> void:
	if hovered_marker == marker:
		return
	if hovered_marker and is_instance_valid(hovered_marker):
		hovered_marker.hovered = false
		marker_unhovered.emit(hovered_marker)
	hovered_marker = marker
	if marker:
		marker.hovered = true
		marker_hovered.emit(marker)


## Returns the nearest camera-facing marker within radius_px, or null.
func _pick_marker(screen_pos: Vector2, radius_px: float) -> SurfaceMarker:
	var cam := _get_camera()
	if cam == null:
		return null

	var best: SurfaceMarker = null
	var best_dist := radius_px

	for marker in markers:
		if not is_instance_valid(marker):
			continue
		# Never pick something on the far side - it's visually behind the planet.
		if not marker.is_facing_camera(cam):
			continue
		if cam.is_position_behind(marker.global_position):
			continue
		var marker_screen := cam.unproject_position(marker.global_position)
		var d := marker_screen.distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best = marker

	return best


func _process(_delta: float) -> void:
	var cam := _get_camera()
	if cam == null:
		return

	if hide_far_side:
		for marker in markers:
			if is_instance_valid(marker):
				marker.visible = marker.is_facing_camera(cam)

	if _controller and "_dragging" in _controller and _controller._dragging:
		_set_hovered(null)
		return

	var mouse_pos := get_viewport().get_mouse_position()
	_set_hovered(_pick_marker(mouse_pos, hover_radius_px))
	
	# --- NEW SYNC LOGIC ---
	# Dynamically pull the flatten value from the parent Globe's shader material
	var parent := get_parent()
	if parent is MeshInstance3D:
		var mat := parent.get_active_material(0) as ShaderMaterial
		if mat:
			var shader_flatten: float = mat.get_shader_parameter("flatten")
			
			# Only trigger the expensive repositioning if the value has actually changed
			if not is_equal_approx(flatten, shader_flatten):
				set_flatten(shader_flatten)
