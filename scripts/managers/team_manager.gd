extends Node
class_name TeamManager
## TeamManager — a persistent node in Main.tscn, referenced elsewhere via
## Game.team_manager (registers itself in _ready() — see game.gd). Owns
## the player's teams (3-5 agents each) and their cohesion. Must be listed
## AFTER AgentManager and BaseManager as a sibling in Main.tscn: the
## starting team is built from Game.agent_manager's roster and placed at
## Game.base_manager's primary base, both in _ready(), which requires
## those managers' own _ready() (where the roster/bases are populated,
## and where they register themselves into Game) to have already run.

signal team_created(team: TeamData)
signal cohesion_changed(team_id: String, new_value: float, delta: float)
signal training_started(team_id: String)
signal training_completed(team_id: String)
signal membership_changed(team_id: String)
signal team_renamed(team_id: String)
signal team_departed(team_id: String)
signal team_arrived(team_id: String, event_id: String)

@export var mission_cohesion_gain: float = 8.0
@export var training_cohesion_gain: float = 12.0
@export var training_days: int = 2

var teams: Array[TeamData] = []

## team id -> days remaining. Presence in this dict is what "in training" means.
var _training: Dictionary = {}

func _ready() -> void:
	Game.team_manager = self
	Game.game_clock.day_advanced.connect(_on_day_advanced)
	var starting := _create_starting_team()
	if starting:
		teams.append(starting)
		print("[TeamManager] %s" % starting.get_status_summary())

## Groups the whole starting roster into one team. Works out of the box
## since the roster is exactly 4 agents (within TeamData's 3-5 range);
## revisit if the starting roster size ever changes.
func _create_starting_team() -> TeamData:
	var ids: Array[String] = []
	for a in Game.agent_manager.roster:
		ids.append(a.id)
	if ids.size() < TeamData.MIN_SIZE:
		push_warning("[TeamManager] starting roster too small to form a team.")
		return null
	return _at_hq(TeamData.new().setup("Alpha Team", ids))

func _at_hq(team: TeamData) -> TeamData:
	var hq := Game.base_manager.get_primary_base()
	team.location = hq.location
	team.location_name = hq.base_name
	return team

func _on_day_advanced(_day: int) -> void:
	for team_id in _training.keys().duplicate():
		_training[team_id] -= 1
		if _training[team_id] <= 0:
			_finish_training(team_id)

## Travel arrival and on-site mission completion both need sub-day
## precision (a short hop or a quick mission shouldn't wait for the next
## day-tick), so both are checked every frame here rather than on
## day_advanced.
func _process(_delta: float) -> void:
	if teams.is_empty():
		return
	var now: float = Game.game_clock.get_current_time_days()
	for team in teams:
		if team.is_traveling and now >= team.travel_arrival_day:
			_complete_travel(team)
		elif team.is_on_mission and now >= team.mission_ready_day:
			_complete_mission_work(team)

## Mechanics shared by every leg of a journey, whether it's the first leg
## of a fresh trip or a subsequent one continued from _complete_travel:
## picks up leg.vehicle (see _pickup_vehicle), marks the team traveling
## toward leg.to, marks available members DEPLOYED (a no-op for members
## already DEPLOYED from an earlier leg — AgentManager.set_status() guards
## on old==new), emits team_departed. Does NOT touch the terminal-intent
## flags (travel_event_id/travel_is_relocation/travel_is_return/
## travel_return_to) — those are set once, by whichever top-level function
## starts the whole journey, and stay untouched across every leg until
## travel_queued_legs empties out.
func _start_leg(team: TeamData, leg: Dictionary) -> void:
	var vehicle: VehicleData = leg["vehicle"]
	_pickup_vehicle(team, vehicle)
	var now: float = Game.game_clock.get_current_time_days()

	team.is_traveling = true
	team.travel_destination = leg["to"]
	team.travel_destination_name = leg["to_name"]
	team.travel_departure_day = now
	team.travel_arrival_day = now + leg["travel_hours"] / 24.0
	team.travel_vehicle_name = vehicle.vehicle_name

	for agent_id in team.member_ids:
		var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
		if a != null and a.is_available():
			Game.agent_manager.set_status(agent_id, AgentData.Status.DEPLOYED)

	team_departed.emit(team.id)
	print("[TeamManager] %s departed for %s via %s (%.0f km, %s)" % [
		team.team_name, leg["to_name"], vehicle.vehicle_name, leg["distance_km"],
		VehicleData.format_duration(leg["travel_hours"]),
	])

