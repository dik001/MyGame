class_name MentalStateModifierData
extends RefCounted

const STACK_POLICY_REPLACE := "replace"
const STACK_POLICY_REFRESH_DURATION := "refresh_duration"
const STACK_POLICY_STACK := "stack"


static func normalize(raw_value: Variant, current_absolute_minutes: int = 0) -> Dictionary:
	var raw: Dictionary = SaveDataUtils.sanitize_dictionary(raw_value)
	var modifier_id: String = String(raw.get("id", "")).strip_edges()

	if modifier_id.is_empty():
		return {}

	var definition_id: String = String(raw.get("definition_id", modifier_id)).strip_edges()
	var stack_policy: String = String(raw.get("stack_policy", STACK_POLICY_REPLACE)).strip_edges().to_lower()

	if stack_policy.is_empty():
		stack_policy = STACK_POLICY_REPLACE

	var applied_at_absolute_minutes: int = int(raw.get("applied_at_absolute_minutes", current_absolute_minutes))
	var duration_minutes: int = int(raw.get("duration_minutes", -1))
	var expires_at_absolute_minutes: int = int(raw.get("expires_at_absolute_minutes", -1))

	if duration_minutes >= 0 and expires_at_absolute_minutes < 0:
		expires_at_absolute_minutes = applied_at_absolute_minutes + duration_minutes
	elif expires_at_absolute_minutes >= 0 and duration_minutes < 0:
		duration_minutes = max(0, expires_at_absolute_minutes - applied_at_absolute_minutes)

	return {
		"id": modifier_id,
		"definition_id": definition_id if not definition_id.is_empty() else modifier_id,
		"source": String(raw.get("source", "system")).strip_edges(),
		"tags": _normalize_tags(raw.get("tags", [])),
		"show_in_ui": bool(raw.get("show_in_ui", false)),
		"title": String(raw.get("title", "")).strip_edges(),
		"status_text": String(raw.get("status_text", raw.get("status", ""))).strip_edges(),
		"description": String(raw.get("description", "")).strip_edges(),
		"mood_delta_per_hour": float(raw.get("mood_delta_per_hour", 0.0)),
		"stress_delta_per_hour": float(raw.get("stress_delta_per_hour", 0.0)),
		"effect_bonuses": SaveDataUtils.sanitize_dictionary(raw.get("effect_bonuses", {})),
		"stack_policy": stack_policy,
		"applied_at_absolute_minutes": applied_at_absolute_minutes,
		"duration_minutes": duration_minutes,
		"expires_at_absolute_minutes": expires_at_absolute_minutes,
	}


static func duplicate_modifier(modifier: Dictionary) -> Dictionary:
	return normalize(modifier, int(modifier.get("applied_at_absolute_minutes", 0)))


static func build_save_payload(modifier: Dictionary) -> Dictionary:
	return duplicate_modifier(modifier)


static func is_expired(modifier: Dictionary, absolute_minutes: int) -> bool:
	var expires_at_absolute_minutes: int = int(modifier.get("expires_at_absolute_minutes", -1))

	return expires_at_absolute_minutes >= 0 and absolute_minutes >= expires_at_absolute_minutes


static func get_remaining_minutes(modifier: Dictionary, absolute_minutes: int) -> int:
	var expires_at_absolute_minutes: int = int(modifier.get("expires_at_absolute_minutes", -1))

	if expires_at_absolute_minutes < 0:
		return -1

	return max(0, expires_at_absolute_minutes - absolute_minutes)


static func has_tag(modifier: Dictionary, tag: StringName) -> bool:
	var tag_text: String = String(tag).strip_edges().to_lower()

	if tag_text.is_empty():
		return false

	for modifier_tag in modifier.get("tags", []):
		if String(modifier_tag).strip_edges().to_lower() == tag_text:
			return true

	return false


static func _normalize_tags(raw_tags: Variant) -> Array[String]:
	var normalized_tags: Array[String] = []

	if raw_tags is Array:
		for tag_value in raw_tags:
			var tag_text: String = String(tag_value).strip_edges()

			if tag_text.is_empty():
				continue

			normalized_tags.append(tag_text)

	return normalized_tags
