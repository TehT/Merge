class_name PersonalityHandler
extends RefCounted
## PersonalityHandler — the Personality Matrix's table-driven computation,
## parallel to SkillHandler: static, no persistent state. Owns the five
## axis keys/pole names, the Archetype naming tables, and the live
## Archetype-readout derivation. See concurrence_agent_design_merged.md §3
## for the design this implements — only the core matrix (axes + Archetype
## + a callable drift primitive); Quirks/Backgrounds/Crucibles (§4) are a
## separate, larger, not-yet-built system.

const AXIS_KEYS: PackedStringArray = ["protocol", "nerve", "attachment", "esoterica", "ego"]

## Each axis's low/high pole name — §3.1.
const POLE_NAMES: Dictionary = {
	"protocol": {"low": "Improviser", "high": "Orthodox"},
	"nerve": {"low": "Cautious", "high": "Reckless"},
	"attachment": {"low": "Detached", "high": "Compassionate"},
	"esoterica": {"low": "Pragmatic", "high": "Attuned"},
	"ego": {"low": "Collaborator", "high": "Dominant"},
}

## Base single-axis titles — used by the cascade's dynamic bottom tier
## (see compute_archetype), never as a fixed CASCADE entry: a fixed entry
## per axis would let list-order silently override actual extremity
## (whichever axis's entry appears first would win for almost every
## agent, since "moderate" thresholds match most non-neutral values).
## Picking the single most-extreme axis at lookup time avoids that.
const BASE_TITLES: Dictionary = {
	"protocol": {"low": "The Maverick", "high": "The Purist"},
	"nerve": {"low": "The Sentinel", "high": "The Daredevil"},
	"attachment": {"low": "The Observer", "high": "The Guardian"},
	"esoterica": {"low": "The Realist", "high": "The Mystic"},
	"ego": {"low": "The Catalyst", "high": "The Sovereign"},
}

## The Archetype Priority Cascade: curated, top-down, first-match-wins.
## Each entry is {"title": String, "conditions": Array of [axis,
## comparator, threshold]}, AND-combined. Ordered most specific/extreme
## first — Apex (3 axes, <20/>80ish) above Synergy (2 axes, <35/>65ish) —
## so a rarer, more specific match is never shadowed by a broader one
## listed after it. A starter set; edit freely, but keep new entries
## slotted in by specificity, not appended at the end.
const CASCADE: Array = [
	# --- Apex: three axes at extreme thresholds ---
	{"title": "The Shadow Sovereign", "conditions": [["attachment", "<", 15], ["ego", ">", 85], ["nerve", "<", 30]]},
	{"title": "The Zealot", "conditions": [["protocol", ">", 85], ["esoterica", ">", 80], ["nerve", "<", 20]]},
	{"title": "The Berserker", "conditions": [["protocol", "<", 20], ["nerve", ">", 85], ["ego", ">", 80]]},
	{"title": "The Ghost", "conditions": [["protocol", ">", 80], ["nerve", "<", 20], ["attachment", "<", 20]]},
	{"title": "The Oracle", "conditions": [["attachment", ">", 80], ["esoterica", ">", 85], ["ego", "<", 20]]},
	{"title": "The Warlord", "conditions": [["protocol", ">", 80], ["attachment", "<", 20], ["ego", ">", 85]]},

	# --- Synergy: two axes at strong thresholds ---
	{"title": "The Hothead", "conditions": [["nerve", ">", 60], ["protocol", "<", 49]]},
	{"title": "The Cold Operator", "conditions": [["protocol", ">", 65], ["attachment", "<", 35]]},
	{"title": "The True Believer", "conditions": [["protocol", ">", 65], ["esoterica", ">", 65]]},
	{"title": "The Company Man", "conditions": [["protocol", ">", 65], ["ego", "<", 35]]},
	{"title": "The Loose Cannon", "conditions": [["nerve", ">", 65], ["attachment", "<", 35]]},
	{"title": "The Iron Fist", "conditions": [["nerve", "<", 35], ["ego", ">", 65]]},
	{"title": "The Zealous Guardian", "conditions": [["attachment", ">", 65], ["esoterica", ">", 65]]},
	{"title": "The Kingmaker", "conditions": [["attachment", ">", 65], ["ego", ">", 65]]},
]

## Independent uniform 0-100 roll per axis — today's only source of
## initial personality (Backgrounds, which the design doc frames as the
## "real" seed, aren't built yet).
static func roll_random_axes() -> Dictionary:
	var out: Dictionary = {}
	for key: String in AXIS_KEYS:
		out[key] = randi_range(0, 100)
	return out


## Live-computed — never stored on the agent, so personality drift changes
## an agent's Archetype for free the moment it happens. Walks CASCADE
## top-down and returns the first rule whose conditions all pass. If none
## match, falls through to a dynamic single-axis title (BASE_TITLES) for
## whichever axis sits furthest from neutral — and to "The Citizen" only
## when every axis is exactly 50 (nothing to name).
static func compute_archetype(agent: AgentData) -> String:
	var values: Dictionary = {
		"protocol": agent.protocol,
		"nerve": agent.nerve,
		"attachment": agent.attachment,
		"esoterica": agent.esoterica,
		"ego": agent.ego,
	}

	for rule: Dictionary in CASCADE:
		if _matches(rule["conditions"], values):
			return rule["title"]

	var ranked: Array = Array(AXIS_KEYS)
	ranked.sort_custom(func(a: String, b: String) -> bool:
		return abs(values[a] - 50) > abs(values[b] - 50))

	var top_axis: String = ranked[0]
	if values[top_axis] == 50:
		return "The Citizen"

	var pole: String = "high" if values[top_axis] > 50 else "low"
	return BASE_TITLES[top_axis][pole]


static func _matches(conditions: Array, values: Dictionary) -> bool:
	for cond: Array in conditions:
		var axis: String = cond[0]
		var comparator: String = cond[1]
		var threshold: int = cond[2]
		var value: int = values[axis]
		var passes: bool
		match comparator:
			"<": passes = value < threshold
			">": passes = value > threshold
			"<=": passes = value <= threshold
			">=": passes = value >= threshold
			_:
				push_warning("PersonalityHandler: unknown comparator '%s'" % comparator)
				passes = false
		if not passes:
			return false
	return true
