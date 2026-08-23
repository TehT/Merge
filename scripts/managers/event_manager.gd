extends Node
class_name EventManager
## EventManager — a persistent node in Main.tscn, referenced elsewhere via
## Game.event_manager (registers itself in _ready() — see game.gd).
## Spawns EventData instances at real city locations, ticks their timers
## on each game day, handles expiration (concealment + escalation), and
## resolves deployed missions.

signal event_spawned(event: EventData)
signal event_expired(event: EventData)
signal event_escalated(old_event: EventData, new_event: EventData)
signal event_resolved(event: EventData, result: Dictionary)

var active_events: Array[EventData] = []

var magic_intensity: float = 1.0
@export var magic_intensity_growth_per_day: float = 0.02
@export var base_spawn_chance_per_day: float = 0.35

@onready var _geo_data: GeoData = Game.geo_data

## Template "reqs" order: [combat, subterfuge, attunement, erudition, influence, ingenuity]
## Values are base proficiency ranks (0-5 early game). Scaled up by magic_intensity.
const _SPAWN_TEMPLATES: Array[Dictionary] = [
	{"type": EventData.EventType.CRYPTID_SIGHTING, "urgency": EventData.Urgency.LOW,
		"reqs": [1, 2, 0, 0, 0, 0], "days": 4, "can_escalate": false},
	{"type": EventData.EventType.MAGICAL_SURGE, "urgency": EventData.Urgency.MEDIUM,
		"reqs": [0, 0, 2, 1, 0, 1], "days": 3, "can_escalate": true,
		"escalates_to": EventData.EventType.PORTAL_BREACH},
	{"type": EventData.EventType.ARTIFACT_ACTIVATION, "urgency": EventData.Urgency.MEDIUM,
		"reqs": [0, 1, 1, 1, 0, 2], "days": 3, "can_escalate": false},
	{"type": EventData.EventType.CULT_ACTIVITY, "urgency": EventData.Urgency.HIGH,
		"reqs": [2, 1, 0, 0, 2, 0], "days": 3, "can_escalate": true,
		"escalates_to": EventData.EventType.PORTAL_BREACH},
	{"type": EventData.EventType.HAUNTING, "urgency": EventData.Urgency.LOW,
		"reqs": [0, 1, 2, 0, 0, 0], "days": 4, "can_escalate": false},
	{"type": EventData.EventType.FAIRY_INCURSION, "urgency": EventData.Urgency.MEDIUM,
		"reqs": [1, 0, 1, 1, 2, 0], "days": 3, "can_escalate": false},
]

const _ESCALATION_TEMPLATES: Array[Dictionary] = [
	{"type": EventData.EventType.PORTAL_BREACH, "urgency": EventData.Urgency.HIGH,
		"reqs": [1, 1, 3, 1, 0, 2], "days": 3, "can_escalate": false},
]

func _ready() -> void:
	Game.event_manager = self
	Game.game_clock.day_advanced.connect(_on_day_advanced)
	Game.team_manager.team_arrived.connect(_on_team_arrived)

func _on_day_advanced(_day: int) -> void:
	magic_intensity += magic_intensity_growth_per_day
	_tick_active_events()
	_maybe_spawn_event()

func _maybe_spawn_event() -> void:
	var chance: float = clampf(base_spawn_chance_per_day * magic_intensity, 0.0, 0.95)
	if randf() < chance:
		spawn_random_event()

func spawn_random_event(template_override: Dictionary = {}) -> EventData:
	var tmpl: Dictionary = template_override if not template_override.is_empty() \
		else _SPAWN_TEMPLATES[randi() % _SPAWN_TEMPLATES.size()]

	var event := EventData.new()
	event.setup(_title_for(tmpl.type), tmpl.type, tmpl.urgency)

	var bonus: int = int(magic_intensity - 1.0)
	var r: Array = tmpl.reqs
	event.set_proficiency_profile(
		mini(r[0] + bonus, 10) if r[0] > 0 else 0,
		mini(r[1] + bonus, 10) if r[1] > 0 else 0,
		mini(r[2] + bonus, 10) if r[2] > 0 else 0,
		mini(r[3] + bonus, 10) if r[3] > 0 else 0,
		mini(r[4] + bonus, 10) if r[4] > 0 else 0,
		mini(r[5] + bonus, 10) if r[5] > 0 else 0)
	event.time_limit_days = tmpl.days
	event.days_remaining = tmpl.days
	event.can_escalate = tmpl.get("can_escalate", false)
	if event.can_escalate:
		event.escalates_to = tmpl.escalates_to
		event.escalation_rank_bump = 1

	var city: Variant = _geo_data.get_random_city(50000) if _geo_data else null
	if city:
		event.location_city = city.name
		event.location_country = city.country
		event.geo_coordinates = Vector2(city.lon, city.lat)

	active_events.append(event)
	event_spawned.emit(event)
	print("[EventManager] Spawned %s at %s (urgency=%s, days=%d, reqs=%s)" % [
		event.title, event.location_city if event.location_city != "" else "unknown location",
		event.get_urgency_name(), event.time_limit_days, event.get_proficiency_requirements(),
	])
	return event

func _tick_active_events() -> void:
	for event in active_events.duplicate():
		if event.status != EventData.Status.ACTIVE:
			continue
		event.days_remaining -= 1
		if event.days_remaining <= 0:
			_handle_expiration(event)

func _handle_expiration(event: EventData) -> void:
	event.status = EventData.Status.EXPIRED
	Game.concealment_state.add(event.concealment_on_fail)
	active_events.erase(event)
	event_expired.emit(event)
	push_warning("[EventManager] %s expired unresolved (+%.1f concealment)" % [
		event.title, event.concealment_on_fail,
	])
	if event.can_escalate:
		_spawn_escalation(event)

