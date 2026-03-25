class_name SaveDataUtils
extends RefCounted


static func vector2_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


static func dict_to_vector2(raw_value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if raw_value is Dictionary:
		var value: Dictionary = raw_value
		return Vector2(
			float(value.get("x", fallback.x)),
			float(value.get("y", fallback.y))
		)

	return fallback


static func string_name_to_string(value: StringName) -> String:
	return String(value)


static func sanitize_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return (raw_value as Dictionary).duplicate(true)

	return {}


static func sanitize_array(raw_value: Variant) -> Array:
	if raw_value is Array:
		return (raw_value as Array).duplicate(true)

	return []


static func texture_to_path(texture: Texture2D) -> String:
	if texture == null:
		return ""

	return String(texture.resource_path)


static func load_texture_from_path(path: String) -> Texture2D:
	var resolved_path := path.strip_edges()

	if resolved_path.is_empty():
		return null

	if not ResourceLoader.exists(resolved_path, "Texture2D"):
		return null

	return load(resolved_path) as Texture2D


static func format_room_name(scene_path: String) -> String:
	var resolved_path := scene_path.strip_edges()

	if resolved_path.is_empty():
		return "Неизвестно"

	match resolved_path:
		"res://scenes/rooms/apartament.tscn":
			return "Квартира"
		"res://scenes/rooms/enterance.tscn":
			return "Подъезд"
		"res://scenes/rooms/elevator.tscn":
			return "Лифт"
		"res://scenes/rooms/town.tscn":
			return "Улица"
		"res://scenes/rooms/supermarket.tscn":
			return "Магазин"
		_:
			var file_name := resolved_path.get_file().get_basename().replace("_", " ").strip_edges()
			return file_name.capitalize() if not file_name.is_empty() else "Неизвестно"
