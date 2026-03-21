class_name FridgeInventoryState
extends Node

signal inventory_changed

var _storage: InventoryStorage = InventoryStorage.new()
var _inventory_size: int = 0
var _initialized: bool = false


func setup_storage(size: int, starter_items: Array[ItemData] = []) -> void:
	if _initialized:
		return

	_inventory_size = size

	if _inventory_size < 1:
		_inventory_size = 1
	_storage.initialize_storage(_inventory_size)
	_initialized = true

	for item_data in starter_items:
		if item_data == null:
			continue

		_storage.add_item(item_data, 1)

	inventory_changed.emit()


func is_initialized() -> bool:
	return _initialized


func get_slots() -> Array:
	return _storage.get_slots()


func get_slot_at(slot_index: int) -> InventorySlotData:
	return _storage.get_slot_at(slot_index)


func get_inventory_size() -> int:
	return _inventory_size


func get_total_weight() -> float:
	return _storage.get_total_weight()


func can_add_item(item_data: ItemData, quantity: int = 1) -> bool:
	if not _initialized:
		return false

	return _storage.can_add_item(item_data, quantity)


func add_item(item_data: ItemData, quantity: int = 1) -> bool:
	if not _initialized:
		return false

	if not _storage.add_item(item_data, quantity):
		return false

	inventory_changed.emit()
	return true


func remove_item_at(slot_index: int, quantity: int = 1) -> bool:
	if not _initialized:
		return false

	if not _storage.remove_item_at(slot_index, quantity):
		return false

	inventory_changed.emit()
	return true


func add_order_items(item_entries: Array) -> bool:
	if not _initialized:
		return false

	var normalized_entries: Array = _normalize_item_entries(item_entries)

	if normalized_entries.is_empty():
		return false

	var simulated_storage: InventoryStorage = _duplicate_storage()

	for entry_variant in normalized_entries:
		var entry: Dictionary = {}

		if entry_variant is Dictionary:
			entry = entry_variant

		var item_data: ItemData = entry.get("item_data", null) as ItemData
		var quantity: int = int(entry.get("quantity", 0))

		if item_data == null or quantity <= 0:
			return false

		if not simulated_storage.add_item(item_data, quantity):
			return false

	for entry_variant in normalized_entries:
		var entry: Dictionary = {}

		if entry_variant is Dictionary:
			entry = entry_variant

		var item_data: ItemData = entry.get("item_data", null) as ItemData
		var quantity: int = int(entry.get("quantity", 0))
		_storage.add_item(item_data, quantity)

	inventory_changed.emit()
	return true


func _duplicate_storage() -> InventoryStorage:
	var duplicated_storage: InventoryStorage = InventoryStorage.new()
	duplicated_storage.initialize_storage(_inventory_size)

	for slot_index in range(_storage.slots.size()):
		var slot: InventorySlotData = _storage.get_slot_at(slot_index)

		if slot == null or slot.is_empty():
			continue

		duplicated_storage.slots[slot_index] = slot.duplicate_data()

	return duplicated_storage


func _normalize_item_entries(item_entries: Array) -> Array:
	var normalized_entries: Array = []

	for entry_variant in item_entries:
		var entry: Dictionary = {}

		if entry_variant is Dictionary:
			entry = entry_variant

		if entry.is_empty():
			continue

		var item_data: ItemData = entry.get("item_data", null) as ItemData

		if item_data == null:
			var item_path: String = String(entry.get("item_path", ""))

			if not item_path.is_empty():
				item_data = load(item_path) as ItemData

		var quantity: int = int(entry.get("quantity", 0))

		if quantity < 0:
			quantity = 0

		if item_data == null or quantity <= 0:
			continue

		normalized_entries.append({
			"item_data": item_data,
			"quantity": quantity,
		})

	return normalized_entries
