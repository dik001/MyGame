extends WorldInteractable

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_path: NodePath

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D

var player_in_range := false


func _ready() -> void:
	interaction_name = "door"
	stat_delta = {}

	if interaction_prompt_text.is_empty():
		interaction_prompt_text = "Use door"

	super._ready()

	if interaction_area == null:
		push_warning("SceneTransitionInteractable is missing InteractionArea.")
		return

	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func can_interact(player_interaction_position: Vector2) -> bool:
	if interaction_area != null and not player_in_range:
		return false

	return super.can_interact(player_interaction_position)


func _after_interact(_player: Node) -> void:
	if target_scene_path.is_empty():
		push_warning("SceneTransitionInteractable target_scene_path is empty.")
		return

	if not ResourceLoader.exists(target_scene_path):
		push_warning("SceneTransitionInteractable could not find scene: %s" % target_scene_path)
		return

	var transition_state := get_node_or_null("/root/SceneTransitionState")

	if transition_state != null:
		if target_spawn_path.is_empty():
			transition_state.clear_pending_spawn()
		else:
			transition_state.set_pending_spawn(target_scene_path, target_spawn_path)

	get_tree().change_scene_to_file(target_scene_path)


func _on_interaction_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_interaction_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
