extends Node
class_name GameClock
## GameClock — a persistent node in Main.tscn, referenced elsewhere via
## Game.game_clock (registers itself in _ready() — see game.gd for why
## that's used instead of %GameClock). The single global source of truth for
## in-game time. Gameplay systems (EventManager, ConcealmentState) hook
## day_advanced; GeoscapeController syncs its sun rotation and calendar
## (day_of_year) from get_day_progress()/current_day instead of running
## its own independent timer, so the visual day/night cycle and the
## backend day tick never drift apart — and pausing the clock pauses both.
##
## Ticks in whole hours internally (day_advanced still fires too, exactly
## every 24 hours) so systems that want finer-than-daily resolution — or
## just smoother countdowns/decay — have a real signal to hook instead of
## polling get_day_progress() themselves (which only TeamManager's travel
## arrival check does today).

signal hour_advanced(hour_of_day: int)
signal day_advanced(day: int)
signal pause_changed(paused: bool)

const HOURS_PER_DAY := 24

## Real seconds per in-game day. Lower this for faster manual iteration.
## Matches the pacing GeoscapeController previously used for its own
## day/night cycle (day_length_seconds = 3.0 in scenes/Main.tscn).
@export var seconds_per_day: float = 120

var current_day: int = 0
var current_hour: int = 0 # 0-23, hour of the current day
var paused: bool = false

## Seconds accumulated within the *current hour* (not the whole day —
## ticking hourly means this only ever needs to fill one hour's worth).
var _accum: float = 0.0

func _ready() -> void:
	Game.game_clock = self

func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta
	var seconds_per_hour := _seconds_per_hour()
	while seconds_per_hour > 0.0 and _accum >= seconds_per_hour:
		_accum -= seconds_per_hour
		_advance_hour()

func _advance_hour() -> void:
	current_hour += 1
	if current_hour >= HOURS_PER_DAY:
		current_hour = 0
		current_day += 1
		day_advanced.emit(current_day)
	hour_advanced.emit(current_hour)

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

## Manually step whole days forward for debug use. Deliberately ignores
## `paused` so time can be stepped while the auto-clock is held for
## inspection. Steps hour-by-hour (not a single jump) so hour_advanced
## still fires for every hour skipped, keeping anything hooked to it
## consistent with anything hooked to day_advanced.
func advance_days(n: int) -> void:
	advance_hours(n * HOURS_PER_DAY)

## Manually step whole hours forward for debug use. Same paused-ignoring
## behavior as advance_days().
func advance_hours(n: int) -> void:
	for _i in n:
		_advance_hour()

## Rescales `_accum` proportionally so the current hour's progress fraction
## (and therefore the sun/terminator position) stays continuous across a
## speed change instead of jumping when the seconds_per_hour denominator
## changes underneath it.
func set_speed(seconds: float) -> void:
	var old_seconds_per_hour := _seconds_per_hour()
	var hour_progress := clampf(_accum / old_seconds_per_hour, 0.0, 1.0) if old_seconds_per_hour > 0.0 else 0.0
	seconds_per_day = maxf(0.1, seconds)
	_accum = hour_progress * _seconds_per_hour()

func _seconds_per_hour() -> float:
	return seconds_per_day / float(HOURS_PER_DAY)

## Fraction (0.0-1.0) elapsed through the current in-game day. Frozen while
## paused. GeoscapeController uses this to drive sun rotation each frame.
func get_day_progress() -> float:
	var seconds_per_hour := _seconds_per_hour()
	var hour_progress := clampf(_accum / seconds_per_hour, 0.0, 1.0) if seconds_per_hour > 0.0 else 0.0
	return clampf((float(current_hour) + hour_progress) / float(HOURS_PER_DAY), 0.0, 1.0)

## Current moment as a single fractional day count (e.g. 3.25 = a quarter
## into day 3). The canonical "now" for anything that needs sub-day
## precision — travel arrival, ETA displays — since current_day alone is
## too coarse and day_advanced only fires on whole-day boundaries.
func get_current_time_days() -> float:
	return float(current_day) + get_day_progress()
