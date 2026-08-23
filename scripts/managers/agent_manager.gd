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

func _create_starting_roster() -> Array[AgentData]:
	var roster_out: Array[AgentData] = []

	var mara_skills: Array[SkillData] = [
		SkillData.new("Close Quarters Combat", SkillData.Proficiency.COMBAT, 4, PackedStringArray(["Melee", "Mundane"])),
		SkillData.new("Firearms", SkillData.Proficiency.COMBAT, 3, PackedStringArray(["Ranged", "Mundane"])),
		SkillData.new("Fieldcraft", SkillData.Proficiency.SUBTERFUGE, 2, PackedStringArray(["Stealth", "Mundane"])),
		SkillData.new("Threat Assessment", SkillData.Proficiency.INGENUITY, 1, PackedStringArray(["Tactical"])),
	]
	roster_out.append(AgentData.new().setup("Mara Okonkwo", mara_skills, AgentData.SupernaturalType.NONE))

	var iris_skills: Array[SkillData] = [
		SkillData.new("Shadowmeld", SkillData.Proficiency.SUBTERFUGE, 4, PackedStringArray(["Stealth", "Arcane"])),
		SkillData.new("Infiltration", SkillData.Proficiency.SUBTERFUGE, 3, PackedStringArray(["Stealth", "Mundane"])),
		SkillData.new("Dark Channeling", SkillData.Proficiency.ATTUNEMENT, 3, PackedStringArray(["Arcane", "Offensive"])),
		SkillData.new("Occult Lore", SkillData.Proficiency.ERUDITION, 2, PackedStringArray(["Knowledge"])),
	]
	roster_out.append(AgentData.new().setup("Iris Vance", iris_skills, AgentData.SupernaturalType.SHADOW))

	var desmond_skills: Array[SkillData] = [
		SkillData.new("Negotiation", SkillData.Proficiency.INFLUENCE, 4, PackedStringArray(["Social", "Mundane"])),
		SkillData.new("Electronic Surveillance", SkillData.Proficiency.INGENUITY, 3, PackedStringArray(["Tech", "Mundane"])),
		SkillData.new("Research", SkillData.Proficiency.ERUDITION, 3, PackedStringArray(["Knowledge", "Mundane"])),
		SkillData.new("Cryptography", SkillData.Proficiency.INGENUITY, 2, PackedStringArray(["Tech", "Knowledge"])),
	]
	roster_out.append(AgentData.new().setup("Desmond Ffrench", desmond_skills, AgentData.SupernaturalType.NONE))

	var kalinda_skills: Array[SkillData] = [
		SkillData.new("Precognition", SkillData.Proficiency.ATTUNEMENT, 3, PackedStringArray(["Arcane", "Divination"])),
		SkillData.new("Combat Training", SkillData.Proficiency.COMBAT, 2, PackedStringArray(["Melee", "Mundane"])),
		SkillData.new("Intuition", SkillData.Proficiency.INFLUENCE, 2, PackedStringArray(["Social", "Arcane"])),
		SkillData.new("Anomaly Reading", SkillData.Proficiency.ERUDITION, 2, PackedStringArray(["Knowledge", "Arcane"])),
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
