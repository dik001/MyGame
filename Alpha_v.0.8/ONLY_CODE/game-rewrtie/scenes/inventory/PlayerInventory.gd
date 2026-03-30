class_name PlayerInventoryState
extends Node


signal inventory_changed
signal item_used(item_data: ItemData)
signal item_dropped(item_data: ItemData)
signal inventory_opened
signal inventory_closed

@export_range(1, 64, 1) var inventory_size: int = 20

const FOOD_SPOILAGE_MULTIPLIER: float = 1.0
const ITEM_STATE_INSTANCE_ID: StringName = &"instance_id"
const ITEM_STATE_STARTER_LOCKED: StringName = &"starter_locked"
const SCHOOL_TOP_ITEM := preload("res://resources/items/school_top.tres")
const SCHOOL_BOTTOM_ITEM := preload("res://resources/items/school_bottom.tres")
const SCHOOL_SHOES_ITEM := preload("res://resources/items/school_shoes.tres")
const STARTER_EQUIPMENT_ITEMS: Array[ItemData] = [
	SCHOOL_TOP_ITEM,
	SCHOOL_BOTTOM_ITEM,
	SCHOOL_SHOES_ITEM,
]

var slots: Array = []
var is_inventory_open := false
var _storage: InventoryStorage = InventoryStorage.new()
var _last_freshness_update_absolute_minutes: int = -1
var _default_inventory_size: int = 20


func _ready() -> void:
	_default_inventory_size = inventory_size
	initialize_inventory()
	call_deferred("_connect_game_time")


func initialize_inventory() -> void:
	_storage.initialize_storage(inventory_size)
	slots = _storage.slots
	_populate_starter_items()
	inventory_changed.emit()


func get_slots() -> Array:
	_sync_food_freshness()
	return _storage.get_slots()


func get_slot_at(slot_index: int) -> InventorySlotData:
	_sync_food_freshness()
	return _storage.get_slot_at(slot_index)


func get_slot_total_weight(slot_index: int) -> float:
	_sync_food_freshness()
	return _storage.get_slot_total_weight(slot_index)


func get_total_weight() -> float:
	_sync_food_freshness()
	return _storage.get_total_weight()


func add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	_sync_food_freshness()

	var normalized_item_state := _normalize_item_state_for_add(item_data, item_state)

	if not _storage.add_item(item_data, quantity, normalized_item_state):
		return false

	inventory_changed.emit()
	return true


func remove_item_at(slot_index: int, quantity: int = 1, allow_equipped_remove: bool = false) -> bool:
	_sync_food_freshness()
	if not allow_equipped_remove and is_slot_equipped(slot_index):
		return false

	if not _storage.remove_item_at(slot_index, quantity):
		return false

	inventory_changed.emit()
	return true


func use_item_at(slot_index: int) -> bool:
	_sync_food_freshness()
	var slot: InventorySlotData = _storage.get_slot_at(slot_index)

	if slot == null or slot.is_empty():
		return false

	var item_data: ItemData = slot.item_data

	if item_data == null or not item_data.can_use_directly():
		return false

	var stats: PlayerStatsState = get_node("/root/PlayerStats") as PlayerStatsState

	if stats == null:
		return false

	var item_state: Dictionary = slot.get_item_state()
	var validation_result: Dictionary = stats.can_use_item(item_data, item_state)

	if not bool(validation_result.get("success", false)):
		return false

	if not _storage.remove_item_at(slot_index, 1):
		return false

	var apply_result: Dictionary = stats.apply_item_use(item_data, item_state)

	if not bool(apply_result.get("success", false)):
		_storage.add_item(item_data, 1, _normalize_item_state_for_add(item_data, item_state))
		return false

	inventory_changed.emit()
	item_used.emit(item_data)
	return true


