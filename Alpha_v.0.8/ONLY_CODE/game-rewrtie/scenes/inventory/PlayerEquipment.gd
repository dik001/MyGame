class_name PlayerEquipmentState
extends Node

signal equipment_changed(equipped_state: Dictionary)
signal equipment_stats_changed(equipment_stats: Dictionary)

const SLOT_TOP: StringName = &"top"
const SLOT_BOTTOM: StringName = &"bottom"
const SLOT_SHOES: StringName = &"shoes"
const SLOT_HEAD: StringName = &"head"
const EQUIPMENT_SLOTS: Array[StringName] = [
	SLOT_TOP,
	SLOT_BOTTOM,
	SLOT_SHOES,
	SLOT_HEAD,
]
const ITEM_STATE_INSTANCE_ID: StringName = &"instance_id"
const ITEM_STATE_STARTER_LOCKED: StringName = &"starter_locked"

var equipped_top_instance_id: String = ""
var equipped_bottom_instance_id: String = ""
var equipped_shoes_instance_id: String = ""
var equipped_head_instance_id: String = ""

var _equipment_stats: Dictionary = _build_empty_stats()


func _ready() -> void:
	call_deferred("_connect_inventory_signals")
	call_deferred("_apply_starter_loadout_if_needed")


func equip_item(inventory_slot_index: int) -> bool:
	var player_inventory := _get_player_inventory()

	if player_inventory == null:
		return false

	var inventory_slot := player_inventory.get_slot_at(inventory_slot_index)

	if inventory_slot == null or inventory_slot.is_empty() or inventory_slot.item_data == null:
		return false

	if not inventory_slot.item_data.is_equipment_item():
		return false

	var slot_name := inventory_slot.item_data.get_equipment_slot()
	var instance_id := String(player_inventory.get_slot_instance_id(inventory_slot_index)).strip_edges()

	if slot_name == &"" or instance_id.is_empty():
		return false

	if get_equipped_instance_id(slot_name) == instance_id:
		return false

	var previous_state := get_equipped_state()
	_clear_instance_from_all_slots(instance_id)
	_set_slot_instance_id(slot_name, instance_id)
	_finalize_equipment_change(previous_state)
	return true


func unequip_item(slot: StringName) -> bool:
	return unequip_slot(slot)


func unequip_slot(slot: StringName) -> bool:
	var resolved_slot := _normalize_slot_name(slot)

	if resolved_slot == &"":
		return false

	if get_equipped_instance_id(resolved_slot).is_empty():
		return false

	var previous_state := get_equipped_state()
	_set_slot_instance_id(resolved_slot, "")
	_finalize_equipment_change(previous_state)
	return true


func unequip_slots(slots: Array) -> void:
	var previous_state := get_equipped_state()
	var changed := false

	for slot_name in slots:
		var resolved_slot := _normalize_slot_name(slot_name)

		if resolved_slot == &"" or get_equipped_instance_id(resolved_slot).is_empty():
			continue

		_set_slot_instance_id(resolved_slot, "")
		changed = true

	if changed:
		_finalize_equipment_change(previous_state)


func unequip_all() -> void:
	var previous_state := get_equipped_state()
	var changed := false

	for slot_name in EQUIPMENT_SLOTS:
		if get_equipped_instance_id(slot_name).is_empty():
			continue

		_set_slot_instance_id(slot_name, "")
		changed = true

	if changed:
		_finalize_equipment_change(previous_state)


func recalc_equipment_stats() -> Dictionary:
	var next_stats := _build_empty_stats()

	for slot_name in EQUIPMENT_SLOTS:
		var slot_data := get_equipped_slot_data(slot_name)

		if slot_data == null or slot_data.is_empty() or slot_data.item_data == null:
			continue

		var item_data := slot_data.item_data
		next_stats["protection"] += int(item_data.protection)
		next_stats["stealth"] += int(item_data.stealth)
		next_stats["attractiveness"] += int(item_data.attractiveness)
		next_stats["speed_modifier"] += float(item_data.speed_modifier)

	next_stats["movement_speed_multiplier"] = maxf(0.05, 1.0 + float(next_stats["speed_modifier"]))

	if next_stats != _equipment_stats:
		_equipment_stats = next_stats
		equipment_stats_changed.emit(get_equipment_stats())

	return get_equipment_stats()


func get_equipment_stats() -> Dictionary:
	return _equipment_stats.duplicate(true)


func get_movement_speed_multiplier() -> float:
	return float(_equipment_stats.get("movement_speed_multiplier", 1.0))


