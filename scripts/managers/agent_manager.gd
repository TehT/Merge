extends Node
class_name AgentManager
## AgentManager — a persistent node in Main.tscn, referenced elsewhere via
## Game.agent_manager (registers itself in _ready() — see game.gd). Owns
## the player's agent roster: the procedurally-generated starting recruits,
## status transitions, and lookup helpers.

signal roster_changed()
signal agent_status_changed(agent_id: String, old_status: AgentData.Status, new_status: AgentData.Status)

@export var roster: Array[AgentData] = []

## How many recruits to procedurally generate for the starting roster.
@export var starting_roster_size: int = 4

## Chance (0-1) that a given recruit is generated as a Generalist rather
## than a Specialist. 0.6 = 3:5 generalists, i.e. a 2:3 specialist-to-
## generalist ratio.
@export_range(0.0, 1.0) var generalist_chance: float = 0.6

func _ready() -> void:
	Game.agent_manager = self
	roster = _create_starting_roster()
	print("[AgentManager] roster initialized with %d agents" % roster.size())

## Starting roster, procedurally built via AgentGenerator instead of
## hand-authored — each recruit gets a NameGenerator name, then
## AgentGenerator.generate_random() rolls their personality first and
## derives Generalist vs. Specialist from it (generalist_chance keeps its
## old aggregate meaning as a threshold on the Protocol axis — see
## AgentGenerator), draws skills from the res://data/skills/<proficiency>/
## catalog. All mundane for now; nothing rolls a SupernaturalType yet
## since there's no Awakened skill catalog to draw from.
func _create_starting_roster() -> Array[AgentData]:
	var roster_out: Array[AgentData] = []
	for i in range(starting_roster_size):
		var recruit_name := NameGenerator.generate_name()
		roster_out.append(AgentGenerator.generate_random(recruit_name, generalist_chance))
	return roster_out

## Adds a hired recruit (from HiringManager) directly onto the roster —
## separate from _create_starting_roster() since this happens mid-game,
## one agent at a time, in response to a player action rather than at
## startup.
func add_recruit(agent: AgentData) -> void:
	roster.append(agent)
	roster_changed.emit()

func get_available_agents() -> Array[AgentData]:
	return roster.filter(func(a: AgentData): return a.is_available())

func get_agent_by_id(agent_id: String) -> AgentData:
	for a in roster:
		if a.id == agent_id:
			return a
	return null

func set_status(agent_id: String, new_status: AgentData.Status) -> void:
	var a := get_agent_by_id(agent_id)
	if a == null:
		return
	var old_status := a.status
	if old_status == new_status:
		return
	a.status = new_status
	agent_status_changed.emit(agent_id, old_status, new_status)

	if new_status == AgentData.Status.KIA:
		roster.erase(a)
		print("[AgentManager] %s was KIA and is gone for good." % a.agent_name)
		roster_changed.emit()

func print_roster_status() -> void:
	print("[AgentManager] roster (%d):" % roster.size())
	for a in roster:
		var ranks := a.get_proficiency_ranks()
		print("  %s [%s/%s] C=%d Su=%d At=%d Er=%d In=%d Ig=%d hp=%.0f/%.0f" % [
			a.agent_name, a.get_status_name(), a.get_type_name(),
			ranks["combat"], ranks["subterfuge"],
			ranks["attunement"], ranks["erudition"],
			ranks["influence"], ranks["ingenuity"],
			a.health, a.max_health,
		])
