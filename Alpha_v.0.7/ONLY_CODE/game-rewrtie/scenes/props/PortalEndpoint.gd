class_name PortalEndpoint
extends WorldInteractable

const DEFAULT_SPAWN_FACING := Vector2.DOWN

@export var portal_id: StringName = &""
@export var spawn_facing: Vector2 = DEFAULT_SPAWN_FACING
@export var entry_anchor_path: NodePath = NodePath("EntryAnchor")


func get_portal_id() -> StringName:
	return portal_id


func get_spawn_position() -> Vector2:
	var entry_anchor := get_node_or_null(entry_anchor_path) as Node2D

	if entry_anchor != null:
		return entry_anchor.global_position

	return get_interaction_point()


func get_spawn_facing() -> Vector2:
	return _normalize_spawn_facing(spawn_facing)


func apply_spawn_to(player: Node2D) -> void:
	if player == null:
		return

	player.global_position = get_spawn_position()

	if player.has_method("set_facing_direction"):
		player.call("set_facing_direction", get_spawn_facing())


func _normalize_spawn_facing(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return DEFAULT_SPAWN_FACING

	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT

	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP
