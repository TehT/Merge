extends Node

var game_clock: GameClock
var resource_state: ResourceState
var concealment_state: ConcealmentState
var agent_manager: AgentManager
var base_manager: BaseManager
var team_manager: TeamManager
var event_manager: EventManager
var event_log: EventLog
var hiring_manager: HiringManager
var geo_data: GeoData
var marker_layer: MarkerLayer

var left_detail: PanelHost
var left_popout: PanelHost
var right_primary: PanelHost
var right_popout: PanelHost
var mission_choice_dialog: MissionChoiceDialog
var root_ui: RootUI