## Removes `vehicle` from wherever it currently sits (a base's fleet) and
## attaches it to `team` — a vehicle in transit belongs exclusively to
## whichever team is using it, so no other team's route search can find it
## (TravelRouter only ever looks at BaseData.vehicles). No-op if the team
## already holds this exact vehicle (e.g. continuing straight on from a
## mission site with nowhere to have dropped it off).
func _pickup_vehicle(team: TeamData, vehicle: VehicleData) -> void:
	if team.current_vehicle == vehicle:
		return
	for base: BaseData in Game.base_manager.bases:
		if base.vehicles.has(vehicle):
			base.vehicles.erase(vehicle)
			break
	team.current_vehicle = vehicle

## Parks the team's current vehicle at `base` (back in its fleet, so
## another team's route search can find it again) and clears
## team.current_vehicle. No-op if the team isn't holding one. Called on
## every arrival at a base — including a relay stop, where _start_leg's
## next _pickup_vehicle() call may immediately re-attach the very same
## vehicle if that's genuinely the best pick again, which is equivalent to
## never letting go of it.
func _release_vehicle(team: TeamData, base: BaseData) -> void:
	if team.current_vehicle == null:
		return
	base.vehicles.append(team.current_vehicle)
	team.current_vehicle = null

## Sums a route's legs into the plan dict shape callers/UI expect
## ({distance_km, travel_hours, arrival_time, vehicle_name}), plus the
## full leg list (for a per-leg breakdown — see detail_view_result.gd).
## arrival_time/vehicle_name describe the *first* leg's departure moment
## and vehicle isn't meaningful for a multi-leg route the same way it is
## for a 1-leg one, but distance_km/travel_hours are always real totals.
func _summarize_route(route: Array) -> Dictionary:
	var now: float = Game.game_clock.get_current_time_days()
	var first_leg: Dictionary = route[0]
	return {
		"distance_km": TravelRouter.total_distance_km(route),
		"travel_hours": TravelRouter.total_hours(route),
		"arrival_time": now + TravelRouter.total_hours(route) / 24.0,
		"vehicle_name": (first_leg["vehicle"] as VehicleData).vehicle_name,
		"legs": route,
	}

## Starts a team on a (possibly multi-leg) journey toward a mission.
## `route` comes from TravelRouter.find_routes(..., final_role=TACTICAL,
## ...) — the player-chosen one, from the deploy UI's route picker. Only
## the final leg is a TACTICAL hop; any earlier legs are TRANSPORT relays.
## Marks members DEPLOYED — actual mission resolution happens later, on
## arrival (EventManager listens for team_arrived), once every queued leg
## has been flown.
func begin_travel_route(team_id: String, route: Array, event_id: String) -> Dictionary:
	var team := get_team(team_id)
	if team == null or route.is_empty():
		return {}

	# Remember where they set out from so begin_return_travel() knows where
	# "home" is once the mission concludes, without hardcoding HQ (matters
	# once multiple bases exist).
	team.travel_return_to = team.location
	team.travel_return_to_name = team.location_name
	team.travel_is_return = false
	team.travel_is_relocation = false
	team.travel_event_id = event_id
	team.travel_queued_legs.assign(route.slice(1))
	_start_leg(team, route[0])
	return _summarize_route(route)

## Relocates a team to a different base, possibly via relay bases — the
## base-to-base counterpart to begin_travel_route(). `route` comes from
## TravelRouter.find_routes(..., final_role=TRANSPORT, ...) via the
## relocation UI's route picker; every leg (including the last) is
## TRANSPORT. No event, no return leg — see TeamData.travel_is_relocation
## for what that changes on final arrival.
func begin_base_transfer_route(team_id: String, route: Array) -> Dictionary:
	var team := get_team(team_id)
	if team == null or route.is_empty():
		return {}

	team.travel_is_relocation = true
	team.travel_is_return = false
	team.travel_event_id = ""
	team.travel_queued_legs.assign(route.slice(1))
	_start_leg(team, route[0])
	return _summarize_route(route)

