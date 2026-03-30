class_name EquipmentDropTarget
extends PanelContainer

signal drop_received(data: Dictionary)

@export var accepted_drag_types: PackedStringArray = PackedStringArray(["equipped_item"])


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false

	var drag_type := String((data as Dictionary).get("drag_type", "")).strip_edges()
	return accepted_drag_types.has(drag_type)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	drop_received.emit((data as Dictionary).duplicate(true))
