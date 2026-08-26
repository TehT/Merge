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

## The specific vehicle this team currently has with them, or null if
## they're not holding one (idle at a base with nothing checked out). A
## vehicle in transit belongs exclusively to whichever team is using it —
## removed from its base's own fleet the moment they take it (see
## TeamManager._pickup_vehicle) and returned to whichever base they next
## arrive at, unless they're away from every base (e.g. sitting at a
## mission site), in which case it just stays with them (see
## TeamManager._release_vehicle / _complete_travel). Never available to a
## different team's route search while attached to this one.
var current_vehicle: VehicleData = null

## Travel state. is_traveling is what "away from location" means; the
## other fields are only meaningful while it's true. travel_event_id ties
## the trip back to the event EventManager should resolve on arrival.
## travel_is_return marks the trip home after a mission: agent status
## results from that mission are held in pending_agent_results and only
## applied once the team is physically back (see TeamManager).
##
## travel_departure_day / travel_arrival_day are fractional day counts
## (GameClock.get_current_time_days()), not whole day indices — travel
## resolves at hour precision, not on day-tick boundaries.
var is_traveling: bool = false
var is_training: bool = false
var travel_destination: Vector2 = Vector2.ZERO
var travel_destination_name: String = ""
var travel_departure_day: float = 0.0
var travel_arrival_day: float = 0.0
var travel_event_id: String = ""
var travel_vehicle_name: String = ""
var travel_is_return: bool = false

## Where a mission-deploy journey originally departed from, and the
## routing target for the trip home — resolved to a base via
## BaseManager.get_base_at()/get_nearest_base() and run through
## TravelRouter.find_routes() (TeamManager.begin_return_travel()), not
## necessarily a single hop.
var travel_return_to: Vector2 = Vector2.ZERO
var travel_return_to_name: String = ""
var pending_agent_results: Dictionary = {} # agent_id -> AgentData.Status

## Legs still to fly after whichever leg is currently in flight (i.e.
## travel_destination/travel_arrival_day) — a multi-leg journey built by
## TravelRouter. Empty for a direct (single-leg) trip. Consumed one at a
## time by TeamManager._complete_travel as each leg's arrival is
## processed; the terminal-intent flags below (travel_is_return/
## travel_is_relocation/travel_event_id) are set once at journey start and
## only acted on once this empties out.
var travel_queued_legs: Array[Dictionary] = []

## True for a base-to-base relocation (TeamManager.begin_base_transfer),
## as opposed to a mission deployment/return trip. A relocation has no
## event to resolve and no return leg — arriving just means "this is
## where the team lives now," so _complete_travel() restores members to
## AVAILABLE immediately instead of holding them DEPLOYED pending a
## mission outcome or a trip home.
var travel_is_relocation: bool = false

## On-site mission work state — distinct from is_traveling, which only
## covers the physical travel legs before and after this. True from the
## moment a team physically arrives at a deployed event until
## mission_duration_hours (EventData) has elapsed; only then does
## TeamManager resolve the mission and start the trip home. Mirrors
## is_traveling's shape (a bool + a fractional-day target,
## GameClock.get_current_time_days()), just for a stationary wait instead
## of a move.
var is_on_mission: bool = false
var mission_ready_day: float = 0.0
var mission_event_id: String = ""

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
	var totals := SkillHandler.empty_proficiency_dict()
	if members.is_empty():
		return totals

	var weight_sum := 0.0
	for m in members:
		var w := maxf(1.0, m.get_average_proficiency_rank())
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
