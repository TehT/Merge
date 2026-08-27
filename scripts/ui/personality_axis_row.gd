@tool
extends VBoxContainer
## PersonalityAxisRow — one axis of an agent's Personality Matrix,
## rendered as a center-filled bar with pole labels on either side. Row
## count is fixed (five per matrix), so each instance lives directly in
## the slideout_personality.tscn with its axis_name / low_pole /
## high_pole @export set in the editor; script only sets the numeric
## value at populate() time (deviation label + fill width/side).

const BAR_W := 140.0
const BAR_H := 14.0
const FILL_COLOR := Color(0.75, 0.68, 0.5, 1.0)

@export var axis_name: String = "" :
	set(v):
		axis_name = v
		if is_inside_tree() and has_node("Header/Name"):
			$Header/Name.text = v

@export var low_pole: String = "" :
	set(v):
		low_pole = v
		if is_inside_tree() and has_node("BarRow/LowPole"):
			$BarRow/LowPole.text = v

@export var high_pole: String = "" :
	set(v):
		high_pole = v
		if is_inside_tree() and has_node("BarRow/HighPole"):
			$BarRow/HighPole.text = v


func _ready() -> void:
	$Header/Name.text = axis_name
	$BarRow/LowPole.text = low_pole
	$BarRow/HighPole.text = high_pole


func set_value(value: int) -> void:
	var delta := value - 50
	$Header/Deviation.text = "+%d" % delta if delta > 0 else "%d" % delta
	_apply_bar(delta)


func _apply_bar(delta: int) -> void:
	var half := BAR_W / 2.0
	var frac := clampf(absf(float(delta)) / 50.0, 0.0, 1.0)
	var fill_w := half * frac
	var fill_x := half if delta >= 0 else half - fill_w
	var fill: ColorRect = $BarRow/Bar/Fill
	fill.visible = fill_w > 0.0
	fill.position = Vector2(fill_x, 1.0)
	fill.size = Vector2(fill_w, BAR_H - 2.0)
