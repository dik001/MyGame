extends WorldInteractable

const DESKTOP_SCENE_PATH := "res://scenes/minigames/computer_desktop.tscn"

@onready var interaction_area: Area2D = $InteractionArea

var player_in_range := false


func _ready() -> void:
	interaction_name = "computer"
	stat_delta = {}
	super._ready()

	if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)


func can_interact(player_interaction_position: Vector2) -> bool:
	if not player_in_range:
		return false

	return super.can_interact(player_interaction_position)


func _after_interact(_player: Node) -> void:
	get_tree().change_scene_to_file(DESKTOP_SCENE_PATH)


func _on_interaction_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_interaction_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
