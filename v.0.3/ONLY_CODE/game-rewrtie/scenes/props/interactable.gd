class_name WorldInteractable
extends Node2D

signal interacted(player: Node, interaction_name: String, stat_delta: Dictionary)

@export var interaction_name: String = "interact"
@export var interaction_prompt_text: String = ""
@export var interaction_radius: float = 40.0
@export var stat_delta: Dictionary = {}

@onready var interaction_point: Marker2D = get_node_or_null("InteractionPoint") as Marker2D


func _ready() -> void:
	stat_delta = stat_delta.duplicate(true)
	add_to_group("interactable")


func can_interact(player_interaction_position: Vector2) -> bool:
	return player_interaction_position.distance_to(get_interaction_point()) <= interaction_radius


func get_interaction_point() -> Vector2:
	if interaction_point == null:
		return global_position

	return interaction_point.global_position


func get_interaction_prompt_text() -> String:
	if not interaction_prompt_text.is_empty():
		return interaction_prompt_text

	match interaction_name:
		"bed":
			return "\u0421\u043F\u0430\u0442\u044C"
		"computer":
			return "\u041A\u043E\u043C\u043F\u044C\u044E\u0442\u0435\u0440"
		"stove":
			return "\u0413\u043E\u0442\u043E\u0432\u0438\u0442\u044C"
		_:
			return "\u0412\u0437\u0430\u0438\u043C\u043E\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435"


func interact(player: Node) -> void:
	if player.has_method("apply_action_tick"):
		player.apply_action_tick(interaction_name, stat_delta)

	interacted.emit(player, interaction_name, stat_delta.duplicate(true))
	_after_interact(player)


func _after_interact(_player: Node) -> void:
	pass
