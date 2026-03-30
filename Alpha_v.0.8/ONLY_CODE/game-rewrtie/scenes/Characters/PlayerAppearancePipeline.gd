extends RefCounted


const BODY_TEXTURE := preload("res://tilesets/Runa_TileSet.png")
const DIRT_TEXTURE := preload("res://tilesets/Runa_TileSet_dirt.png")
const BLOOD_TEXTURE_PATH := "res://tilesets/Runa_TileSet_blood.png"
const FRAME_SIZE := Vector2(64.0, 64.0)
const PREVIEW_ANIMATION: StringName = &"Idle_Front"
const LAYER_ORDER: Array[StringName] = [
	&"body",
	&"bottom",
	&"shoes",
	&"top",
	&"dirt",
	&"blood",
]
const LAYER_Z_INDEX := {
	&"body": 0,
	&"bottom": 1,
	&"shoes": 2,
	&"top": 3,
	&"dirt": 5,
	&"blood": 6,
}
# Every wearable sheet must match the body's shared 64x64 frame grid so slot layers can
# reuse the exact same animation/frame index without any per-item offset hacks.
const EQUIPMENT_SLOT_LAYERS: Array[StringName] = [
	&"top",
	&"bottom",
	&"shoes",
]
const ANIMATION_DEFINITIONS := {
	&"Idle_Back": {"speed": 1.0, "cells": [Vector2i(0, 3)]},
	&"Idle_Front": {"speed": 1.0, "cells": [Vector2i(0, 0)]},
	&"Idle_Left": {"speed": 1.0, "cells": [Vector2i(0, 1)]},
	&"Idle_Right": {"speed": 1.0, "cells": [Vector2i(2, 2)]},
	&"Walk_Back": {"speed": 7.0, "cells": [Vector2i(2, 3), Vector2i(0, 3), Vector2i(1, 3)]},
	&"Walk_Front": {"speed": 7.0, "cells": [Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 0)]},
	&"Walk_Left": {"speed": 7.0, "cells": [Vector2i(2, 1), Vector2i(0, 1), Vector2i(1, 1)]},
	&"Walk_Right": {"speed": 7.0, "cells": [Vector2i(1, 2), Vector2i(2, 2), Vector2i(0, 2)]},
}

var _sprite_frames_cache: Dictionary = {}
var _frame_texture_cache: Dictionary = {}
var _blood_texture_cache: Texture2D = null
var _blood_texture_checked := false
var _validated_texture_cache: Dictionary = {}
var _warning_cache: Dictionary = {}


func get_layer_order() -> Array[StringName]:
	return LAYER_ORDER.duplicate()


func get_overlay_layer_order() -> Array[StringName]:
	var overlay_layers: Array[StringName] = []

	for layer_name in LAYER_ORDER:
		if layer_name == &"body":
			continue

		overlay_layers.append(layer_name)

	return overlay_layers


func get_layer_z_index(layer_name: StringName) -> int:
	return int(LAYER_Z_INDEX.get(layer_name, 0))


func resolve_player_equipment(preferred_player_equipment: Node = null) -> Node:
	if is_instance_valid(preferred_player_equipment):
		return preferred_player_equipment

	return _get_root_singleton("PlayerEquipment")


func resolve_player_body_state(preferred_player_body_state: Node = null) -> Node:
	if is_instance_valid(preferred_player_body_state):
		return preferred_player_body_state

	return _get_root_singleton("PlayerBodyState")


func get_layer_texture(
	layer_name: StringName,
	preferred_player_equipment: Node = null,
	preferred_player_body_state: Node = null
) -> Texture2D:
	match layer_name:
		&"body":
			return BODY_TEXTURE
		&"dirt":
			return DIRT_TEXTURE if get_dirt_alpha(preferred_player_body_state) > 0.01 else null
		&"blood":
			if get_blood_alpha(preferred_player_body_state) <= 0.01:
				return null

			return get_blood_texture()
		_:
			return get_equipped_appearance_texture(layer_name, preferred_player_equipment)


