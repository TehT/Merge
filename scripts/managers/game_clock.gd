extends Node
## GameClock — a persistent node in Main.tscn, referenced elsewhere via its
## scene-unique name (%GameClock). The single global source of truth for
## in-game time. Gameplay systems (EventManager, ConcealmentState) hook
## day_advanced; GeoscapeController syncs its sun rotation and calendar
## (day_of_year) from get_day_progress()/current_day instead of running
## its own independent timer, so the visual day/night cycle and the
## backend day tick never drift apart — and pausing the clock pauses both.

signal day_advanced(day: int)
signal pause_changed(paused: bool)

## Real seconds per in-game day. Lower this for faster manual iteration.
## Matches the pacing GeoscapeController previously used for its own
## day/night cycle (day_length_seconds = 3.0 in scenes/Main.tscn).
@export var seconds_per_day: float = 60.0

var current_day: int = 0
var paused: bool = false

var _accum: float = 0.0

func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta
	while _accum >= seconds_per_day:
		_accum -= seconds_per_day
		_advance_day()

func _advance_day() -> void:
	current_day += 1
	day_advanced.emit(current_day)

func pause() -> void:
	_set_paused(true)

func resume() -> void:
	_set_paused(false)

func toggle_pause() -> void:
	_set_paused(not paused)

func _set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	pause_changed.emit(paused)

## Manually step days forward for debug use. Deliberately ignores `paused`
## so days can be stepped while the auto-clock is held for inspection.
func advance_days(n: int) -> void:
	for _i in n:
		_advance_day()

## Rescales `_accum` proportionally so the current day's progress fraction
## (and therefore the sun/terminator position) stays continuous across a
## speed change instead of jumping when the seconds_per_day denominator changes.
func set_speed(seconds: float) -> void:
	var progress := get_day_progress()
	seconds_per_day = maxf(0.1, seconds)
	_accum = progress * seconds_per_day

## Fraction (0.0-1.0) elapsed through the current in-game day. Frozen while
## paused. GeoscapeController uses this to drive sun rotation each frame.
func get_day_progress() -> float:
	if seconds_per_day <= 0.0:
		return 0.0
	return clampf(_accum / seconds_per_day, 0.0, 1.0)
