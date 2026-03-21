extends Area2D

var is_consumed := false


func _ready() -> void:
	if not is_in_group("slithario_food"):
		add_to_group("slithario_food")


func setup_at(world_position: Vector2) -> void:
	global_position = world_position


func consume() -> bool:
	if is_consumed:
		return false

	is_consumed = true
	queue_free()
	return true
