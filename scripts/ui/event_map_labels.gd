extends Control
## EventMapLabels — clickable title chips floating above each active
## event's map marker. A screen-space overlay (not a 3D Label3D) so the
## text stays upright and readable regardless of globe rotation/flatten
## state. Positions are recomputed every frame from the marker's projected
## screen position.

signal event_label_clicked(ev: EventData)

var _labels: Dictionary = {} # event_id -> Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.event_manager.event_spawned.connect(_on_event_spawned)
	Game.event_manager.event_expired.connect(_on_event_expired)
	Game.event_manager.event_resolved.connect(_on_event_resolved)


func _on_event_spawned(ev: EventData) -> void:
	if ev.location_city == "":
		return

	var btn := Button.new()
	btn.text = ev.title
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", ev.get_urgency_color())
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.8)
	style.border_color = ev.get_urgency_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_top = 2.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)

	btn.pressed.connect(_on_label_pressed.bind(ev.id))
	btn.visible = false
	add_child(btn)
	_labels[ev.id] = btn


func _on_label_pressed(event_id: String) -> void:
	var ev: EventData = Game.event_manager.get_event_by_id(event_id)
	if ev == null:
		return
	event_label_clicked.emit(ev)


func _on_event_expired(ev: EventData) -> void:
	_remove_label(ev.id)


func _on_event_resolved(ev: EventData, _team_name: String, _result: MissionResolutionResult) -> void:
	_remove_label(ev.id)


func _remove_label(event_id: String) -> void:
	var btn: Button = _labels.get(event_id)
	if btn:
		btn.queue_free()
		_labels.erase(event_id)


func _process(_delta: float) -> void:
	if _labels.is_empty():
		return

	var camera: Camera3D = %Camera3D
	var marker_layer: Node = %MarkerLayer

	for event_id: String in _labels.keys():
		var btn: Button = _labels[event_id]
		var marker: SurfaceMarker = marker_layer.get_event_marker(event_id)

		if marker == null or not is_instance_valid(marker):
			btn.visible = false
			continue
		if not marker.visible:
			btn.visible = false
			continue
		if not marker.is_facing_camera(camera) or camera.is_position_behind(marker.global_position):
			btn.visible = false
			continue

		var screen_pos := camera.unproject_position(marker.global_position)
		btn.visible = true
		btn.position = screen_pos + Vector2(-btn.size.x * 0.5, 10.0)
