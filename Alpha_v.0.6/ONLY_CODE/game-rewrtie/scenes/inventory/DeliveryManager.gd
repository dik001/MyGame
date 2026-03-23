class_name DeliveryManagerState
extends Node

signal deliveries_updated
signal delivery_created(delivery_id: int)
signal delivery_completed(delivery_id: int)

const DELIVERY_DURATION_MINUTES: int = 4 * 60

var _active_deliveries: Array = []
var _delivered_deliveries: Array = []
var _next_delivery_id: int = 1
var _is_updating_deliveries: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not GameTime.time_changed.is_connected(_on_external_state_changed):
		GameTime.time_changed.connect(_on_external_state_changed)

	if not FridgeInventory.inventory_contents_changed.is_connected(_on_fridge_inventory_changed):
		FridgeInventory.inventory_contents_changed.connect(_on_fridge_inventory_changed)

	update_deliveries(GameTime.get_absolute_minutes())


func create_delivery(items: Array) -> Dictionary:
	var normalized_items: Array = _normalize_items(items)

	if normalized_items.is_empty():
		return {}

	var created_at: int = GameTime.get_absolute_minutes()
	var delivery: Dictionary = {
		"id": _next_delivery_id,
		"items": normalized_items,
		"created_at": created_at,
		"deliver_at": created_at + DELIVERY_DURATION_MINUTES,
		"last_item_state_update_at": created_at,
		"status": "in_transit",
	}

	_next_delivery_id += 1
	_active_deliveries.append(delivery)
	deliveries_updated.emit()
	delivery_created.emit(int(delivery.get("id", -1)))
	return delivery.duplicate(true)


func update_deliveries(current_game_time: int = -1) -> void:
	if _is_updating_deliveries:
		return

	_is_updating_deliveries = true
	var current_absolute_minutes: int = current_game_time

	if current_absolute_minutes < 0:
		current_absolute_minutes = GameTime.get_absolute_minutes()

	var has_changes: bool = false

	for delivery_index in range(_active_deliveries.size() - 1, -1, -1):
		var delivery: Dictionary = {}

		if _active_deliveries[delivery_index] is Dictionary:
			delivery = _active_deliveries[delivery_index]

		if delivery.is_empty():
			_active_deliveries.remove_at(delivery_index)
			has_changes = true
			continue

		delivery = _advance_delivery_item_states(delivery, current_absolute_minutes)
		_active_deliveries[delivery_index] = delivery
		var deliver_at: int = int(delivery.get("deliver_at", current_absolute_minutes))

		if current_absolute_minutes < deliver_at:
			if String(delivery.get("status", "")) != "in_transit":
				delivery["status"] = "in_transit"
				_active_deliveries[delivery_index] = delivery
				has_changes = true

			continue

		if not FridgeInventory.is_initialized():
			continue

		var delivery_items: Array = delivery.get("items", [])

		if not FridgeInventory.add_order_items(delivery_items):
			if String(delivery.get("status", "")) != "awaiting_fridge_space":
				delivery["status"] = "awaiting_fridge_space"
				_active_deliveries[delivery_index] = delivery
				has_changes = true

			continue

		delivery["status"] = "delivered"
		delivery["delivered_at"] = current_absolute_minutes
		_delivered_deliveries.append(delivery.duplicate(true))
		_active_deliveries.remove_at(delivery_index)
		has_changes = true
		delivery_completed.emit(int(delivery.get("id", -1)))

	if has_changes:
		deliveries_updated.emit()

	_is_updating_deliveries = false


func get_active_deliveries() -> Array:
	return _active_deliveries.duplicate(true)


func get_delivered_deliveries() -> Array:
	return _delivered_deliveries.duplicate(true)


func get_remaining_minutes(delivery: Dictionary) -> int:
	return max(0, int(delivery.get("deliver_at", 0)) - GameTime.get_absolute_minutes())


func _on_external_state_changed(_absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	update_deliveries(_absolute_minutes)


func _on_fridge_inventory_changed() -> void:
	update_deliveries(GameTime.get_absolute_minutes())


func _normalize_items(items: Array) -> Array:
	var aggregated_entries: Dictionary = {}

	for item_variant in items:
		var entry: Dictionary = {}

		if item_variant is Dictionary:
			entry = item_variant

		if entry.is_empty():
			continue

		var item_data: ItemData = _resolve_item_data_from_entry(entry)

		if item_data == null:
			continue

		var quantity: int = int(entry.get("quantity", 0))
		var raw_item_state: Variant = entry.get("item_state", {})
		var item_state: Dictionary = raw_item_state if raw_item_state is Dictionary else {}

		if FoodFreshness.is_food_item(item_data):
			item_state = FoodFreshness.normalize_state(item_data, item_state)

		if quantity < 0:
			quantity = 0

		if quantity <= 0:
			continue

		var item_path: String = item_data.resource_path

		if item_path.is_empty():
			continue

		var aggregate_key: String = "%s|%s" % [item_path, FoodFreshness.build_stack_key(item_data, item_state)]
		var aggregated_entry: Dictionary = {}

		if aggregated_entries.has(aggregate_key):
			aggregated_entry = aggregated_entries[aggregate_key]

		if aggregated_entry.is_empty():
			aggregated_entry = {
				"item_path": item_path,
				"quantity": 0,
				"item_state": item_state.duplicate(true),
			}

		aggregated_entry["quantity"] = int(aggregated_entry.get("quantity", 0)) + quantity
		aggregated_entries[aggregate_key] = aggregated_entry

	var normalized_items: Array = []

	for aggregate_key in aggregated_entries.keys():
		var aggregated_entry: Dictionary = aggregated_entries[aggregate_key]
		var item_path: String = String(aggregated_entry.get("item_path", ""))
		var item_data: ItemData = load(item_path) as ItemData

		if item_data == null:
			continue

		normalized_items.append({
			"item_path": item_path,
			"quantity": int(aggregated_entry.get("quantity", 0)),
			"item_state": FoodFreshness.normalize_state(item_data, aggregated_entry.get("item_state", {})),
		})

	return normalized_items


func _advance_delivery_item_states(delivery: Dictionary, current_absolute_minutes: int) -> Dictionary:
	if delivery.is_empty():
		return delivery

	var last_update_at: int = int(delivery.get("last_item_state_update_at", delivery.get("created_at", current_absolute_minutes)))
	var elapsed_minutes: int = current_absolute_minutes - last_update_at

	if elapsed_minutes <= 0:
		return delivery

	var updated_items: Array = []

	for entry_variant in delivery.get("items", []):
		var entry: Dictionary = {}

		if entry_variant is Dictionary:
			entry = (entry_variant as Dictionary).duplicate(true)

		if entry.is_empty():
			continue

		var item_data: ItemData = _resolve_item_data_from_entry(entry)
		var raw_item_state: Variant = entry.get("item_state", {})
		var item_state: Dictionary = raw_item_state if raw_item_state is Dictionary else {}

		if item_data != null and FoodFreshness.is_food_item(item_data):
			entry["item_state"] = FoodFreshness.apply_elapsed_minutes(item_data, item_state, elapsed_minutes, 1.0)

		updated_items.append(entry)

	delivery["items"] = updated_items
	delivery["last_item_state_update_at"] = current_absolute_minutes
	return delivery


func _resolve_item_data_from_entry(entry: Dictionary) -> ItemData:
	var item_data: ItemData = entry.get("item_data", null) as ItemData

	if item_data != null:
		return item_data

	var item_path: String = String(entry.get("item_path", ""))

	if item_path.is_empty():
		return null

	return load(item_path) as ItemData
