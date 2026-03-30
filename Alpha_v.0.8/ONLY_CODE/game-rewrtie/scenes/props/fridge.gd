extends WorldInteractable

const STORAGE_WINDOW_SCENE := preload("res://scenes/ui/storage_window.tscn")
const DEFAULT_APPLE := preload("res://resources/items/apple.tres")

const STORAGE_TITLE_TEXT := "\u0425\u043e\u043b\u043e\u0434\u0438\u043b\u044c\u043d\u0438\u043a"
const NO_PLAYER_SPACE_TEXT := "\u041d\u0435\u0442 \u043c\u0435\u0441\u0442\u0430 \u0432 \u0438\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u0435."
const NO_STORAGE_SPACE_TEXT := "\u041d\u0435\u0442 \u043c\u0435\u0441\u0442\u0430 \u0432 \"%s\"."
const MOVED_TO_PLAYER_TEXT := "\u041f\u0440\u0435\u0434\u043c\u0435\u0442 \u043f\u0435\u0440\u0435\u043d\u0435\u0441\u0451\u043d \u0432 \u0438\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u044c."
const MOVED_TO_STORAGE_TEXT := "\u041f\u0440\u0435\u0434\u043c\u0435\u0442 \u043f\u0435\u0440\u0435\u043d\u0435\u0441\u0451\u043d \u0432 \"%s\"."
const STORE_FAILED_TEXT := "\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u0435\u0440\u0435\u043d\u0435\u0441\u0442\u0438 \u043f\u0440\u0435\u0434\u043c\u0435\u0442 \u0432 \"%s\"."
const TAKE_FAILED_TEXT := "\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0431\u0440\u0430\u0442\u044c \u043f\u0440\u0435\u0434\u043c\u0435\u0442."
const NOT_USABLE_TEXT := "\u042d\u0442\u043e\u0442 \u043f\u0440\u0435\u0434\u043c\u0435\u0442 \u043d\u0435\u043b\u044c\u0437\u044f \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c."
const USED_ITEM_TEXT := "\u0418\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u043d\u043e: %s."

signal inventory_changed

@export var closed_texture: Texture2D
@export var open_texture: Texture2D
@export_range(1, 64, 1) var inventory_size: int = 12
@export var starter_items: Array[ItemData] = [
	DEFAULT_APPLE,
]

@onready var sprite: Sprite2D = $Sprite2D

var _active_window: StorageWindow
var _active_player: Node
var _suppress_window_refresh: bool = false


func _ready() -> void:
	interaction_name = "fridge"
	interaction_prompt_text = WorldInteractable.DEFAULT_INTERACTION_PROMPT_TEXT
	stat_delta = {}
	FridgeInventory.setup_storage(inventory_size, starter_items)

	if not FridgeInventory.inventory_changed.is_connected(_on_fridge_inventory_changed):
		FridgeInventory.inventory_changed.connect(_on_fridge_inventory_changed)

	_update_sprite(false)
	super._ready()


func interact(player: Node) -> void:
	if _active_window != null and is_instance_valid(_active_window):
		return

	_active_player = player
	interacted.emit(player, interaction_name, {})
	_set_modal_state(true)
	_update_sprite(true)
	_open_window()


func get_storage_title() -> String:
	return STORAGE_TITLE_TEXT


func get_slots() -> Array:
	return FridgeInventory.get_slots()


func get_inventory_size() -> int:
	return FridgeInventory.get_inventory_size()


func can_add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	return FridgeInventory.can_add_item(item_data, quantity, item_state)


