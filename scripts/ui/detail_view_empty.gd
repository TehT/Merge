extends "res://scripts/ui/detail_view_base.gd"
## DetailViewEmpty — the "select an agent or event to view details" hint
## the left detail panel falls back to when nothing is selected. Its own
## view so PanelHost can list it in the registry like any other content,
## rather than the panel needing a special empty-state code path.

func populate(_data: Variant, _dismiss: Callable) -> void:
	var hint := Label.new()
	hint.text = "Select an agent or event to view details."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	add_child(hint)