## Sends a team back toward a base after a mission concludes — routed via
## TravelRouter (possibly multi-leg), auto-picking the fastest route with
## no player involvement, since this fires reactively once the mission
## resolves. Members stay DEPLOYED (set by begin_travel_route and never
## reverted) until _complete_travel applies their real outcome statuses on
## the final arrival — so a team is genuinely unavailable for the whole
## round trip, not just the outbound leg.
##
## If any agent came back INJURED or KIA, the team diverts to the nearest
## base to their current location instead of trekking all the way back to
## where they departed from — wounded agents get to safety fastest, not
## the full journey home. Either way this is travel_is_return=true, since
## that flag's meaning ("apply pending_agent_results on final arrival") is
## correct regardless of which base they actually land at.
func begin_return_travel(team_id: String) -> void:
	var team := get_team(team_id)
	if team == null:
		return

	var casualty := false
	for status: AgentData.Status in team.pending_agent_results.values():
		if status == AgentData.Status.INJURED or status == AgentData.Status.KIA:
			casualty = true
			break

	var target_base: BaseData = Game.base_manager.get_nearest_base(team.location) if casualty \
			else Game.base_manager.get_base_at(team.travel_return_to)

	if target_base == null:
		# Couldn't resolve a real base (e.g. travel_return_to's coordinate
		# doesn't exactly match a known base) -- fall back to the raw
		# coordinate directly, same as today's pre-routing behavior.
		team.travel_is_return = true
		_begin_return_flat(team, team.travel_return_to, team.travel_return_to_name)
		return

	team.travel_is_return = true
	var routes := TravelRouter.find_routes(team.location, team.location_name,
			target_base.location, target_base.base_name, team.member_ids.size(),
			VehicleData.Role.TRANSPORT, Game.base_manager.bases, team.current_vehicle)

	if routes.is_empty():
		_begin_return_flat(team, target_base.location, target_base.base_name)
		return

	team.travel_queued_legs.assign(routes[0].slice(1))
	_start_leg(team, routes[0][0])

## Always-succeeds fallback for when no real route can be found (stranded
## edge case) — a flat, vehicleless 24h trip home, matching this
## project's existing degrade-gracefully behavior for "no vehicle found."
func _begin_return_flat(team: TeamData, destination: Vector2, destination_name: String) -> void:
	var now: float = Game.game_clock.get_current_time_days()
	team.is_traveling = true
	team.travel_destination = destination
	team.travel_destination_name = destination_name
	team.travel_departure_day = now
	team.travel_arrival_day = now + 1.0
	team.travel_queued_legs = []

	team_departed.emit(team.id)
	print("[TeamManager] %s began return trip to %s (no vehicle found, flat 24h)" % [
		team.team_name, destination_name,
	])

