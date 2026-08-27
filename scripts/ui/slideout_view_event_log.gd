extends VBoxContainer
## SlideoutViewEventLog — running history of what's happened this session
## (see EventLog): events spawning/expiring/escalating/resolving, teams
## departing/arriving/returning. Newest entry first. Opened via the small
## button below the left sidebar toggle (root_ui.gd); stays live while
## open, appending new entries as they happen.

var _list: VBoxContainer


func populate(_data: Variant, _on_close: Callable) -> void:
	_add_header("Event Log")
	add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)

	Game.event_log.entry_added.connect(_on_entry_added)
	_rebuild()


func _add_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	add_child(lbl)


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()

	var entries := Game.event_log.entries
	if entries.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "Nothing has happened yet."
		none_lbl.add_theme_font_size_override("font_size", 12)
		none_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		_list.add_child(none_lbl)
		return

	for i in range(entries.size() - 1, -1, -1):
		_list.add_child(_make_row(entries[i]))


func _make_row(entry: EventLogEntry) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)

	var day_lbl := Label.new()
	day_lbl.text = entry.format_timestamp()
	day_lbl.add_theme_font_size_override("font_size", 10)
	day_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
	row.add_child(day_lbl)

	var text_lbl := Label.new()
	text_lbl.text = entry.text
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(text_lbl)

	return row


func _on_entry_added(_entry: EventLogEntry) -> void:
	_rebuild()
