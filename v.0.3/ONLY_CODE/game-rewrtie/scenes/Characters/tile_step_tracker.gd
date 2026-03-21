class_name TileStepTracker
extends Node

signal tile_changed(previous_tile: Vector2i, current_tile: Vector2i)

var _tracked_node: Node2D
var _tile_map_layer: TileMapLayer
var _current_tile: Vector2i
var _has_current_tile := false
var _sample_offset := Vector2.ZERO


func setup(tracked_node: Node2D, tile_map_layer: TileMapLayer, sample_offset: Vector2 = Vector2.ZERO) -> void:
	_tracked_node = tracked_node
	_tile_map_layer = tile_map_layer
	_sample_offset = sample_offset
	reset()


func reset() -> void:
	if _tracked_node == null or _tile_map_layer == null:
		_has_current_tile = false
		return

	_current_tile = get_current_tile()
	_has_current_tile = true


func update_tile() -> void:
	if _tracked_node == null or _tile_map_layer == null:
		return

	var next_tile := get_current_tile()

	if not _has_current_tile:
		_current_tile = next_tile
		_has_current_tile = true
		return

	if next_tile == _current_tile:
		return

	var previous_tile := _current_tile
	_current_tile = next_tile
	tile_changed.emit(previous_tile, next_tile)


func get_current_tile() -> Vector2i:
	var sample_position := _tracked_node.global_position + _sample_offset
	return _tile_map_layer.local_to_map(_tile_map_layer.to_local(sample_position))
