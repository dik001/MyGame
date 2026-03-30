class_name SceneStartPoint
extends Marker2D

const DEFAULT_SPAWN_FACING := Vector2.DOWN

@export var spawn_facing: Vector2 = DEFAULT_SPAWN_FACING


func get_spawn_position() -> Vector2:
	return global_position


func get_spawn_facing() -> Vector2:
	if spawn_facing == Vector2.ZERO:
		return DEFAULT_SPAWN_FACING

	if absf(spawn_facing.x) > absf(spawn_facing.y):
		return Vector2.RIGHT if spawn_facing.x > 0.0 else Vector2.LEFT

	return Vector2.DOWN if spawn_facing.y > 0.0 else Vector2.UP
