extends Node
class_name HiringManager
## HiringManager — a persistent node in Main.tscn, referenced elsewhere via
## Game.hiring_manager (registers itself in _ready() — see game.gd). Owns
## the weekly hiring pool: procedurally-generated recruits (the same
## AgentGenerator/NameGenerator pipeline AgentManager uses for the
## starting roster) the player can hire onto AgentManager's roster for
## funding. Refreshes every refresh_interval_days: half the current pool
## is randomly discarded, then refilled back up to pool_size with fresh
## recruits — so a recruit the player passes on doesn't linger forever,
## but a full turnover isn't guaranteed either.

signal pool_refreshed()
signal recruit_hired(agent: AgentData)

@export var pool_size: int = 6
@export var hire_cost: int = 100
@export var refresh_interval_days: int = 7

## Chance (0-1) a given recruit generates as a Generalist rather than a
## Specialist — same knob and same default as AgentManager's starting
## roster.
@export_range(0.0, 1.0) var generalist_chance: float = 0.6

var pool: Array[AgentData] = []

var _days_since_refresh: int = 0

func _ready() -> void:
	Game.hiring_manager = self
	Game.game_clock.day_advanced.connect(_on_day_advanced)
	_refresh_pool()

func _on_day_advanced(_day: int) -> void:
	_days_since_refresh += 1
	if _days_since_refresh >= refresh_interval_days:
		_days_since_refresh = 0
		_refresh_pool()

## Half the current pool (rounded down) is randomly discarded, then
## refilled back up to pool_size with fresh recruits. Operates on
## whatever's actually still sitting in the pool right now, not its
## nominal starting size — hiring several recruits during the week just
## means fewer get discarded at the next refresh, no special-casing needed.
func _refresh_pool() -> void:
	pool.shuffle()
	var discard_count := pool.size() / 2
	for _i in range(discard_count):
		pool.pop_back()
	while pool.size() < pool_size:
		pool.append(_generate_recruit())
	pool_refreshed.emit()
	print("[HiringManager] Hiring pool refreshed (%d recruits, next refresh in %d days)" % [
		pool.size(), refresh_interval_days,
	])

func _generate_recruit() -> AgentData:
	var recruit_name := NameGenerator.generate_name()
	var archetype := AgentGenerator.Archetype.GENERALIST if randf() < generalist_chance \
			else AgentGenerator.Archetype.SPECIALIST
	return AgentGenerator.generate(recruit_name, archetype)

## Hires the given pool recruit onto the roster for hire_cost funding.
## Returns false (no charge, no change) if the recruit isn't in the pool
## or funding is short.
func hire(agent_id: String) -> bool:
	var idx := _find_pool_index(agent_id)
	if idx == -1:
		return false
	if not Game.resource_state.spend_funding(hire_cost):
		return false

	var agent: AgentData = pool[idx]
	pool.remove_at(idx)
	Game.agent_manager.add_recruit(agent)
	recruit_hired.emit(agent)
	print("[HiringManager] Hired %s for %d funding" % [agent.agent_name, hire_cost])
	return true

func _find_pool_index(agent_id: String) -> int:
	for i in range(pool.size()):
		if pool[i].id == agent_id:
			return i
	return -1

func get_days_until_refresh() -> int:
	return refresh_interval_days - _days_since_refresh
