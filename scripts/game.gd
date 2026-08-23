extends Node
## Game — autoload singleton (see project.godot [autoload]). A typed
## registry of the core managers and top-level UI panels, so other code
## can use e.g. Game.agent_manager instead of %AgentManager.
##
## Why this exists: %UniqueName lookups resolve by walking the calling
## node's `owner` chain, but nodes created purely at runtime
## (SomeControl.new() + add_child(), which is how every dynamically-built
## detail/slideout view in scripts/ui/detail_view_*.gd and
## scripts/ui/slideout_view_*.gd is built) never get `owner` assigned —
## add_child() alone doesn't set it, only packed-scene instantiation does.
## %-lookups performed from inside those dynamically-created nodes can
## silently fail to resolve. Game sidesteps this: autoload singletons
## resolve by global name, not by walking any node's owner chain, so
## Game.agent_manager works identically no matter how or where the
## calling code was created.
##
## The managers themselves are still plain scene nodes under Main, NOT
## autoloads (duplicating them as autoloads is exactly the bug that was
## fixed earlier — see the technical GDD's gotchas list). Each one
## registers itself into Game as the very first line of its own _ready(),
## so Game is only ever read after the registering manager's _ready() has
## run. Sibling order in Main.tscn still matters for cross-manager reads
## during _ready() (e.g. TeamManager building its starting team from
## AgentManager's roster) exactly as it did with %-lookups — this doesn't
## change that, it only changes how the reference is resolved.

var game_clock: GameClock
var resource_state: ResourceState
var concealment_state: ConcealmentState
var agent_manager: AgentManager
var team_manager: TeamManager
var event_manager: EventManager
var geo_data: GeoData

## The two top-level UI panels dynamically-created views need to reach
## (deploy/vehicle/proficiency clicks, mission reports). Everything else
## UI-side (SquadList, EventList, MarkerLayer, ...) is only ever
## referenced from properly scene-owned scripts, where %-lookups already
## work fine — no need to register those here too.
var detail_sidebar: DetailSidebar
var slideout_panel: SlideoutPanel
