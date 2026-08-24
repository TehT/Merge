## AgentGenerator — procedural agent creation. Builds a full AgentData
## (skills + proficiency spread) from an archetype and a proficiency
## choice, drawing skills from SkillHandler.get_skills_for_proficiency()
## and instantiate()ing them so generated agents never alias a shared
## catalog resource. A static utility (RefCounted), not an autoload.
class_name AgentGenerator
extends RefCounted

enum Archetype { SPECIALIST, GENERALIST }

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


static func generate(agent_name: String, archetype: Archetype,
		supernatural_type: AgentData.SupernaturalType = AgentData.SupernaturalType.NONE) -> AgentData:
	match archetype:
		Archetype.SPECIALIST:
			return generate_random_specialist(agent_name, supernatural_type)
		_:
			return generate_generalist(agent_name, supernatural_type)