func drop_item_at(slot_index: int, quantity: int = 1) -> bool:
	_sync_food_freshness()
	var slot: InventorySlotData = _storage.get_slot_at(slot_index)

	if slot == null or slot.is_empty() or quantity <= 0:
		return false

	var item_data: ItemData = slot.item_data

	if not remove_item_at(slot_index, quantity):
		return false

	item_dropped.emit(item_data)
	return true


func has_free_slot() -> bool:
	return _storage.has_free_slot()


func can_add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	_sync_food_freshness()

	return _storage.can_add_item(item_data, quantity, _normalize_item_state_for_add(item_data, item_state))


func find_stack_for(item_data: ItemData, item_state: Dictionary = {}) -> int:
	_sync_food_freshness()
	return _storage.find_stack_for(item_data, item_state)


func find_empty_slot() -> int:
	return _storage.find_empty_slot()


func get_inventory_size() -> int:
	return inventory_size


func set_inventory_open(is_open: bool) -> void:
	if is_inventory_open == is_open:
		return

	is_inventory_open = is_open

	if is_inventory_open:
		inventory_opened.emit()
	else:
		inventory_closed.emit()


func build_save_data() -> Dictionary:
	_sync_food_freshness()
	return {
		"inventory_size": inventory_size,
		"slots": _storage.serialize_slots(),
		"last_freshness_update_absolute_minutes": _last_freshness_update_absolute_minutes,
	}


func apply_save_data(data: Dictionary) -> void:
	inventory_size = max(1, int(data.get("inventory_size", _default_inventory_size)))
	_storage.initialize_storage(inventory_size)
	slots = _storage.slots
	_storage.apply_serialized_slots(SaveDataUtils.sanitize_array(data.get("slots", [])))
	_ensure_equipment_instance_ids_in_storage()
	_populate_starter_items()
	is_inventory_open = false
	_last_freshness_update_absolute_minutes = int(
		data.get("last_freshness_update_absolute_minutes", GameTime.get_absolute_minutes())
	)
	inventory_changed.emit()


func reset_state() -> void:
	inventory_size = _default_inventory_size
	_storage.initialize_storage(inventory_size)
	slots = _storage.slots
	_populate_starter_items()
	is_inventory_open = false
	_last_freshness_update_absolute_minutes = -1
	inventory_changed.emit()


func get_slot_item_state(slot_index: int) -> Dictionary:
	var slot := get_slot_at(slot_index)

	if slot == null or slot.is_empty():
		return {}

	return slot.get_item_state()


func get_slot_instance_id(slot_index: int) -> String:
	var slot := get_slot_at(slot_index)

	if slot == null or slot.is_empty():
		return ""

	return String(slot.get_item_state().get(ITEM_STATE_INSTANCE_ID, "")).strip_edges()


func is_slot_equipped(slot_index: int) -> bool:
	var player_equipment := _get_player_equipment()

	if player_equipment == null or not player_equipment.has_method("is_inventory_slot_equipped"):
		return false

	return bool(player_equipment.is_inventory_slot_equipped(slot_index))


func can_sell_slot(slot_index: int) -> bool:
	var slot := get_slot_at(slot_index)

	if slot == null or slot.is_empty() or slot.item_data == null:
		return false

	var item_data := slot.item_data

	if not item_data.is_equipment_item():
		return false

	if is_slot_equipped(slot_index):
		return false

	if not item_data.can_sell:
		return false

	if bool(slot.get_item_state().get(ITEM_STATE_STARTER_LOCKED, false)):
		return false

	return item_data.get_fixed_sell_price() > 0


func get_sell_price_for_slot(slot_index: int) -> int:
	if not can_sell_slot(slot_index):
		return 0

	var slot := get_slot_at(slot_index)
	return slot.item_data.get_fixed_sell_price() if slot != null and slot.item_data != null else 0


