extends VBoxContainer
## DetailSidebar — left sidebar loader. Owns which view is currently shown
## and the signal wiring that decides when to refresh it; the actual
## content-building for each view type lives in its own script
## (detail_view_*.gd) so this file stays a thin dispatcher instead of a
## monolith covering all five view types.

const DetailViewAgent := preload("res://scripts/ui/detail_view_agent.gd")
const DetailViewTeam := preload("res://scripts/ui/detail_view_team.gd")
const DetailViewEvent := preload("res://scripts/ui/detail_view_event.gd")
const DetailViewResult := preload("res://scripts/ui/detail_view_result.gd")
const DetailViewHQ := preload("res://scripts/ui/detail_view_hq.gd")

enum _View { EMPTY, AGENT, TEAM, EVENT, RESULT, HQ }

var _view: _View = _View.EMPTY
var _view_agent: AgentData
var _view_team: TeamData
var _view_event: EventData
var _refresh_pending := false

func _ready() -> void:
	add_theme_constant_override("separation", 6)

	%TeamManager.membership_changed.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.cohesion_changed.connect(func(_tid: String, _v: float, _d: float) -> void: _schedule_refresh())
	%TeamManager.training_started.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.training_completed.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.team_departed.connect(func(_tid: String) -> void: _schedule_refresh())
	%TeamManager.team_arrived.connect(func(_tid: String, _eid: String) -> void: _schedule_refresh())
	%TeamManager.team_created.connect(func(_t: TeamData) -> void: _schedule_refresh())
	%TeamManager.team_renamed.connect(func(_tid: String) -> void: _schedule_refresh())
	%AgentManager.agent_status_changed.connect(func(_aid: String, _o: AgentData.Status, _n: AgentData.Status) -> void: _schedule_refresh())
	%AgentManager.roster_changed.connect(_schedule_refresh)
	%EventManager.event_resolved.connect(_on_mission_resolved)

	show_empty()


func _schedule_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	_refresh_view.call_deferred()


func _refresh_view() -> void:
	_refresh_pending = false
	match _view:
		_View.AGENT:
			if _view_agent:
				show_agent(_view_agent)
		_View.TEAM:
			if _view_team:
				show_team(_view_team)
		_View.HQ:
			show_hq()


func show_agent(agent: AgentData) -> void:
	_view = _View.AGENT
	_view_agent = agent
	_clear()
	var view: VBoxContainer = DetailViewAgent.new()
	add_child(view)
	view.populate(agent)


func show_team(team: TeamData) -> void:
	_view = _View.TEAM
	_view_team = team
	_clear()
	var view: VBoxContainer = DetailViewTeam.new()
	add_child(view)
	view.populate(team)


func show_event(ev: EventData) -> void:
	_view = _View.EVENT
	_view_event = ev
	_clear()
	var view: VBoxContainer = DetailViewEvent.new()
	add_child(view)
	view.populate(ev)


func show_hq() -> void:
	_view = _View.HQ
	_clear()
	var view: VBoxContainer = DetailViewHQ.new()
	add_child(view)
	view.populate()


## Mission resolution now happens whenever a traveling team arrives (see
## TeamManager.team_arrived / EventManager._on_team_arrived), which can be
## days after the player clicked Deploy and long after they've moved on to
## something else — so the report pops up on its own rather than only
## showing right after a Deploy click.
func _on_mission_resolved(ev: EventData, result: Dictionary) -> void:
	show_mission_result(result.get("team_name", "Squad"), ev.title, result)


func show_mission_result(team_name: String, ev_title: String, result: Dictionary) -> void:
	_view = _View.RESULT
	_clear()
	var view: VBoxContainer = DetailViewResult.new()
	add_child(view)
	view.populate_mission_result(team_name, ev_title, result, show_empty)


func show_travel_confirmation(team_name: String, ev_title: String, plan: Dictionary) -> void:
	_view = _View.RESULT
	_clear()
	var view: VBoxContainer = DetailViewResult.new()
	add_child(view)
	view.populate_travel_confirmation(team_name, ev_title, plan, show_empty)


func show_empty() -> void:
	_view = _View.EMPTY
	_view_agent = null
	_view_team = null
	_view_event = null
	_clear()
	var hint := Label.new()
	hint.text = "Select an agent or event to view details."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
	add_child(hint)


func _clear() -> void:
	%SkillSlideout.dismiss()
	for child in get_children():
		child.queue_free()
