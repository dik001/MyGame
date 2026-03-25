class_name LocationPortal
extends PortalEndpoint

const DOOR_INTERACTION_PROMPT_TEXT := "ВОЙТИ"

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_portal_id: StringName = &""
@export var prompt_label_path: NodePath = NodePath("PressELabel")
@export var interaction_area_path: NodePath = NodePath("InteractionArea")

@onready var interaction_area: Area2D = get_node_or_null(interaction_area_path) as Area2D
@onready var prompt_label: CanvasItem = get_node_or_null(prompt_label_path) as CanvasItem

var _player_inside := false


func _ready() -> void:
	interaction_name = "door"
	interaction_prompt_text = DOOR_INTERACTION_PROMPT_TEXT
	stat_delta = {}
	super._ready()

	if interaction_point == null:
		push_warning("LocationPortal is missing InteractionPoint: %s" % get_path())

	if interaction_area == null:
		push_warning("LocationPortal is missing InteractionArea: %s" % get_path())
		return

	_configure_prompt_label()
	_set_prompt_visible(false)

	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func can_interact(_player_interaction_position: Vector2) -> bool:
	var game_manager := _get_game_manager()

	if game_manager == null:
		return false

	if not _player_inside or game_manager.is_transition_in_progress():
		return false

	return true


func _after_interact(_player: Node) -> void:
	var game_manager := _get_game_manager()

	if game_manager == null:
		return

	if target_scene_path.is_empty():
		push_warning("LocationPortal target_scene_path is empty: %s" % get_path())
		return

	if game_manager.is_transition_in_progress():
		return

	game_manager.change_scene(target_scene_path, target_portal_id)


func _on_interaction_area_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = true
	_set_prompt_visible(true)


func _on_interaction_area_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = false
	_set_prompt_visible(false)


func _set_prompt_visible(should_show: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = should_show


func _configure_prompt_label() -> void:
	if prompt_label == null:
		return

	var prompt_text := "%s - %s" % [_resolve_interact_key_text(), DOOR_INTERACTION_PROMPT_TEXT]

	if prompt_label is Label:
		(prompt_label as Label).text = prompt_text
		return

	if prompt_label.has_method("set_text"):
		prompt_label.call("set_text", prompt_text)


func _resolve_interact_key_text() -> String:
	for event in InputMap.action_get_events("interact"):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		var keycode := key_event.physical_keycode

		if keycode == 0:
			keycode = key_event.keycode

		var key_text := OS.get_keycode_string(keycode)

		if not key_text.is_empty():
			return key_text.to_upper()

	return "E"


func _get_game_manager() -> Node:
	return get_tree().root.get_node_or_null("GameManager")
