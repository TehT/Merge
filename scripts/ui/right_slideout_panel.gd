extends PanelContainer
class_name RightSlideoutPanel
## RightSlideoutPanel — secondary pop-out panel on the right side,
## mirroring SlideoutPanel's role on the left (registers itself in
## _ready() as Game.right_slideout_panel — see game.gd). Owns the panel
## chrome; content-building for each type lives in its own script
## (right_slideout_view_*.gd), same thin-dispatcher split as SlideoutPanel.
## Hosts "detail/action" screens that don't belong as a persistent
## RightSidebar tab — hiring recruits today, transferring equipment
## between bases later. RootUI positions this (sliding out to the left of
## RightSidebar) and will auto-dismiss the left SlideoutPanel if opening
## this one would visually overlap it, and vice versa — see
## root_ui.gd._slideouts_would_overlap().

const RightSlideoutViewHire := preload("res://scripts/ui/right_slideout_view_hire.gd")

enum _Mode { NONE, HIRE }

var _content: VBoxContainer
var _mode: _Mode = _Mode.NONE


func _ready() -> void:
	Game.right_slideout_panel = self
	visible = false
	custom_minimum_size.x = 260

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	style.border_color = Color(0.2, 0.22, 0.28, 1.0)
	style.border_width_left = 1
	style.set_corner_radius_all(0)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func show_hire() -> void:
	if _mode == _Mode.HIRE and visible:
		dismiss()
		return

	_mode = _Mode.HIRE
	_clear_content()
	var view: VBoxContainer = RightSlideoutViewHire.new()
	_content.add_child(view)
	view.populate(dismiss)
	visible = true


func dismiss() -> void:
	visible = false
	_mode = _Mode.NONE


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()
