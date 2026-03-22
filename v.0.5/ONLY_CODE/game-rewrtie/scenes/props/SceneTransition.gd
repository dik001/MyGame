extends Node2D

@export_file("*.tscn") var target_scene: String = ""
@export var spawn_point_name: StringName = &""
@export var prompt_label_path: NodePath = NodePath("PressELabel")

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var interaction_point: Node2D = get_node_or_null("InteractionPoint") as Node2D
@onready var prompt_label: CanvasItem = get_node_or_null(prompt_label_path) as CanvasItem

var _player_inside := false


func _ready() -> void:
	if interaction_point == null:
		push_warning("SceneTransition is missing InteractionPoint.")

	if interaction_area == null:
		push_warning("SceneTransition is missing InteractionArea.")
		return

	_set_prompt_visible(false)

	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func _process(_delta: float) -> void:
	if not _player_inside or GameManager.is_transition_in_progress():
		return

	if not Input.is_action_just_pressed("interact"):
		return

	GameManager.change_scene(target_scene, spawn_point_name)


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


func _set_prompt_visible(is_visible: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = is_visible
