@tool
extends HBoxContainer
## InfoRow — the shared "Key .......... Value" row that appears through
## every detail view. Key is set in the editor (@export shows in the
## Inspector for each instance); value is set at populate() time via
## set_value(). Optionally clickable — flip the @export bool to show a
## trailing "›" arrow and receive a `clicked` signal on left-click,
## covering all the drill-down rows (Personality, Location→transport,
## equip slots, etc.) without needing a separate clickable-row template.

signal clicked

@export var key: String = "" :
	set(v):
		key = v
		if is_inside_tree() and has_node("Key"):
			$Key.text = v

@export var value: String = "" :
	set(v):
		value = v
		if is_inside_tree() and has_node("Value"):
			$Value.text = v

@export var clickable: bool = false :
	set(v):
		clickable = v
		if is_inside_tree() and has_node("Arrow"):
			$Arrow.visible = v
		mouse_filter = MOUSE_FILTER_STOP if v else MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if v else CURSOR_ARROW


func _ready() -> void:
	$Key.text = key
	$Value.text = value
	$Arrow.visible = clickable
	if clickable:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


func set_value(v: String) -> void:
	value = v  # triggers the setter above


## Dim the value label — used by agent equipment slots to render "Empty"
## in a lighter tone than a real item name.
func set_value_dim(dim: bool) -> void:
	if dim:
		$Value.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1.0))
	else:
		$Value.remove_theme_color_override("font_color")
