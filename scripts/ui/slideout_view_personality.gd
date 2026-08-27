extends VBoxContainer
## SlideoutViewPersonality — drill-down for one agent's full Personality
## Matrix: the Archetype readout plus a center-filled bar per axis. Each
## axis is stored 0-100 (unchanged), but reads visually as two 0-50
## scales back to back — the fill starts at the middle and grows toward
## whichever pole the value leans, so "50" always means dead-center/
## neutral and the bar's two halves are each pole's own 0-50 reach, not
## one 0-100 track.
##
## Layout lives in scenes/ui/views/slideout_personality.tscn (editable
## in the editor). The five axis rows are direct static instances of
## personality_axis_row.tscn with their axis name and pole labels set
## per instance in the editor; script only sets the numeric value.


func populate(data: Variant, on_close: Callable) -> void:
	var agent: AgentData = data

	%Header.close_requested.connect(on_close)

	%Archetype.text = agent.get_archetype()

	%ProtocolAxis.set_value(agent.protocol)
	%NerveAxis.set_value(agent.nerve)
	%AttachmentAxis.set_value(agent.attachment)
	%EsotericaAxis.set_value(agent.esoterica)
	%EgoAxis.set_value(agent.ego)
