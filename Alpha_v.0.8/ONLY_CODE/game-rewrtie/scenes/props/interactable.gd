class_name WorldInteractable
extends Node2D

signal interacted(player: Node, interaction_name: String, stat_delta: Dictionary)

const DEFAULT_INTERACTION_PROMPT_TEXT := "ВЗАИМОДЕЙСТВОВАТЬ"

@export var interaction_name: String = "interact"
@export var interaction_prompt_text: String = ""
@export var interaction_radius: float = 40.0
@export var stat_delta: Dictionary = {}
@export var grid_anchor_offset: Vector2 = Vector2.ZERO
@export var grid_occupied_pattern_id: StringName = &"auto"
@export var grid_interaction_pattern_id: StringName = &"occupied_ring"
@export var grid_occupied_probe_points: Array[Vector2] = []
@export var grid_interaction_probe_points: Array[Vector2] = []

@onready var interaction_point: Marker2D = get_node_or_null("InteractionPoint") as Marker2D


func _ready() -> void:
	stat_delta = stat_delta.duplicate(true)
	add_to_group("interactable")


func can_interact(player_interaction_position: Vector2) -> bool:
	return player_interaction_position.distance_to(get_interaction_point()) <= interaction_radius


func can_interact_from_context(
	player: Node,
	_actor_cell: Vector2i,
	_facing: Vector2,
	_world_grid,
	_pattern_id: StringName = &""
) -> bool:
	return _allows_grid_interaction(player)


func get_interaction_point() -> Vector2:
	if interaction_point == null:
		return global_position

	return interaction_point.global_position


func get_interaction_prompt_text() -> String:
	if not interaction_prompt_text.is_empty():
		return interaction_prompt_text

	match interaction_name:
		"bed":
			return "СПАТЬ"
		"stove":
			return "ГОТОВИТЬ"
		_:
			return DEFAULT_INTERACTION_PROMPT_TEXT


func get_grid_anchor_cell(world_grid) -> Vector2i:
	if world_grid == null:
		return Vector2i.ZERO

	return world_grid.world_to_cell(get_grid_anchor_world_position())


func get_interaction_cells(world_grid) -> Array[Vector2i]:
	if world_grid == null:
		return []

	var anchor_cell: Vector2i = get_grid_anchor_cell(world_grid)

	match grid_interaction_pattern_id:
		&"none":
			return []
		&"probes":
			return _get_cells_from_probe_points(world_grid, grid_interaction_probe_points)
		&"occupied":
			return get_occupied_cells(world_grid)
		&"occupied_ring", &"ring":
			return _get_interaction_ring_cells(world_grid)
		&"cross":
			return [
				anchor_cell,
				anchor_cell + Vector2i.LEFT,
				anchor_cell + Vector2i.RIGHT,
				anchor_cell + Vector2i.UP,
				anchor_cell + Vector2i.DOWN,
			]
		_:
			return [anchor_cell]


func get_occupied_cells(world_grid) -> Array[Vector2i]:
	if world_grid == null:
		return []

	if not grid_occupied_probe_points.is_empty():
		return _get_cells_from_probe_points(world_grid, grid_occupied_probe_points)

	match grid_occupied_pattern_id:
		&"none":
			return []
		&"anchor":
			return [get_grid_anchor_cell(world_grid)]
		&"cross":
			var anchor_cell: Vector2i = get_grid_anchor_cell(world_grid)
			return [
				anchor_cell,
				anchor_cell + Vector2i.LEFT,
				anchor_cell + Vector2i.RIGHT,
				anchor_cell + Vector2i.UP,
				anchor_cell + Vector2i.DOWN,
			]
		_:
			return _get_blocking_cells_from_physics(world_grid)


func get_grid_anchor_world_position() -> Vector2:
	return get_interaction_point() + grid_anchor_offset


func interact(player: Node) -> void:
	if player.has_method("apply_action_tick"):
		player.apply_action_tick(interaction_name, stat_delta)

	interacted.emit(player, interaction_name, stat_delta.duplicate(true))
	_after_interact(player)


func _after_interact(_player: Node) -> void:
	pass


func _allows_grid_interaction(_player: Node) -> bool:
	return true


func _get_cells_from_probe_points(world_grid, probe_points: Array[Vector2]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}

	for probe_point in probe_points:
		var world_point: Vector2 = to_global(probe_point)
		var cell: Vector2i = world_grid.world_to_cell(world_point)
		var key := "%s:%s" % [cell.x, cell.y]

		if seen.has(key):
			continue

		seen[key] = true
		cells.append(cell)

	return cells


func _get_interaction_ring_cells(world_grid) -> Array[Vector2i]:
	var occupied_cells: Array[Vector2i] = get_occupied_cells(world_grid)

	if occupied_cells.is_empty():
		occupied_cells = [get_grid_anchor_cell(world_grid)]

	var occupied_lookup: Dictionary = {}
	var ring_cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	var cardinal_offsets: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]

	for occupied_cell in occupied_cells:
		occupied_lookup["%s:%s" % [occupied_cell.x, occupied_cell.y]] = true

	for occupied_cell in occupied_cells:
		for offset in cardinal_offsets:
			var ring_cell: Vector2i = occupied_cell + offset
			var key := "%s:%s" % [ring_cell.x, ring_cell.y]

			if occupied_lookup.has(key) or seen.has(key):
				continue

			seen[key] = true
			ring_cells.append(ring_cell)

	return ring_cells


func _get_blocking_cells_from_physics(world_grid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}

	for body in _find_blocking_collision_objects(self):
		if world_grid == null:
			continue

		for cell in world_grid.get_collision_object_cells(body):
			var key := "%s:%s" % [cell.x, cell.y]

			if seen.has(key):
				continue

			seen[key] = true
			cells.append(cell)

	return cells


func _find_blocking_collision_objects(root_node: Node) -> Array[CollisionObject2D]:
	var result: Array[CollisionObject2D] = []

	for child in root_node.get_children():
		if child is StaticBody2D or child is CharacterBody2D:
			result.append(child as CollisionObject2D)
			continue

		if child is Area2D:
			continue

		result.append_array(_find_blocking_collision_objects(child))

	return result
