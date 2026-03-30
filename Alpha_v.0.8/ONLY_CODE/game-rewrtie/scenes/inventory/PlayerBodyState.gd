class_name PlayerBodyStateData
extends Node

signal body_state_changed(body_state: Dictionary)

const MIN_BODY_VALUE := 0
const MAX_BODY_VALUE := 100
const DIRT_VISIBILITY_THRESHOLD := 30
const BLOOD_VISIBILITY_THRESHOLD := 1
const DEFAULT_UNTIDY_DIRT_ALPHA := 0.22
const DEFAULT_DIRTY_DIRT_ALPHA := 0.55
const DEFAULT_UNSANITARY_DIRT_ALPHA := 0.90

var body_dirt: int = 0
var body_blood: int = 0


func get_body_state() -> Dictionary:
	return {
		"body_dirt": body_dirt,
		"body_blood": body_blood,
		"dirt_visual_alpha": get_dirt_visual_alpha(),
		"blood_visual_alpha": get_blood_visual_alpha(),
	}


func set_body_dirt(value: int) -> void:
	var next_value := clampi(value, MIN_BODY_VALUE, MAX_BODY_VALUE)

	if next_value == body_dirt:
		return

	body_dirt = next_value
	body_state_changed.emit(get_body_state())


func set_body_blood(value: int) -> void:
	var next_value := clampi(value, MIN_BODY_VALUE, MAX_BODY_VALUE)

	if next_value == body_blood:
		return

	body_blood = next_value
	body_state_changed.emit(get_body_state())


func set_body_values(next_dirt: int, next_blood: int) -> void:
	var dirt_changed := clampi(next_dirt, MIN_BODY_VALUE, MAX_BODY_VALUE) != body_dirt
	var blood_changed := clampi(next_blood, MIN_BODY_VALUE, MAX_BODY_VALUE) != body_blood

	body_dirt = clampi(next_dirt, MIN_BODY_VALUE, MAX_BODY_VALUE)
	body_blood = clampi(next_blood, MIN_BODY_VALUE, MAX_BODY_VALUE)

	if dirt_changed or blood_changed:
		body_state_changed.emit(get_body_state())


func set_body_dirt_from_hygiene_value(hygiene_value: int) -> void:
	set_body_dirt(MAX_BODY_VALUE - clampi(hygiene_value, MIN_BODY_VALUE, MAX_BODY_VALUE))


func clear_body_blood() -> void:
	set_body_blood(0)


func wash_body(clear_blood := true) -> void:
	if clear_blood:
		set_body_values(0, 0)
		return

	set_body_dirt(0)


func should_show_dirt() -> bool:
	return get_dirt_visual_alpha() > 0.01


func should_show_blood() -> bool:
	return body_blood >= BLOOD_VISIBILITY_THRESHOLD


func get_dirt_visual_alpha() -> float:
	var player_stats := get_node_or_null("/root/PlayerStats")

	if player_stats != null and player_stats.has_method("get_hygiene_state"):
		var hygiene_state: Variant = player_stats.call("get_hygiene_state")

		if hygiene_state is Dictionary:
			return clampf(float((hygiene_state as Dictionary).get("dirt_visual_alpha", 0.0)), 0.0, 1.0)

	return _build_default_dirt_alpha(body_dirt)


func get_blood_visual_alpha() -> float:
	if body_blood <= BLOOD_VISIBILITY_THRESHOLD:
		return 0.0

	return clampf(float(body_blood) / float(MAX_BODY_VALUE), 0.25, 1.0)


func build_save_data() -> Dictionary:
	return get_body_state()


func apply_save_data(data: Dictionary) -> void:
	body_dirt = _resolve_hygiene_bound_dirt(int(data.get("body_dirt", 0)))
	body_blood = clampi(int(data.get("body_blood", 0)), MIN_BODY_VALUE, MAX_BODY_VALUE)
	body_state_changed.emit(get_body_state())


func reset_state() -> void:
	body_dirt = _resolve_hygiene_bound_dirt(0)
	body_blood = 0
	body_state_changed.emit(get_body_state())


func _resolve_hygiene_bound_dirt(fallback_dirt: int) -> int:
	var player_stats := get_node_or_null("/root/PlayerStats")

	if player_stats != null and player_stats.has_method("get_hygiene_value"):
		return MAX_BODY_VALUE - clampi(int(player_stats.call("get_hygiene_value")), MIN_BODY_VALUE, MAX_BODY_VALUE)

	return clampi(fallback_dirt, MIN_BODY_VALUE, MAX_BODY_VALUE)


func _build_default_dirt_alpha(dirt_value: int) -> float:
	var normalized_dirt: int = clampi(dirt_value, MIN_BODY_VALUE, MAX_BODY_VALUE)

	if normalized_dirt <= 0:
		return 0.0

	if normalized_dirt < 25:
		return lerpf(0.0, DEFAULT_UNTIDY_DIRT_ALPHA, float(normalized_dirt) / 25.0)

	if normalized_dirt < 50:
		return lerpf(
			DEFAULT_UNTIDY_DIRT_ALPHA,
			DEFAULT_DIRTY_DIRT_ALPHA,
			float(normalized_dirt - 25) / 25.0
		)

	if normalized_dirt < 75:
		return lerpf(
			DEFAULT_DIRTY_DIRT_ALPHA,
			DEFAULT_UNSANITARY_DIRT_ALPHA,
			float(normalized_dirt - 50) / 25.0
		)

	return DEFAULT_UNSANITARY_DIRT_ALPHA