func get_equipped_appearance_texture(
	slot_name: StringName,
	preferred_player_equipment: Node = null
) -> Texture2D:
	if not EQUIPMENT_SLOT_LAYERS.has(slot_name):
		return null

	var player_equipment := resolve_player_equipment(preferred_player_equipment)

	if player_equipment == null or not player_equipment.has_method("get_equipped_slot_data"):
		return null

	var slot_data := player_equipment.get_equipped_slot_data(slot_name) as InventorySlotData

	if slot_data == null or slot_data.is_empty() or slot_data.item_data == null:
		return null

	return slot_data.item_data.appearance_texture


func should_show_dirt(preferred_player_body_state: Node = null) -> bool:
	var player_body_state := resolve_player_body_state(preferred_player_body_state)
	return (
		player_body_state != null
		and player_body_state.has_method("should_show_dirt")
		and bool(player_body_state.should_show_dirt())
	)


func should_show_blood(preferred_player_body_state: Node = null) -> bool:
	var player_body_state := resolve_player_body_state(preferred_player_body_state)
	return (
		player_body_state != null
		and player_body_state.has_method("should_show_blood")
		and bool(player_body_state.should_show_blood())
	)


func get_layer_modulate(
	layer_name: StringName,
	preferred_player_body_state: Node = null
) -> Color:
	match layer_name:
		&"dirt":
			return Color(1.0, 1.0, 1.0, get_dirt_alpha(preferred_player_body_state))
		&"blood":
			return Color(1.0, 1.0, 1.0, get_blood_alpha(preferred_player_body_state))
		_:
			return Color(1.0, 1.0, 1.0, 1.0)


func get_dirt_alpha(preferred_player_body_state: Node = null) -> float:
	var player_body_state := resolve_player_body_state(preferred_player_body_state)

	if (
		player_body_state != null
		and player_body_state.has_method("get_dirt_visual_alpha")
	):
		return clampf(float(player_body_state.get_dirt_visual_alpha()), 0.0, 1.0)

	return 1.0 if should_show_dirt(player_body_state) else 0.0


func get_blood_alpha(preferred_player_body_state: Node = null) -> float:
	var player_body_state := resolve_player_body_state(preferred_player_body_state)

	if (
		player_body_state != null
		and player_body_state.has_method("get_blood_visual_alpha")
	):
		return clampf(float(player_body_state.get_blood_visual_alpha()), 0.0, 1.0)

	return 1.0 if should_show_blood(player_body_state) else 0.0


func get_blood_texture() -> Texture2D:
	if _blood_texture_checked:
		return _blood_texture_cache

	_blood_texture_checked = true

	if ResourceLoader.exists(BLOOD_TEXTURE_PATH):
		_blood_texture_cache = load(BLOOD_TEXTURE_PATH) as Texture2D

	return _blood_texture_cache


func get_sprite_frames(texture: Texture2D) -> SpriteFrames:
	if texture == null:
		return null

	if not validate_layer_texture(texture):
		return null

	var cache_key := _build_texture_cache_key(texture)

	if _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key] as SpriteFrames

	var sprite_frames := SpriteFrames.new()

	for animation_name in ANIMATION_DEFINITIONS.keys():
		var definition: Dictionary = ANIMATION_DEFINITIONS[animation_name]
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_loop(animation_name, true)
		sprite_frames.set_animation_speed(animation_name, float(definition.get("speed", 1.0)))

		for cell in definition.get("cells", []):
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = texture
			atlas_texture.region = Rect2(Vector2(cell) * FRAME_SIZE, FRAME_SIZE)
			sprite_frames.add_frame(animation_name, atlas_texture)

	_sprite_frames_cache[cache_key] = sprite_frames
	return sprite_frames


func get_frame_texture(
	texture: Texture2D,
	animation_name: StringName,
	frame_index: int,
	layer_name: StringName = &""
) -> Texture2D:
	if texture == null:
		return null

	if not validate_layer_texture(texture, layer_name):
		return null

	var frame_region := _get_frame_region(animation_name, frame_index)

	if frame_region == Rect2():
		return null

	var cache_key := "%s|%s|%d" % [
		_build_texture_cache_key(texture),
		String(animation_name),
		frame_index,
	]

	if _frame_texture_cache.has(cache_key):
		return _frame_texture_cache[cache_key] as Texture2D

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = frame_region
	_frame_texture_cache[cache_key] = atlas_texture
	return atlas_texture


