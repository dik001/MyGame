class_name StoveInteractable
extends WorldInteractable

const COOKING_SYSTEM_SCRIPT := preload("res://scenes/inventory/CookingSystem.gd")
const STOVE_WINDOW_SCENE := preload("res://scenes/ui/stove_window.tscn")

const DEFAULT_STATION_TITLE_TEXT := "Плита"
const DEFAULT_SUCCESS_NOTIFICATION_DURATION := 2.4
const STATUS_COLOR_SUCCESS := Color(0.66, 1.0, 0.76, 1.0)
const STATUS_COLOR_ERROR := Color(1.0, 0.65, 0.65, 1.0)

@export var station_title_text: String = DEFAULT_STATION_TITLE_TEXT
@export var station_tags: PackedStringArray = PackedStringArray(["fire", "water"])

var _active_window: StoveWindow
var _active_player: Node
var _suppress_window_refresh := false
var _cooking_system = COOKING_SYSTEM_SCRIPT.new()


func _ready() -> void:
	interaction_name = "stove"
	interaction_prompt_text = "Готовить"
	stat_delta = {}
	super._ready()


func interact(player: Node) -> void:
	if _active_window != null and is_instance_valid(_active_window):
		return

	_active_player = player
	interacted.emit(player, interaction_name, {})
	_set_modal_state(true)
	_open_window()


func _open_window() -> void:
	_active_window = STOVE_WINDOW_SCENE.instantiate() as StoveWindow

	if _active_window == null:
		push_warning("Stove could not instantiate StoveWindow.")
		_finish_close()
		return

	var ui_parent := _get_ui_parent()

	if ui_parent == null:
		push_warning("Stove could not find a UI parent for StoveWindow.")
		_active_window.queue_free()
		_active_window = null
		_finish_close()
		return

	_active_window.close_requested.connect(_close_window)
	_active_window.selection_changed.connect(_on_selection_changed)
	_active_window.cook_requested.connect(_on_cook_requested)
	_active_window.tree_exited.connect(_on_window_tree_exited)
	ui_parent.add_child(_active_window)
	_connect_refresh_sources()
	_update_active_window()
	_active_window.show_status_message("")


func _close_window() -> void:
	var window := _active_window
	_active_window = null
	_disconnect_refresh_sources()

	if window != null and is_instance_valid(window):
		if window.tree_exited.is_connected(_on_window_tree_exited):
			window.tree_exited.disconnect(_on_window_tree_exited)

		window.queue_free()

	_finish_close()


func _on_window_tree_exited() -> void:
	_active_window = null
	_disconnect_refresh_sources()
	_finish_close()


func _finish_close() -> void:
	_set_modal_state(false)
	_active_player = null


func _on_selection_changed(_selected_items: Array) -> void:
	if _suppress_window_refresh:
		return

	_update_active_window()


func _on_cook_requested(selected_items: Array) -> void:
	var player_inventory := _get_player_inventory()

	if player_inventory == null:
		_show_status_message("Инвентарь игрока недоступен.", true)
		return

	_suppress_window_refresh = true
	var cook_result := _cooking_system.cook_selected_items(
		selected_items,
		_get_cooking_storages(),
		player_inventory,
		station_tags
	)
	_suppress_window_refresh = false

	var was_successful := bool(cook_result.get("success", false))
	var message := String(cook_result.get("message", "")).strip_edges()

	if was_successful and _active_window != null and is_instance_valid(_active_window):
		_active_window.clear_selection()

	_update_active_window()

	if message.is_empty():
		message = "Не удалось приготовить."

	_show_status_message(message, not was_successful)

	if was_successful:
		_show_hud_notification(message)


func _on_player_inventory_changed() -> void:
	if _suppress_window_refresh:
		return

	_update_active_window()


func _on_fridge_inventory_changed() -> void:
	if _suppress_window_refresh:
		return

	_update_active_window()


