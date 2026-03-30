extends WorldInteractable

const SHOP_WINDOW_SCENE := preload("res://scenes/ui/shop_window.tscn")
const CASHIER_MENU_SCENE := preload("res://scenes/part_time/CashierInteractionWindow.tscn")
const TRASH_SORTING_MINIGAME_SCENE := preload("res://scenes/part_time/TrashSortingMinigameUI.tscn")
const PART_TIME_CONFIG = preload("res://scenes/part_time/CashierPartTimeConfig.gd")
const DEFAULT_WINDOW_TITLE := "Касса"
const DEFAULT_WINDOW_SUBTITLE := "Те же товары, но дешевле. Покупка сразу попадает в инвентарь."
const HYGIENE_DIRTY_SEQUENCE: Array[Dictionary] = [
	{
		"speaker_name": "Кассир",
		"speaker_id": "cashier",
		"text": "От тебя тянет улицей и потом. Только не стой так близко к прилавку.",
	},
	{
		"speaker_name": "Руна",
		"speaker_id": "runa",
		"text": "Мне нужны продукты. Не больше.",
	},
]
const HYGIENE_UNSANITARY_SEQUENCE: Array[Dictionary] = [
	{
		"speaker_name": "Кассир",
		"speaker_id": "cashier",
		"text": "Сначала бы отмыться. Здесь и без того душно, а ты будто всё несёшь на себе.",
	},
	{
		"speaker_name": "Руна",
		"speaker_id": "runa",
		"text": "Я заберу своё и уйду.",
	},
]
const HYGIENE_FALLBACK_DIRTY_TEXT := "Кассир недовольно морщится, но всё же обслуживает."
const HYGIENE_FALLBACK_UNSANITARY_TEXT := "Кассир косится на запущенный вид Руны, но магазин всё же открыт."

@export var catalog: Array[ItemData] = []
@export var window_title_text: String = DEFAULT_WINDOW_TITLE
@export_multiline var window_subtitle_text: String = DEFAULT_WINDOW_SUBTITLE
@export var price_overrides: Dictionary = {}
@export_range(0.1, 2.0, 0.01) var catalog_price_multiplier: float = 1.0

@onready var interaction_area: Area2D = get_node_or_null("../Area2D") as Area2D

var _active_modal: Control
var _active_window_layer: CanvasLayer
var _active_player: Node
var _player_in_range := false


func _ready() -> void:
	interaction_name = "cashier"
	interaction_prompt_text = WorldInteractable.DEFAULT_INTERACTION_PROMPT_TEXT
	stat_delta = {}
	super._ready()

	if not is_in_group("runtime_transient_ui_owner"):
		add_to_group("runtime_transient_ui_owner")

	if interaction_area == null:
		return

	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func can_interact(player_interaction_position: Vector2) -> bool:
	if _has_active_interaction():
		return false

	return super.can_interact(player_interaction_position)


func can_interact_from_context(
	player: Node,
	_actor_cell: Vector2i,
	_facing: Vector2,
	_world_grid: WorldGrid,
	_pattern_id: StringName = &""
) -> bool:
	return _allows_grid_interaction(player)


func interact(player: Node) -> void:
	if _has_active_interaction():
		return

	_active_player = player
	interacted.emit(player, interaction_name, {})
	_set_modal_state(true)
	await _play_cashier_greeting()

	if _active_player == null:
		return

	_open_cashier_menu()


func force_close_transient_ui() -> void:
	_force_close_interaction()


func _open_cashier_menu() -> void:
	var menu := CASHIER_MENU_SCENE.instantiate()

	if not (menu is Control):
		push_warning("Cashier could not instantiate CashierInteractionWindow.")
		_close_interaction()
		return

	menu.shop_selected.connect(_on_cashier_menu_shop_selected)
	menu.job_selected.connect(_on_cashier_menu_job_selected)
	menu.closed.connect(_on_cashier_menu_closed)

	if not _show_modal(menu):
		push_warning("Cashier could not show CashierInteractionWindow.")
		_close_interaction()


