class_name ItemData
extends Resource

@export var id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(1, 999, 1) var max_stack_size: int = 1
@export var weight: float = 0.0
@export_range(0, 9999, 1) var price: int = 0
@export var is_consumable: bool = false
@export var hunger_restore: int = 0


func get_display_name() -> String:
	if not item_name.is_empty():
		return item_name

	if not id.is_empty():
		return id.capitalize()

	return "Предмет"


func get_effective_max_stack_size() -> int:
	return max(1, max_stack_size)


func get_effective_weight() -> float:
	return max(weight, 0.0)


func get_effective_price() -> int:
	return max(price, 0)


func can_stack() -> bool:
	return get_effective_max_stack_size() > 1


func matches(other_item_data: ItemData) -> bool:
	if other_item_data == null:
		return false

	if not id.is_empty() and not other_item_data.id.is_empty():
		return id == other_item_data.id

	if not resource_path.is_empty() and not other_item_data.resource_path.is_empty():
		return resource_path == other_item_data.resource_path

	return self == other_item_data
