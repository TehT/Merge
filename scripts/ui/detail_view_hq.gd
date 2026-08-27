extends "res://scripts/ui/detail_view_base.gd"
## DetailViewHQ — base overview: fleet and local equipment (both
## clickable, opening their info slideouts), squads and their status, a
## Base Upgrades placeholder. Equipment here is only what's local to this
## base (BaseData.local_equipment) — the right sidebar's Equipment tab
## shows the full pool including org-wide global_equipment. Squads are
## filtered the same way: only teams whose current location (TeamData.
## location) matches this specific base — a team traveling away still
## shows here (location doesn't update until arrival, see TeamManager.
## _complete_travel), but one that's arrived at a mission or a different
## base doesn't. The right sidebar's Squads tab (agent_tab.gd) stays a
## flat, base-blind roster of every squad in the org.
##
## Layout lives in scenes/ui/views/detail_hq.tscn (editable in the
## editor); this script only fills the mount-point lists (%VehicleList,
## %SquadList, %EquipmentList) with row instances at populate() time.
## Row templates are their own scenes — see scenes/ui/rows/vehicle_row
## and equipment_row — so the row appearance is editor-editable too.

## Row scenes exported so they show up on the .tscn root node in the
## editor and stay editable per-project without editing this script.
@export var vehicle_row_scene: PackedScene
@export var equipment_row_scene: PackedScene


func populate(data: Variant, _dismiss: Callable) -> void:
	var base: BaseData = data
	var hq := base if base != null else Game.base_manager.get_primary_base()

	%Title.text = hq.base_name
	_fill_vehicles(hq.vehicles)
	_fill_squads(hq.location)
	_fill_equipment(hq.local_equipment, hq.id)


func _fill_vehicles(vehicles: Array[VehicleData]) -> void:
	_clear_children(%VehicleList)
	if vehicles.is_empty():
		_add_placeholder_row("No vehicles in the fleet.", %VehicleList)
		return
	for vehicle in vehicles:
		var row := vehicle_row_scene.instantiate()
		%VehicleList.add_child(row)
		row.populate(vehicle)
		row.clicked.connect(func(v: VehicleData) -> void:
				Game.left_popout.toggle_showing("vehicle", v))


func _fill_squads(location: Vector2) -> void:
	_clear_children(%SquadList)
	var teams: Array[TeamData] = Game.team_manager.teams.filter(
			func(t: TeamData) -> bool: return t.location == location)
	if teams.is_empty():
		_add_placeholder_row("No squads at this base.", %SquadList)
		return
	for team in teams:
		if team.is_traveling:
			var hours_left := maxf(0.0, (team.travel_arrival_day - Game.game_clock.get_current_time_days()) * 24.0)
			_add_info_row(team.team_name, "En route to %s (%s)" % [
					team.travel_destination_name, VehicleData.format_duration(hours_left)], %SquadList)
		elif team.is_on_mission:
			var hours_left := maxf(0.0, (team.mission_ready_day - Game.game_clock.get_current_time_days()) * 24.0)
			_add_info_row(team.team_name, "On mission at %s (%s left)" % [
					team.location_name, VehicleData.format_duration(hours_left)], %SquadList)
		else:
			_add_info_row(team.team_name, "At base", %SquadList)


func _fill_equipment(items: Array[EquipmentData], base_id: String) -> void:
	_clear_children(%EquipmentList)
	if items.is_empty():
		_add_placeholder_row("No base-local equipment.", %EquipmentList)
		return
	for item in items:
		var row := equipment_row_scene.instantiate()
		%EquipmentList.add_child(row)
		row.populate(item, base_id)
		row.clicked.connect(func(it: EquipmentData, bid: String) -> void:
				Game.left_popout.toggle_showing("equipment_info", {"item": it, "base_id": bid}))


static func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