func _spawn_escalation(parent: EventData) -> void:
	var tmpl := _find_template_for_type(parent.escalates_to)
	var child := spawn_random_event(tmpl)
	child.location_city = parent.location_city
	child.location_country = parent.location_country
	child.geo_coordinates = parent.geo_coordinates
	var bump: int = parent.escalation_rank_bump
	if child.req_combat > 0: child.req_combat = mini(child.req_combat + bump, 10)
	if child.req_subterfuge > 0: child.req_subterfuge = mini(child.req_subterfuge + bump, 10)
	if child.req_attunement > 0: child.req_attunement = mini(child.req_attunement + bump, 10)
	if child.req_erudition > 0: child.req_erudition = mini(child.req_erudition + bump, 10)
	if child.req_influence > 0: child.req_influence = mini(child.req_influence + bump, 10)
	if child.req_ingenuity > 0: child.req_ingenuity = mini(child.req_ingenuity + bump, 10)
	event_escalated.emit(parent, child)
	print("[EventManager] %s escalated into %s at %s" % [parent.title, child.title, child.location_city])

## Starts a team traveling to an event instead of resolving it immediately.
## Marks the event DEPLOYED (which pauses its days_remaining countdown —
## see _tick_active_events) and hands off to TeamManager.begin_travel() for
## the actual travel-time math. The mission resolves later, when
## TeamManager fires team_arrived. Returns the travel plan dict from
## begin_travel(), or {} if the event/team don't exist. vehicle_override
## forwards straight to begin_travel() (the deploy UI's dropdown pick);
## omit it to auto-select the best fleet vehicle.
func deploy_team(event_id: String, team_id: String, vehicle_override: VehicleData = null) -> Dictionary:
	var event := get_event_by_id(event_id)
	if event == null:
		return {}
	var team: TeamData = Game.team_manager.get_team(team_id)
	if team == null:
		push_warning("[EventManager] no such team: %s" % team_id)
		return {}

	var plan: Dictionary = Game.team_manager.begin_travel(
			team_id, event.geo_coordinates, event.location_city, event_id, vehicle_override)
	if plan.is_empty():
		return {}

	event.status = EventData.Status.DEPLOYED
	return plan

func _on_team_arrived(team_id: String, event_id: String) -> void:
	if event_id == "":
		return # team wasn't traveling for a mission (shouldn't happen, but be safe)

	var event := get_event_by_id(event_id)
	if event == null:
		return
	var team: TeamData = Game.team_manager.get_team(team_id)
	if team == null:
		return

	var members: Array[AgentData] = []
	for agent_id in team.member_ids:
		var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
		if a != null and a.status == AgentData.Status.DEPLOYED:
			members.append(a)

	var result := MissionResolver.resolve(event, members, team)
	result["team_name"] = team.team_name
	_apply_resolution(event, result)
	Game.team_manager.grant_mission_cohesion(team_id)

	# Agents keep their DEPLOYED status until the team is physically back —
	# their real outcome (available/injured/KIA) applies on the return leg.
	team.pending_agent_results = result.agent_results.duplicate()
	Game.team_manager.begin_return_travel(team_id)

	event_resolved.emit(event, result)
	print("[EventManager] %s resolved %s -> %s (suitability=%.2f chance=%.2f roll=%.2f)" % [
		team.team_name, event.title, result.outcome, result.team_suitability, result.chance, result.roll,
	])

func resolve_event_solo(event_id: String, agent_id: String) -> Dictionary:
	var event := get_event_by_id(event_id)
	if event == null:
		return {}

	var agent: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
	if agent == null or not agent.is_available():
		return {}

	var result := MissionResolver.resolve(event, [agent])
	_apply_resolution(event, result)
	for aid: String in result.agent_results:
		Game.agent_manager.set_status(aid, result.agent_results[aid])

	event_resolved.emit(event, result)
	print("[EventManager] %s resolved %s solo -> %s (suitability=%.2f chance=%.2f roll=%.2f)" % [
		agent.agent_name, event.title, result.outcome, result.team_suitability, result.chance, result.roll,
	])
	return result

func _apply_resolution(event: EventData, result: Dictionary) -> void:
	match result.outcome:
		"success":
			Game.resource_state.earn_funding(event.reward_funding)
			Game.resource_state.earn_intel(event.reward_intel)
			Game.concealment_state.add(event.concealment_on_success)
			event.status = EventData.Status.RESOLVED_SUCCESS
		"partial":
			Game.resource_state.earn_funding(int(event.reward_funding * 0.5))
			Game.resource_state.earn_intel(int(event.reward_intel * 0.5))
			Game.concealment_state.add(event.concealment_on_partial)
			event.status = EventData.Status.RESOLVED_PARTIAL
		_:
			Game.concealment_state.add(event.concealment_on_fail)
			event.status = EventData.Status.RESOLVED_FAIL

	event.resolution_roll = result.roll
	active_events.erase(event)

func get_active_events() -> Array[EventData]:
	return active_events

func get_event_by_id(event_id: String) -> EventData:
	for e in active_events:
		if e.id == event_id:
			return e
	return null

func _title_for(event_type: EventData.EventType) -> String:
	var stub := EventData.new()
	stub.event_type = event_type
	return stub.get_type_name()

func _find_template_for_type(event_type: EventData.EventType) -> Dictionary:
	for tmpl in _SPAWN_TEMPLATES:
		if tmpl.type == event_type:
			return tmpl
	for tmpl in _ESCALATION_TEMPLATES:
		if tmpl.type == event_type:
			return tmpl
	return _SPAWN_TEMPLATES[0]
