extends Node
class_name EventLog
## EventLog — a persistent node in Main.tscn, referenced elsewhere via
## Game.event_log (registers itself in _ready() — see game.gd). Listens to
## EventManager/TeamManager signals and keeps a running, player-facing
## history of what's happened (events spawning/expiring/escalating/
## resolving, teams departing/arriving/returning) — shown in the event log
## panel (SlideoutViewEventLog), opened via the small button under the
## left sidebar toggle. Must be listed after EventManager and TeamManager
## as a sibling in Main.tscn, so Game.event_manager/Game.team_manager
## already exist when this connects to their signals in _ready().

signal entry_added(entry: EventLogEntry)

## Caps memory/UI growth over a long session — oldest entries drop off
## first. Well beyond what a player would ever scroll back through.
const MAX_ENTRIES := 300

var entries: Array[EventLogEntry] = []

func _ready() -> void:
	Game.event_log = self
	Game.event_manager.event_spawned.connect(_on_event_spawned)
	Game.event_manager.event_expired.connect(_on_event_expired)
	Game.event_manager.event_escalated.connect(_on_event_escalated)
	Game.event_manager.event_resolved.connect(_on_event_resolved)
	Game.team_manager.team_departed.connect(_on_team_departed)
	Game.team_manager.team_arrived.connect(_on_team_arrived)
	Game.base_manager.vehicle_transfer_started.connect(_on_vehicle_transfer_started)
	Game.base_manager.vehicle_transfer_completed.connect(_on_vehicle_transfer_completed)
	Game.base_manager.base_relocation_started.connect(_on_base_relocation_started)
	Game.base_manager.base_relocation_completed.connect(_on_base_relocation_completed)


func _on_event_spawned(event: EventData) -> void:
	var where := event.location_city if event.location_city != "" else "an unknown location"
	_add("New event: %s at %s" % [event.title, where])


func _on_event_expired(event: EventData) -> void:
	_add("%s expired unresolved" % event.title)


func _on_event_escalated(old_event: EventData, new_event: EventData) -> void:
	_add("%s escalated into %s" % [old_event.title, new_event.title])


func _on_event_resolved(event: EventData, team_name: String, result: MissionResolutionResult) -> void:
	_add("%s resolved %s -> %s" % [
		team_name, event.title, MissionResolutionResult.outcome_name(result.outcome).capitalize(),
	])


## team_departed fires for both the outbound leg (begin_travel) and the
## return leg (begin_return_travel) — team.travel_is_return is already set
## by the time either emits, so it's read here to tell the two apart
## rather than needing a second signal.
func _on_team_departed(team_id: String) -> void:
	var team := Game.team_manager.get_team(team_id)
	if team == null:
		return
	if team.travel_is_return:
		_add("%s set out for home, to %s" % [team.team_name, team.travel_destination_name])
	else:
		_add("%s departed for %s" % [team.team_name, team.travel_destination_name])


## team_arrived fires for both a real mission site (event_id set — whether
## arriving directly or after an on-site mission_duration_hours delay) and
## the final return home (event_id == "", set by TeamManager as "just a
## return, nothing to resolve").
func _on_team_arrived(team_id: String, event_id: String) -> void:
	var team := Game.team_manager.get_team(team_id)
	if team == null:
		return
	if event_id == "":
		_add("%s returned to %s" % [team.team_name, team.location_name])
	else:
		_add("%s arrived at %s" % [team.team_name, team.location_name])


## Empty-cabin vehicle ferry between bases (no team on board) — starts
## when a player clicks Send on the vehicle popout's Relocate section.
func _on_vehicle_transfer_started(vehicle: VehicleData, from_base_id: String,
		to_base_id: String, _arrival_day: float) -> void:
	var from_base := Game.base_manager.get_base_by_id(from_base_id)
	var to_base := Game.base_manager.get_base_by_id(to_base_id)
	if from_base == null or to_base == null:
		return
	_add("%s ferrying %s → %s" % [vehicle.vehicle_name, from_base.base_name, to_base.base_name])


func _on_vehicle_transfer_completed(vehicle: VehicleData, to_base_id: String) -> void:
	var to_base := Game.base_manager.get_base_by_id(to_base_id)
	if to_base == null:
		return
	_add("%s arrived at %s" % [vehicle.vehicle_name, to_base.base_name])


func _on_base_relocation_started(base: BaseData) -> void:
	_add("%s setting course for %s" % [base.base_name, base.travel_destination_name])


func _on_base_relocation_completed(base: BaseData) -> void:
	_add("%s moored at %s" % [base.base_name, base.travel_destination_name])


func _add(text: String) -> void:
	var entry := EventLogEntry.new(Game.game_clock.current_day, Game.game_clock.current_hour, text)
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(entry)