func _complete_travel(team: TeamData) -> void:
	team.location = team.travel_destination
	team.location_name = team.travel_destination_name
	team.is_traveling = false

	# Parks the vehicle here if this arrival is at a real base (relay stop
	# or final arrival alike) — a mission site owns no fleet, so away from
	# every base the vehicle just stays with the team (get_base_at returns
	# null there, so this is a no-op).
	var arrived_base := Game.base_manager.get_base_at(team.location)
	if arrived_base != null:
		_release_vehicle(team, arrived_base)

	if not team.travel_queued_legs.is_empty():
		var next_leg: Dictionary = team.travel_queued_legs.pop_front()
		_start_leg(team, next_leg)
		return

	if team.travel_is_relocation:
		team.travel_is_relocation = false
		for agent_id in team.member_ids:
			var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
			if a != null and a.status == AgentData.Status.DEPLOYED:
				Game.agent_manager.set_status(agent_id, AgentData.Status.AVAILABLE)
		print("[TeamManager] %s relocated to %s" % [team.team_name, team.location_name])
		team_arrived.emit(team.id, "") # empty event_id = "nothing to resolve"
		return

	if team.travel_is_return:
		team.travel_is_return = false
		for agent_id: String in team.pending_agent_results:
			Game.agent_manager.set_status(agent_id, team.pending_agent_results[agent_id])
		team.pending_agent_results.clear()
		print("[TeamManager] %s returned to %s" % [team.team_name, team.location_name])
		team_arrived.emit(team.id, "") # empty event_id = "just a return, nothing to resolve"
		return

	var event_id := team.travel_event_id
	team.travel_event_id = ""
	print("[TeamManager] %s arrived at %s" % [team.team_name, team.location_name])

	var event: EventData = Game.event_manager.get_event_by_id(event_id) if event_id != "" else null
	if event != null and event.mission_duration_hours > 0.0:
		team.is_on_mission = true
		team.mission_event_id = event_id
		team.mission_ready_day = Game.game_clock.get_current_time_days() + event.mission_duration_hours / 24.0
	else:
		team_arrived.emit(team.id, event_id)

## Fires once a team's on-site mission_duration_hours has elapsed — the
## same team_arrived signal EventManager already resolves missions on,
## just delayed past physical arrival by however long the event takes to
## actually work. Kept as the same signal so EventManager's resolution
## hook needs no changes for this middle leg to exist.
func _complete_mission_work(team: TeamData) -> void:
	team.is_on_mission = false
	var event_id := team.mission_event_id
	team.mission_event_id = ""
	print("[TeamManager] %s finished working the mission at %s" % [team.team_name, team.location_name])
	team_arrived.emit(team.id, event_id)

func create_empty_team(team_name: String) -> TeamData:
	var empty_ids: Array[String] = []
	var team := _at_hq(TeamData.new().setup(team_name, empty_ids))
	teams.append(team)
	team_created.emit(team)
	return team

func rename_team(team_id: String, new_name: String) -> void:
	var team := get_team(team_id)
	if team == null:
		return
	team.team_name = new_name
	team_renamed.emit(team_id)

func create_team(team_name: String, agent_ids: Array[String]) -> TeamData:
	if agent_ids.size() < TeamData.MIN_SIZE or agent_ids.size() > TeamData.MAX_SIZE:
		push_warning("[TeamManager] team size must be %d-%d, got %d" % [
			TeamData.MIN_SIZE, TeamData.MAX_SIZE, agent_ids.size()])
		return null
	for agent_id in agent_ids:
		if get_team_of_agent(agent_id) != null:
			push_warning("[TeamManager] agent %s is already on a team" % agent_id)
			return null

	var team := _at_hq(TeamData.new().setup(team_name, agent_ids))
	teams.append(team)
	team_created.emit(team)
	return team

func get_team(team_id: String) -> TeamData:
	for t in teams:
		if t.id == team_id:
			return t
	return null

func get_team_of_agent(agent_id: String) -> TeamData:
	for t in teams:
		if t.has_member(agent_id):
			return t
	return null

## Where an agent currently is, for base-local systems (equip-picking) to
## filter by: the base matching their team's current location, or
## BaseManager's primary base if they're not on a team at all (an
## unassigned roster agent is treated as sitting at HQ, the same default
## a brand-new team starts at). Returns null if their team is away from
## every known base right now (traveling, or on-site at a mission) --
## nothing base-local is reachable there.
func get_agent_base(agent_id: String) -> BaseData:
	var team := get_team_of_agent(agent_id)
	if team == null:
		return Game.base_manager.get_primary_base()
	return Game.base_manager.get_base_at(team.location)

## Atomically replaces one member with another (e.g. backfilling an
## injured slot). Cuts cohesion proportionally — losing 1 of n members'
## worth of built rapport — rather than resetting it outright, since only
## part of the group dynamic changed.
func swap_member(team_id: String, old_agent_id: String, new_agent_id: String) -> bool:
	var team := get_team(team_id)
	if team == null:
		return false
	var idx := team.member_ids.find(old_agent_id)
	if idx == -1:
		return false
	if get_team_of_agent(new_agent_id) != null:
		push_warning("[TeamManager] agent %s is already on a team" % new_agent_id)
		return false

	var n := team.member_ids.size()
	team.member_ids[idx] = new_agent_id
	_set_cohesion(team, team.cohesion * float(n - 1) / float(n))
	membership_changed.emit(team_id)
	print("[TeamManager] %s swapped a member (cohesion now %.1f)" % [team.team_name, team.cohesion])
	return true

