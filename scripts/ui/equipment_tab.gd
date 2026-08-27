extends VBoxContainer
## EquipmentTab — equipment de-pooled by location: an expandable tree of
## Base Name -> equipment type -> individual items (Game.base_manager.
## get_equipment_by_location()), plus a fuzzy search bar (%
## EquipmentSearchBar, a sibling above the scrolling list — see Main.tscn)
## that filters items by name and auto-expands whichever folders contain
## a match. Clicking an item row opens a read-only info card in the
## slideout, same as before. Pure agent/team equip-picking
## (slideout_view_equip_slot.gd) still uses the flat, still-pooled
## get_all_equipment() until agents/teams have a real home base to filter
## by — see BaseManager's own docs.

const SLOT_TYPE_ORDER := ["Weapon", "Armor", "Gadget"]
const _INDENT_PX := 18.0

var _selected_item: EquipmentData
var _search_text: String = ""
var _expanded: Dictionary = {}  # folder path (String) -> bool, default true


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	%EquipmentSearchBar.text_changed.connect(_on_search_changed)
	Game.base_manager.equipment_changed.connect(_refresh)
	_refresh()


func _on_search_changed(new_text: String) -> void:
	_search_text = new_text
	_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var groups: Array[Dictionary] = Game.base_manager.get_equipment_by_location()
	if groups.is_empty():
		var empty := Label.new()
		empty.text = "No equipment in the locker."
		empty.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(empty)
		return

	var query := _search_text.strip_edges()
	var any_shown := false
	for group: Dictionary in groups:
		if _add_base_folder(group["label"], group["base_id"], group["items"], query):
			any_shown = true

	if not any_shown:
		var no_match := Label.new()
		no_match.text = "No equipment matches \"%s\"." % query
		no_match.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
		add_child(no_match)


## One base-level folder (Base Name -> type subfolders -> items). Returns
## whether anything was actually shown — under an active search, a base
## with zero matching items is skipped entirely rather than shown empty.
func _add_base_folder(base_label: String, base_id: String, items: Array, query: String) -> bool:
	var by_type: Dictionary = {}
	var shown_count := 0
	for item: EquipmentData in items:
		if not query.is_empty() and not _fuzzy_match(query, item.equipment_name):
			continue
		if not by_type.has(item.slot_type):
			by_type[item.slot_type] = []
		(by_type[item.slot_type] as Array).append(item)
		shown_count += 1

	if by_type.is_empty():
		return false

	# An active search forces every matching folder open so results are
	# visible immediately, without disturbing what the user had manually
	# expanded/collapsed for the next time they clear the search.
	var forced_open := not query.is_empty()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.visible = forced_open or _is_expanded(base_label)

	for slot_type: String in SLOT_TYPE_ORDER:
		if by_type.has(slot_type):
			_add_type_folder(content, base_label, base_id, slot_type, by_type[slot_type], forced_open)

	add_child(_make_folder_header(base_label, "%s (%d)" % [base_label, shown_count], content, 0))
	add_child(content)
	return true


func _add_type_folder(parent: VBoxContainer, base_label: String, base_id: String, slot_type: String,
		items: Array, forced_open: bool) -> void:
	var path := "%s/%s" % [base_label, slot_type]
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.visible = forced_open or _is_expanded(path)

	for item: EquipmentData in items:
		content.add_child(_make_item_row(item, base_id, 2))

	parent.add_child(_make_folder_header(path, "%s (%d)" % [slot_type, items.size()], content, 1))
	parent.add_child(content)


func _is_expanded(path: String) -> bool:
	return _expanded.get(path, true)


## Case-insensitive subsequence match — every character of query must
## appear in text in order, not necessarily contiguous (e.g. "cbt vst"
## matches "Combat Vest"). Standard lightweight fuzzy-find behavior.
static func _fuzzy_match(query: String, text: String) -> bool:
	var q := query.to_lower()
	var t := text.to_lower()
	var qi := 0
	for c in t:
		if qi < q.length() and c == q[qi]:
			qi += 1
	return qi == q.length()


func _make_folder_header(path: String, label_text: String, content: Control, indent_level: int) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override("separation", 6)

	if indent_level > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(_INDENT_PX * indent_level, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)

	var arrow := Label.new()
	arrow.text = "▾" if content.visible else "▸"
	arrow.custom_minimum_size.x = 16
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if indent_level == 0:
		lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			content.visible = not content.visible
			_expanded[path] = content.visible
			arrow.text = "▾" if content.visible else "▸")

	return row


func _make_item_row(item: EquipmentData, base_id: String, indent_level: int = 0) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if item == _selected_item:
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.15, 0.2, 0.3, 0.95)
		sel.set_corner_radius_all(4)
		sel.content_margin_left = 10.0
		sel.content_margin_top = 6.0
		sel.content_margin_right = 10.0
		sel.content_margin_bottom = 6.0
		panel.add_theme_stylebox_override("panel", sel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	if indent_level > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(_INDENT_PX * indent_level, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(spacer)

	var name_lbl := Label.new()
	name_lbl.text = item.equipment_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	panel.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventMouseButton and input_event.pressed \
				and input_event.button_index == MOUSE_BUTTON_LEFT:
			_selected_item = item
			Game.left_popout.toggle_showing("equipment_info", {"item": item, "base_id": base_id})
			_refresh())

	return panel
