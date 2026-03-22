extends WorldInteractable

const FRIDGE_WINDOW_SCENE := preload("res://scenes/ui/fridge_window.tscn")
const DEFAULT_APPLE := preload("res://resources/items/apple.tres")
const DEFAULT_BREAD := preload("res://resources/items/bread.tres")

signal inventory_changed

@export var closed_texture: Texture2D
@export var open_texture: Texture2D
@export_range(1, 64, 1) var inventory_size: int = 12
@export var starter_items: Array[ItemData] = [
	DEFAULT_APPLE,
	DEFAULT_APPLE,
	DEFAULT_BREAD,
]

@onready var sprite: Sprite2D = $Sprite2D

var _active_window: FridgeWindow
var _active_player: Node


func _ready() -> void:
	interaction_name = "fridge"
	interaction_prompt_text = "\u041E\u0442\u043A\u0440\u044B\u0442\u044C \u0445\u043E\u043B\u043E\u0434\u0438\u043B\u044C\u043D\u0438\u043A"
	stat_delta = {}
	FridgeInventory.setup_storage(inventory_size, starter_items)

	if not FridgeInventory.inventory_changed.is_connected(_on_fridge_inventory_changed):
		FridgeInventory.inventory_changed.connect(_on_fridge_inventory_changed)

	_update_sprite(false)
	super._ready()


func interact(player: Node) -> void:
	if _active_window != null:
		return

	_active_player = player
	interacted.emit(player, interaction_name, {})
	_set_modal_state(true)
	_update_sprite(true)
	_open_window()


func get_slots() -> Array:
	return FridgeInventory.get_slots()


func get_inventory_size() -> int:
	return FridgeInventory.get_inventory_size()


func add_item_to_fridge(item_data: ItemData, quantity: int = 1) -> bool:
	return FridgeInventory.add_item(item_data, quantity)


func take_item(slot_index: int) -> bool:
	var slot := FridgeInventory.get_slot_at(slot_index)
	var player_inventory := _get_player_inventory()

	if slot == null or slot.is_empty() or slot.item_data == null or player_inventory == null:
		return false

	if not player_inventory.add_item(slot.item_data, 1):
		_show_status_message("\u041D\u0435\u0442 \u043C\u0435\u0441\u0442\u0430 \u0432 \u0438\u043D\u0432\u0435\u043D\u0442\u0430\u0440\u0435.")
		return false

	FridgeInventory.remove_item_at(slot_index, 1)
	_show_status_message("\u041F\u0440\u0435\u0434\u043C\u0435\u0442 \u043F\u0435\u0440\u0435\u043D\u0435\u0441\u0451\u043D \u0432 \u0438\u043D\u0432\u0435\u043D\u0442\u0430\u0440\u044C.")
	return true


func eat_item(slot_index: int) -> bool:
	var slot := FridgeInventory.get_slot_at(slot_index)
	var stats := _get_player_stats()

	if slot == null or slot.is_empty() or slot.item_data == null or stats == null:
		return false

	var item_data: ItemData = slot.item_data

	if not item_data.is_consumable:
		_show_status_message("\u042D\u0442\u043E\u0442 \u043F\u0440\u0435\u0434\u043C\u0435\u0442 \u043D\u0435\u043B\u044C\u0437\u044F \u0441\u044A\u0435\u0441\u0442\u044C.")
		return false

	stats.add_hunger(item_data.hunger_restore)
	FridgeInventory.remove_item_at(slot_index, 1)
	_show_status_message("\u0412\u044B \u0441\u044A\u0435\u043B\u0438 %s." % item_data.get_display_name())
	return true


func _open_window() -> void:
	_active_window = FRIDGE_WINDOW_SCENE.instantiate() as FridgeWindow

	if _active_window == null:
		push_warning("Fridge could not instantiate FridgeWindow.")
		_finish_close()
		return

	_active_window.close_requested.connect(_close_window)
	_active_window.take_requested.connect(_on_take_requested)
	_active_window.eat_requested.connect(_on_eat_requested)
	_active_window.tree_exited.connect(_on_window_tree_exited)
	inventory_changed.connect(_update_active_window)
	_get_ui_parent().add_child(_active_window)
	_active_window.set_inventory_size(get_inventory_size())
	_active_window.set_slots(get_slots())
	_active_window.show_status_message("")


func _close_window() -> void:
	var window: FridgeWindow = _active_window
	_active_window = null

	if window != null and is_instance_valid(window):
		if window.tree_exited.is_connected(_on_window_tree_exited):
			window.tree_exited.disconnect(_on_window_tree_exited)

		if inventory_changed.is_connected(_update_active_window):
			inventory_changed.disconnect(_update_active_window)

		window.queue_free()

	_finish_close()


func _on_window_tree_exited() -> void:
	_active_window = null
	_finish_close()


func _finish_close() -> void:
	_set_modal_state(false)
	_update_sprite(false)
	_active_player = null


func _on_take_requested(slot_index: int) -> void:
	take_item(slot_index)


func _on_eat_requested(slot_index: int) -> void:
	eat_item(slot_index)


func _on_fridge_inventory_changed() -> void:
	inventory_changed.emit()
	_update_active_window()


func _update_active_window() -> void:
	if _active_window == null or not is_instance_valid(_active_window):
		return

	_active_window.set_slots(get_slots())


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
	if _active_player != null and _active_player.has_method("set_input_locked"):
		_active_player.set_input_locked(is_active)

	var hud: Node = _find_hud()

	if hud != null and hud.has_method("set_clock_paused"):
		hud.set_clock_paused(is_active)


func _get_ui_parent() -> Node:
	var current_scene: Node = get_tree().current_scene

	if current_scene != null:
		return current_scene

	return get_tree().root


func _find_hud() -> Node:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null:
		return hud

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return null

	return current_scene.get_node_or_null("HUD")


func _get_player_inventory() -> PlayerInventoryState:
	return get_node_or_null("/root/PlayerInventory") as PlayerInventoryState


func _get_player_stats() -> PlayerStatsState:
	return get_node_or_null("/root/PlayerStats") as PlayerStatsState
