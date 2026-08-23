## TeamData — a persistent squad of 3-5 agents. Replaces ad-hoc per-mission
## agent picking: agents deploy as a team, and the team's effective
## proficiency profile is a level-weighted average of its current members,
## boosted by cohesion (built up through missions completed together and
## dedicated training — see TeamManager).
class_name TeamData
extends Resource

const MIN_SIZE := 3
const MAX_SIZE := 5

const MAX_COHESION_BONUS := 0.5

@export var id: String = ""
@export var team_name: String = ""
@export var member_ids: Array[String] = []

var cohesion: float = 0.0

## Current location (lon, lat) — set to HQ by TeamManager on creation, and
## updated to the destination when travel completes.
var location: Vector2 = Vector2.ZERO
var location_name: String = ""

## Travel state. is_traveling is what "away from location" means; the
## other fields are only meaningful while it's true. travel_event_id ties
## the trip back to the event EventManager should resolve on arrival.
## travel_is_return marks the trip home after a mission: agent status
## results from that mission are held in pending_agent_results and only
## applied once the team is physically back (see TeamManager).
var is_traveling: bool = false
var travel_destination: Vector2 = Vector2.ZERO
var travel_destination_name: String = ""
var travel_departure_day: int = 0
var travel_arrival_day: int = 0
var travel_event_id: String = ""
var travel_vehicle_name: String = ""
var travel_is_return: bool = false
var travel_return_to: Vector2 = Vector2.ZERO
var travel_return_to_name: String = ""
var pending_agent_results: Dictionary = {} # agent_id -> AgentData.Status

func setup(p_name: String, ids: Array[String]) -> TeamData:
	id = _generate_id()
	team_name = p_name
	member_ids = ids.duplicate()
	return self

static func _generate_id() -> String:
	return "team_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

func is_valid_size() -> bool:
	return member_ids.size() >= MIN_SIZE and member_ids.size() <= MAX_SIZE

func has_member(agent_id: String) -> bool:
	return agent_id in member_ids

func compute_effective_skills(members: Array[AgentData]) -> Dictionary:
	var totals := SkillData.empty_proficiency_dict()
	if members.is_empty():
		return totals

	var weight_sum := 0.0
	for m in members:
		var w := float(maxi(1, m.level))
		weight_sum += w
		var scores := m.get_proficiency_scores()
		for key: String in totals:
			totals[key] += scores[key] * w

	var bonus := 1.0 + (cohesion / 100.0) * MAX_COHESION_BONUS
	for key: String in totals:
		totals[key] = (totals[key] / weight_sum) * bonus
	return totals

func get_status_summary() -> String:
	return "%s (%d members, cohesion %.0f%%)" % [team_name, member_ids.size(), cohesion]
