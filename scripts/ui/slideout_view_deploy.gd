extends VBoxContainer
## SlideoutViewDeploy — squad picker for deploying to an event: every
## non-empty squad with match %, availability, a route dropdown (every
## viable way to get there — direct or relayed through a Transport hop
## to another base, via TravelRouter — ranked fastest first, auto-
## selects the fastest but overridable), and a Deploy button.
##
## Layout lives in scenes/ui/views/slideout_deploy.tscn (editable in
## the editor). Each deployable team is one instance of deploy_row.tscn
## added to %TeamList — the row handles its own dropdown + button
## wiring and just emits deploy_requested when Deploy is pressed.

@export var deploy_row_scene: PackedScene

var _event: EventData


func populate(data: Variant, on_close: Callable) -> void:
	_event = data

	%Header.close_requested.connect(on_close)
	%Subtitle.text = _event.title

	var teams: Array[TeamData] = Game.team_manager.teams
	var deployable := teams.filter(func(t: TeamData) -> bool: return not t.member_ids.is_empty())

	if deployable.is_empty():
		%EmptyLabel.visible = true
		return

	for team: TeamData in deployable:
		var row := deploy_row_scene.instantiate()
		%TeamList.add_child(row)
		row.populate(team, _event)
		row.deploy_requested.connect(func(picked: TeamData, route: Array) -> void:
				_do_deploy(picked, route, on_close))


func _do_deploy(team: TeamData, route: Array, on_close: Callable) -> void:
	var team_name := team.team_name
	var ev_title := _event.title
	var plan: Dictionary = Game.event_manager.deploy_team(_event.id, team.id, route)
	if plan.is_empty():
		return
	on_close.call()
	Game.left_detail.show_view("travel_confirmation",
			{"team_name": team_name, "ev_title": ev_title, "plan": plan})
