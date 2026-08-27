extends HBoxContainer
## VehicleRow — one row in a fleet list: name + stats + click arrow.
## Editor-editable via scenes/ui/rows/vehicle_row.tscn; the caller
## instantiates it, calls populate(vehicle), and connects `clicked`
## rather than knowing anything about the row's internal layout.

signal clicked(vehicle: VehicleData)

var _vehicle: VehicleData


func populate(vehicle: VehicleData) -> void:
	_vehicle = vehicle
	%Name.text = vehicle.vehicle_name
	%Stats.text = "%d km/h  •  %d km range  •  %d cap" % [
			int(round(vehicle.speed_kmh)), int(vehicle.max_range_km), vehicle.capacity]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_vehicle)