func get_preview_texture(
	texture: Texture2D,
	animation_name: StringName = PREVIEW_ANIMATION,
	frame_index: int = 0
) -> Texture2D:
	return get_frame_texture(texture, animation_name, frame_index)


func validate_layer_texture(texture: Texture2D, layer_name: StringName = &"") -> bool:
	if texture == null:
		return false

	var cache_key := _build_texture_cache_key(texture)

	if _validated_texture_cache.has(cache_key):
		return bool(_validated_texture_cache[cache_key])

	var texture_size := texture.get_size()
	var frame_width := int(FRAME_SIZE.x)
	var frame_height := int(FRAME_SIZE.y)
	var width := int(round(texture_size.x))
	var height := int(round(texture_size.y))
	var is_valid := width > 0 and height > 0

	if is_valid and (width % frame_width != 0 or height % frame_height != 0):
		is_valid = false

	var columns := 0
	var rows := 0

	if is_valid:
		columns = width / frame_width
		rows = height / frame_height

		for animation_name in ANIMATION_DEFINITIONS.keys():
			var definition: Dictionary = ANIMATION_DEFINITIONS[animation_name]

			for cell_variant in definition.get("cells", []):
				if not (cell_variant is Vector2i):
					is_valid = false
					break

				var cell := cell_variant as Vector2i

				if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
					is_valid = false
					break

			if not is_valid:
				break

	_validated_texture_cache[cache_key] = is_valid

	if not is_valid:
		var minimum_size := get_minimum_sheet_size()
		var texture_label := texture.resource_path if not texture.resource_path.is_empty() else cache_key
		var layer_label := " for layer '%s'" % String(layer_name) if layer_name != &"" else ""
		_warn_once(
			"layout|%s" % cache_key,
			"Appearance texture%s is incompatible with the shared %s x %s frame grid. Texture '%s' has size %d x %d, expected a %d x %d-aligned sheet that covers every animation cell." % [
				layer_label,
				int(FRAME_SIZE.x),
				int(FRAME_SIZE.y),
				texture_label,
				width,
				height,
				int(minimum_size.x),
				int(minimum_size.y),
			]
		)

	return is_valid


func _get_frame_region(animation_name: StringName, frame_index: int) -> Rect2:
	var definition: Dictionary = ANIMATION_DEFINITIONS.get(animation_name, {})
	var cells: Array = definition.get("cells", [])

	if cells.is_empty():
		return Rect2()

	var resolved_frame_index := clampi(frame_index, 0, cells.size() - 1)
	var cell: Vector2i = cells[resolved_frame_index]
	return Rect2(Vector2(cell) * FRAME_SIZE, FRAME_SIZE)


func get_minimum_sheet_size() -> Vector2:
	var max_cell := Vector2i.ZERO

	for animation_name in ANIMATION_DEFINITIONS.keys():
		var definition: Dictionary = ANIMATION_DEFINITIONS[animation_name]

		for cell_variant in definition.get("cells", []):
			if not (cell_variant is Vector2i):
				continue

			var cell := cell_variant as Vector2i
			max_cell.x = maxi(max_cell.x, cell.x)
			max_cell.y = maxi(max_cell.y, cell.y)

	return Vector2(max_cell + Vector2i.ONE) * FRAME_SIZE


func _build_texture_cache_key(texture: Texture2D) -> String:
	if not texture.resource_path.is_empty():
		return texture.resource_path

	return str(texture.get_instance_id())


func _warn_once(cache_key: String, message: String) -> void:
	if _warning_cache.has(cache_key):
		return

	_warning_cache[cache_key] = true
	push_warning(message)


func _get_root_singleton(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree

	if tree == null or tree.root == null:
		return null

	return tree.root.get_node_or_null(node_name)
