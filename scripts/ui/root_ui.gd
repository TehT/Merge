extends Control
class_name RootUI

const SIDEBAR_W := 320.0
const SLIDEOUT_W := 260.0
const TOGGLE_W := 24.0
const ANIM_SPEED := 0.15

var _left_open := true
var _right_open := true

func _ready() -> void:
	Game.root_ui = self
	%DetailPanel/LeftToggle.pressed.connect(_toggle_left)
	$RightSidebar/Layout/RightTabIcons/RightToggle.pressed.connect(_toggle_right)
	%EventLogToggle.pressed.connect(func() -> void: Game.slideout_panel.show_event_log())

	%SquadsIcon.pressed.connect(func() -> void: %Tabs.current_tab = 0)
	%EventsIcon.pressed.connect(func() -> void: %Tabs.current_tab = 1)
	%ResearchIcon.pressed.connect(func() -> void: %Tabs.current_tab = 2)
	%EquipmentIcon.pressed.connect(func() -> void: %Tabs.current_tab = 3)
	%BasesIcon.pressed.connect(func() -> void: %Tabs.current_tab = 4)

	%SquadList.agent_selected.connect(_on_agent_selected)
	%SquadList.team_selected.connect(_on_team_selected)
	%EventList.event_selected.connect(_on_event_selected)
	%BasesList.base_selected.connect(_on_base_selected)
	%EventMapLabels.event_label_clicked.connect(_on_event_selected)
	%MarkerLayer.event_marker_clicked.connect(_on_event_selected)
	%MarkerLayer.base_marker_clicked.connect(func(base_id: String) -> void:
		_on_base_selected(Game.base_manager.get_base_by_id(base_id)))

	Game.slideout_panel.visibility_changed.connect(_on_left_slideout_visibility_changed)
	Game.right_slideout_panel.visibility_changed.connect(_on_right_slideout_visibility_changed)

	_apply_left(false)
	_apply_right(false)


func _on_agent_selected(agent: AgentData) -> void:
	Game.detail_sidebar.show_agent(agent)
	open_left()


func _on_team_selected(team: TeamData) -> void:
	Game.detail_sidebar.show_team(team)
	open_left()


func _on_base_selected(base: BaseData) -> void:
	Game.detail_sidebar.show_hq(base)
	open_left()


func _on_event_selected(ev: EventData) -> void:
	Game.detail_sidebar.show_event(ev)
	open_left()


## Public (unlike _toggle_left/_apply_left) — called from anywhere that
## just populated Game.detail_sidebar and wants the left sidebar visibly
## open for it, without caring whether it already was (e.g.
## RightSlideoutViewHire, clicking a recruit).
func open_left() -> void:
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
	# Closed still leaves TOGGLE_W on screen (the toggle rail sits at the
	# end of the sidebar's HBox) so LeftToggle stays clickable instead of
	# sliding off with the content panel.
	var sb_l := 0.0 if _left_open else -(SIDEBAR_W - TOGGLE_W)
	var sb_r := SIDEBAR_W if _left_open else TOGGLE_W
	%DetailPanel/LeftToggle.text = "◀" if _left_open else "▶"

	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property($LeftSidebar, "offset_left", sb_l, ANIM_SPEED)
		tw.tween_property($LeftSidebar, "offset_right", sb_r, ANIM_SPEED)
	else:
		$LeftSidebar.offset_left = sb_l
		$LeftSidebar.offset_right = sb_r

	_apply_slideout(animate)


func _apply_slideout(animate: bool) -> void:
	var base := SIDEBAR_W + TOGGLE_W if _left_open else TOGGLE_W
	var so_visible: bool = Game.slideout_panel.visible
	var so_l := base if so_visible else base - SLIDEOUT_W+50
	var so_r := base + SLIDEOUT_W+15 if so_visible else base+15

	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property(Game.slideout_panel, "offset_left", so_l, ANIM_SPEED)
		tw.tween_property(Game.slideout_panel, "offset_right", so_r, ANIM_SPEED)
	else:
		Game.slideout_panel.offset_left = so_l
		Game.slideout_panel.offset_right = so_r


func _apply_right(animate: bool) -> void:
	# Mirrors _apply_left: closed still leaves TOGGLE_W on screen (the
	# toggle rail sits at the START of RightSidebar's HBox) so RightToggle
	# stays clickable instead of sliding off with the content panel.
	var sb_l := -SIDEBAR_W if _right_open else -TOGGLE_W
	var sb_r := 0.0 if _right_open else SIDEBAR_W - TOGGLE_W
	%RightToggle.text = "▶" if _right_open else "◀"

	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property($RightSidebar, "offset_left", sb_l, ANIM_SPEED)
		tw.tween_property($RightSidebar, "offset_right", sb_r, ANIM_SPEED)
	else:
		$RightSidebar.offset_left = sb_l
		$RightSidebar.offset_right = sb_r

	_apply_right_slideout(animate)

func _apply_right_slideout(animate: bool) -> void:
	var base := SIDEBAR_W + TOGGLE_W if _right_open else TOGGLE_W
	var so_visible: bool = Game.right_slideout_panel.visible
	var so_l := -(base + SLIDEOUT_W) if so_visible else -base
	var so_r := -base if so_visible else -(base - SLIDEOUT_W)

	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property(Game.right_slideout_panel, "offset_left", so_l, ANIM_SPEED)
		tw.tween_property(Game.right_slideout_panel, "offset_right", so_r, ANIM_SPEED)
	else:
		Game.right_slideout_panel.offset_left = so_l
		Game.right_slideout_panel.offset_right = so_r


func _on_left_slideout_visibility_changed() -> void:
	if Game.slideout_panel.visible and Game.right_slideout_panel.visible and _slideouts_would_overlap():
		Game.right_slideout_panel.dismiss()
	_apply_slideout(true)


func _on_right_slideout_visibility_changed() -> void:
	if Game.right_slideout_panel.visible and Game.slideout_panel.visible and _slideouts_would_overlap():
		Game.slideout_panel.dismiss()
	_apply_right_slideout(true)


## True if the left SlideoutPanel and the right RightSlideoutPanel would
## visually overlap at their current open/closed target positions, given
## the viewport's current width. Checked whenever either becomes visible
## so opening one can pre-emptively close the other rather than letting
## them collide — derived purely from the sidebars' open/closed state (not
## the panels' actual, possibly still-tweening rects), so it's correct
## immediately rather than racing the slide animation. Most relevant at
## narrow window widths; the target release resolution has much more room
## either side, so this should rarely if ever actually trigger there.
## viewport_w defaults to the real viewport width; overridable so the
## calculation itself (pure, given the two open/closed flags and a width)
## can be tested without depending on get_viewport_rect() — which reports
## a small stub size in a headless run, not the project's real configured
## window size.
func _slideouts_would_overlap(viewport_w: float = -1.0) -> bool:
	if viewport_w < 0.0:
		viewport_w = get_viewport_rect().size.x

	var left_base := SIDEBAR_W + TOGGLE_W if _left_open else TOGGLE_W
	var left_r := left_base + SLIDEOUT_W

	var right_base := SIDEBAR_W + TOGGLE_W if _right_open else TOGGLE_W
	var right_l := viewport_w - (right_base + SLIDEOUT_W)

	return left_r > right_l
