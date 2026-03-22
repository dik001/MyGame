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

	if not FridgeInventory.inventory_changed.is_connected(_on_fridge_inventory_changed):
		FridgeInventory.inventory_changed.connect(_on_fridge_inventory_changed)

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
	var aggregated_quantities: Dictionary = {}

	for item_variant in items:
		var entry: Dictionary = {}

		if item_variant is Dictionary:
			entry = item_variant

		if entry.is_empty():
			continue

		var item_data: ItemData = entry.get("item_data", null) as ItemData

		if item_data == null:
			var entry_item_path: String = String(entry.get("item_path", ""))

			if not entry_item_path.is_empty():
				item_data = load(entry_item_path) as ItemData

		if item_data == null:
			continue

		var quantity: int = int(entry.get("quantity", 0))

		if quantity < 0:
			quantity = 0

		if quantity <= 0:
			continue

		var item_path: String = item_data.resource_path

		if item_path.is_empty():
			continue

		aggregated_quantities[item_path] = int(aggregated_quantities.get(item_path, 0)) + quantity

	var normalized_items: Array = []

	for item_path_variant in aggregated_quantities.keys():
		var item_path: String = String(item_path_variant)
		var item_data: ItemData = load(item_path) as ItemData

		if item_data == null:
			continue

		normalized_items.append({
			"item_path": String(item_path),
			"quantity": int(aggregated_quantities[item_path]),
		})

	return normalized_items
