extends Control
## RootUI — manages the dual-sidebar layout. Right sidebar holds overview
## tabs (Squads, Events, etc.); left sidebar shows details for whatever
## is selected on the right. Both sidebars slide open/closed.

const SIDEBAR_W := 320.0
const SLIDEOUT_W := 260.0
const TOGGLE_W := 24.0
const ANIM_SPEED := 0.15

var _left_open := false
var _right_open := true

func _ready() -> void:
	$LeftToggle.pressed.connect(_toggle_left)
	$RightToggle.pressed.connect(_toggle_right)

	%SquadList.agent_selected.connect(_on_agent_selected)
	%SquadList.team_selected.connect(_on_team_selected)
	%EventList.event_selected.connect(_on_event_selected)
	%EventMapLabels.event_label_clicked.connect(_on_event_selected)
	%MarkerLayer.event_marker_clicked.connect(_on_event_selected)
	%MarkerLayer.hq_marker_clicked.connect(_on_hq_selected)

	%SkillSlideout.visibility_changed.connect(func() -> void:
		_apply_slideout(true))

	_apply_left(false)
	_apply_right(false)


func _on_agent_selected(agent: AgentData) -> void:
	%DetailPanel.show_agent(agent)
	_open_left()


func _on_team_selected(team: TeamData) -> void:
	%DetailPanel.show_team(team)
	_open_left()


func _on_hq_selected() -> void:
	%DetailPanel.show_hq()
	_open_left()


func _on_event_selected(ev: EventData) -> void:
	%DetailPanel.show_event(ev)
	_open_left()


func _open_left() -> void:
	if not _left_open:
		_left_open = true
		_apply_left(true)


func _toggle_left() -> void:
	_left_open = not _left_open
	_apply_left(true)


func _toggle_right() -> void:
	_right_open = not _right_open
	_apply_right(true)


func _apply_left(animate: bool) -> void:
	var sb_l := 0.0 if _left_open else -SIDEBAR_W
	var sb_r := SIDEBAR_W if _left_open else 0.0
	var tg_l := SIDEBAR_W if _left_open else 0.0
	var tg_r := SIDEBAR_W + TOGGLE_W if _left_open else TOGGLE_W
	$LeftToggle.text = "◀" if _left_open else "▶"

	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property($LeftSidebar, "offset_left", sb_l, ANIM_SPEED)
		tw.tween_property($LeftSidebar, "offset_right", sb_r, ANIM_SPEED)
		tw.tween_property($LeftToggle, "offset_left", tg_l, ANIM_SPEED)
		tw.tween_property($LeftToggle, "offset_right", tg_r, ANIM_SPEED)
	else:
		$LeftSidebar.offset_left = sb_l
		$LeftSidebar.offset_right = sb_r
		$LeftToggle.offset_left = tg_l
		$LeftToggle.offset_right = tg_r

	_apply_slideout(animate)


func _apply_slideout(animate: bool) -> void:
	var base := SIDEBAR_W + TOGGLE_W if _left_open else TOGGLE_W
	var so_visible: bool = %SkillSlideout.visible
	var so_l := base if so_visible else base - SLIDEOUT_W
	var so_r := base + SLIDEOUT_W if so_visible else base

	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property(%SkillSlideout, "offset_left", so_l, ANIM_SPEED)
		tw.tween_property(%SkillSlideout, "offset_right", so_r, ANIM_SPEED)
	else:
		%SkillSlideout.offset_left = so_l
		%SkillSlideout.offset_right = so_r


func _apply_right(animate: bool) -> void:
	var sb_l := -SIDEBAR_W if _right_open else 0.0
	var sb_r := 0.0 if _right_open else SIDEBAR_W
	var tg_l := -(SIDEBAR_W + TOGGLE_W) if _right_open else -TOGGLE_W
	var tg_r := -SIDEBAR_W if _right_open else 0.0
	$RightToggle.text = "▶" if _right_open else "◀"

	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property($RightSidebar, "offset_left", sb_l, ANIM_SPEED)
		tw.tween_property($RightSidebar, "offset_right", sb_r, ANIM_SPEED)
		tw.tween_property($RightToggle, "offset_left", tg_l, ANIM_SPEED)
		tw.tween_property($RightToggle, "offset_right", tg_r, ANIM_SPEED)
	else:
		$RightSidebar.offset_left = sb_l
		$RightSidebar.offset_right = sb_r
		$RightToggle.offset_left = tg_l
		$RightToggle.offset_right = tg_r
