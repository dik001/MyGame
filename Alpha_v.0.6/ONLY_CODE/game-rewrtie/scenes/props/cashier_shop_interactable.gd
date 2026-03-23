extends WorldInteractable

const SHOP_WINDOW_SCENE := preload("res://scenes/ui/shop_window.tscn")
const DEFAULT_WINDOW_TITLE := "\u041a\u0430\u0441\u0441\u0430"
const DEFAULT_WINDOW_SUBTITLE := "\u0422\u0435 \u0436\u0435 \u0442\u043e\u0432\u0430\u0440\u044b, \u043d\u043e \u0434\u0435\u0448\u0435\u0432\u043b\u0435. \u041f\u043e\u043a\u0443\u043f\u043a\u0430 \u0441\u0440\u0430\u0437\u0443 \u043f\u043e\u043f\u0430\u0434\u0430\u0435\u0442 \u0432 \u0438\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u044c."

@export var catalog: Array[ItemData] = []
@export var window_title_text: String = DEFAULT_WINDOW_TITLE
@export_multiline var window_subtitle_text: String = DEFAULT_WINDOW_SUBTITLE
@export var price_overrides: Dictionary = {}

@onready var interaction_area: Area2D = get_node_or_null("../Area2D") as Area2D

var _active_window: ShopWindow
var _active_window_layer: CanvasLayer
var _active_player: Node
var _player_in_range: bool = false


func _ready() -> void:
	interaction_name = "cashier"
	interaction_prompt_text = "\u041a\u0430\u0441\u0441\u0430"
	stat_delta = {}
	super._ready()

	if interaction_area == null:
		return

	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func can_interact(player_interaction_position: Vector2) -> bool:
	if interaction_area != null and not _player_in_range:
		return false

	return super.can_interact(player_interaction_position)


func interact(player: Node) -> void:
	if _active_window != null and is_instance_valid(_active_window):
		return

	_active_player = player
	interacted.emit(player, interaction_name, {})
	_set_modal_state(true)
	_open_window()


func _open_window() -> void:
	_active_window = SHOP_WINDOW_SCENE.instantiate() as ShopWindow

	if _active_window == null:
		push_warning("Cashier could not instantiate ShopWindow.")
		_finish_close()
		return

	_active_window.catalog = catalog.duplicate()
	_active_window.use_delivery = false
	_active_window.set_window_texts(window_title_text, window_subtitle_text)
	_active_window.set_price_overrides(price_overrides)
	_active_window.close_requested.connect(_close_window)
	_active_window.tree_exited.connect(_on_window_tree_exited)

	var ui_parent: Node = _get_ui_parent()

	if ui_parent == null:
		push_warning("Cashier could not find a UI parent for ShopWindow.")
		_active_window.queue_free()
		_active_window = null
		_finish_close()
		return

	_active_window_layer = _create_window_layer()

	if _active_window_layer == null:
		push_warning("Cashier could not create a window layer for ShopWindow.")
		_active_window.queue_free()
		_active_window = null
		_finish_close()
		return

	ui_parent.add_child(_active_window_layer)

	var window_root: Control = _active_window_layer.get_child(0) as Control

	if window_root == null:
		push_warning("Cashier window layer is missing its root Control.")
		_active_window_layer.queue_free()
		_active_window_layer = null
		_active_window.queue_free()
		_active_window = null
		_finish_close()
		return

	window_root.add_child(_active_window)
	_stretch_window_to_parent(_active_window)
	_active_window.open_window()


func _close_window() -> void:
	var window: ShopWindow = _active_window
	var window_layer: CanvasLayer = _active_window_layer
	_active_window = null
	_active_window_layer = null

	if window != null and is_instance_valid(window):
		if window.tree_exited.is_connected(_on_window_tree_exited):
			window.tree_exited.disconnect(_on_window_tree_exited)

	if window_layer != null and is_instance_valid(window_layer):
		window_layer.queue_free()
	elif window != null and is_instance_valid(window):
		window.queue_free()

	_finish_close()


func _on_window_tree_exited() -> void:
	_active_window = null
	_active_window_layer = null
	_finish_close()


func _finish_close() -> void:
	_set_modal_state(false)
	_active_player = null


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
