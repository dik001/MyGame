class_name WorldGrid
extends Node2D

const DEFAULT_CELL_SIZE := Vector2i(32, 32)
const DEFAULT_PLAYER_ACTION_PATTERN := &"current_or_front"

@export var cell_size: Vector2i = DEFAULT_CELL_SIZE
@export_range(0.01, 1.0, 0.01) var step_duration: float = 0.14
@export_range(0.01, 1.0, 0.01) var hold_repeat_initial_delay: float = 0.18
@export_range(0.01, 1.0, 0.01) var hold_repeat_interval: float = 0.10
@export var allow_diagonal_movement: bool = false
@export var block_cells_with_tile_collision: bool = true
@export var block_cells_with_physics_bodies: bool = true
@export var show_debug_overlay: bool = false
@export var debug_grid_color: Color = Color(1.0, 1.0, 1.0, 0.08)
@export var debug_blocked_color: Color = Color(0.92, 0.22, 0.22, 0.28)
@export var debug_actor_cell_color: Color = Color(0.18, 0.92, 0.42, 0.32)
@export var debug_target_cell_color: Color = Color(1.0, 0.86, 0.2, 0.30)
@export var debug_pattern_color: Color = Color(0.22, 0.86, 1.0, 0.26)
@export var debug_interaction_color: Color = Color(0.78, 0.43, 1.0, 0.30)

var _room_root: Node2D
var _floor_tilemap: TileMapLayer
var _tile_layers: Array[TileMapLayer] = []
var _registered_interactables: Array[WorldInteractable] = []
var _static_blocked_cells: Dictionary = {}
var _actor_cell_by_id: Dictionary = {}
var _grid_bounds_min: Vector2i = Vector2i.ZERO
var _grid_bounds_max: Vector2i = Vector2i.ZERO
var _has_grid_bounds: bool = false

var _debug_actor_cell: Vector2i = Vector2i.ZERO
var _debug_target_cell: Vector2i = Vector2i.ZERO
var _debug_has_target_cell: bool = false
var _debug_pattern_cells: Array[Vector2i] = []
var _debug_interaction_cells: Array[Vector2i] = []

var _pattern_definitions: Dictionary = {
	&"current": [Vector2i.ZERO],
	&"front_1": [Vector2i(0, 1)],
	&"current_or_front": [Vector2i.ZERO, Vector2i(0, 1)],
	&"wide_front": [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)],
	&"line_2": [Vector2i(0, 1), Vector2i(0, 2)],
	&"line_3": [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
}


func _ready() -> void:
	top_level = true
	z_index = 200
	if not is_in_group("world_grid"):
		add_to_group("world_grid")
	visible = show_debug_overlay


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		show_debug_overlay = not show_debug_overlay
		visible = show_debug_overlay
		queue_redraw()


func configure_for_room(room_root: Node2D, floor_tilemap: TileMapLayer) -> void:
	_room_root = room_root
	_floor_tilemap = floor_tilemap
	_tile_layers.clear()
	_registered_interactables.clear()
	_static_blocked_cells.clear()
	_actor_cell_by_id.clear()
	_has_grid_bounds = false
	_debug_pattern_cells.clear()
	_debug_interaction_cells.clear()
	_debug_has_target_cell = false

	if _room_root == null:
		queue_redraw()
		return

	_collect_tile_layers(_room_root)
	_collect_interactables(_room_root)

	if block_cells_with_tile_collision:
		_collect_tile_collision_cells()

	if block_cells_with_physics_bodies:
		_collect_collision_object_cells(_room_root)

	_collect_interactable_occupied_cells()

	visible = show_debug_overlay
	queue_redraw()


