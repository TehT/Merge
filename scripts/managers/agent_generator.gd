## AgentGenerator — procedural agent creation. Builds a full AgentData
## (skills + proficiency spread + personality) drawing skills from
## SkillHandler.get_skills_for_proficiency() and instantiate()ing them so
## generated agents never alias a shared catalog resource. A static
## utility (RefCounted), not an autoload. generate_random() is the sole
## entry point callers should use (see below) — generate_specialist()/
## generate_generalist()/generate_random_specialist() are its building
## blocks, still independently useful for hand-authored content.
class_name AgentGenerator
extends RefCounted

## Specialist: 5 skills total — 3 in a primary Proficiency (one at rank 2,
## two at rank 1, which SkillHandler's rank aggregation resolves to
## Proficiency rank 2) and 2 in a secondary Proficiency (both at rank 1,
## resolving to Proficiency rank 1).
static func generate_specialist(agent_name: String, primary: SkillData.Proficiency,
		secondary: SkillData.Proficiency,
		supernatural_type: AgentData.SupernaturalType = AgentData.SupernaturalType.NONE) -> AgentData:
	assert(primary != secondary, "AgentGenerator: specialist primary/secondary must differ")

	var skills: Array[SkillData] = []

	var primary_pool := SkillHandler.get_skills_for_proficiency(primary)
	primary_pool.shuffle()
	for i in range(mini(3, primary_pool.size())):
		skills.append(SkillHandler.instantiate(primary_pool[i], 2 if i == 0 else 1))

	var secondary_pool := SkillHandler.get_skills_for_proficiency(secondary)
	secondary_pool.shuffle()
	for i in range(mini(2, secondary_pool.size())):
		skills.append(SkillHandler.instantiate(secondary_pool[i], 1))

	return AgentData.new().setup(agent_name, skills, supernatural_type)


## Generalist: 6 skills total, every one at rank 1, spread across 4
## different Proficiencies (each resolving to Proficiency rank 1 — an
## all-rank-1 category never has a skill meeting the rank-2 threshold, so
## it stays at rank 1 regardless of skill count). 2 of those 4
## Proficiencies get 2 skills each, the other 2 get 1 skill each.
static func generate_generalist(agent_name: String,
		supernatural_type: AgentData.SupernaturalType = AgentData.SupernaturalType.NONE) -> AgentData:
	var profs: Array = SkillData.Proficiency.values()
	profs.shuffle()
	var chosen: Array = profs.slice(0, 4)

	var skills: Array[SkillData] = []
	for i in range(chosen.size()):
		var pool := SkillHandler.get_skills_for_proficiency(chosen[i])
		pool.shuffle()
		var count: int = 2 if i < 2 else 1
		for j in range(mini(count, pool.size())):
			skills.append(SkillHandler.instantiate(pool[j], 1))

	return AgentData.new().setup(agent_name, skills, supernatural_type)


## Convenience: picks primary/secondary Proficiencies at random and
## delegates to generate_specialist().
static func generate_random_specialist(agent_name: String,
		supernatural_type: AgentData.SupernaturalType = AgentData.SupernaturalType.NONE) -> AgentData:
	var profs: Array = SkillData.Proficiency.values()
	profs.shuffle()
	return generate_specialist(agent_name, profs[0], profs[1], supernatural_type)


## Rolls a full personality (PersonalityHandler.roll_random_axes()),
## derives Specialist vs. Generalist from the Protocol axis instead of an
## independent coin flip — a high-Protocol/Orthodox agent tests out as a
## Specialist, one correlation, nothing deeper yet (design doc §3.6).
## generalist_chance keeps its old aggregate meaning (0.6 = 60%
## generalists): Protocol rolls uniform 0-100, so gating the split at
## (100 * generalist_chance) reproduces the same population-level ratio
## the old independent flip gave. The sole entry point every caller
## (AgentManager's starting roster, HiringManager's weekly pool) should use.
static func generate_random(agent_name: String, generalist_chance: float,
		supernatural_type: AgentData.SupernaturalType = AgentData.SupernaturalType.NONE) -> AgentData:
	var personality := PersonalityHandler.roll_random_axes()
	var is_generalist: bool = personality["protocol"] < int(100.0 * generalist_chance)

	var agent: AgentData = generate_generalist(agent_name, supernatural_type) if is_generalist \
			else generate_random_specialist(agent_name, supernatural_type)

	agent.protocol = personality["protocol"]
	agent.nerve = personality["nerve"]
	agent.attachment = personality["attachment"]
	agent.esoterica = personality["esoterica"]
	agent.ego = personality["ego"]
	return agent
