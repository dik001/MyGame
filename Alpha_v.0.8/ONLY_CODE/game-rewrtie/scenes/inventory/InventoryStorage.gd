class_name InventoryStorage
extends RefCounted


var storage_size: int = 0
var slots: Array = []


func initialize_storage(size: int) -> void:
	storage_size = max(0, size)
	slots.clear()
	slots.resize(storage_size)


func get_slots() -> Array:
	return slots.duplicate()


func get_slot_at(slot_index: int) -> InventorySlotData:
	if slot_index < 0 or slot_index >= slots.size():
		return null

	return slots[slot_index] as InventorySlotData


func get_slot_total_weight(slot_index: int) -> float:
	var slot := get_slot_at(slot_index)

	if slot == null:
		return 0.0

	return slot.get_total_weight()


func get_total_weight() -> float:
	var total_weight := 0.0

	for slot_entry in slots:
		var slot := slot_entry as InventorySlotData

		if slot == null or slot.is_empty():
			continue

		total_weight += slot.get_total_weight()

	return total_weight


func has_free_slot() -> bool:
	return find_empty_slot() != -1


func find_stack_for(item_data: ItemData, item_state: Dictionary = {}) -> int:
	if item_data == null:
		return -1

	for slot_index in slots.size():
		var slot: InventorySlotData = slots[slot_index] as InventorySlotData

		if slot != null and slot.can_stack_with(item_data, item_state):
			return slot_index

	return -1


func find_empty_slot() -> int:
	for slot_index in slots.size():
		var slot: InventorySlotData = slots[slot_index] as InventorySlotData

		if slot == null or slot.is_empty():
			return slot_index

	return -1


func can_add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	if item_data == null or quantity <= 0:
		return false

	var remaining_quantity: int = quantity

	for slot_entry in slots:
		var slot: InventorySlotData = slot_entry as InventorySlotData

		if slot == null or slot.is_empty():
			continue

		if not slot.can_stack_with(item_data, item_state):
			continue

		remaining_quantity -= slot.get_available_stack_space()

		if remaining_quantity <= 0:
			return true

	var per_slot_capacity: int = item_data.get_effective_max_stack_size()

	for slot_entry in slots:
		var slot: InventorySlotData = slot_entry as InventorySlotData

		if slot != null and not slot.is_empty():
			continue

		remaining_quantity -= per_slot_capacity

		if remaining_quantity <= 0:
			return true

	return false


func add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	if not can_add_item(item_data, quantity, item_state):
		return false

	var remaining_quantity: int = quantity

	while remaining_quantity > 0:
		var stack_index: int = find_stack_for(item_data, item_state)

		if stack_index == -1:
			break

		var stack_slot: InventorySlotData = get_slot_at(stack_index)
		remaining_quantity -= stack_slot.add_quantity(remaining_quantity)

	while remaining_quantity > 0:
		var empty_slot_index: int = find_empty_slot()

		if empty_slot_index == -1:
			return false

		var slot_quantity: int = min(remaining_quantity, item_data.get_effective_max_stack_size())
		slots[empty_slot_index] = InventorySlotData.new(item_data, slot_quantity, item_state)
		remaining_quantity -= slot_quantity

	return true


func remove_item_at(slot_index: int, quantity: int = 1) -> bool:
	var slot: InventorySlotData = get_slot_at(slot_index)

	if slot == null or slot.is_empty() or quantity <= 0:
		return false

	slot.remove_quantity(quantity)

	if slot.is_empty():
		slots[slot_index] = null

	return true


func clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return

	slots[slot_index] = null


func advance_food_freshness(elapsed_minutes: int, spoilage_multiplier: float) -> bool:
	if elapsed_minutes <= 0:
		return false

	var changed: bool = false

	for slot_entry in slots:
		var slot: InventorySlotData = slot_entry as InventorySlotData

		if slot == null or slot.is_empty():
			continue

		changed = slot.advance_freshness(elapsed_minutes, spoilage_multiplier) or changed

	return changed


func serialize_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for slot_index in range(slots.size()):
		var slot: InventorySlotData = slots[slot_index] as InventorySlotData

		if slot == null or slot.is_empty() or slot.item_data == null:
			continue

		var item_path := String(slot.item_data.resource_path)

		if item_path.is_empty():
			continue

		result.append({
			"slot_index": slot_index,
			"item_path": item_path,
			"quantity": slot.quantity,
			"item_state": slot.get_item_state(),
		})

	return result


func apply_serialized_slots(serialized_slots: Array) -> void:
	for slot_index in range(slots.size()):
		slots[slot_index] = null

	for entry_variant in serialized_slots:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var item_path := String(entry.get("item_path", "")).strip_edges()

		if item_path.is_empty() or not ResourceLoader.exists(item_path, "Resource"):
			continue

		var item_data := load(item_path) as ItemData
		var quantity := int(entry.get("quantity", 0))

		if item_data == null or quantity <= 0:
			continue

		var item_state := SaveDataUtils.sanitize_dictionary(entry.get("item_state", {}))
		var target_slot_index := int(entry.get("slot_index", find_empty_slot()))

		if target_slot_index < 0 or target_slot_index >= slots.size():
			target_slot_index = find_empty_slot()

		if target_slot_index < 0 or target_slot_index >= slots.size():
			continue

		slots[target_slot_index] = InventorySlotData.new(item_data, quantity, item_state)
