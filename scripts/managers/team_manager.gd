extends Node
## TeamManager — a persistent node in Main.tscn, referenced elsewhere via
## its scene-unique name (%TeamManager). Owns the player's teams (3-5
## agents each) and their cohesion. Must be listed AFTER AgentManager as a
## sibling in Main.tscn: the starting team is built from %AgentManager's
## roster in _ready(), which requires AgentManager's own _ready() (where
## the roster is populated) to have already run.

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

## HQ location (lon, lat) — Berlin, Germany for now. New teams start here.
const HQ_LOCATION := Vector2(13.405, 52.52)
const HQ_NAME := "HQ (Berlin, Germany)"

## The base's fleet. Deploying a team auto-picks the best fit from here
## (see get_best_vehicle) rather than teams owning a fixed transport —
## growing this list (magical vehicle, teleport pad, ...) is how travel
## options expand later in the game.
var vehicles: Array[VehicleData] = [VehicleData.new()]

var teams: Array[TeamData] = []

## team id -> days remaining. Presence in this dict is what "in training" means.
var _training: Dictionary = {}

func _ready() -> void:
	%GameClock.day_advanced.connect(_on_day_advanced)
	var starting := _create_starting_team()
	if starting:
		teams.append(starting)
		print("[TeamManager] %s" % starting.get_status_summary())

## Groups the whole starting roster into one team. Works out of the box
## since the roster is exactly 4 agents (within TeamData's 3-5 range);
## revisit if the starting roster size ever changes.
func _create_starting_team() -> TeamData:
	var ids: Array[String] = []
	for a in %AgentManager.roster:
		ids.append(a.id)
	if ids.size() < TeamData.MIN_SIZE:
		push_warning("[TeamManager] starting roster too small to form a team.")
		return null
	return _at_hq(TeamData.new().setup("Alpha Team", ids))

func _at_hq(team: TeamData) -> TeamData:
	team.location = HQ_LOCATION
	team.location_name = HQ_NAME
	return team

func _on_day_advanced(_day: int) -> void:
	for team_id in _training.keys().duplicate():
		_training[team_id] -= 1
		if _training[team_id] <= 0:
			_finish_training(team_id)

	for team in teams:
		if team.is_traveling and %GameClock.current_day >= team.travel_arrival_day:
			_complete_travel(team)

## Picks the best fleet vehicle for a trip of this distance/team size:
## fastest among those that can reach it and carry everyone, tie-broken by
## lowest operation cost. Returns null if nothing in the fleet qualifies.
func get_best_vehicle(distance_km: float, team_size: int) -> VehicleData:
	var best: VehicleData = null
	var best_days := INF
	for v: VehicleData in vehicles:
		if not v.can_reach(distance_km) or not v.can_carry(team_size):
			continue
		var days := v.compute_travel_days(distance_km)
		if best == null or days < best_days or (days == best_days and v.operation_cost < best.operation_cost):
			best = v
			best_days = days
	return best

## Starts a team traveling toward an event's location. Returns a plan
## dict ({distance_km, travel_days, arrival_day, vehicle_name}) for the
## caller to show the player, or {} if the team doesn't exist or no fleet
## vehicle can reach the destination / carry the whole team. Marks members
## DEPLOYED — actual mission resolution happens later, on arrival
## (EventManager listens for team_arrived).
func begin_travel(team_id: String, destination: Vector2, destination_name: String, event_id: String) -> Dictionary:
	var team := get_team(team_id)
	if team == null:
		return {}

	var distance := GeoData.haversine_km(team.location.y, team.location.x, destination.y, destination.x)
	var vehicle := get_best_vehicle(distance, team.member_ids.size())
	if vehicle == null:
		push_warning("[TeamManager] no fleet vehicle can reach %s (%.0f km) with a team of %d" % [
			destination_name, distance, team.member_ids.size(),
		])
		return {}

	var days := vehicle.compute_travel_days(distance)

	# Remember where they set out from so begin_return_travel() knows where
	# "home" is once the mission concludes, without hardcoding HQ (matters
	# once multiple bases exist).
	team.travel_return_to = team.location
	team.travel_return_to_name = team.location_name
	team.travel_is_return = false

	team.is_traveling = true
	team.travel_destination = destination
	team.travel_destination_name = destination_name
	team.travel_departure_day = %GameClock.current_day
	team.travel_arrival_day = %GameClock.current_day + days
	team.travel_event_id = event_id
	team.travel_vehicle_name = vehicle.vehicle_name

	for agent_id in team.member_ids:
		var a: AgentData = %AgentManager.get_agent_by_id(agent_id)
		if a != null and a.is_available():
			%AgentManager.set_status(agent_id, AgentData.Status.DEPLOYED)

	team_departed.emit(team_id)
	print("[TeamManager] %s departed for %s via %s (%.0f km, %d day(s))" % [
		team.team_name, destination_name, vehicle.vehicle_name, distance, days,
	])
	return {
		"distance_km": distance, "travel_days": days,
		"arrival_day": team.travel_arrival_day, "vehicle_name": vehicle.vehicle_name,
	}

## Sends a team back to wherever they departed from after a mission
## concludes. Members stay DEPLOYED (set by begin_travel and never
## reverted) until _complete_travel applies their real outcome statuses on
## arrival — so a team is genuinely unavailable for the whole round trip,
## not just the outbound leg.
func begin_return_travel(team_id: String) -> void:
	var team := get_team(team_id)
	if team == null:
		return

	var distance := GeoData.haversine_km(team.location.y, team.location.x,
			team.travel_return_to.y, team.travel_return_to.x)
	var vehicle := get_best_vehicle(distance, team.member_ids.size())
	var days := vehicle.compute_travel_days(distance) if vehicle else 1

	team.is_traveling = true
	team.travel_destination = team.travel_return_to
	team.travel_destination_name = team.travel_return_to_name
	team.travel_departure_day = %GameClock.current_day
	team.travel_arrival_day = %GameClock.current_day + days
	team.travel_is_return = true
	if vehicle:
		team.travel_vehicle_name = vehicle.vehicle_name

	team_departed.emit(team_id)
	print("[TeamManager] %s began return trip to %s (%.0f km, %d day(s))" % [
		team.team_name, team.travel_destination_name, distance, days,
	])

func _complete_travel(team: TeamData) -> void:
	team.location = team.travel_destination
	team.location_name = team.travel_destination_name
	team.is_traveling = false

	if team.travel_is_return:
		team.travel_is_return = false
		for agent_id: String in team.pending_agent_results:
			%AgentManager.set_status(agent_id, team.pending_agent_results[agent_id])
		team.pending_agent_results.clear()
		print("[TeamManager] %s returned to %s" % [team.team_name, team.location_name])
		team_arrived.emit(team.id, "") # empty event_id = "just a return, nothing to resolve"
		return

	var event_id := team.travel_event_id
	team.travel_event_id = ""
	print("[TeamManager] %s arrived at %s" % [team.team_name, team.location_name])
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
		var a: AgentData = %AgentManager.get_agent_by_id(agent_id)
		if a == null or not a.is_available():
			return false

	for agent_id in team.member_ids:
		%AgentManager.set_status(agent_id, AgentData.Status.TRAINING)
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
		%AgentManager.set_status(agent_id, AgentData.Status.AVAILABLE)
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
