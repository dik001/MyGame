class_name ATMInteractable
extends WorldInteractable

const ATM_WINDOW_SCENE := preload("res://scenes/ui/atm_window.tscn")

@onready var interaction_area: Area2D = get_node_or_null("Area2D") as Area2D

var _active_window: ATMWindow
var _active_window_layer: CanvasLayer
var _active_player: Node
var _player_in_range: bool = false


func _ready() -> void:
	interaction_name = "atm"
	interaction_prompt_text = WorldInteractable.DEFAULT_INTERACTION_PROMPT_TEXT
	interaction_radius = 48.0
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
	_active_window = ATM_WINDOW_SCENE.instantiate() as ATMWindow

	if _active_window == null:
		push_warning("ATM could not instantiate ATMWindow.")
		_finish_close()
		return

	_active_window.close_requested.connect(_close_window)
	_active_window.tree_exited.connect(_on_window_tree_exited)

	var ui_parent: Node = _get_ui_parent()

	if ui_parent == null:
		push_warning("ATM could not find a UI parent for ATMWindow.")
		_active_window.queue_free()
		_active_window = null
		_finish_close()
		return

	_active_window_layer = _create_window_layer()

	if _active_window_layer == null:
		push_warning("ATM could not create a window layer for ATMWindow.")
		_active_window.queue_free()
		_active_window = null
		_finish_close()
		return

	ui_parent.add_child(_active_window_layer)

	var window_root: Control = _active_window_layer.get_child(0) as Control

	if window_root == null:
		push_warning("ATM window layer is missing its root Control.")
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
	var window: ATMWindow = _active_window
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
