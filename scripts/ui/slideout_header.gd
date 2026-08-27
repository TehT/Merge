@tool
extends HBoxContainer
## SlideoutHeader — shared "title  .....  ✕" row that leads every popout
## view. Title text/color/size are @export so each instance is
## editor-configurable; close_requested fires when the ✕ is pressed and
## the enclosing view wires it up to its dismiss callback.

signal close_requested

@export var title: String = "" :
	set(v):
		title = v
		if is_inside_tree() and has_node("Title"):
			$Title.text = v

@export var title_color: Color = Color(0, 0, 0, 0) :
	set(v):
		title_color = v
		if is_inside_tree() and has_node("Title"):
			if v.a > 0.0:
				$Title.add_theme_color_override("font_color", v)
			else:
				$Title.remove_theme_color_override("font_color")

@export var title_size: int = 16 :
	set(v):
		title_size = v
		if is_inside_tree() and has_node("Title"):
			$Title.add_theme_font_size_override("font_size", v)


func _ready() -> void:
	$Title.text = title
	$Title.add_theme_font_size_override("font_size", title_size)
	if title_color.a > 0.0:
		$Title.add_theme_color_override("font_color", title_color)
	$CloseBtn.pressed.connect(func() -> void: close_requested.emit())


## Runtime setters used by view scripts that build title/color from
## dynamic data (vehicle name, agent-derived accent, etc.) — same
## effect as flipping the @export but avoids relying on GDScript's
## dot-through-setter syntax on scene instances, which is what
## `header.title = "Foo"` does anyway.
func set_title(text: String) -> void:
	title = text  # triggers setter


func set_title_color(color: Color) -> void:
	title_color = color  # triggers setter


func set_title_size(size: int) -> void:
	title_size = size  # triggers setter
