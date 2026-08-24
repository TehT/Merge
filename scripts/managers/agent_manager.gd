extends Node
class_name AgentManager
## AgentManager — a persistent node in Main.tscn, referenced elsewhere via
## Game.agent_manager (registers itself in _ready() — see game.gd). Owns
## the player's agent roster: the starting 4 agents, status transitions,
## and lookup helpers.

signal roster_changed()
signal agent_status_changed(agent_id: String, old_status: AgentData.Status, new_status: AgentData.Status)

@export var roster: Array[AgentData] = []

func _ready() -> void:
	Game.agent_manager = self
	roster = _create_starting_roster()
	print("[AgentManager] roster initialized with %d agents" % roster.size())

## Starting roster's skills, loaded from saved SkillData resources (see
## res://data/skills/<proficiency>/) instead of built inline — rebalancing
## a skill or adding a new one is a .tres edit, not a code change. Skills
## aren't agent-specific, so they're grouped by proficiency rather than by
## which agent happens to use them; the same resource can be reused across
## multiple agents. The agent shells themselves (name, supernatural type)
## stay code-built here since there's no per-agent resource type yet.
func _create_starting_roster() -> Array[AgentData]:
	var roster_out: Array[AgentData] = []

	var mara_skills: Array[SkillData] = [
		preload("res://data/skills/combat/close_quarters_combat.tres"),
		preload("res://data/skills/combat/firearms.tres"),
		preload("res://data/skills/subterfuge/fieldcraft.tres"),
		preload("res://data/skills/ingenuity/threat_assessment.tres"),
	]
	roster_out.append(AgentData.new().setup("Mara Okonkwo", mara_skills, AgentData.SupernaturalType.NONE))

	var iris_skills: Array[SkillData] = [
		preload("res://data/skills/subterfuge/shadowmeld.tres"),
		preload("res://data/skills/subterfuge/infiltration.tres"),
		preload("res://data/skills/attunement/dark_channeling.tres"),
		preload("res://data/skills/erudition/occult_lore.tres"),
	]
	roster_out.append(AgentData.new().setup("Iris Vance", iris_skills, AgentData.SupernaturalType.SHADOW))

	var desmond_skills: Array[SkillData] = [
		preload("res://data/skills/influence/negotiation.tres"),
		preload("res://data/skills/ingenuity/electronic_surveillance.tres"),
		preload("res://data/skills/erudition/research.tres"),
		preload("res://data/skills/ingenuity/cryptography.tres"),
	]
	roster_out.append(AgentData.new().setup("Desmond Ffrench", desmond_skills, AgentData.SupernaturalType.NONE))

	var kalinda_skills: Array[SkillData] = [
		preload("res://data/skills/attunement/precognition.tres"),
		preload("res://data/skills/combat/combat_training.tres"),
		preload("res://data/skills/influence/intuition.tres"),
		preload("res://data/skills/erudition/anomaly_reading.tres"),
	]
	roster_out.append(AgentData.new().setup("Kalinda Reyes", kalinda_skills, AgentData.SupernaturalType.SEER))

	return roster_out

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