func sell_item_at(slot_index: int, payment_source := "cash") -> Dictionary:
	var result := {
		"success": false,
		"price": 0,
		"item_name": "",
		"payment_source": String(payment_source).strip_edges().to_lower(),
		"message": "",
	}

	var slot := get_slot_at(slot_index)

	if slot == null or slot.is_empty() or slot.item_data == null:
		result["message"] = "Предмет не найден."
		return result

	if not can_sell_slot(slot_index):
		result["item_name"] = slot.item_data.get_display_name()
		result["message"] = "Этот предмет нельзя продать."
		return result

	var item_data := slot.item_data
	var item_state := slot.get_item_state()
	var sell_price := get_sell_price_for_slot(slot_index)
	var economy := _get_player_economy()

	result["item_name"] = item_data.get_display_name()
	result["price"] = sell_price

	if economy == null:
		result["message"] = "Экономика игрока недоступна."
		return result

	if not remove_item_at(slot_index, 1):
		result["message"] = "Не удалось убрать предмет из инвентаря."
		return result

	if String(result["payment_source"]) == "bank":
		economy.add_bank_dollars(sell_price, false)
	else:
		result["payment_source"] = "cash"
		economy.add_cash_dollars(sell_price, false)

	result["success"] = true
	result["message"] = "Предмет продан."
	return result


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

	if _storage.advance_food_freshness(elapsed_minutes, FOOD_SPOILAGE_MULTIPLIER):
		inventory_changed.emit()


func _populate_starter_items() -> void:
	var changed := false

	for item_data in STARTER_EQUIPMENT_ITEMS:
		if item_data == null or _has_item_in_storage(item_data):
			continue

		var starter_state := {
			ITEM_STATE_STARTER_LOCKED: true,
		}

		if _storage.add_item(item_data, 1, _normalize_item_state_for_add(item_data, starter_state)):
			changed = true

	if changed:
		slots = _storage.slots


func _normalize_item_state_for_add(item_data: ItemData, item_state: Dictionary = {}) -> Dictionary:
	if item_data == null:
		return {}

	var normalized_state: Dictionary = item_state.duplicate(true)

	if item_data.is_equipment_item():
		var instance_id := String(normalized_state.get(ITEM_STATE_INSTANCE_ID, "")).strip_edges()

		if instance_id.is_empty():
			instance_id = _generate_item_instance_id(item_data)

		normalized_state[ITEM_STATE_INSTANCE_ID] = instance_id
		normalized_state[ITEM_STATE_STARTER_LOCKED] = bool(normalized_state.get(ITEM_STATE_STARTER_LOCKED, false))

	return FoodFreshness.normalize_state(item_data, normalized_state)


func _generate_item_instance_id(item_data: ItemData) -> String:
	var item_key := item_data.id.strip_edges()

	if item_key.is_empty():
		item_key = item_data.resource_path.get_file().get_basename()

	if item_key.is_empty():
		item_key = "item"

	return "%s_%d_%d" % [item_key, Time.get_ticks_usec(), randi()]


func _ensure_equipment_instance_ids_in_storage() -> void:
	var changed := false

	for slot_entry in _storage.slots:
		var slot := slot_entry as InventorySlotData

		if slot == null or slot.is_empty() or slot.item_data == null:
			continue

		if not slot.item_data.is_equipment_item():
			continue

		var normalized_state := _normalize_item_state_for_add(slot.item_data, slot.get_item_state())

		if normalized_state == slot.get_item_state():
			continue

		slot.set_item_state(normalized_state)
		changed = true

	if changed:
		slots = _storage.slots


func _has_item_in_storage(item_data: ItemData) -> bool:
	if item_data == null:
		return false

	for slot_entry in _storage.slots:
		var slot := slot_entry as InventorySlotData

		if slot == null or slot.is_empty() or slot.item_data == null:
			continue

		if slot.item_data.matches(item_data):
			return true

	return false


func _get_player_equipment() -> Node:
	return get_node_or_null("/root/PlayerEquipment")


func _get_player_economy() -> PlayerEconomyState:
	return get_node_or_null("/root/PlayerEconomy") as PlayerEconomyState
