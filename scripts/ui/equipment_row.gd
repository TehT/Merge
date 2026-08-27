extends HBoxContainer
## EquipmentRow — one row in a base-local equipment list: item name +
## slot type + click. Callers pass base_id along at populate time so the
## `clicked` signal carries both (needed for the equipment-info popout
## to know where the item lives when offering a transfer action).

signal clicked(item: EquipmentData, base_id: String)

var _item: EquipmentData
var _base_id: String


func populate(item: EquipmentData, base_id: String) -> void:
	_item = item
	_base_id = base_id
	%Name.text = item.equipment_name
	%Slot.text = item.slot_type


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_item, _base_id)
