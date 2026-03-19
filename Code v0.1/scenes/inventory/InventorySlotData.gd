class_name InventorySlotData
extends RefCounted

var item_data: ItemData
var quantity: int = 0


func _init(initial_item_data: ItemData = null, initial_quantity: int = 0) -> void:
	set_data(initial_item_data, initial_quantity)


func set_data(next_item_data: ItemData, next_quantity: int) -> void:
	if next_item_data == null or next_quantity <= 0:
		clear()
		return

	item_data = next_item_data
	quantity = min(next_quantity, item_data.get_effective_max_stack_size())


func clear() -> void:
	item_data = null
	quantity = 0


func is_empty() -> bool:
	return item_data == null or quantity <= 0


func can_stack_with(other_item_data: ItemData) -> bool:
	if is_empty() or other_item_data == null:
		return false

	return item_data.matches(other_item_data) and item_data.can_stack() and quantity < item_data.get_effective_max_stack_size()


func get_available_stack_space() -> int:
	if is_empty():
		return 0

	return max(0, item_data.get_effective_max_stack_size() - quantity)


func get_total_weight() -> float:
	if is_empty():
		return 0.0

	return item_data.get_effective_weight() * float(quantity)


func add_quantity(amount: int) -> int:
	if is_empty() or amount <= 0:
		return 0

	var added_amount: int = min(amount, get_available_stack_space())
	quantity += added_amount
	return added_amount


func remove_quantity(amount: int) -> int:
	if is_empty() or amount <= 0:
		return 0

	var removed_amount: int = min(amount, quantity)
	quantity -= removed_amount

	if quantity <= 0:
		clear()

	return removed_amount


func duplicate_data() -> InventorySlotData:
	if is_empty():
		return InventorySlotData.new()

	return InventorySlotData.new(item_data, quantity)
