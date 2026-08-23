extends PanelContainer
## SlideoutPanel — secondary pop-out panel loader. Owns the panel chrome
## (styling, scroll area) and which content type is active; the actual
## content-building for each type lives in its own script
## (slideout_view_*.gd) so this file stays a thin dispatcher. Doubles as a
## drill-down for proficiency skills (clicking a proficiency bar), the
## squad picker for deploying a team to an event (clicking "Deploy Team"),
## and a vehicle info card (clicking a fleet vehicle in the HQ panel).

const SlideoutViewProficiency := preload("res://scripts/ui/slideout_view_proficiency.gd")
const SlideoutViewDeploy := preload("res://scripts/ui/slideout_view_deploy.gd")
const SlideoutViewVehicle := preload("res://scripts/ui/slideout_view_vehicle.gd")

enum _Mode { NONE, PROFICIENCY, DEPLOY, VEHICLE }

var _content: VBoxContainer
var _mode: _Mode = _Mode.NONE
var _active_prof_key: String = ""
var _active_agent: AgentData
var _active_event: EventData
var _active_vehicle: VehicleData


func _ready() -> void:
	visible = false
	custom_minimum_size.x = 260

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	style.border_color = Color(0.2, 0.22, 0.28, 1.0)
	style.border_width_right = 1
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


func show_proficiency(agent: AgentData, prof_key: String) -> void:
	if _mode == _Mode.PROFICIENCY and _active_agent == agent and _active_prof_key == prof_key and visible:
		dismiss()
		return

	_mode = _Mode.PROFICIENCY
	_active_agent = agent
	_active_prof_key = prof_key
	_clear_content()
	var view: VBoxContainer = SlideoutViewProficiency.new()
	_content.add_child(view)
	view.populate(agent, prof_key, dismiss)
	visible = true


func show_deploy_teams(ev: EventData) -> void:
	if _mode == _Mode.DEPLOY and _active_event == ev and visible:
		dismiss()
		return

	_mode = _Mode.DEPLOY
	_active_event = ev
	_clear_content()
	var view: VBoxContainer = SlideoutViewDeploy.new()
	_content.add_child(view)
	view.populate(ev, dismiss)
	visible = true


func show_vehicle(vehicle: VehicleData) -> void:
	if _mode == _Mode.VEHICLE and _active_vehicle == vehicle and visible:
		dismiss()
		return

	_mode = _Mode.VEHICLE
	_active_vehicle = vehicle
	_clear_content()
	var view: VBoxContainer = SlideoutViewVehicle.new()
	_content.add_child(view)
	view.populate(vehicle, dismiss)
	visible = true


func dismiss() -> void:
	visible = false
	_mode = _Mode.NONE
	_active_prof_key = ""
	_active_agent = null
	_active_event = null
	_active_vehicle = null


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()