func _open_shop_window() -> void:
	var shop_window := SHOP_WINDOW_SCENE.instantiate() as ShopWindow

	if shop_window == null:
		push_warning("Cashier could not instantiate ShopWindow.")
		_close_interaction()
		return

	shop_window.catalog = catalog.duplicate()
	shop_window.use_delivery = false
	shop_window.payment_source = "cash"
	shop_window.set_window_texts(window_title_text, window_subtitle_text)
	shop_window.set_price_overrides(_build_price_overrides())
	shop_window.close_requested.connect(_close_interaction)

	if not _show_modal(shop_window):
		push_warning("Cashier could not show ShopWindow.")
		_close_interaction()


func _open_trash_sorting_minigame() -> void:
	var minigame := TRASH_SORTING_MINIGAME_SCENE.instantiate()

	if not (minigame is Control):
		push_warning("Cashier could not instantiate TrashSortingMinigameUI.")

		if CashierPartTimeState != null and CashierPartTimeState.has_method("interrupt_shift"):
			CashierPartTimeState.interrupt_shift(&"minigame_open_failed")

		_close_interaction()
		return

	minigame.finished.connect(_on_trash_sorting_finished)

	if not _show_modal(minigame):
		push_warning("Cashier could not show TrashSortingMinigameUI.")

		if CashierPartTimeState != null and CashierPartTimeState.has_method("interrupt_shift"):
			CashierPartTimeState.interrupt_shift(&"minigame_open_failed")

		_close_interaction()


func _on_cashier_menu_shop_selected() -> void:
	_open_shop_window()


func _on_cashier_menu_job_selected() -> void:
	if CashierPartTimeState == null or not CashierPartTimeState.has_method("can_start_shift"):
		_show_hud_notification("Подработка сейчас недоступна.")
		return

	var availability: Dictionary = CashierPartTimeState.can_start_shift()

	if not bool(availability.get("allowed", false)):
		_clear_active_modal()
		await _play_dialogue_sequence(
			PART_TIME_CONFIG.get_job_unavailable_sequence(
				StringName(String(availability.get("reason", "")).strip_edges())
			)
		)

		if _active_player != null:
			_open_cashier_menu()

		return

	CashierPartTimeState.start_shift()

	if not CashierPartTimeState.is_shift_active():
		_show_hud_notification("Не удалось начать смену.")
		_close_interaction()
		return

	_open_trash_sorting_minigame()


func _on_cashier_menu_closed() -> void:
	_close_interaction()


func _on_trash_sorting_finished(_result: Dictionary) -> void:
	_close_interaction()


func _on_active_modal_tree_exited() -> void:
	_active_modal = null
	_destroy_window_layer()
	_finish_close()


func _play_cashier_greeting() -> void:
	var greeting_sequence: Array[Dictionary] = _resolve_cashier_greeting_sequence()
	await _play_dialogue_sequence(greeting_sequence)


func _resolve_cashier_greeting_sequence() -> Array[Dictionary]:
	if PlayerStats == null or not PlayerStats.has_method("consume_hygiene_npc_comment"):
		return PART_TIME_CONFIG.get_default_greeting_sequence()

	var comment_result: Variant = PlayerStats.consume_hygiene_npc_comment(&"cashier")

	if not (comment_result is Dictionary):
		return PART_TIME_CONFIG.get_default_greeting_sequence()

	var comment_data: Dictionary = comment_result

	if not bool(comment_data.get("should_comment", false)):
		return PART_TIME_CONFIG.get_default_greeting_sequence()

	var stage_id := StringName(String(comment_data.get("stage_id", "")).strip_edges())
	var sequence: Array[Dictionary] = _build_hygiene_comment_sequence(stage_id)
	var humiliation_multiplier := 1.0

	if stage_id == &"hygiene_unsanitary":
		humiliation_multiplier = 1.25

	if PlayerMentalState != null and PlayerMentalState.has_method("apply_event"):
		PlayerMentalState.apply_event(&"hygiene_humiliation_comment", {
			"source": "cashier_comment",
			"multiplier": humiliation_multiplier,
			"tags": ["social", "shop"],
		})

	if sequence.is_empty():
		var fallback_text := HYGIENE_FALLBACK_DIRTY_TEXT

		if stage_id == &"hygiene_unsanitary":
			fallback_text = HYGIENE_FALLBACK_UNSANITARY_TEXT

		_show_hud_notification(fallback_text)
		return PART_TIME_CONFIG.get_default_greeting_sequence()

	return sequence


