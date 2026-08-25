class_name MissionResolutionStrategy
extends Resource
## MissionResolutionStrategy — Strategy pattern base for mission
## resolution. Each MissionCheck holds one (@export-swappable in the
## Inspector, or assignable at runtime) and calls resolve() without
## knowing which concrete algorithm is behind it, so the resolution method
## can change (a single stat check, tag-breadth pooling, ...) without
## touching MissionPhaseRunner or MissionCheck's own plumbing.
## Resource (not RefCounted) so concrete strategies can carry their own
## tunable @export parameters and be saved/swapped as .tres files, same as
## VehicleData/SkillData.

## Resolves a mission for the given squad against the given check.
## Concrete strategies override this and must return a fully-populated
## MissionResolutionResult — the contract every caller relies on.
func resolve(_check: MissionCheck, _squad: Array[AgentData]) -> MissionResolutionResult:
	push_error("MissionResolutionStrategy.resolve() not implemented — override in a subclass")
	return MissionResolutionResult.new()