func world_to_cell(world_pos: Vector2) -> Vector2i:
	if _floor_tilemap != null:
		return _floor_tilemap.local_to_map(_floor_tilemap.to_local(world_pos))

	var half_cell: Vector2 = Vector2(cell_size) * 0.5
	return Vector2i(
		int(floor((world_pos.x + half_cell.x) / maxf(1.0, float(cell_size.x)))),
		int(floor((world_pos.y + half_cell.y) / maxf(1.0, float(cell_size.y))))
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	if _floor_tilemap != null:
		return _floor_tilemap.to_global(_floor_tilemap.map_to_local(cell))

	return Vector2(
		float(cell.x * cell_size.x) + (float(cell_size.x) * 0.5),
		float(cell.y * cell_size.y) + (float(cell_size.y) * 0.5)
	)


func can_enter(cell: Vector2i, actor: Node = null) -> bool:
	if _has_grid_bounds and not _is_cell_inside_bounds(cell):
		return false

	if _static_blocked_cells.has(_cell_key(cell)):
		return false

	var occupied_actor: Node = _get_actor_at_cell(cell)

	if occupied_actor != null and occupied_actor != actor:
		return false

	return true


func reserve_actor_cell(actor: Node, _from_cell: Vector2i, to_cell: Vector2i) -> void:
	if actor == null:
		return

	var actor_id: int = actor.get_instance_id()

	if _actor_cell_by_id.has(actor_id):
		_actor_cell_by_id.erase(actor_id)

	_actor_cell_by_id[actor_id] = to_cell
	_expand_bounds(to_cell)
	queue_redraw()


func clear_actor_cell(actor: Node) -> void:
	if actor == null:
		return

	var actor_id: int = actor.get_instance_id()

	if not _actor_cell_by_id.has(actor_id):
		return

	_actor_cell_by_id.erase(actor_id)
	queue_redraw()


func get_actor_cell(actor: Node) -> Vector2i:
	if actor == null:
		return Vector2i.ZERO

	return _actor_cell_by_id.get(actor.get_instance_id(), Vector2i.ZERO)


func find_interactable_for(
	actor_cell: Vector2i,
	facing: Vector2,
	actor: Node = null,
	pattern_id: StringName = DEFAULT_PLAYER_ACTION_PATTERN
) -> WorldInteractable:
	var action_cells: Array[Vector2i] = resolve_pattern(actor_cell, facing, pattern_id)
	var best_match: WorldInteractable = null
	var best_distance: float = INF
	_debug_interaction_cells.clear()

	for interactable in _registered_interactables:
		if interactable == null or not is_instance_valid(interactable):
			continue

		var interaction_cells: Array[Vector2i] = interactable.get_interaction_cells(self)

		if interaction_cells.is_empty():
			continue

		if not cells_overlap(action_cells, interaction_cells):
			continue

		if not interactable.can_interact_from_context(actor, actor_cell, facing, self, pattern_id):
			continue

		var anchor_cell: Vector2i = interactable.get_grid_anchor_cell(self)
		var distance: float = actor_cell.distance_squared_to(anchor_cell)

		if best_match == null or distance < best_distance:
			best_match = interactable
			best_distance = distance
			_debug_interaction_cells = interaction_cells.duplicate()

	return best_match


func resolve_pattern(origin_cell: Vector2i, facing: Vector2, pattern_id: StringName) -> Array[Vector2i]:
	var offsets_variant: Variant = _pattern_definitions.get(pattern_id, _pattern_definitions.get(&"current", []))
	var offsets: Array = offsets_variant if offsets_variant is Array else []
	var resolved_cells: Array[Vector2i] = []

	for raw_offset in offsets:
		if not (raw_offset is Vector2i):
			continue

		var rotated_offset: Vector2i = _rotate_offset_for_facing(raw_offset, facing)
		resolved_cells.append(origin_cell + rotated_offset)

	return resolved_cells


func cells_overlap(left: Array[Vector2i], right: Array[Vector2i]) -> bool:
	if left.is_empty() or right.is_empty():
		return false

	var lookup: Dictionary = {}

	for cell in left:
		lookup[_cell_key(cell)] = true

	for cell in right:
		if lookup.has(_cell_key(cell)):
			return true

	return false


func set_debug_context(
	actor_cell: Vector2i,
	target_cell: Vector2i,
	has_target_cell: bool,
	pattern_cells: Array[Vector2i],
	interaction_cells: Array[Vector2i]
) -> void:
	_debug_actor_cell = actor_cell
	_debug_target_cell = target_cell
	_debug_has_target_cell = has_target_cell
	_debug_pattern_cells = pattern_cells.duplicate()
	_debug_interaction_cells = interaction_cells.duplicate()
	visible = show_debug_overlay
	queue_redraw()


func get_player_action_pattern_id() -> StringName:
	return DEFAULT_PLAYER_ACTION_PATTERN


func get_registered_interactables() -> Array[WorldInteractable]:
	return _registered_interactables.duplicate()


func get_collision_object_cells(collision_object: CollisionObject2D) -> Array[Vector2i]:
	return _get_collision_object_cells(collision_object)


func _draw() -> void:
	if not show_debug_overlay or not _has_grid_bounds:
		return

	for y in range(_grid_bounds_min.y, _grid_bounds_max.y + 1):
		for x in range(_grid_bounds_min.x, _grid_bounds_max.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			var cell_rect: Rect2 = _cell_to_rect(cell)
			draw_rect(cell_rect, debug_grid_color, false, 1.0)

			if _static_blocked_cells.has(_cell_key(cell)):
				draw_rect(cell_rect, debug_blocked_color, true)

	for cell_variant in _actor_cell_by_id.values():
		if not (cell_variant is Vector2i):
			continue

		draw_rect(_cell_to_rect(cell_variant as Vector2i), debug_actor_cell_color, true)

	for cell in _debug_pattern_cells:
		draw_rect(_cell_to_rect(cell), debug_pattern_color, true)

	for cell in _debug_interaction_cells:
		draw_rect(_cell_to_rect(cell), debug_interaction_color, true)

	draw_rect(_cell_to_rect(_debug_actor_cell), debug_actor_cell_color, true)

	if _debug_has_target_cell:
		draw_rect(_cell_to_rect(_debug_target_cell), debug_target_cell_color, true)


func _collect_tile_layers(root_node: Node) -> void:
	if root_node is TileMapLayer:
		_tile_layers.append(root_node as TileMapLayer)

	for child in root_node.get_children():
		_collect_tile_layers(child)


func _collect_interactables(root_node: Node) -> void:
	var interactable: WorldInteractable = root_node as WorldInteractable

	if interactable != null and interactable.has_method("get_interaction_cells") and interactable.has_method("can_interact_from_context"):
		_registered_interactables.append(interactable)

	for child in root_node.get_children():
		_collect_interactables(child)


func _collect_tile_collision_cells() -> void:
	for tile_layer in _tile_layers:
		var physics_layers_count: int = _get_tile_physics_layers_count(tile_layer)

		for cell in tile_layer.get_used_cells():
			var tile_data: TileData = tile_layer.get_cell_tile_data(cell)

			if tile_data == null:
				_expand_bounds(cell)
				continue

			var collision_count: int = _get_tile_collision_polygon_count(tile_data, physics_layers_count)

			if collision_count > 0:
				_mark_static_cell(cell, {"kind": "tile", "source": tile_layer})
			else:
				_expand_bounds(cell)


func _collect_collision_object_cells(root_node: Node) -> void:
	if root_node is CollisionObject2D:
		var collision_object: CollisionObject2D = root_node as CollisionObject2D

		if collision_object is Area2D:
			pass
		else:
			for cell in _get_collision_object_cells(collision_object):
				_mark_static_cell(cell, {"kind": "body", "source": collision_object})

	for child in root_node.get_children():
		_collect_collision_object_cells(child)


func _collect_interactable_occupied_cells() -> void:
	for interactable in _registered_interactables:
		if interactable == null or not is_instance_valid(interactable):
			continue

		var occupied_cells: Array[Vector2i] = interactable.get_occupied_cells(self)

		for cell in occupied_cells:
			_mark_static_cell(cell, {"kind": "interactable", "source": interactable})


func _get_collision_object_cells(collision_object: CollisionObject2D) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	if collision_object == null:
		return cells

	var seen: Dictionary = {}

	for collision_shape in _find_collision_shapes(collision_object):
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue

		var world_rect: Rect2 = _get_collision_shape_world_rect(collision_shape)

		if world_rect.size == Vector2.ZERO:
			continue

		for cell in _get_cells_overlapping_rect(world_rect):
			var key: String = _cell_key(cell)

			if seen.has(key):
				continue

			seen[key] = true
			cells.append(cell)

	return cells


func _find_collision_shapes(root_node: Node) -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []

	for child in root_node.get_children():
		if child is CollisionShape2D:
			result.append(child as CollisionShape2D)
			continue

		if child is CollisionObject2D:
			continue

		result.append_array(_find_collision_shapes(child))

	return result


func _get_collision_shape_world_rect(collision_shape: CollisionShape2D) -> Rect2:
	var shape: Shape2D = collision_shape.shape
	var local_points: Array = []

	if shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape as RectangleShape2D
		var extents: Vector2 = rectangle.size * 0.5
		local_points = [
			Vector2(-extents.x, -extents.y),
			Vector2(extents.x, -extents.y),
			Vector2(extents.x, extents.y),
			Vector2(-extents.x, extents.y),
		]
	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		var half_width: float = capsule.radius
		var half_height: float = capsule.height * 0.5
		local_points = [
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height),
		]
	elif shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		local_points = [
			Vector2(-circle.radius, -circle.radius),
			Vector2(circle.radius, -circle.radius),
			Vector2(circle.radius, circle.radius),
			Vector2(-circle.radius, circle.radius),
		]
	elif shape is ConvexPolygonShape2D:
		local_points = (shape as ConvexPolygonShape2D).points
	elif shape is ConcavePolygonShape2D:
		local_points = (shape as ConcavePolygonShape2D).segments
	else:
		return Rect2()

	if local_points.is_empty():
		return Rect2()

	var shape_transform: Transform2D = collision_shape.global_transform
	var min_point: Vector2 = shape_transform * local_points[0]
	var max_point: Vector2 = min_point

	for local_point in local_points:
		var world_point: Vector2 = shape_transform * local_point
		min_point.x = minf(min_point.x, world_point.x)
		min_point.y = minf(min_point.y, world_point.y)
		max_point.x = maxf(max_point.x, world_point.x)
		max_point.y = maxf(max_point.y, world_point.y)

	return Rect2(min_point, max_point - min_point)


func _get_cells_overlapping_rect(world_rect: Rect2) -> Array[Vector2i]:
	var top_left: Vector2i = world_to_cell(world_rect.position)
	var bottom_right: Vector2i = world_to_cell(world_rect.end - Vector2(0.01, 0.01))
	var cells: Array[Vector2i] = []

	for y in range(min(top_left.y, bottom_right.y), max(top_left.y, bottom_right.y) + 1):
		for x in range(min(top_left.x, bottom_right.x), max(top_left.x, bottom_right.x) + 1):
			cells.append(Vector2i(x, y))

	return cells


func _get_tile_physics_layers_count(tile_layer: TileMapLayer) -> int:
	if tile_layer == null or tile_layer.tile_set == null:
		return 0

	if tile_layer.tile_set.has_method("get_physics_layers_count"):
		return int(tile_layer.tile_set.call("get_physics_layers_count"))

	return 0


func _get_tile_collision_polygon_count(tile_data: TileData, physics_layers_count: int) -> int:
	if tile_data == null or physics_layers_count <= 0:
		return 0

	var collision_count := 0

	if tile_data.has_method("get_collision_polygons_count"):
		for layer_index in range(physics_layers_count):
			collision_count += int(tile_data.call("get_collision_polygons_count", layer_index))

	return collision_count


func _mark_static_cell(cell: Vector2i, metadata: Dictionary) -> void:
	_static_blocked_cells[_cell_key(cell)] = metadata.duplicate(true)
	_expand_bounds(cell)


func _expand_bounds(cell: Vector2i) -> void:
	if not _has_grid_bounds:
		_grid_bounds_min = cell
		_grid_bounds_max = cell
		_has_grid_bounds = true
		return

	_grid_bounds_min.x = mini(_grid_bounds_min.x, cell.x)
	_grid_bounds_min.y = mini(_grid_bounds_min.y, cell.y)
	_grid_bounds_max.x = maxi(_grid_bounds_max.x, cell.x)
	_grid_bounds_max.y = maxi(_grid_bounds_max.y, cell.y)


func _is_cell_inside_bounds(cell: Vector2i) -> bool:
	return cell.x >= _grid_bounds_min.x \
		and cell.x <= _grid_bounds_max.x \
		and cell.y >= _grid_bounds_min.y \
		and cell.y <= _grid_bounds_max.y


func _get_actor_at_cell(cell: Vector2i) -> Node:
	for actor_id in _actor_cell_by_id.keys():
		var actor_cell: Vector2i = _actor_cell_by_id.get(actor_id, Vector2i.ZERO)

		if actor_cell == cell:
			return instance_from_id(int(actor_id)) as Node

	return null


func _cell_key(cell: Vector2i) -> String:
	return "%s:%s" % [cell.x, cell.y]


func _rotate_offset_for_facing(offset: Vector2i, facing: Vector2) -> Vector2i:
	if facing == Vector2.ZERO:
		return offset

	var cardinal: Vector2 = _normalize_direction(facing)

	if cardinal == Vector2.RIGHT:
		return Vector2i(offset.y, -offset.x)

	if cardinal == Vector2.LEFT:
		return Vector2i(-offset.y, offset.x)

	if cardinal == Vector2.UP:
		return Vector2i(-offset.x, -offset.y)

	return offset


func _normalize_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.DOWN

	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT

	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP


func _cell_to_rect(cell: Vector2i) -> Rect2:
	var center: Vector2 = cell_to_world(cell)
	var half_size: Vector2 = Vector2(cell_size) * 0.5
	return Rect2(center - half_size, Vector2(cell_size))