func add_member(team_id: String, agent_id: String) -> bool:
	var team := get_team(team_id)
	if team == null:
		return false
	if team.member_ids.size() >= TeamData.MAX_SIZE:
		push_warning("[TeamManager] %s is full (%d/%d)" % [team.team_name, team.member_ids.size(), TeamData.MAX_SIZE])
		return false
	if get_team_of_agent(agent_id) != null:
		push_warning("[TeamManager] agent %s is already on a team" % agent_id)
		return false
	team.member_ids.append(agent_id)
	var n := team.member_ids.size()
	_set_cohesion(team, team.cohesion * float(n - 1) / float(n))
	membership_changed.emit(team_id)
	print("[TeamManager] %s added a member (%d/%d, cohesion %.1f)" % [team.team_name, n, TeamData.MAX_SIZE, team.cohesion])
	return true


func remove_member(team_id: String, agent_id: String) -> bool:
	var team := get_team(team_id)
	if team == null:
		return false
	var idx := team.member_ids.find(agent_id)
	if idx == -1:
		return false
	team.member_ids.remove_at(idx)
	var n := team.member_ids.size()
	if n > 0:
		_set_cohesion(team, team.cohesion * float(n) / float(n + 1))
	membership_changed.emit(team_id)
	print("[TeamManager] %s removed a member (%d/%d, cohesion %.1f)" % [team.team_name, n, TeamData.MAX_SIZE, team.cohesion])
	return true


## Called by EventManager whenever this team completes a mission (any
## outcome — bonding happens by working together, not just by winning).
func grant_mission_cohesion(team_id: String) -> void:
	var team := get_team(team_id)
	if team == null:
		return
	_set_cohesion(team, team.cohesion + mission_cohesion_gain)

## Sends every member of the team to Training for training_days. Requires
## the whole team to currently be Available (can't train while deployed,
## injured, or already training).
func start_training(team_id: String) -> bool:
	var team := get_team(team_id)
	if team == null or _training.has(team_id):
		return false
	for agent_id in team.member_ids:
		var a: AgentData = Game.agent_manager.get_agent_by_id(agent_id)
		if a == null or not a.is_available():
			return false

	for agent_id in team.member_ids:
		Game.agent_manager.set_status(agent_id, AgentData.Status.TRAINING)
	_training[team_id] = training_days
	training_started.emit(team_id)
	print("[TeamManager] %s began training (%d days)" % [team.team_name, training_days])
	return true

func _finish_training(team_id: String) -> void:
	_training.erase(team_id)
	var team := get_team(team_id)
	if team == null:
		return
	for agent_id in team.member_ids:
		Game.agent_manager.set_status(agent_id, AgentData.Status.AVAILABLE)
	_set_cohesion(team, team.cohesion + training_cohesion_gain)
	training_completed.emit(team_id)
	print("[TeamManager] %s finished training (cohesion now %.1f)" % [team.team_name, team.cohesion])

## Days left in training, or 0 if the team isn't currently training.
func get_training_days_left(team_id: String) -> int:
	return _training.get(team_id, 0)

func _set_cohesion(team: TeamData, new_value: float) -> void:
	var old := team.cohesion
	team.cohesion = clampf(new_value, 0.0, 100.0)
	if not is_equal_approx(team.cohesion, old):
		cohesion_changed.emit(team.id, team.cohesion, team.cohesion - old)

func print_team_status() -> void:
	print("[TeamManager] %d team(s):" % teams.size())
	for t in teams:
		var training_note := " [training, %d days left]" % _training[t.id] if _training.has(t.id) else ""
		print("  %s — members=%s%s" % [t.get_status_summary(), t.member_ids, training_note])
