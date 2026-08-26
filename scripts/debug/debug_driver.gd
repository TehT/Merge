extends Node
## DebugDriver — manual test harness for the Milestone 1 backend loop.
## No UI exists yet, so this exposes the event/agent/team/resolution
## systems via raw keycodes, matching GeoscapeController's existing input
## pattern (which also checks event.keycode directly rather than using
## InputMap).
##
## 1: spawn a random event now
## 2: list active events
## 3: send the first team traveling to the most urgent event (resolves on arrival)
## 4: advance 1 day manually      5: advance 7 days manually
## H: advance 1 hour manually
## 6: toggle GameClock pause
## 7: print full roster status
## 8: print concealment/funding/intel
## 9: print full status (events + roster + teams + resources)
## 0: print team status (cohesion, members)
## T: start training for the first team (requires all members Available)
## P: print per-skill and per-Proficiency XP for the whole roster

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_1: Game.event_manager.spawn_random_event()
		KEY_2: _list_events()
		KEY_3: _deploy_first_team_to_most_urgent()
		KEY_4: Game.game_clock.advance_days(1)
		KEY_5: Game.game_clock.advance_days(7)
		KEY_H: Game.game_clock.advance_hours(1)
		KEY_6:
			Game.game_clock.toggle_pause()
			print("[Debug] paused=%s" % [Game.game_clock.paused])
		KEY_7: Game.agent_manager.print_roster_status()
		KEY_8: _print_resources()
		KEY_9: _print_full_status()
		KEY_0: Game.team_manager.print_team_status()
		KEY_T: _train_first_team()
		KEY_P: Game.agent_manager.print_xp_status()

func _list_events() -> void:
	var events: Array[EventData] = Game.event_manager.get_active_events()
	if events.is_empty():
		print("[Debug] no active events")
		return
	print("[Debug] active events (%d):" % events.size())
	for e in events:
		print("  %s [%s/%s] days_left=%d loc=%s reqs=%s" % [
			e.title, e.get_urgency_name(), e.get_type_name(),
			e.days_remaining, e.location_city, e.get_skill_requirements(),
		])

func _deploy_first_team_to_most_urgent() -> void:
	var events: Array[EventData] = Game.event_manager.get_active_events()
	if events.is_empty():
		print("[Debug] no active events")
		return

	var teams: Array[TeamData] = Game.team_manager.teams
	if teams.is_empty():
		print("[Debug] no teams exist")
		return
	var team := teams[0]

	events.sort_custom(func(a: EventData, b: EventData): return a.urgency > b.urgency)
	var event: EventData = events[0]

	var routes := TravelRouter.find_routes(team.location, team.location_name,
			event.geo_coordinates, event.location_city, team.member_ids.size(),
			VehicleData.Role.TACTICAL, Game.base_manager.bases, team.current_vehicle)
	if routes.is_empty():
		print("[Debug] deploy failed (no route reaches this event)")
		return

	var plan: Dictionary = Game.event_manager.deploy_team(event.id, team.id, routes[0])
	if plan.is_empty():
		print("[Debug] deploy failed (team or event not found)")
		return
	print("[Debug] %s departed for %s: %.0f km, %s, arriving day %.2f" % [
		team.team_name, event.title, plan.distance_km,
		VehicleData.format_duration(plan.travel_hours), plan.arrival_time,
	])

func _train_first_team() -> void:
	var teams: Array[TeamData] = Game.team_manager.teams
	if teams.is_empty():
		print("[Debug] no teams exist")
		return
	var team := teams[0]
	var started: bool = Game.team_manager.start_training(team.id)
	if not started:
		print("[Debug] %s can't start training right now (already training, or a member isn't Available)" % team.team_name)

func _print_resources() -> void:
	print("[Debug] concealment=%.1f funding=%d intel=%d" % [
		Game.concealment_state.value, Game.resource_state.funding, Game.resource_state.intel,
	])

func _print_full_status() -> void:
	_list_events()
	Game.agent_manager.print_roster_status()
	Game.team_manager.print_team_status()
	print("[Debug] concealment=%.1f funding=%d intel=%d magic_intensity=%.2f day=%d" % [
		Game.concealment_state.value, Game.resource_state.funding, Game.resource_state.intel,
		Game.event_manager.magic_intensity, Game.game_clock.current_day,
	])