func add_item(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	return FridgeInventory.add_item(item_data, quantity, item_state)


func remove_item_at(slot_index: int, quantity: int = 1) -> bool:
	return FridgeInventory.remove_item_at(slot_index, quantity)


func add_item_to_fridge(item_data: ItemData, quantity: int = 1, item_state: Dictionary = {}) -> bool:
	return add_item(item_data, quantity, item_state)


func store_item(slot_index: int) -> bool:
	var player_inventory := _get_player_inventory()
	var slot := player_inventory.get_slot_at(slot_index) if player_inventory != null else null

	if slot == null or slot.is_empty() or slot.item_data == null or player_inventory == null:
		return false

	var item_data: ItemData = slot.item_data
	var item_state := slot.get_item_state()

	if not can_add_item(item_data, 1, item_state):
		_show_status_message(NO_STORAGE_SPACE_TEXT % get_storage_title())
		return false

	_suppress_window_refresh = true

	if not add_item(item_data, 1, item_state):
		_suppress_window_refresh = false
		_show_status_message(STORE_FAILED_TEXT % get_storage_title())
		return false

	if not player_inventory.remove_item_at(slot_index, 1):
		var rollback_slot_index := _find_matching_slot_index_in_array(get_slots(), item_data, item_state)

		if rollback_slot_index >= 0:
			remove_item_at(rollback_slot_index, 1)

		_suppress_window_refresh = false
		_update_active_window()
		_show_status_message(STORE_FAILED_TEXT % get_storage_title())
		return false

	_suppress_window_refresh = false
	_update_active_window()
	_show_status_message(MOVED_TO_STORAGE_TEXT % get_storage_title())
	return true


func take_item(slot_index: int) -> bool:
	var slot := FridgeInventory.get_slot_at(slot_index)
	var player_inventory := _get_player_inventory()

	if slot == null or slot.is_empty() or slot.item_data == null or player_inventory == null:
		return false

	var item_data: ItemData = slot.item_data
	var item_state := slot.get_item_state()

	_suppress_window_refresh = true

	if not player_inventory.add_item(item_data, 1, item_state):
		_suppress_window_refresh = false
		_show_status_message(NO_PLAYER_SPACE_TEXT)
		return false

	if not remove_item_at(slot_index, 1):
		var rollback_slot_index := _find_matching_slot_index_in_array(player_inventory.get_slots(), item_data, item_state)

		if rollback_slot_index >= 0:
			player_inventory.remove_item_at(rollback_slot_index, 1)

		_suppress_window_refresh = false
		_update_active_window()
		_show_status_message(TAKE_FAILED_TEXT)
		return false

	_suppress_window_refresh = false
	_update_active_window()
	_show_status_message(MOVED_TO_PLAYER_TEXT)
	return true


func consume_item(slot_index: int) -> bool:
	var slot := FridgeInventory.get_slot_at(slot_index)
	var stats := _get_player_stats()

	if slot == null or slot.is_empty() or slot.item_data == null or stats == null:
		return false

	var item_data: ItemData = slot.item_data

	if not item_data.can_use_directly():
		_show_status_message(NOT_USABLE_TEXT)
		return false

	_suppress_window_refresh = true
	var item_state := slot.get_item_state()
	var validation_result: Dictionary = stats.can_use_item(item_data, item_state)

	if not bool(validation_result.get("success", false)):
		_suppress_window_refresh = false
		_show_status_message(String(validation_result.get("message", NOT_USABLE_TEXT)))
		return false

	if not remove_item_at(slot_index, 1):
		_suppress_window_refresh = false
		_update_active_window()
		return false

	var apply_result: Dictionary = stats.apply_item_use(item_data, item_state)

	if not bool(apply_result.get("success", false)):
		add_item(item_data, 1, item_state)
		_suppress_window_refresh = false
		_update_active_window()
		_show_status_message(String(apply_result.get("message", NOT_USABLE_TEXT)))
		return false

	_suppress_window_refresh = false
	_update_active_window()
	_show_status_message(String(apply_result.get("message", USED_ITEM_TEXT % item_data.get_display_name())))
	return true


func eat_item(slot_index: int) -> bool:
	return consume_item(slot_index)


func _open_window() -> void:
	_active_window = STORAGE_WINDOW_SCENE.instantiate() as StorageWindow

	if _active_window == null:
		push_warning("Fridge could not instantiate StorageWindow.")
		_finish_close()
		return

	var ui_parent := _get_ui_parent()

	if ui_parent == null:
		push_warning("Fridge could not find a UI parent for StorageWindow.")
		_active_window.queue_free()
		_active_window = null
		_finish_close()
		return

	_active_window.close_requested.connect(_close_window)
	_active_window.store_requested.connect(_on_store_requested)
	_active_window.take_requested.connect(_on_take_requested)
	_active_window.consume_requested.connect(_on_consume_requested)
	_active_window.tree_exited.connect(_on_window_tree_exited)
	_connect_window_refresh_sources()
	ui_parent.add_child(_active_window)
	_active_window.set_storage_title(get_storage_title())
	_active_window.set_storage_supports_consume(true)
	_active_window.set_storage_freshness_display_multiplier(FoodFreshness.FRIDGE_SPOILAGE_MULTIPLIER)
	_update_active_window()
	_active_window.show_status_message("")


func _close_window() -> void:
	var window: StorageWindow = _active_window
	_active_window = null

	_disconnect_window_refresh_sources()

	if window != null and is_instance_valid(window):
		if window.tree_exited.is_connected(_on_window_tree_exited):
			window.tree_exited.disconnect(_on_window_tree_exited)

		window.queue_free()

	_finish_close()


func _on_window_tree_exited() -> void:
	_active_window = null
	_disconnect_window_refresh_sources()
	_finish_close()


func _finish_close() -> void:
	_set_modal_state(false)
	_update_sprite(false)
	_active_player = null


func _on_store_requested(slot_index: int) -> void:
	store_item(slot_index)


func _on_take_requested(slot_index: int) -> void:
	take_item(slot_index)


func _on_consume_requested(slot_index: int) -> void:
	consume_item(slot_index)


func _on_fridge_inventory_changed() -> void:
	if _suppress_window_refresh:
		return

	inventory_changed.emit()


func _on_player_inventory_changed() -> void:
	if _suppress_window_refresh:
		return

	_update_active_window()


func _update_active_window() -> void:
	if _active_window == null or not is_instance_valid(_active_window):
		return

	var player_inventory := _get_player_inventory()
	var player_slots: Array = player_inventory.get_slots() if player_inventory != null else []
	_active_window.set_player_slots(player_slots)
	_active_window.set_storage_slots(get_slots())


func _show_status_message(message: String) -> void:
	if _active_window != null and is_instance_valid(_active_window):
		_active_window.show_status_message(message)


func _update_sprite(is_open: bool) -> void:
	if sprite == null:
		return

	if is_open and open_texture != null:
		sprite.texture = open_texture
		return

	if closed_texture != null:
		sprite.texture = closed_texture


func _set_modal_state(is_active: bool) -> void:
	if _active_player != null and is_instance_valid(_active_player) and _active_player.has_method("set_input_locked"):
		_active_player.set_input_locked(is_active)

	var hud: Node = _find_hud()

	if hud != null and hud.has_method("set_clock_paused"):
		hud.set_clock_paused(is_active)


func _get_ui_parent() -> Node:
	var tree := get_tree()

	if tree == null:
		return null

	var current_scene: Node = tree.current_scene

	if current_scene != null:
		return current_scene

	return tree.root


func _find_hud() -> Node:
	var tree := get_tree()

	if tree == null:
		return null

	var hud: Node = tree.get_first_node_in_group("hud")

	if hud != null:
		return hud

	var current_scene: Node = tree.current_scene

	if current_scene == null:
		return null

	return current_scene.get_node_or_null("HUD")


func _get_player_inventory() -> PlayerInventoryState:
	var player_inventory := PlayerInventory as PlayerInventoryState
	return player_inventory if is_instance_valid(player_inventory) else null


func _get_player_stats() -> PlayerStatsState:
	var player_stats := PlayerStats as PlayerStatsState
	return player_stats if is_instance_valid(player_stats) else null


func _connect_window_refresh_sources() -> void:
	if not inventory_changed.is_connected(_update_active_window):
		inventory_changed.connect(_update_active_window)

	var player_inventory := _get_player_inventory()

	if player_inventory != null and not player_inventory.inventory_changed.is_connected(_on_player_inventory_changed):
		player_inventory.inventory_changed.connect(_on_player_inventory_changed)


func _disconnect_window_refresh_sources() -> void:
	if inventory_changed.is_connected(_update_active_window):
		inventory_changed.disconnect(_update_active_window)

	var player_inventory := _get_player_inventory()

	if player_inventory != null and player_inventory.inventory_changed.is_connected(_on_player_inventory_changed):
		player_inventory.inventory_changed.disconnect(_on_player_inventory_changed)


func _find_matching_slot_index_in_array(slots: Array, item_data: ItemData, item_state: Dictionary = {}) -> int:
	if item_data == null:
		return -1

	for slot_index in range(slots.size()):
		var slot := slots[slot_index] as InventorySlotData

		if slot == null or slot.is_empty() or slot.item_data == null:
			continue

		if not slot.item_data.matches(item_data):
			continue

		if not FoodFreshness.can_stack(item_data, slot.get_item_state(), item_state):
			continue

		return slot_index

	return -1