func _play_dialogue_sequence(sequence: Array[Dictionary]) -> void:
	if sequence.is_empty():
		return

	if DialogueManager != null and DialogueManager.has_method("play_sequence"):
		DialogueManager.play_sequence(sequence, true)
		await DialogueManager.dialogue_hidden
		return

	var fallback_text := String(sequence[0].get("text", "")).strip_edges()

	if not fallback_text.is_empty():
		_show_hud_notification(fallback_text)


func _show_modal(modal: Control) -> bool:
	var window_root := _ensure_window_root()

	if window_root == null:
		return false

	_clear_active_modal()
	_active_modal = modal
	window_root.add_child(modal)
	_stretch_window_to_parent(modal)

	if not modal.tree_exited.is_connected(_on_active_modal_tree_exited):
		modal.tree_exited.connect(_on_active_modal_tree_exited)

	if modal.has_method("open_window"):
		modal.call("open_window")

	return true


func _ensure_window_root() -> Control:
	if _active_window_layer != null and is_instance_valid(_active_window_layer):
		return _active_window_layer.get_child(0) as Control

	var ui_parent: Node = _get_ui_parent()

	if ui_parent == null:
		return null

	_active_window_layer = _create_window_layer()

	if _active_window_layer == null:
		return null

	ui_parent.add_child(_active_window_layer)
	return _active_window_layer.get_child(0) as Control


func _clear_active_modal() -> void:
	var modal := _active_modal
	_active_modal = null

	if modal == null or not is_instance_valid(modal):
		return

	if modal.has_method("force_close"):
		modal.call("force_close")

	if modal.tree_exited.is_connected(_on_active_modal_tree_exited):
		modal.tree_exited.disconnect(_on_active_modal_tree_exited)

	modal.queue_free()


func _close_interaction() -> void:
	_clear_active_modal()
	_destroy_window_layer()
	_finish_close()


func _force_close_interaction() -> void:
	if CashierPartTimeState != null and CashierPartTimeState.has_method("is_shift_active") and CashierPartTimeState.is_shift_active():
		CashierPartTimeState.interrupt_shift(&"forced_close")

	_clear_active_modal()
	_destroy_window_layer()
	_finish_close()


func _destroy_window_layer() -> void:
	if _active_window_layer != null and is_instance_valid(_active_window_layer):
		_active_window_layer.queue_free()

	_active_window_layer = null


func _finish_close() -> void:
	_set_modal_state(false)
	_active_player = null


func _has_active_interaction() -> bool:
	return _active_player != null or (_active_modal != null and is_instance_valid(_active_modal))


func _allows_grid_interaction(_player: Node) -> bool:
	return not _has_active_interaction()


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

	var hud: Node = _find_hud()

	if hud != null:
		return hud

	return get_tree().root


func _find_hud() -> Node:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null:
		return hud

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return null

	return current_scene.get_node_or_null("HUD")


func _stretch_window_to_parent(window: Control) -> void:
	if window == null:
		return

	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.anchor_left = 0.0
	window.anchor_top = 0.0
	window.anchor_right = 1.0
	window.anchor_bottom = 1.0
	window.offset_left = 0.0
	window.offset_top = 0.0
	window.offset_right = 0.0
	window.offset_bottom = 0.0
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_price_overrides() -> Dictionary:
	var resolved_overrides: Dictionary = price_overrides.duplicate(true)

	if is_equal_approx(catalog_price_multiplier, 1.0):
		return resolved_overrides

	for item_data in catalog:
		if item_data == null:
			continue

		var item_key: String = item_data.id.strip_edges()

		if item_key.is_empty():
			item_key = item_data.resource_path

		if item_key.is_empty():
			continue

		resolved_overrides[item_key] = int(round(float(item_data.get_effective_price()) * catalog_price_multiplier))

	return resolved_overrides


func _create_window_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.layer = 12

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	return layer


func _on_interaction_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_interaction_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _build_hygiene_comment_sequence(stage_id: StringName) -> Array[Dictionary]:
	match stage_id:
		&"hygiene_unsanitary":
			return HYGIENE_UNSANITARY_SEQUENCE.duplicate(true)
		&"hygiene_dirty":
			return HYGIENE_DIRTY_SEQUENCE.duplicate(true)
		_:
			return []


func _show_hud_notification(message: String) -> void:
	var hud: Node = _find_hud()

	if hud != null and hud.has_method("show_notification"):
		hud.show_notification(message)
