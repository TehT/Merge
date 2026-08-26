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

## The Archetype naming scheme (given, not derived from the design doc's
## own seed table — this fully replaces that curated 7-pair + generic-
## fallback approach). Each pole has a "Primary Archetype" noun-phrase,
## used when that axis is the agent's *most* extreme, and an "Archetype
## Modifier" adjective, used when it's the *second*-most extreme — so
## which of an agent's two dominant axes is more extreme genuinely changes
## the result (A-primary/B-secondary reads differently from B-primary/
## A-secondary), not just which two axes are involved.
const PRIMARY_ARCHETYPES: Dictionary = {
	"protocol": {"low": "The Maverick", "high": "The Purist"},
	"nerve": {"low": "The Sentinel", "high": "The Daredevil"},
	"attachment": {"low": "The Observer", "high": "The Guardian"},
	"esoterica": {"low": "The Realist", "high": "The Mystic"},
	"ego": {"low": "The Catalyst", "high": "The Sovereign"},
}

const ARCHETYPE_MODIFIERS: Dictionary = {
	"protocol": {"low": "Unbound", "high": "Strict"},
	"nerve": {"low": "Wary", "high": "Volatile"},
	"attachment": {"low": "Cold", "high": "Empathetic"},
	"esoterica": {"low": "Grounded", "high": "Ethereal"},
	"ego": {"low": "Synergistic", "high": "Commanding"},
}

## Independent uniform 0-100 roll per axis — today's only source of
## initial personality (Backgrounds, which the design doc frames as the
## "real" seed, aren't built yet).
static func roll_random_axes() -> Dictionary:
	var out: Dictionary = {}
	for key: String in AXIS_KEYS:
		out[key] = randi_range(0, 100)
	return out


## Live-computed — never stored on the agent, so personality drift changes
## an agent's Archetype for free the moment it happens. Ranks all five
## axes by distance from the neutral midpoint (50); the most extreme axis
## supplies the Primary Archetype noun, the second-most-extreme supplies
## the Modifier adjective, combined as "The <Modifier> <noun>" (the
## primary name's own "The " is stripped before combining). Full 10×9
## coverage by construction — no fallback needed. Ties resolve by
## AXIS_KEYS order; exactly 50 counts as the high pole.
static func compute_archetype(agent: AgentData) -> String:
	var values: Dictionary = {
		"protocol": agent.protocol,
		"nerve": agent.nerve,
		"attachment": agent.attachment,
		"esoterica": agent.esoterica,
		"ego": agent.ego,
	}

	var ranked: Array = Array(AXIS_KEYS)
	ranked.sort_custom(func(a: String, b: String) -> bool:
		return abs(values[a] - 50) > abs(values[b] - 50))

	var primary_axis: String = ranked[0]
	var secondary_axis: String = ranked[1]
	var primary_pole: String = "high" if values[primary_axis] >= 50 else "low"
	var secondary_pole: String = "high" if values[secondary_axis] >= 50 else "low"

	var primary_name: String = PRIMARY_ARCHETYPES[primary_axis][primary_pole]
	var modifier: String = ARCHETYPE_MODIFIERS[secondary_axis][secondary_pole]
	var noun: String = primary_name.trim_prefix("The ")

	return "The %s %s" % [modifier, noun]