func _update_active_window() -> void:
	if _active_window == null or not is_instance_valid(_active_window):
		return

	var supply_entries := _cooking_system.build_combined_supply_entries(_get_cooking_storages(), station_tags)
	_active_window.set_station_title(_get_station_title())
	_active_window.set_supply_entries(supply_entries)
	var selected_items := _active_window.get_selected_items()
	var selection_report := _cooking_system.build_hidden_selection_report(selected_items, station_tags)
	_active_window.set_selection_report(selection_report)


func _show_status_message(message: String, is_error := false) -> void:
	if _active_window == null or not is_instance_valid(_active_window):
		return

	var status_color := STATUS_COLOR_ERROR if is_error else STATUS_COLOR_SUCCESS
	_active_window.show_status_message(message, status_color)


func _show_hud_notification(message: String) -> void:
	var trimmed_message := message.strip_edges()

	if trimmed_message.is_empty():
		return

	var hud := _find_hud()

	if hud != null and hud.has_method("show_notification"):
		hud.show_notification(trimmed_message, DEFAULT_SUCCESS_NOTIFICATION_DURATION)


func _set_modal_state(is_active: bool) -> void:
	if _active_player != null and is_instance_valid(_active_player) and _active_player.has_method("set_input_locked"):
		_active_player.set_input_locked(is_active)

	var hud := _find_hud()

	if hud != null and hud.has_method("set_clock_paused"):
		hud.set_clock_paused(is_active)


func _get_station_title() -> String:
	var trimmed_title := station_title_text.strip_edges()
	return trimmed_title if not trimmed_title.is_empty() else DEFAULT_STATION_TITLE_TEXT


func _get_ui_parent() -> Node:
	var tree := get_tree()

	if tree == null:
		return null

	var current_scene := tree.current_scene

	if current_scene != null:
		return current_scene

	return tree.root


func _find_hud() -> Node:
	var tree := get_tree()

	if tree == null:
		return null

	var hud := tree.get_first_node_in_group("hud")

	if hud != null:
		return hud

	var current_scene := tree.current_scene

	if current_scene == null:
		return null

	return current_scene.get_node_or_null("HUD")


func _get_player_inventory() -> PlayerInventoryState:
	var player_inventory := PlayerInventory as PlayerInventoryState
	return player_inventory if is_instance_valid(player_inventory) else null


func _get_fridge_inventory() -> FridgeInventoryState:
	var fridge_inventory := FridgeInventory as FridgeInventoryState

	if not is_instance_valid(fridge_inventory):
		return null

	if fridge_inventory.has_method("is_initialized") and not fridge_inventory.is_initialized():
		return null

	return fridge_inventory


func _get_cooking_storages() -> Array:
	var storages: Array = []
	var player_inventory := _get_player_inventory()

	if player_inventory != null:
		storages.append({
			"storage": player_inventory,
		})

	var fridge_inventory := _get_fridge_inventory()

	if fridge_inventory != null:
		storages.append({
			"storage": fridge_inventory,
		})

	return storages


func _connect_refresh_sources() -> void:
	var player_inventory := _get_player_inventory()

	if player_inventory != null and not player_inventory.inventory_changed.is_connected(_on_player_inventory_changed):
		player_inventory.inventory_changed.connect(_on_player_inventory_changed)

	var fridge_inventory := _get_fridge_inventory()

	if fridge_inventory != null and not fridge_inventory.inventory_changed.is_connected(_on_fridge_inventory_changed):
		fridge_inventory.inventory_changed.connect(_on_fridge_inventory_changed)


func _disconnect_refresh_sources() -> void:
	var player_inventory := _get_player_inventory()

	if player_inventory != null and player_inventory.inventory_changed.is_connected(_on_player_inventory_changed):
		player_inventory.inventory_changed.disconnect(_on_player_inventory_changed)

	var fridge_inventory := _get_fridge_inventory()

	if fridge_inventory != null and fridge_inventory.inventory_changed.is_connected(_on_fridge_inventory_changed):
		fridge_inventory.inventory_changed.disconnect(_on_fridge_inventory_changed)
