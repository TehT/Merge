extends VBoxContainer
## RightSlideoutViewHire — the weekly hiring pool (HiringManager), shown
## in the right-side popout (Game.right_popout). Each row shows a
## recruit's name/type/proficiency spread and a Hire button (disabled
## if funding is short); hiring moves them onto the roster immediately
## and removes them from the pool. Clicking anywhere on a row other
## than the Hire button opens that recruit's full agent sheet in the
## left detail panel (same view a roster agent gets) — a preview
## before committing funding to them.
##
## Layout lives in scenes/ui/views/slideout_hire.tscn (editable in the
## editor). Recruit rows are instances of recruit_row.tscn added to
## %RecruitList; the row emits hire_pressed / preview_requested and
## this script routes those to HiringManager / left_detail.

@export var recruit_row_scene: PackedScene


func populate(_data: Variant, on_close: Callable) -> void:
	%Header.close_requested.connect(on_close)

	Game.hiring_manager.pool_refreshed.connect(_refresh)
	Game.hiring_manager.recruit_hired.connect(func(_a: AgentData) -> void: _refresh())
	Game.resource_state.funding_changed.connect(func(_v: int, _d: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	for child in %RecruitList.get_children():
		child.queue_free()

	var days_left := Game.hiring_manager.get_days_until_refresh()
	%RefreshLabel.text = "New recruits in %d day%s" % [days_left, "" if days_left == 1 else "s"]

	var pool: Array[AgentData] = Game.hiring_manager.pool
	%EmptyLabel.visible = pool.is_empty()

	var hire_cost := Game.hiring_manager.hire_cost
	var funding: int = Game.resource_state.funding
	for recruit: AgentData in pool:
		var row := recruit_row_scene.instantiate()
		%RecruitList.add_child(row)
		row.populate(recruit, hire_cost, funding)
		row.hire_pressed.connect(func(r: AgentData) -> void:
				Game.hiring_manager.hire(r.id))
		row.preview_requested.connect(func(r: AgentData) -> void:
				Game.left_detail.show_view("agent", r)
				Game.root_ui.open_left())
