class_name FridgeInventoryState
extends Node


signal inventory_changed
signal inventory_contents_changed

var _storage: InventoryStorage = InventoryStorage.new()
var _inventory_size: int = 0
var _initialized: bool = false
var _last_freshness_update_absolute_minutes: int = -1
var _default_inventory_size: int = 0
var _default_starter_items: Array[String] = []


func _ready() -> void:
	call_deferred("_connect_game_time")


func setup_storage(size: int, starter_items: Array[ItemData] = []) -> void:
	if _default_inventory_size <= 0:
		_default_inventory_size = max(1, size)

	if _default_starter_items.is_empty():
		for item_data in starter_items:
			if item_data == null or item_data.resource_path.is_empty():
				continue

			_default_starter_items.append(item_data.resource_path)

	if _initialized:
		return

	_inventory_size = max(1, size)
	_storage.initialize_storage(_inventory_size)
	_initialized = true

	for item_data in starter_items:
		if item_data == null:
			continue

		_storage.add_item(item_data, 1)

	inventory_changed.emit()
	inventory_contents_changed.emit()


func is_initialized() -> bool:
	return _initialized


func get_slots() -> Array:
	_sync_food_freshness()
	return _storage.get_slots()


func get_slot_at(slot_index: int) -> InventorySlotData:
	_sync_food_freshness()
	return _storage.get_slot_at(slot_index)


func get_inventory_size() -> int:
	return _inventory_size


func get_total_weight() -> float:
	_sync_food_freshness()
	return _storage.get_total_weight()


func can_add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	if not _initialized:
		return false

	_sync_food_freshness()
	return _storage.can_add_item(item_data, quantity, item_state)


func add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	if not _initialized:
		return false

	_sync_food_freshness()

	if not _storage.add_item(item_data, quantity, item_state):
		return false

	inventory_changed.emit()
	inventory_contents_changed.emit()
	return true


func remove_item_at(slot_index: int, quantity: int = 1) -> bool:
	if not _initialized:
		return false

	_sync_food_freshness()

	if not _storage.remove_item_at(slot_index, quantity):
		return false

	inventory_changed.emit()
	inventory_contents_changed.emit()
	return true


func add_order_items(item_entries: Array) -> bool:
	if not _initialized:
		return false

	_sync_food_freshness()
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
		var item_state: Dictionary = entry.get("item_state", {})

		if item_data == null or quantity <= 0:
			return false

		if not simulated_storage.add_item(item_data, quantity, item_state):
			return false

	for entry_variant in normalized_entries:
		var entry: Dictionary = {}

		if entry_variant is Dictionary:
			entry = entry_variant

		var item_data: ItemData = entry.get("item_data", null) as ItemData
		var quantity: int = int(entry.get("quantity", 0))
		var item_state: Dictionary = entry.get("item_state", {})
		_storage.add_item(item_data, quantity, item_state)

	inventory_changed.emit()
	inventory_contents_changed.emit()
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
		var item_state: Dictionary = {}
		var raw_item_state: Variant = entry.get("item_state", {})

		if raw_item_state is Dictionary:
			item_state = FoodFreshness.normalize_state(item_data, raw_item_state as Dictionary)

		if quantity < 0:
			quantity = 0

		if item_data == null or quantity <= 0:
			continue

		normalized_entries.append({
			"item_data": item_data,
			"quantity": quantity,
			"item_state": item_state,
		})

	return normalized_entries


func _connect_game_time() -> void:
	var game_time: GameTimeState = get_node_or_null("/root/GameTime") as GameTimeState

	if game_time == null:
		return

	if not game_time.time_changed.is_connected(_on_game_time_changed):
		game_time.time_changed.connect(_on_game_time_changed)

	_last_freshness_update_absolute_minutes = game_time.get_absolute_minutes()


func _on_game_time_changed(absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	_sync_food_freshness(absolute_minutes)


func _sync_food_freshness(current_absolute_minutes: int = -1) -> void:
	if not _initialized:
		return

	var game_time: GameTimeState = get_node_or_null("/root/GameTime") as GameTimeState

	if game_time == null:
		return

	var resolved_absolute_minutes: int = current_absolute_minutes

	if resolved_absolute_minutes < 0:
		resolved_absolute_minutes = game_time.get_absolute_minutes()

	if _last_freshness_update_absolute_minutes < 0:
		_last_freshness_update_absolute_minutes = resolved_absolute_minutes
		return

	var elapsed_minutes: int = resolved_absolute_minutes - _last_freshness_update_absolute_minutes
	_last_freshness_update_absolute_minutes = resolved_absolute_minutes

	if elapsed_minutes <= 0:
		return

	if _storage.advance_food_freshness(elapsed_minutes, FoodFreshness.FRIDGE_SPOILAGE_MULTIPLIER):
		inventory_changed.emit()


func build_save_data() -> Dictionary:
	_sync_food_freshness()
	return {
		"inventory_size": _inventory_size,
		"initialized": _initialized,
		"slots": _storage.serialize_slots(),
		"last_freshness_update_absolute_minutes": _last_freshness_update_absolute_minutes,
	}


func apply_save_data(data: Dictionary) -> void:
	_inventory_size = max(1, int(data.get("inventory_size", _default_inventory_size if _default_inventory_size > 0 else 12)))
	_storage.initialize_storage(_inventory_size)
	_initialized = bool(data.get("initialized", true))
	_storage.apply_serialized_slots(SaveDataUtils.sanitize_array(data.get("slots", [])))
	_last_freshness_update_absolute_minutes = int(
		data.get("last_freshness_update_absolute_minutes", GameTime.get_absolute_minutes())
	)
	inventory_changed.emit()
	inventory_contents_changed.emit()


func reset_state() -> void:
	_storage.initialize_storage(max(0, _inventory_size))
	_inventory_size = 0
	_initialized = false
	_last_freshness_update_absolute_minutes = -1
	inventory_changed.emit()
	inventory_contents_changed.emit()
