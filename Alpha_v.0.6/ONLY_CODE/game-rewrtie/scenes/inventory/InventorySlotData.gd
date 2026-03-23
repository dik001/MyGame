class_name InventorySlotData
extends RefCounted

var item_data: ItemData
var quantity: int = 0
var item_state: Dictionary = {}


func _init(initial_item_data: ItemData = null, initial_quantity: int = 0, initial_item_state: Dictionary = {}) -> void:
	set_data(initial_item_data, initial_quantity, initial_item_state)


func set_data(next_item_data: ItemData, next_quantity: int, next_item_state: Dictionary = {}) -> void:
	if next_item_data == null or next_quantity <= 0:
		clear()
		return

	item_data = next_item_data
	quantity = min(next_quantity, item_data.get_effective_max_stack_size())
	item_state = FoodFreshness.normalize_state(item_data, next_item_state)


func clear() -> void:
	item_data = null
	quantity = 0
	item_state.clear()


func is_empty() -> bool:
	return item_data == null or quantity <= 0


func can_stack_with(other_item_data: ItemData, other_item_state: Dictionary = {}) -> bool:
	if is_empty() or other_item_data == null:
		return false

	return (
		item_data.matches(other_item_data)
		and item_data.can_stack()
		and quantity < item_data.get_effective_max_stack_size()
		and FoodFreshness.can_stack(item_data, item_state, other_item_state)
	)


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


func get_item_state() -> Dictionary:
	return item_state.duplicate(true)


func set_item_state(next_item_state: Dictionary) -> void:
	if is_empty():
		item_state.clear()
		return

	item_state = FoodFreshness.normalize_state(item_data, next_item_state)


func has_freshness() -> bool:
	return FoodFreshness.is_food_item(item_data)


func is_spoiled() -> bool:
	return FoodFreshness.is_spoiled(item_data, item_state)


func can_consume_safely() -> bool:
	return not has_freshness() or not is_spoiled()


func get_freshness_text(spoilage_multiplier: float = 1.0) -> String:
	return FoodFreshness.format_compact_status(item_data, item_state, spoilage_multiplier)


func get_freshness_tooltip_text(spoilage_multiplier: float = 1.0) -> String:
	return FoodFreshness.format_inventory_status(item_data, item_state, spoilage_multiplier)


func advance_freshness(elapsed_minutes: int, spoilage_multiplier: float) -> bool:
	if not has_freshness() or elapsed_minutes <= 0:
		return false

	var next_item_state: Dictionary = FoodFreshness.apply_elapsed_minutes(item_data, item_state, elapsed_minutes, spoilage_multiplier)

	if next_item_state == item_state:
		return false

	item_state = next_item_state
	return true


func duplicate_data() -> InventorySlotData:
	if is_empty():
		return InventorySlotData.new()

	return InventorySlotData.new(item_data, quantity, item_state.duplicate(true))
