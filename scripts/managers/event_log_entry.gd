class_name EventLogEntry
extends RefCounted
## EventLogEntry — one line in EventLog's running history: a local in-game
## timestamp (day + hour, straight from GameClock's own whole-hour
## resolution — see GameClock.current_day/current_hour) plus the
## human-readable text describing what happened. Plain data, no behavior —
## EventLog builds these, the event log panel (SlideoutViewEventLog) just
## displays them in order.

var day: int = 0
var hour: int = 0
var text: String = ""

func _init(p_day: int = 0, p_hour: int = 0, p_text: String = "") -> void:
	day = p_day
	hour = p_hour
	text = p_text

## "Day 5, 14:00" — GameClock only ticks in whole hours, so minutes are
## always :00; not worth displaying a false precision it doesn't have.
func format_timestamp() -> String:
	return "Day %d, %02d:00" % [day, hour]
