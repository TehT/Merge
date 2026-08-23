extends VBoxContainer
## SlideoutViewBase — shared building blocks for the pop-out slideout's
## content types (Proficiency/Deploy/Vehicle). Each concrete view extends
## this by path, matching DetailViewBase's pattern — see detail_view_base.gd.

## Shared header row: title + a "✕" button wired to on_close. color with
## alpha 0 (the default) means "no override, inherit the theme's default
## label color" — matches what each view originally did when it didn't
## set a title color at all.
func _add_header(title_text: String, on_close: Callable,
		color: Color = Color(0, 0, 0, 0), font_size: int = 16) -> void:
	var header := HBoxContainer.new()
	add_child(header)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", font_size)
	if color.a > 0.0:
		title.add_theme_color_override("font_color", color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(on_close)
	header.add_child(close_btn)
