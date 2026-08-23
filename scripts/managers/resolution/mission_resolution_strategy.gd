class_name MissionResolutionStrategy
extends Resource
## MissionResolutionStrategy — Strategy pattern base for mission
## resolution. EventManager holds one (@export-swappable in the Inspector,
## or assignable at runtime) and calls resolve() without knowing which
## concrete algorithm is behind it, so the resolution method can change (a
## single stat check today, a multi-phase gauntlet later) without touching
## the spawn/travel/arrival plumbing that calls it.
## Resource (not RefCounted) so concrete strategies can carry their own
## tunable @export parameters and be saved/swapped as .tres files, same as
## VehicleData/SkillData.

## Resolves a mission for the given squad against the given event.
## Concrete strategies override this and must return a fully-populated
## MissionResolutionResult — the contract every caller relies on.
func resolve(_event: EventData, _squad: Array[AgentData]) -> MissionResolutionResult:
	push_error("MissionResolutionStrategy.resolve() not implemented — override in a subclass")
	return MissionResolutionResult.new()
