extends PanelContainer
## TopBar — persistent HUD strip: date/year, pause + speed controls,
## Funding, Intel, and a threshold-marked Concealment meter. Lives in
## Main.tscn under UI/Root (themed via theme/ui_theme.tres).

@onready var _date_label: Label = %DateLabel
@onready var _pause_button: Button = %PauseButton
@onready var _funding_label: Label = %FundingLabel
@onready var _intel_label: Label = %IntelLabel
@onready var _concealment_bar: ProgressBar = %ConcealmentBar
@onready var _concealment_label: Label = %ConcealmentLabel

## Captured once at startup so speed presets are relative to whatever
## GameClock's own default is, rather than hardcoding it a second time here.
@onready var _base_seconds_per_day: float = Game.game_clock.seconds_per_day

const _SPEED_BUTTONS := [
	{"name": "Speed1x", "multiplier": 1.0},
	{"name": "Speed2x", "multiplier": 2.0},
	{"name": "Speed4x", "multiplier": 4.0},
]

var _fill_style: StyleBoxFlat

func _ready() -> void:
	_fill_style = StyleBoxFlat.new()
	_fill_style.corner_radius_top_left = 3
	_fill_style.corner_radius_top_right = 3
	_fill_style.corner_radius_bottom_right = 3
	_fill_style.corner_radius_bottom_left = 3
	_concealment_bar.add_theme_stylebox_override("fill", _fill_style)

	_pause_button.pressed.connect(func() -> void: Game.game_clock.toggle_pause())
	Game.game_clock.pause_changed.connect(_on_pause_changed)
	Game.game_clock.day_advanced.connect(_update_date)

	var speed_group := ButtonGroup.new()
	for entry in _SPEED_BUTTONS:
		var btn := get_node("HBox/SpeedButtons/%s" % entry.name) as Button
		btn.toggle_mode = true
		btn.button_group = speed_group
		var multiplier: float = entry.multiplier
		btn.button_pressed = is_equal_approx(multiplier, 1.0)
		btn.pressed.connect(func() -> void: Game.game_clock.set_speed(_base_seconds_per_day / multiplier))

	Game.resource_state.funding_changed.connect(_on_funding_changed)
	Game.resource_state.intel_changed.connect(_on_intel_changed)
	Game.concealment_state.concealment_changed.connect(_on_concealment_changed)
	Game.concealment_state.threshold_crossed.connect(_on_threshold_crossed)

	_update_date()
	_on_pause_changed(Game.game_clock.paused)
	_on_funding_changed(Game.resource_state.funding, 0)
	_on_intel_changed(Game.resource_state.intel, 0)
	_on_concealment_changed(Game.concealment_state.value, 0.0)


func _update_date() -> void:
	var geoscape: Node = get_tree().current_scene
	var date_str: String = geoscape.get_date_string()
	_date_label.text = date_str


func _on_pause_changed(paused: bool) -> void:
	_pause_button.text = "▶" if paused else "⏸"


func _on_funding_changed(new_value: int, _delta: int) -> void:
	_funding_label.text = "Funding %d" % new_value


func _on_intel_changed(new_value: int, _delta: int) -> void:
	_intel_label.text = "Intel %d" % new_value


func _on_concealment_changed(new_value: float, _delta: float) -> void:
	_concealment_bar.value = new_value
	_concealment_label.text = "%d%%" % int(round(new_value))
	_fill_style.bg_color = _concealment_color(new_value)


## Brief highlight flash when a threshold (25/50/75/100) is crossed, since
## those moments matter narratively and shouldn't be easy to miss.
func _on_threshold_crossed(_threshold: int) -> void:
	_concealment_bar.modulate = Color(1.6, 1.6, 1.6)
	var tween := create_tween()
	tween.tween_property(_concealment_bar, "modulate", Color.WHITE, 0.4)


func _concealment_color(value: float) -> Color:
	var low: Color = get_theme_color("low", "Concealment")
	var mid: Color = get_theme_color("mid", "Concealment")
	var high: Color = get_theme_color("high", "Concealment")
	if value <= 50.0:
		return low.lerp(mid, value / 50.0)
	return mid.lerp(high, (value - 50.0) / 50.0)
