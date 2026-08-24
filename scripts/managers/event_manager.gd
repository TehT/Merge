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
signal event_resolved(event: EventData, team_name: String, result: MissionResolutionResult)

var active_events: Array[EventData] = []

var magic_intensity: float = 1.0
@export var magic_intensity_growth_per_day: float = 0.02
@export var base_spawn_chance_per_day: float = 0.35

## The "black box" mission resolver — Strategy pattern (see
## scripts/managers/resolution/). A live default instance (rather than
## null) so the Inspector shows a populated, expandable resource on this
## node from the start — an unset Resource-typed @export shows as
## "[empty]" with nothing to click into. Swap it in the Inspector (drag in
## a different strategy .tres, or use the dropdown arrow to pick "New
## GauntletResolutionStrategy" once one exists), or reassign it at
## runtime (Game.event_manager.resolution_strategy = X.new()), without
## touching any of the spawn/travel/arrival logic below.
@export var resolution_strategy: MissionResolutionStrategy = StatCheckResolutionStrategy.new()

@onready var _geo_data: GeoData = Game.geo_data

## Spawn pool, loaded from saved EventData resources (see
## res://data/event_templates/) — each one a base profile (type, urgency,
## proficiency requirements, time limit, escalation) that spawn_random_event()
## duplicates and fills in with a fresh id/location. Adding or rebalancing
## an event type is a .tres edit, not a code change.
@export var spawn_templates: Array[EventData] = [
]

## Escalation-only profiles — not part of the random spawn pool, only
## reached via _spawn_escalation() looking up an expiring event's
## escalates_to type.
@export var escalation_templates: Array[EventData] = [
]

func _ready() -> void:
	Game.event_manager = self
	if resolution_strategy == null:
		resolution_strategy = StatCheckResolutionStrategy.new()
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

func spawn_random_event(template_override: EventData = null) -> EventData:
	if template_override == null and spawn_templates.is_empty():
		return null
	var tmpl: EventData = template_override if template_override != null \
		else spawn_templates[randi() % spawn_templates.size()]

	## duplicate(true) so this spawn gets its own copies of the template's
	## arrays (tags, decision options, ...) rather than sharing them with
	## every other event spawned from the same template.
	var event: EventData = tmpl.duplicate(true)
	event.setup(tmpl.get_type_name(), tmpl.event_type, tmpl.urgency)

	var bonus: int = int(magic_intensity - 1.0)
	event.req_combat = mini(event.req_combat + bonus, 10) if event.req_combat > 0 else 0
	event.req_subterfuge = mini(event.req_subterfuge + bonus, 10) if event.req_subterfuge > 0 else 0
	event.req_attunement = mini(event.req_attunement + bonus, 10) if event.req_attunement > 0 else 0
	event.req_erudition = mini(event.req_erudition + bonus, 10) if event.req_erudition > 0 else 0
	event.req_influence = mini(event.req_influence + bonus, 10) if event.req_influence > 0 else 0
	event.req_ingenuity = mini(event.req_ingenuity + bonus, 10) if event.req_ingenuity > 0 else 0

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
	if escalation_templates.is_empty():
		return
	var tmpl := _find_template_for_type(parent.escalates_to)
	var child := spawn_random_event(tmpl)
	if child == null:
		return
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

	var result := resolution_strategy.resolve(event, members)
	_backfill_agent_results(members, result)
	_apply_resolution(event, result)
	Game.team_manager.grant_mission_cohesion(team_id)

	# Agents keep their DEPLOYED status until the team is physically back —
	# their real outcome (available/injured/KIA) applies on the return leg.
	team.pending_agent_results = result.agent_results.duplicate()
	Game.team_manager.begin_return_travel(team_id)

	event_resolved.emit(event, team.team_name, result)
	print("[EventManager] %s resolved %s -> %s (suitability=%.2f chance=%.2f roll=%.2f)" % [
		team.team_name, event.title, MissionResolutionResult.outcome_name(result.outcome),
		result.team_suitability, result.chance, result.roll,
	])
	_print_resolution_log(result)

func resolve_event_solo(event_id: String, agent_id: String) -> MissionResolutionResult:
	var event := get_event_by_id(event_id)
	if event == null:
		return null

	var agent: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
	if agent == null or not agent.is_available():
		return null

	var result := resolution_strategy.resolve(event, [agent])
	_backfill_agent_results([agent], result)
	_apply_resolution(event, result)
	for aid: String in result.agent_results:
		Game.agent_manager.set_status(aid, result.agent_results[aid])

	event_resolved.emit(event, agent.agent_name, result)
	print("[EventManager] %s resolved %s solo -> %s (suitability=%.2f chance=%.2f roll=%.2f)" % [
		agent.agent_name, event.title, MissionResolutionResult.outcome_name(result.outcome),
		result.team_suitability, result.chance, result.roll,
	])
	_print_resolution_log(result)
	return result

## Prints whatever trace the resolution strategy left on the result (see
## MissionResolutionResult.log_lines) — the detailed "why", underneath
## the one-line summary every strategy already gets. A strategy that
## doesn't populate a log just prints nothing extra here.
func _print_resolution_log(result: MissionResolutionResult) -> void:
	for line: String in result.log_lines:
		print("    " + line)

## Fills in AVAILABLE for any squad member a resolution strategy left out
## of agent_results. Strategies are a Strategy-pattern black box (see
## MissionResolutionStrategy) — a future one might only ever mention
## agents whose status actually changes, and an agent it never mentions
## shouldn't get stranded DEPLOYED forever for it. No status change means
## they came home safe.
func _backfill_agent_results(members: Array[AgentData], result: MissionResolutionResult) -> void:
	for member: AgentData in members:
		if not result.agent_results.has(member.id):
			result.agent_results[member.id] = AgentData.Status.AVAILABLE

func _apply_resolution(event: EventData, result: MissionResolutionResult) -> void:
	match result.outcome:
		MissionResolutionResult.Outcome.SUCCESS:
			Game.resource_state.earn_funding(event.reward_funding)
			Game.resource_state.earn_intel(event.reward_intel)
			Game.concealment_state.add(event.concealment_on_success)
			event.status = EventData.Status.RESOLVED_SUCCESS
		MissionResolutionResult.Outcome.PARTIAL:
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

func _find_template_for_type(event_type: EventData.EventType) -> EventData:
	for tmpl: EventData in spawn_templates:
		if tmpl.event_type == event_type:
			return tmpl
	for tmpl: EventData in escalation_templates:
		if tmpl.event_type == event_type:
			return tmpl
	return spawn_templates[0] if not spawn_templates.is_empty() else null