func is_inventory_slot_equipped(slot_index: int) -> bool:
	var player_inventory := _get_player_inventory()

	if player_inventory == null or not player_inventory.has_method("get_slot_instance_id"):
		return false

	var instance_id := String(player_inventory.get_slot_instance_id(slot_index)).strip_edges()

	if instance_id.is_empty():
		return false

	for slot_name in EQUIPMENT_SLOTS:
		if get_equipped_instance_id(slot_name) == instance_id:
			return true

	return false


func get_equipped_state() -> Dictionary:
	return {
		String(SLOT_TOP): equipped_top_instance_id,
		String(SLOT_BOTTOM): equipped_bottom_instance_id,
		String(SLOT_SHOES): equipped_shoes_instance_id,
		String(SLOT_HEAD): equipped_head_instance_id,
	}


func get_equipped_instance_id(slot: StringName) -> String:
	match _normalize_slot_name(slot):
		SLOT_TOP:
			return equipped_top_instance_id
		SLOT_BOTTOM:
			return equipped_bottom_instance_id
		SLOT_SHOES:
			return equipped_shoes_instance_id
		SLOT_HEAD:
			return equipped_head_instance_id
		_:
			return ""


func get_equipped_slot_data(slot: StringName) -> InventorySlotData:
	var slot_index := get_equipped_inventory_slot_index(slot)
	var player_inventory := _get_player_inventory()

	if slot_index < 0 or player_inventory == null:
		return null

	return player_inventory.get_slot_at(slot_index)


func get_equipped_inventory_slot_index(slot: StringName) -> int:
	var player_inventory := _get_player_inventory()

	if player_inventory == null:
		return -1

	var instance_id := get_equipped_instance_id(slot)

	if instance_id.is_empty():
		return -1

	var slots: Array = player_inventory.get_slots()

	for slot_index in range(slots.size()):
		var inventory_slot := slots[slot_index] as InventorySlotData

		if inventory_slot == null or inventory_slot.is_empty():
			continue

		if String(inventory_slot.get_item_state().get(ITEM_STATE_INSTANCE_ID, "")).strip_edges() == instance_id:
			return slot_index

	return -1


func build_save_data() -> Dictionary:
	return {
		"equipped_top_instance_id": equipped_top_instance_id,
		"equipped_bottom_instance_id": equipped_bottom_instance_id,
		"equipped_shoes_instance_id": equipped_shoes_instance_id,
		"equipped_head_instance_id": equipped_head_instance_id,
	}


func apply_save_data(data: Dictionary) -> void:
	var previous_state := get_equipped_state()
	equipped_top_instance_id = String(data.get("equipped_top_instance_id", "")).strip_edges()
	equipped_bottom_instance_id = String(data.get("equipped_bottom_instance_id", "")).strip_edges()
	equipped_shoes_instance_id = String(data.get("equipped_shoes_instance_id", "")).strip_edges()
	equipped_head_instance_id = String(data.get("equipped_head_instance_id", "")).strip_edges()
	_sanitize_equipped_state()
	_finalize_equipment_change(previous_state)


func reset_state() -> void:
	var previous_state := get_equipped_state()
	equipped_top_instance_id = ""
	equipped_bottom_instance_id = ""
	equipped_shoes_instance_id = ""
	equipped_head_instance_id = ""
	_assign_starter_loadout()
	_finalize_equipment_change(previous_state)


func _connect_inventory_signals() -> void:
	var player_inventory := _get_player_inventory()

	if player_inventory == null:
		return

	if not player_inventory.inventory_changed.is_connected(_on_player_inventory_changed):
		player_inventory.inventory_changed.connect(_on_player_inventory_changed)

	_on_player_inventory_changed()


func _on_player_inventory_changed() -> void:
	var previous_state := get_equipped_state()
	_sanitize_equipped_state()
	_finalize_equipment_change(previous_state)


func _apply_starter_loadout_if_needed() -> void:
	var previous_state := get_equipped_state()

	if _assign_starter_loadout():
		_finalize_equipment_change(previous_state)


