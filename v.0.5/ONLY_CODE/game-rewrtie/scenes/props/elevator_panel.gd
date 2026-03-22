extends WorldInteractable

const DEFAULT_APARTMENT_FLOOR_SCENE := "res://scenes/rooms/enterance.tscn"
const DEFAULT_STREET_SCENE := "res://scenes/rooms/town.tscn"
const GAME_THEME := preload("res://resources/ui/game_theme.tres")

@export_file("*.tscn") var apartment_floor_scene: String = DEFAULT_APARTMENT_FLOOR_SCENE
@export var apartment_floor_spawn_name: StringName = &"from_elevator"
@export_file("*.tscn") var street_scene: String = DEFAULT_STREET_SCENE
@export var street_spawn_name: StringName = &"from_elevator"

@onready var interaction_area: Area2D = $InteractionArea

var _active_menu: CanvasLayer
var _active_player: Node
var _player_in_range := false


func _ready() -> void:
	interaction_name = "elevator_panel"
	interaction_prompt_text = "Панель лифта"
	stat_delta = {}
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()

	if interaction_area == null:
		push_warning("ElevatorPanel is missing InteractionArea.")
		return

	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func can_interact(player_interaction_position: Vector2) -> bool:
	if _active_menu != null or not _player_in_range:
		return false

	return super.can_interact(player_interaction_position)


func _after_interact(player: Node) -> void:
	if _active_menu != null:
		return

	_active_player = player
	_set_modal_state(true)
	_open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _active_menu == null:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_close_menu()


func _open_menu() -> void:
	_active_menu = _build_menu()

	if _active_menu == null:
		_set_modal_state(false)
		_active_player = null
		return

	_active_menu.tree_exited.connect(_on_menu_tree_exited)
	_get_ui_parent().add_child(_active_menu)


func _close_menu() -> void:
	var menu := _active_menu
	_active_menu = null

	if menu != null and is_instance_valid(menu):
		if menu.tree_exited.is_connected(_on_menu_tree_exited):
			menu.tree_exited.disconnect(_on_menu_tree_exited)

		menu.queue_free()

	_finish_close()


func _on_menu_tree_exited() -> void:
	_active_menu = null
	_finish_close()


func _finish_close() -> void:
	_set_modal_state(false)
	_active_player = null


func _on_apartment_floor_pressed() -> void:
	_request_transition(apartment_floor_scene, apartment_floor_spawn_name)


func _on_street_pressed() -> void:
	_request_transition(street_scene, street_spawn_name)


func _request_transition(scene_path: String, spawn_name: StringName) -> void:
	_close_menu()
	GameManager.change_scene(scene_path, spawn_name)


func _on_interaction_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true


func _on_interaction_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false


func _set_modal_state(is_active: bool) -> void:
	if _active_player != null and _active_player.has_method("set_input_locked"):
		_active_player.set_input_locked(is_active)

	var hud := _find_hud()

	if hud != null and hud.has_method("set_clock_paused"):
		hud.set_clock_paused(is_active)


func _build_menu() -> CanvasLayer:
	var menu_layer := CanvasLayer.new()
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_layer.layer = 12

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.theme = GAME_THEME
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Лифт"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Куда поехать?"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	content.add_child(subtitle)

	var apartment_button := Button.new()
	apartment_button.text = "Этаж апартаментов"
	apartment_button.custom_minimum_size = Vector2(0.0, 48.0)
	apartment_button.pressed.connect(_on_apartment_floor_pressed)
	content.add_child(apartment_button)

	var street_button := Button.new()
	street_button.text = "На улицу"
	street_button.custom_minimum_size = Vector2(0.0, 48.0)
	street_button.pressed.connect(_on_street_pressed)
	content.add_child(street_button)

	var cancel_button := Button.new()
	cancel_button.text = "Отмена"
	cancel_button.custom_minimum_size = Vector2(0.0, 44.0)
	cancel_button.pressed.connect(_close_menu)
	content.add_child(cancel_button)

	apartment_button.call_deferred("grab_focus")
	return menu_layer


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0823529, 0.0980392, 0.145098, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.713726, 0.784314, 0.901961, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


func _get_ui_parent() -> Node:
	var current_scene := get_tree().current_scene

	if current_scene != null:
		return current_scene

	return get_tree().root


func _find_hud() -> Node:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null:
		return hud

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return null

	return current_scene.get_node_or_null("HUD")
