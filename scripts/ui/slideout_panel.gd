extends PanelContainer
class_name SlideoutPanel
## SlideoutPanel — secondary pop-out panel loader, referenced elsewhere
## via Game.slideout_panel (registers itself in _ready() — see game.gd;
## used instead of %SkillSlideout for the same dynamically-created-node
## reason detail_sidebar.gd uses Game.detail_sidebar). Owns the panel
## chrome (styling, scroll area) and which content type is active; the
## actual content-building for each type lives in its own script
## (slideout_view_*.gd) so this file stays a thin dispatcher. Doubles as a
## drill-down for proficiency skills (clicking a proficiency bar), the
## squad picker for deploying a team to an event (clicking "Deploy Team"),
## a vehicle info card (clicking a fleet vehicle in the HQ panel), an
## equipment info card with a transfer-to-another-location action
## (clicking a locker item in the Equipment tab), the equip/unequip
## picker for one of an agent's equipment
## slots (clicking a slot in the agent sheet), the Personality Matrix
## drill-down (clicking the Archetype row in the agent sheet), the
## event log (the small button below the left sidebar toggle), and the
## base-transport picker (clicking a stationary team's Location row).

const SlideoutViewProficiency := preload("res://scripts/ui/slideout_view_proficiency.gd")
const SlideoutViewDeploy := preload("res://scripts/ui/slideout_view_deploy.gd")
const SlideoutViewVehicle := preload("res://scripts/ui/slideout_view_vehicle.gd")
const SlideoutViewEquipment := preload("res://scripts/ui/slideout_view_equipment.gd")
const SlideoutViewEquipSlot := preload("res://scripts/ui/slideout_view_equip_slot.gd")
const SlideoutViewEventLog := preload("res://scripts/ui/slideout_view_event_log.gd")
const SlideoutViewPersonality := preload("res://scripts/ui/slideout_view_personality.gd")
const SlideoutViewBaseTransport := preload("res://scripts/ui/slideout_view_base_transport.gd")

enum _Mode { NONE, PROFICIENCY, DEPLOY, VEHICLE, EQUIPMENT_INFO, EQUIP_SLOT, EVENT_LOG, PERSONALITY, BASE_TRANSPORT }

var _content: VBoxContainer
var _mode: _Mode = _Mode.NONE
var _active_prof_key: String = ""
var _active_agent: AgentData
var _active_event: EventData
var _active_vehicle: VehicleData
var _active_equipment: EquipmentData
var _active_equipment_base_id: String = ""
var _active_slot_type: String = ""
var _active_team: TeamData


func _ready() -> void:
	Game.slideout_panel = self
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


## base_id is where item currently lives ("" for global_equipment, else a
## BaseData.id) — SlideoutViewEquipment needs it to build the transfer
## destination list (every other location) and to call
## BaseManager.transfer_equipment() with the right source.
func show_equipment_info(item: EquipmentData, base_id: String = "") -> void:
	if _mode == _Mode.EQUIPMENT_INFO and _active_equipment == item and visible:
		dismiss()
		return

	_mode = _Mode.EQUIPMENT_INFO
	_active_equipment = item
	_active_equipment_base_id = base_id
	_clear_content()
	var view: VBoxContainer = SlideoutViewEquipment.new()
	_content.add_child(view)
	view.populate(item, base_id, dismiss)
	visible = true


func show_equip_slot(agent: AgentData, slot_type: String) -> void:
	if _mode == _Mode.EQUIP_SLOT and _active_agent == agent and _active_slot_type == slot_type and visible:
		dismiss()
		return

	_mode = _Mode.EQUIP_SLOT
	_active_agent = agent
	_active_slot_type = slot_type
	_clear_content()
	var view: VBoxContainer = SlideoutViewEquipSlot.new()
	_content.add_child(view)
	view.populate(agent, slot_type, dismiss)
	visible = true


func show_event_log() -> void:
	if _mode == _Mode.EVENT_LOG and visible:
		dismiss()
		return

	_mode = _Mode.EVENT_LOG
	_clear_content()
	var view: VBoxContainer = SlideoutViewEventLog.new()
	_content.add_child(view)
	view.populate(dismiss)
	visible = true


func show_personality(agent: AgentData) -> void:
	if _mode == _Mode.PERSONALITY and _active_agent == agent and visible:
		dismiss()
		return

	_mode = _Mode.PERSONALITY
	_active_agent = agent
	_clear_content()
	var view: VBoxContainer = SlideoutViewPersonality.new()
	_content.add_child(view)
	view.populate(agent, dismiss)
	visible = true


func show_base_transport(team: TeamData) -> void:
	if _mode == _Mode.BASE_TRANSPORT and _active_team == team and visible:
		dismiss()
		return

	_mode = _Mode.BASE_TRANSPORT
	_active_team = team
	_clear_content()
	var view: VBoxContainer = SlideoutViewBaseTransport.new()
	_content.add_child(view)
	view.populate(team, dismiss)
	visible = true


func dismiss() -> void:
	visible = false
	_mode = _Mode.NONE
	_active_prof_key = ""
	_active_agent = null
	_active_event = null
	_active_vehicle = null
	_active_equipment = null
	_active_equipment_base_id = ""
	_active_slot_type = ""
	_active_team = null


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()
