## EventData — Core data structure for magical events.
##
## An event represents a magical incident on the geoscape that the player
## must respond to. Events spawn at real locations, have proficiency
## requirements that determine which agents are suited to handle them,
## and carry consequences for success, failure, or neglect.
class_name EventData
extends Resource

## ── Enums ────────────────────────────────────────────────────────────────────

enum EventType {
	CRYPTID_SIGHTING,
	MAGICAL_SURGE,
	ARTIFACT_ACTIVATION,
	PORTAL_BREACH,
	CULT_ACTIVITY,
	FAIRY_INCURSION,
	HAUNTING,
	MIRROR_MERGE,
}

enum Urgency { LOW, MEDIUM, HIGH, CRITICAL }

enum Status { ACTIVE, DEPLOYED, RESOLVED_SUCCESS, RESOLVED_PARTIAL, RESOLVED_FAIL, EXPIRED }

## ── Identity ────────────────────────────────────────────────────────────────

@export var id: String = ""
@export var event_type: EventType = EventType.MAGICAL_SURGE
@export var title: String = ""
@export var summary: String = ""
@export_multiline var description: String = ""

## ── Location ────────────────────────────────────────────────────────────────

@export var location_city: String = ""
@export var location_country: String = ""
@export var geo_coordinates: Vector2 = Vector2.ZERO
@export var grid_cell: Vector2 = Vector2.ZERO
@export var biome: String = ""

## ── Urgency & Timing ────────────────────────────────────────────────────────

@export var urgency: Urgency = Urgency.MEDIUM
@export var day_spawned: int = 0
@export var time_limit_days: int = 3
var days_remaining: int = 3

## ── Proficiency Requirements ───────────────────────────────────────────────
## Each value is a required proficiency rank (0-10). 0 means that
## proficiency is irrelevant. Compared against agent/team proficiency
## ranks to calculate suitability.

@export_group("Proficiency Requirements")
@export_range(0, 10) var req_combat: int = 0
@export_range(0, 10) var req_subterfuge: int = 0
@export_range(0, 10) var req_attunement: int = 0
@export_range(0, 10) var req_erudition: int = 0
@export_range(0, 10) var req_influence: int = 0
@export_range(0, 10) var req_ingenuity: int = 0

func set_proficiency_profile(combat: int, subterfuge: int, attunement: int,
		erudition: int, influence: int, ingenuity: int) -> void:
	req_combat = combat
	req_subterfuge = subterfuge
	req_attunement = attunement
	req_erudition = erudition
	req_influence = influence
	req_ingenuity = ingenuity

func get_proficiency_requirements() -> Dictionary:
	return {
		"combat": req_combat,
		"subterfuge": req_subterfuge,
		"attunement": req_attunement,
		"erudition": req_erudition,
		"influence": req_influence,
		"ingenuity": req_ingenuity,
	}

func get_skill_requirements() -> Dictionary:
	return get_proficiency_requirements()

func get_primary_proficiency() -> String:
	var reqs := get_proficiency_requirements()
	var best_key := "combat"
	var best_val := 0
	for key: String in reqs:
		if reqs[key] > best_val:
			best_val = reqs[key]
			best_key = key
	return best_key

func get_required_rank_count() -> int:
	var count := 0
	for key: String in SkillData.PROFICIENCY_KEYS:
		if get_proficiency_requirements()[key] > 0:
			count += 1
	return count

func get_total_difficulty() -> int:
	return req_combat + req_subterfuge + req_attunement + req_erudition \
		+ req_influence + req_ingenuity

## ── Tags ────────────────────────────────────────────────────────────────────
## Event tags interact with agent skill tags — a tag here can counter
## agent skills that share the same tag, reducing effective proficiency.

@export_group("Tags")
@export var tags: PackedStringArray = []

## Counter-tags: agent skills with these tags are negated for this event.
## e.g. ["Melee"] means skills tagged [Melee] contribute nothing.
@export var counter_tags: PackedStringArray = []

func has_tag(tag: String) -> bool:
	return tag in tags

## ── Stakes ──────────────────────────────────────────────────────────────────

@export_group("Stakes")
@export var concealment_on_fail: float = 5.0
@export var concealment_on_partial: float = 2.0
@export var concealment_on_success: float = -1.0

## ── Rewards ─────────────────────────────────────────────────────────────────

@export_group("Rewards")
@export var reward_funding: int = 50
@export var reward_intel: int = 10
@export var reward_item: String = ""

## ── Escalation ──────────────────────────────────────────────────────────────

@export_group("Escalation")
@export var escalates_to: EventType = EventType.MAGICAL_SURGE
@export var can_escalate: bool = false
@export var escalation_rank_bump: int = 1

## ── Decision Event ──────────────────────────────────────────────────────────

@export_group("Decision")
@export var is_decision_event: bool = false
@export_multiline var decision_prompt: String = ""
@export var decision_option_labels: PackedStringArray = []
@export var decision_option_concealment: PackedFloat32Array = []
@export var decision_option_funding: PackedInt32Array = []
@export var decision_option_consequence_keys: PackedStringArray = []

## ── Runtime State ───────────────────────────────────────────────────────────

var status: Status = Status.ACTIVE
var assigned_agent_ids: Array[String] = []
var resolution_roll: float = -1.0

## ── Convenience ─────────────────────────────────────────────────────────────

func setup(p_title: String, p_type: EventType, p_urgency: Urgency = Urgency.MEDIUM) -> EventData:
	id = _generate_id()
	title = p_title
	event_type = p_type
	urgency = p_urgency
	days_remaining = time_limit_days
	return self

static func _generate_id() -> String:
	return "evt_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

func get_type_name() -> String:
	match event_type:
		EventType.CRYPTID_SIGHTING: return "Cryptid Sighting"
		EventType.MAGICAL_SURGE: return "Magical Surge"
		EventType.ARTIFACT_ACTIVATION: return "Artifact Activation"
		EventType.PORTAL_BREACH: return "Portal Breach"
		EventType.CULT_ACTIVITY: return "Cult Activity"
		EventType.FAIRY_INCURSION: return "Fairy Incursion"
		EventType.HAUNTING: return "Haunting"
		EventType.MIRROR_MERGE: return "Mirror Merge"
	return "Unknown"

func get_urgency_name() -> String:
	match urgency:
		Urgency.LOW: return "Low"
		Urgency.MEDIUM: return "Medium"
		Urgency.HIGH: return "High"
		Urgency.CRITICAL: return "Critical"
	return "Unknown"

func get_urgency_color() -> Color:
	match urgency:
		Urgency.LOW: return Color(0.4, 0.7, 0.4)
		Urgency.MEDIUM: return Color(0.9, 0.8, 0.2)
		Urgency.HIGH: return Color(0.9, 0.5, 0.1)
		Urgency.CRITICAL: return Color(0.9, 0.15, 0.15)
	return Color.WHITE

func is_expired() -> bool:
	return days_remaining <= 0 and status == Status.ACTIVE

func has_agents_assigned() -> bool:
	return not assigned_agent_ids.is_empty()
