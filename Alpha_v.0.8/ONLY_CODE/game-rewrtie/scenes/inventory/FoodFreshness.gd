class_name FoodFreshness
extends RefCounted

const MINUTES_PER_DAY: float = 24.0 * 60.0
const FRIDGE_SPOILAGE_MULTIPLIER: float = 0.1
const STATE_REMAINING_MINUTES: StringName = &"freshness_remaining_minutes"


static func is_food_item(item_data: ItemData) -> bool:
	return item_data != null and item_data.is_food_item() and item_data.get_base_shelf_life_minutes() > 0.0


static func build_fresh_state(item_data: ItemData) -> Dictionary:
	if not is_food_item(item_data):
		return {}

	return {
		STATE_REMAINING_MINUTES: item_data.get_base_shelf_life_minutes(),
	}


static func normalize_state(item_data: ItemData, raw_state: Dictionary = {}) -> Dictionary:
	var normalized_state: Dictionary = raw_state.duplicate(true)

	if not is_food_item(item_data):
		return normalized_state

	var max_minutes: float = item_data.get_base_shelf_life_minutes()

	if not normalized_state.has(STATE_REMAINING_MINUTES):
		normalized_state[STATE_REMAINING_MINUTES] = max_minutes

	if raw_state.has(STATE_REMAINING_MINUTES):
		normalized_state[STATE_REMAINING_MINUTES] = clampf(
			float(raw_state.get(STATE_REMAINING_MINUTES, max_minutes)),
			0.0,
			max_minutes
		)

	return normalized_state


static func get_remaining_minutes(item_data: ItemData, state: Dictionary = {}) -> float:
	if not is_food_item(item_data):
		return -1.0

	var normalized_state: Dictionary = normalize_state(item_data, state)
	return max(0.0, float(normalized_state.get(STATE_REMAINING_MINUTES, 0.0)))


static func get_effective_remaining_minutes(
	item_data: ItemData,
	state: Dictionary = {},
	spoilage_multiplier: float = 1.0
) -> float:
	if not is_food_item(item_data):
		return -1.0

	var remaining_minutes: float = get_remaining_minutes(item_data, state)
	var effective_multiplier: float = max(spoilage_multiplier, 0.0001)
	return remaining_minutes / effective_multiplier


static func apply_elapsed_minutes(
	item_data: ItemData,
	state: Dictionary,
	elapsed_minutes: int,
	spoilage_multiplier: float = 1.0
) -> Dictionary:
	if not is_food_item(item_data):
		return {}

	if elapsed_minutes <= 0:
		return normalize_state(item_data, state)

	var normalized_state: Dictionary = normalize_state(item_data, state)
	var current_remaining: float = get_remaining_minutes(item_data, normalized_state)
	var next_remaining: float = max(0.0, current_remaining - (float(elapsed_minutes) * max(spoilage_multiplier, 0.0)))
	normalized_state[STATE_REMAINING_MINUTES] = next_remaining
	return normalized_state


static func is_spoiled(item_data: ItemData, state: Dictionary = {}) -> bool:
	if not is_food_item(item_data):
		return false

	return get_remaining_minutes(item_data, state) <= 0.0


static func can_stack(item_data: ItemData, left_state: Dictionary = {}, right_state: Dictionary = {}) -> bool:
	if not is_food_item(item_data):
		return normalize_state(item_data, left_state) == normalize_state(item_data, right_state)

	var left_minutes: int = int(roundi(get_remaining_minutes(item_data, left_state)))
	var right_minutes: int = int(roundi(get_remaining_minutes(item_data, right_state)))
	return left_minutes == right_minutes


static func build_stack_key(item_data: ItemData, state: Dictionary = {}) -> String:
	if item_data == null:
		return ""

	var item_key: String = item_data.resource_path if not item_data.resource_path.is_empty() else item_data.id

	if not is_food_item(item_data):
		var normalized_state := normalize_state(item_data, state)

		if normalized_state.is_empty():
			return item_key

		return "%s|%s" % [item_key, JSON.stringify(normalized_state, "")]

	return "%s|%d" % [item_key, int(roundi(get_remaining_minutes(item_data, state)))]


static func format_compact_status(
	item_data: ItemData,
	state: Dictionary = {},
	spoilage_multiplier: float = 1.0
) -> String:
	if not is_food_item(item_data):
		return ""

	if is_spoiled(item_data, state):
		return "\u0418\u0441\u043f\u043e\u0440\u0447\u0435\u043d\u043e"

	var remaining_minutes: float = get_effective_remaining_minutes(item_data, state, spoilage_multiplier)
	var remaining_days: float = remaining_minutes / MINUTES_PER_DAY

	if remaining_days >= 10.0:
		return "%.0f \u0434\u043d." % remaining_days

	if remaining_days >= 1.0:
		return "%.1f \u0434\u043d." % remaining_days

	var remaining_hours: float = remaining_minutes / 60.0

	if remaining_hours >= 1.0:
		return "%.1f \u0447." % remaining_hours

	return "<1 \u0447."


static func format_inventory_status(
	item_data: ItemData,
	state: Dictionary = {},
	spoilage_multiplier: float = 1.0
) -> String:
	if not is_food_item(item_data):
		return ""

	if is_spoiled(item_data, state):
		return "\u0418\u0441\u043f\u043e\u0440\u0447\u0435\u043d\u043e"

	return "\u0421\u0432\u0435\u0436\u0435\u0441\u0442\u044c: %s" % format_compact_status(item_data, state, spoilage_multiplier)
