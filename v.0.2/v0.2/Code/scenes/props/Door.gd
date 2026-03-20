extends WorldInteractable

@export var closed_texture: Texture2D
@export var open_texture: Texture2D
@export var is_open: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var blocking_body: StaticBody2D = get_node_or_null("StaticBody2D") as StaticBody2D
@onready var blocking_collision: CollisionShape2D = get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
@onready var interaction_point_side_a: Node2D = _get_interaction_point_node("InteractionPointSideA", "WorldInteractableSideA")
@onready var interaction_point_side_b: Node2D = _get_interaction_point_node("InteractionPointSideB", "WorldInteractableSideB")

var _has_cached_reference_position := false
var _cached_reference_position := Vector2.ZERO


func _ready() -> void:
	interaction_name = "door"
	stat_delta = {}
	_disable_legacy_side_interactables()
	_apply_state()
	super._ready()


func interact(player: Node) -> void:
	if is_open and _is_close_blocked():
		return

	is_open = not is_open
	_apply_state()
	interacted.emit(player, interaction_name, stat_delta.duplicate(true))


func can_interact(player_interaction_position: Vector2) -> bool:
	_cached_reference_position = player_interaction_position
	_has_cached_reference_position = true

	var nearest_point := _get_nearest_interaction_point(player_interaction_position)
	return player_interaction_position.distance_to(nearest_point) <= interaction_radius


func get_interaction_point() -> Vector2:
	return _get_nearest_interaction_point(_get_reference_position())


func _apply_state() -> void:
	if sprite != null:
		var target_texture := _get_current_texture()

		if target_texture != null:
			sprite.texture = target_texture
			sprite.offset = _get_texture_offset(target_texture)

	if blocking_collision != null:
		blocking_collision.disabled = is_open


func _get_current_texture() -> Texture2D:
	if is_open:
		if open_texture != null:
			return open_texture

		return closed_texture

	if closed_texture != null:
		return closed_texture

	return open_texture


func _get_texture_offset(target_texture: Texture2D) -> Vector2:
	if target_texture == null:
		return Vector2.ZERO

	var reference_texture := closed_texture

	if reference_texture == null:
		reference_texture = target_texture

	var size_difference := target_texture.get_size() - reference_texture.get_size()
	return Vector2(-size_difference.x * 0.5, size_difference.y * 0.5)


func _is_close_blocked() -> bool:
	if blocking_collision == null or blocking_collision.shape == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = blocking_collision.shape
	query.transform = blocking_collision.global_transform
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 0x7fffffff

	if blocking_body != null:
		query.exclude = [blocking_body.get_rid()]

	for result in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider := result.get("collider") as Node

		if collider != null and collider.is_in_group("player"):
			return true

	return false


func _get_nearest_interaction_point(reference_position: Vector2) -> Vector2:
	var has_side_a := interaction_point_side_a != null
	var has_side_b := interaction_point_side_b != null

	if has_side_a and has_side_b:
		var point_a := interaction_point_side_a.global_position
		var point_b := interaction_point_side_b.global_position

		if reference_position.distance_squared_to(point_a) <= reference_position.distance_squared_to(point_b):
			return point_a

		return point_b

	if has_side_a:
		return interaction_point_side_a.global_position

	if has_side_b:
		return interaction_point_side_b.global_position

	return global_position


func _get_reference_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player != null:
		var player_interaction_point := player.get_node_or_null("InteractionPoint") as Node2D

		if player_interaction_point != null:
			return player_interaction_point.global_position

		return player.global_position

	if _has_cached_reference_position:
		return _cached_reference_position

	return global_position


func _get_interaction_point_node(primary_name: String, fallback_name: String = "") -> Node2D:
	var node := get_node_or_null(primary_name) as Node2D

	if node != null:
		return node

	if not fallback_name.is_empty():
		return get_node_or_null(fallback_name) as Node2D

	return null


func _disable_legacy_side_interactables() -> void:
	for node in [interaction_point_side_a, interaction_point_side_b]:
		if node != null and node.is_in_group("interactable"):
			node.remove_from_group("interactable")