func _find_starter_instance_id_for_slot(slot: StringName) -> String:
	var player_inventory := _get_player_inventory()

	if player_inventory == null:
		return ""

	var slots: Array = player_inventory.get_slots()

	for slot_entry in slots:
		var inventory_slot := slot_entry as InventorySlotData

		if inventory_slot == null or inventory_slot.is_empty() or inventory_slot.item_data == null:
			continue

		if not inventory_slot.item_data.is_equipment_item():
			continue

		if inventory_slot.item_data.get_equipment_slot() != slot:
			continue

		var item_state := inventory_slot.get_item_state()

		if not bool(item_state.get(ITEM_STATE_STARTER_LOCKED, false)):
			continue

		var instance_id := String(item_state.get(ITEM_STATE_INSTANCE_ID, "")).strip_edges()

		if instance_id.is_empty():
			continue

		return instance_id

	return ""


func _sanitize_equipped_state() -> void:
	var seen_instance_ids: Dictionary = {}

	for slot_name in EQUIPMENT_SLOTS:
		var instance_id := get_equipped_instance_id(slot_name)

		if instance_id.is_empty():
			continue

		if seen_instance_ids.has(instance_id):
			_set_slot_instance_id(slot_name, "")
			continue

		var inventory_slot := _find_inventory_slot_data_by_instance_id(instance_id)

		if (
			inventory_slot == null
			or inventory_slot.is_empty()
			or inventory_slot.item_data == null
			or not inventory_slot.item_data.is_equipment_item()
			or inventory_slot.item_data.get_equipment_slot() != slot_name
		):
			_set_slot_instance_id(slot_name, "")
			continue

		seen_instance_ids[instance_id] = true


func _find_inventory_slot_data_by_instance_id(instance_id: String) -> InventorySlotData:
	if instance_id.is_empty():
		return null

	var player_inventory := _get_player_inventory()

	if player_inventory == null:
		return null

	var slots: Array = player_inventory.get_slots()

	for slot_entry in slots:
		var inventory_slot := slot_entry as InventorySlotData

		if inventory_slot == null or inventory_slot.is_empty():
			continue

		if String(inventory_slot.get_item_state().get(ITEM_STATE_INSTANCE_ID, "")).strip_edges() == instance_id:
			return inventory_slot

	return null


func _clear_instance_from_all_slots(instance_id: String) -> void:
	if instance_id.is_empty():
		return

	for slot_name in EQUIPMENT_SLOTS:
		if get_equipped_instance_id(slot_name) == instance_id:
			_set_slot_instance_id(slot_name, "")


func _set_slot_instance_id(slot: StringName, instance_id: String) -> void:
	match _normalize_slot_name(slot):
		SLOT_TOP:
			equipped_top_instance_id = instance_id
		SLOT_BOTTOM:
			equipped_bottom_instance_id = instance_id
		SLOT_SHOES:
			equipped_shoes_instance_id = instance_id
		SLOT_HEAD:
			equipped_head_instance_id = instance_id


func _normalize_slot_name(raw_slot: StringName) -> StringName:
	match String(raw_slot).strip_edges().to_lower():
		"top":
			return SLOT_TOP
		"bottom":
			return SLOT_BOTTOM
		"shoes":
			return SLOT_SHOES
		"head":
			return SLOT_HEAD
		_:
			return &""


func _finalize_equipment_change(previous_state: Dictionary) -> void:
	var current_state := get_equipped_state()
	var state_changed := current_state != previous_state
	var previous_stats := _equipment_stats.duplicate(true)
	var next_stats := recalc_equipment_stats()

	if state_changed:
		equipment_changed.emit(current_state.duplicate(true))
	elif next_stats != previous_stats:
		equipment_changed.emit(current_state.duplicate(true))


func _clear_all_equipment() -> void:
	var previous_state := get_equipped_state()
	equipped_top_instance_id = ""
	equipped_bottom_instance_id = ""
	equipped_shoes_instance_id = ""
	equipped_head_instance_id = ""
	_finalize_equipment_change(previous_state)


func _assign_starter_loadout() -> bool:
	var changed := false

	for slot_name in [SLOT_TOP, SLOT_BOTTOM, SLOT_SHOES]:
		if not get_equipped_instance_id(slot_name).is_empty():
			continue

		var starter_instance_id := _find_starter_instance_id_for_slot(slot_name)

		if starter_instance_id.is_empty():
			continue

		_set_slot_instance_id(slot_name, starter_instance_id)
		changed = true

	return changed


func _build_empty_stats() -> Dictionary:
	return {
		"protection": 0,
		"stealth": 0,
		"attractiveness": 0,
		"speed_modifier": 0.0,
		"movement_speed_multiplier": 1.0,
	}


func _get_player_inventory() -> PlayerInventoryState:
	return get_node_or_null("/root/PlayerInventory") as PlayerInventoryState
