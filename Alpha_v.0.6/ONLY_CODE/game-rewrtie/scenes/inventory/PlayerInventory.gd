class_name PlayerInventoryState
extends Node

signal inventory_changed
signal item_used(item_data: ItemData)
signal item_dropped(item_data: ItemData)
signal inventory_opened
signal inventory_closed

@export_range(1, 64, 1) var inventory_size: int = 20

const FOOD_SPOILAGE_MULTIPLIER: float = 1.0

var slots: Array = []
var is_inventory_open := false
var _storage: InventoryStorage = InventoryStorage.new()
var _last_freshness_update_absolute_minutes: int = -1


func _ready() -> void:
	initialize_inventory()
	call_deferred("_connect_game_time")


func initialize_inventory() -> void:
	_storage.initialize_storage(inventory_size)
	slots = _storage.slots
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

	if not _storage.add_item(item_data, quantity, item_state):
		return false

	inventory_changed.emit()
	return true


func remove_item_at(slot_index: int, quantity: int = 1) -> bool:
	_sync_food_freshness()

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

	if item_data == null or not item_data.is_consumable:
		return false

	if not slot.can_consume_safely():
		return false

	var stats: PlayerStatsState = get_node("/root/PlayerStats") as PlayerStatsState

	if stats == null:
		return false

	stats.add_hunger(item_data.hunger_restore)
	_storage.remove_item_at(slot_index, 1)
	inventory_changed.emit()
	item_used.emit(item_data)
	return true


func drop_item_at(slot_index: int, quantity: int = 1) -> bool:
	_sync_food_freshness()
	var slot: InventorySlotData = _storage.get_slot_at(slot_index)

	if slot == null or slot.is_empty() or quantity <= 0:
		return false

	var item_data: ItemData = slot.item_data

	if not _storage.remove_item_at(slot_index, quantity):
		return false

	inventory_changed.emit()
	item_dropped.emit(item_data)
	return true


func has_free_slot() -> bool:
	return _storage.has_free_slot()


func can_add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	_sync_food_freshness()
	return _storage.can_add_item(item_data, quantity, item_state)


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
