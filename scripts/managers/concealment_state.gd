extends Node
## ConcealmentState — a persistent node in Main.tscn, referenced elsewhere
## via its scene-unique name (%ConcealmentState). The central tension
## meter, 0 (perfectly hidden) to 100 (full public knowledge). Failed/
## expired events add concealment; successful containment reduces it; it
## passively decays each day. Crossing 25/50/75 fires escalation hooks
## (stubbed for now); hitting 100 triggers the Revelation (stubbed — no
## Act 3 transition yet).

signal concealment_changed(new_value: float, delta: float)
signal threshold_crossed(threshold: int)
signal revelation_triggered()

const THRESHOLDS := [25, 50, 75, 100]

@export var daily_decay: float = 1.0

var value: float = 0.0

func _ready() -> void:
	%GameClock.day_advanced.connect(_on_day_advanced)

func _on_day_advanced(_day: int) -> void:
	reduce(daily_decay)

func add(amount: float) -> void:
	_set_value(value + amount)

func reduce(amount: float) -> void:
	_set_value(value - amount)

func _set_value(new_value: float) -> void:
	var old := value
	value = clampf(new_value, 0.0, 100.0)
	if is_equal_approx(value, old):
		return
	concealment_changed.emit(value, value - old)
	for t in THRESHOLDS:
		if old < t and value >= t:
			threshold_crossed.emit(t)
			print("[ConcealmentState] threshold crossed: %d" % t)
			if t == 100:
				revelation_triggered.emit()
				push_warning("[ConcealmentState] REVELATION TRIGGERED (stub — no Act 3 transition yet)")
