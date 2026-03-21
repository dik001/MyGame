class_name PlayerInventoryState
extends Node

signal inventory_changed
signal item_used(item_data: ItemData)
signal item_dropped(item_data: ItemData)
signal inventory_opened
signal inventory_closed

@export_range(1, 64, 1) var inventory_size: int = 20

var slots: Array = []
var is_inventory_open := false
var _storage: InventoryStorage = InventoryStorage.new()


func _ready() -> void:
	initialize_inventory()


func initialize_inventory() -> void:
	_storage.initialize_storage(inventory_size)
	slots = _storage.slots
	inventory_changed.emit()


func get_slots() -> Array:
	return _storage.get_slots()


func get_slot_at(slot_index: int) -> InventorySlotData:
	return _storage.get_slot_at(slot_index)


func get_slot_total_weight(slot_index: int) -> float:
	return _storage.get_slot_total_weight(slot_index)


func get_total_weight() -> float:
	return _storage.get_total_weight()


func add_item(item_data: ItemData, quantity: int = 1) -> bool:
	if not _storage.add_item(item_data, quantity):
		return false

	inventory_changed.emit()
	return true


func remove_item_at(slot_index: int, quantity: int = 1) -> bool:
	if not _storage.remove_item_at(slot_index, quantity):
		return false

	inventory_changed.emit()
	return true


func use_item_at(slot_index: int) -> bool:
	var slot: InventorySlotData = _storage.get_slot_at(slot_index)

	if slot == null or slot.is_empty():
		return false

	var item_data: ItemData = slot.item_data

	if item_data == null or not item_data.is_consumable:
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


func can_add_item(item_data: ItemData, quantity: int = 1) -> bool:
	return _storage.can_add_item(item_data, quantity)


func find_stack_for(item_data: ItemData) -> int:
	return _storage.find_stack_for(item_data)


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
