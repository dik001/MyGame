class_name ItemData
extends Resource

const CATEGORY_MISC: StringName = &"misc"
const CATEGORY_FOOD: StringName = &"food"
const CATEGORY_HOUSEHOLD: StringName = &"household"
const CATEGORY_MEDICAL: StringName = &"medical"
const CATEGORY_SMOKING: StringName = &"smoking"
const CATEGORY_EQUIPMENT: StringName = &"equipment"
const VALID_ITEM_CATEGORIES: Array[StringName] = [
	CATEGORY_MISC,
	CATEGORY_FOOD,
	CATEGORY_HOUSEHOLD,
	CATEGORY_MEDICAL,
	CATEGORY_SMOKING,
	CATEGORY_EQUIPMENT,
]

const SOURCE_NONE: StringName = &"none"
const SOURCE_STORE: StringName = &"store"
const SOURCE_PHARMACY: StringName = &"pharmacy"
const SOURCE_BLACK_MARKET: StringName = &"black_market"
const VALID_ITEM_SOURCES: Array[StringName] = [
	SOURCE_NONE,
	SOURCE_STORE,
	SOURCE_PHARMACY,
	SOURCE_BLACK_MARKET,
]

const EQUIPMENT_SLOT_TOP: StringName = &"top"
const EQUIPMENT_SLOT_BOTTOM: StringName = &"bottom"
const EQUIPMENT_SLOT_SHOES: StringName = &"shoes"
const EQUIPMENT_SLOT_HEAD: StringName = &"head"
const VALID_EQUIPMENT_SLOTS: Array[StringName] = [
	EQUIPMENT_SLOT_TOP,
	EQUIPMENT_SLOT_BOTTOM,
	EQUIPMENT_SLOT_SHOES,
	EQUIPMENT_SLOT_HEAD,
]

@export var id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(1, 999, 1) var max_stack_size: int = 1
@export var weight: float = 0.0
@export_range(0, 9999, 1) var price: int = 0
@export var is_consumable: bool = false
@export var is_food: bool = false
@export var hunger_restore: int = 0
@export var hp_restore: int = 0
@export var energy_restore: int = 0
@export var mood_delta: int = 0
@export var stress_delta: int = 0
@export var use_effects: Array[Dictionary] = []
@export_range(0.0, 365.0, 0.1) var base_shelf_life_days: float = 0.0
@export var category: StringName = CATEGORY_MISC
@export var item_source: StringName = SOURCE_NONE
@export var equipment_slot: StringName = &""
@export var protection: int = 0
@export var stealth: int = 0
@export var attractiveness: int = 0
@export var speed_modifier: float = 0.0
@export_range(0, 9999, 1) var fixed_sell_price: int = 0
@export var can_sell: bool = true
@export var appearance_texture: Texture2D
@export var tags: PackedStringArray = PackedStringArray()


func get_display_name() -> String:
	if not item_name.is_empty():
		return item_name

	if not id.is_empty():
		return id.capitalize()

	return "Предмет"


func get_effective_max_stack_size() -> int:
	return max(1, max_stack_size)


func get_effective_weight() -> float:
	return max(weight, 0.0)


func get_effective_price() -> int:
	return max(price, 0)


func can_stack() -> bool:
	return get_effective_max_stack_size() > 1


func is_food_item() -> bool:
	return is_food


func get_item_category() -> StringName:
	if VALID_ITEM_CATEGORIES.has(category):
		if category == CATEGORY_MISC and is_food_item():
			return CATEGORY_FOOD

		return category

	if category == CATEGORY_EQUIPMENT:
		return CATEGORY_EQUIPMENT

	if category == CATEGORY_FOOD or is_food_item():
		return CATEGORY_FOOD

	return CATEGORY_MISC


func get_item_source() -> StringName:
	if VALID_ITEM_SOURCES.has(item_source):
		return item_source

	return SOURCE_NONE


func can_use_directly() -> bool:
	return is_consumable


func get_instant_stat_delta() -> Dictionary:
	return {
		"hp": hp_restore,
		"hunger": hunger_restore,
		"energy": energy_restore,
		"mood": mood_delta,
		"stress": stress_delta,
	}


func is_equipment_item() -> bool:
	return get_item_category() == CATEGORY_EQUIPMENT and get_equipment_slot() != &""


func get_equipment_slot() -> StringName:
	if not VALID_EQUIPMENT_SLOTS.has(equipment_slot):
		return &""

	return equipment_slot


func get_fixed_sell_price() -> int:
	return max(fixed_sell_price, 0)


func get_equipment_stat_block() -> Dictionary:
	return {
		"protection": protection,
		"stealth": stealth,
		"attractiveness": attractiveness,
		"speed_modifier": speed_modifier,
	}


func get_tags() -> PackedStringArray:
	return tags.duplicate()


func get_use_effects() -> Array[Dictionary]:
	return use_effects.duplicate(true)


func get_base_shelf_life_days() -> float:
	return max(base_shelf_life_days, 0.0)


func get_base_shelf_life_minutes() -> float:
	return get_base_shelf_life_days() * 24.0 * 60.0


func matches(other_item_data: ItemData) -> bool:
	if other_item_data == null:
		return false

	if not id.is_empty() and not other_item_data.id.is_empty():
		return id == other_item_data.id

	if not resource_path.is_empty() and not other_item_data.resource_path.is_empty():
		return resource_path == other_item_data.resource_path

	return self == other_item_data
