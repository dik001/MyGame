class_name CookingSystem
extends RefCounted

const RECIPES_DIRECTORY := "res://resources/recipes"
const RECIPE_EXTENSION := ".tres"

const STATUS_READY_TEXT := "Можно приготовить."
const STATUS_READY_SHORT_TEXT := "Готово"
const STATUS_MISSING_INGREDIENTS_SHORT_TEXT := "Нет ингредиентов"
const STATUS_MISSING_STATION_SHORT_TEXT := "Нет условий"
const STATUS_UNAVAILABLE_SHORT_TEXT := "Недоступно"
const STATUS_INVALID_TEXT := "Рецепт настроен некорректно."
const STATUS_MISSING_STATION_TEMPLATE := "Не хватает условий станции: %s."
const STATUS_MISSING_INGREDIENTS_TEMPLATE := "Не хватает ингредиентов: %s."
const STATUS_UNKNOWN_ITEM_TEXT := "Неизвестный ингредиент"
const CRAFT_SUCCESS_TEMPLATE := "Приготовлено: %s."
const CRAFT_SUCCESS_WITH_COUNT_TEMPLATE := "Приготовлено: %s x%d."
const CRAFT_RECIPE_NOT_FOUND_TEXT := "Рецепт не найден."
const CRAFT_ADD_RESULT_FAILED_TEXT := "Не удалось выдать результат готовки."
const CRAFT_REMOVE_INGREDIENTS_FAILED_TEXT := "Не удалось списать ингредиенты."
const STATUS_SELECTION_EMPTY_TEXT := "Положите ингредиенты на плиту."
const STATUS_SELECTION_PARTIAL_TEXT := "Похоже, чего-то еще не хватает."
const STATUS_SELECTION_INVALID_TEXT := "Из такого набора ничего не выйдет."
const STATUS_SELECTION_READY_TEXT := "Сочетание подходит. Можно зажечь огонь."

const SELECTION_STATE_EMPTY := "empty"
const SELECTION_STATE_PARTIAL := "partial"
const SELECTION_STATE_INVALID := "invalid"
const SELECTION_STATE_READY := "ready"
const SELECTION_STATE_BLOCKED := "blocked"


func load_recipes() -> Array[RecipeData]:
	var recipes: Array[RecipeData] = []
	var directory := DirAccess.open(RECIPES_DIRECTORY)

	if directory == null:
		return recipes

	directory.list_dir_begin()

	while true:
		var file_name := directory.get_next()

		if file_name.is_empty():
			break

		if directory.current_is_dir():
			continue

		if not file_name.ends_with(RECIPE_EXTENSION):
			continue

		var recipe_path := "%s/%s" % [RECIPES_DIRECTORY, file_name]
		var recipe := load(recipe_path) as RecipeData

		if recipe == null:
			continue

		recipes.append(recipe)

	directory.list_dir_end()
	recipes.sort_custom(Callable(self, "_sort_recipes_by_name"))
	return recipes


func find_recipe_by_id(recipe_id: String) -> RecipeData:
	var trimmed_recipe_id := recipe_id.strip_edges()

	if trimmed_recipe_id.is_empty():
		return null

	for recipe in load_recipes():
		if _get_recipe_id(recipe) == trimmed_recipe_id:
			return recipe

	return null


func build_combined_supply_entries(
	storages: Array,
	_station_tags: PackedStringArray = PackedStringArray()
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for storage_entry in storages:
		for slot_entry in _get_storage_slots(storage_entry):
			var slot := slot_entry as InventorySlotData

			if slot == null or slot.is_empty() or slot.item_data == null:
				continue

			if not _is_food_supply_item(slot.item_data):
				continue

			var entry_index := _find_item_entry_index(entries, slot.item_data)

			if entry_index < 0:
				entries.append({
					"item_data": slot.item_data,
					"display_name": slot.item_data.get_display_name(),
					"quantity": slot.quantity,
				})
				continue

			var existing_entry := entries[entry_index]
			existing_entry["quantity"] = int(existing_entry.get("quantity", 0)) + slot.quantity
			entries[entry_index] = existing_entry

	entries.sort_custom(Callable(self, "_sort_supply_entries"))
	return entries


func build_hidden_selection_report(
	selected_items: Array,
	station_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var normalized_selection := _normalize_item_entries(selected_items)
	var total_selected_quantity := _get_total_quantity_from_entries(normalized_selection)

	if normalized_selection.is_empty() or total_selected_quantity <= 0:
		return {
			"state": SELECTION_STATE_EMPTY,
			"can_cook": false,
			"message": STATUS_SELECTION_EMPTY_TEXT,
			"recipe": null,
			"recipe_id": "",
			"result_item": null,
			"result_count": 0,
		}

	var exact_recipe := _find_recipe_for_selection(
		normalized_selection,
		total_selected_quantity,
		station_tags,
		true
	)

	if exact_recipe != null:
		return _build_selection_report(
			SELECTION_STATE_READY,
			exact_recipe,
			STATUS_SELECTION_READY_TEXT,
			true
		)

	var blocked_recipe := _find_recipe_for_selection(
		normalized_selection,
		total_selected_quantity,
		station_tags,
		false
	)

	if blocked_recipe != null:
		var missing_station_tags := _get_missing_station_tags(
			blocked_recipe.required_station_tags,
			station_tags
		)
		var blocked_message := STATUS_MISSING_STATION_TEMPLATE % _format_station_tag_list(
			missing_station_tags
		)
		return _build_selection_report(
			SELECTION_STATE_BLOCKED,
			blocked_recipe,
			blocked_message,
			false
		)

	if _has_partial_recipe_match(normalized_selection, total_selected_quantity, station_tags):
		return {
			"state": SELECTION_STATE_PARTIAL,
			"can_cook": false,
			"message": STATUS_SELECTION_PARTIAL_TEXT,
			"recipe": null,
			"recipe_id": "",
			"result_item": null,
			"result_count": 0,
		}

	return {
		"state": SELECTION_STATE_INVALID,
		"can_cook": false,
		"message": STATUS_SELECTION_INVALID_TEXT,
		"recipe": null,
		"recipe_id": "",
		"result_item": null,
		"result_count": 0,
	}


func build_recipe_report(
	recipe: RecipeData,
	inventory: PlayerInventoryState,
	station_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var inventory_slots := _get_storage_slots(inventory)
	return _build_recipe_report_from_slots(recipe, inventory_slots, station_tags)


func build_recipe_reports(
	inventory: PlayerInventoryState,
	station_tags: PackedStringArray = PackedStringArray()
) -> Array[Dictionary]:
	var inventory_slots := _get_storage_slots(inventory)
	var reports: Array[Dictionary] = []

	for recipe in load_recipes():
		reports.append(_build_recipe_report_from_slots(recipe, inventory_slots, station_tags))

	reports.sort_custom(Callable(self, "_sort_recipe_reports"))
	return reports


func cook_recipe(
	recipe: RecipeData,
	inventory: PlayerInventoryState,
	station_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var result := {
		"success": false,
		"message": CRAFT_RECIPE_NOT_FOUND_TEXT,
		"recipe": recipe,
		"report": {},
	}

	if recipe == null or inventory == null:
		return result

	var report := build_recipe_report(recipe, inventory, station_tags)
	result["report"] = report
	result["message"] = String(report.get("detailed_status_text", STATUS_INVALID_TEXT))

	if not bool(report.get("is_available", false)):
		return result

	var removal_plan := _build_multi_storage_removal_plan(recipe, [{"storage": inventory}])

	if removal_plan.is_empty():
		result["message"] = CRAFT_REMOVE_INGREDIENTS_FAILED_TEXT
		return result

	return _commit_recipe_with_plan(recipe, removal_plan, inventory, report)


func cook_recipe_by_id(
	recipe_id: String,
	inventory: PlayerInventoryState,
	station_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var recipe := find_recipe_by_id(recipe_id)
	return cook_recipe(recipe, inventory, station_tags)


func cook_selected_items(
	selected_items: Array,
	storages: Array,
	output_inventory: PlayerInventoryState,
	station_tags: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var report := build_hidden_selection_report(selected_items, station_tags)
	var recipe := report.get("recipe") as RecipeData
	var result := {
		"success": false,
		"message": String(report.get("message", STATUS_SELECTION_INVALID_TEXT)),
		"recipe": recipe,
		"report": report,
	}

	if output_inventory == null:
		result["message"] = CRAFT_ADD_RESULT_FAILED_TEXT
		return result

	if recipe == null or not bool(report.get("can_cook", false)):
		return result

	var removal_plan := _build_multi_storage_removal_plan(recipe, storages)

	if removal_plan.is_empty():
		result["message"] = CRAFT_REMOVE_INGREDIENTS_FAILED_TEXT
		return result

	return _commit_recipe_with_plan(recipe, removal_plan, output_inventory, report)


func _build_recipe_report_from_slots(
	recipe: RecipeData,
	inventory_slots: Array,
	station_tags: PackedStringArray
) -> Dictionary:
	var recipe_id := _get_recipe_id(recipe)
	var display_name := recipe.get_display_name() if recipe != null else "Recipe"
	var description := String(recipe.description if recipe != null else "").strip_edges()
	var result_item := recipe.result_item if recipe != null else null
	var result_count: int = maxi(1, int(recipe.result_count if recipe != null else 1))
	var required_station_tags := (
		recipe.required_station_tags.duplicate()
		if recipe != null
		else PackedStringArray()
	)
	var missing_station_tags := _get_missing_station_tags(required_station_tags, station_tags)
	var ingredient_reports: Array[Dictionary] = []
	var missing_ingredients: Array[Dictionary] = []

	if recipe != null:
		for ingredient_entry in recipe.get_ingredients():
			var normalized_ingredient := _build_ingredient_report(ingredient_entry, inventory_slots)
			ingredient_reports.append(normalized_ingredient)

			if not bool(normalized_ingredient.get("is_enough", false)):
				missing_ingredients.append(normalized_ingredient)

	var is_valid := recipe != null and result_item != null and not ingredient_reports.is_empty()
	var needs_station := not missing_station_tags.is_empty()
	var needs_ingredients := not missing_ingredients.is_empty()
	var reasons: Array[String] = []

	if not is_valid:
		reasons.append(STATUS_INVALID_TEXT)

	if needs_station:
		reasons.append(STATUS_MISSING_STATION_TEMPLATE % _format_station_tag_list(missing_station_tags))

	if needs_ingredients:
		reasons.append(STATUS_MISSING_INGREDIENTS_TEMPLATE % _format_missing_ingredient_list(missing_ingredients))

	if reasons.is_empty():
		reasons.append(STATUS_READY_TEXT)

	var is_available := is_valid and not needs_station and not needs_ingredients
	var short_status_text := STATUS_READY_SHORT_TEXT

	if not is_available:
		if needs_station:
			short_status_text = STATUS_MISSING_STATION_SHORT_TEXT
		elif needs_ingredients:
			short_status_text = STATUS_MISSING_INGREDIENTS_SHORT_TEXT
		else:
			short_status_text = STATUS_UNAVAILABLE_SHORT_TEXT

	return {
		"recipe": recipe,
		"recipe_id": recipe_id,
		"display_name": display_name,
		"description": description,
		"result_item": result_item,
		"result_count": result_count,
		"ingredients": ingredient_reports,
		"missing_ingredients": missing_ingredients,
		"required_station_tags": required_station_tags,
		"missing_station_tags": missing_station_tags,
		"needs_station": needs_station,
		"needs_ingredients": needs_ingredients,
		"is_available": is_available,
		"is_valid": is_valid,
		"short_status_text": short_status_text,
		"detailed_status_text": " ".join(reasons),
	}


func _build_selection_report(
	state: String,
	recipe: RecipeData,
	message: String,
	can_cook: bool
) -> Dictionary:
	return {
		"state": state,
		"can_cook": can_cook,
		"message": message,
		"recipe": recipe,
		"recipe_id": _get_recipe_id(recipe),
		"result_item": recipe.result_item if recipe != null else null,
		"result_count": maxi(1, int(recipe.result_count if recipe != null else 1)),
	}


func _build_ingredient_report(ingredient_entry: Dictionary, inventory_slots: Array) -> Dictionary:
	var ingredient_data := SaveDataUtils.sanitize_dictionary(ingredient_entry)
	var item_data := ingredient_data.get("item") as ItemData
	var required_quantity: int = maxi(1, int(ingredient_data.get("quantity", 1)))
	var available_quantity := _count_item_quantity_in_slots(item_data, inventory_slots)
	var item_name := _get_item_name(item_data)

	return {
		"item_data": item_data,
		"item_name": item_name,
		"required_quantity": required_quantity,
		"available_quantity": available_quantity,
		"missing_quantity": max(0, required_quantity - available_quantity),
		"is_enough": available_quantity >= required_quantity,
	}


func _count_item_quantity_in_slots(item_data: ItemData, inventory_slots: Array) -> int:
	if item_data == null:
		return 0

	var total_quantity := 0

	for slot_entry in inventory_slots:
		var slot := slot_entry as InventorySlotData

		if slot == null or slot.is_empty() or slot.item_data == null:
			continue

		if not slot.item_data.matches(item_data):
			continue

		total_quantity += slot.quantity

	return total_quantity


func _commit_recipe_with_plan(
	recipe: RecipeData,
	removal_plan: Array,
	output_inventory: PlayerInventoryState,
	report: Dictionary = {}
) -> Dictionary:
	var result := {
		"success": false,
		"message": CRAFT_RECIPE_NOT_FOUND_TEXT,
		"recipe": recipe,
		"report": report.duplicate(true),
	}

	if recipe == null or output_inventory == null:
		return result

	var removed_entries: Array[Dictionary] = []

	for plan_entry_variant in removal_plan:
		var plan_entry := plan_entry_variant as Dictionary
		var storage := _get_storage_node(plan_entry.get("storage", null))
		var slot_index := int(plan_entry.get("slot_index", -1))
		var quantity := int(plan_entry.get("quantity", 0))
		var item_data := plan_entry.get("item_data") as ItemData
		var item_state := SaveDataUtils.sanitize_dictionary(plan_entry.get("item_state", {}))

		if storage == null or slot_index < 0 or quantity <= 0 or item_data == null:
			_rollback_removed_entries(removed_entries)
			result["message"] = CRAFT_REMOVE_INGREDIENTS_FAILED_TEXT
			return result

		if not bool(storage.call("remove_item_at", slot_index, quantity)):
			_rollback_removed_entries(removed_entries)
			result["message"] = CRAFT_REMOVE_INGREDIENTS_FAILED_TEXT
			return result

		removed_entries.append({
			"storage": storage,
			"item_data": item_data,
			"quantity": quantity,
			"item_state": item_state,
		})

	if recipe.result_item == null:
		_rollback_removed_entries(removed_entries)
		result["message"] = STATUS_INVALID_TEXT
		return result

	if not output_inventory.add_item(recipe.result_item, max(1, recipe.result_count)):
		_rollback_removed_entries(removed_entries)
		result["message"] = CRAFT_ADD_RESULT_FAILED_TEXT
		return result

	result["success"] = true
	result["message"] = _build_success_message(recipe)
	return result


func _build_multi_storage_removal_plan(recipe: RecipeData, storages: Array) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []

	if recipe == null:
		return plan

	for ingredient_entry in recipe.get_ingredients():
		var ingredient_data := SaveDataUtils.sanitize_dictionary(ingredient_entry)
		var item_data := ingredient_data.get("item") as ItemData
		var remaining_quantity: int = maxi(1, int(ingredient_data.get("quantity", 1)))

		if item_data == null:
			return []

		for storage_entry in storages:
			var storage := _get_storage_node(storage_entry)
			var slots := _get_storage_slots(storage_entry)

			if storage == null or slots.is_empty():
				continue

			for slot_index in range(slots.size()):
				var slot := slots[slot_index] as InventorySlotData

				if slot == null or slot.is_empty() or slot.item_data == null:
					continue

				if not slot.item_data.matches(item_data):
					continue

				var consumed_quantity: int = mini(remaining_quantity, slot.quantity)

				if consumed_quantity <= 0:
					continue

				plan.append({
					"storage": storage,
					"slot_index": slot_index,
					"quantity": consumed_quantity,
					"item_data": slot.item_data,
					"item_state": slot.get_item_state(),
				})
				remaining_quantity -= consumed_quantity

				if remaining_quantity <= 0:
					break

			if remaining_quantity <= 0:
				break

		if remaining_quantity > 0:
			return []

	return plan


func _rollback_removed_entries(removed_entries: Array[Dictionary]) -> void:
	for removed_entry in removed_entries:
		var storage := _get_storage_node(removed_entry.get("storage", null))
		var item_data := removed_entry.get("item_data") as ItemData
		var quantity := int(removed_entry.get("quantity", 0))
		var item_state := SaveDataUtils.sanitize_dictionary(removed_entry.get("item_state", {}))

		if storage == null or item_data == null or quantity <= 0:
			continue

		storage.call("add_item", item_data, quantity, item_state)


func _get_allowed_ingredient_items(station_tags: PackedStringArray) -> Array[ItemData]:
	var allowed_items: Array[ItemData] = []

	for recipe in load_recipes():
		if recipe == null:
			continue

		if not _get_missing_station_tags(recipe.required_station_tags, station_tags).is_empty():
			continue

		for ingredient_entry in recipe.get_ingredients():
			var item_data := SaveDataUtils.sanitize_dictionary(ingredient_entry).get("item") as ItemData

			if item_data == null or _contains_matching_item(allowed_items, item_data):
				continue

			allowed_items.append(item_data)

	return allowed_items


func _is_food_supply_item(item_data: ItemData) -> bool:
	if item_data == null:
		return false

	return item_data.get_item_category() == ItemData.CATEGORY_FOOD


func _normalize_item_entries(item_entries: Array) -> Array[Dictionary]:
	var normalized_entries: Array[Dictionary] = []

	for entry_variant in item_entries:
		var item_data := _extract_item_data(entry_variant)
		var quantity := _extract_quantity(entry_variant)

		if item_data == null or quantity <= 0:
			continue

		var entry_index := _find_item_entry_index(normalized_entries, item_data)

		if entry_index < 0:
			normalized_entries.append({
				"item_data": item_data,
				"quantity": quantity,
			})
			continue

		var existing_entry := normalized_entries[entry_index]
		existing_entry["quantity"] = int(existing_entry.get("quantity", 0)) + quantity
		normalized_entries[entry_index] = existing_entry

	return normalized_entries


func _extract_item_data(entry_variant: Variant) -> ItemData:
	if entry_variant is ItemData:
		return entry_variant as ItemData

	if entry_variant is InventorySlotData:
		var slot := entry_variant as InventorySlotData
		return slot.item_data if slot != null else null

	if not (entry_variant is Dictionary):
		return null

	var entry := entry_variant as Dictionary
	var item_data := entry.get("item_data") as ItemData

	if item_data != null:
		return item_data

	item_data = entry.get("item") as ItemData

	if item_data != null:
		return item_data

	var item_path := String(entry.get("item_path", "")).strip_edges()

	if item_path.is_empty():
		return null

	return load(item_path) as ItemData


func _extract_quantity(entry_variant: Variant) -> int:
	if entry_variant is ItemData:
		return 1

	if entry_variant is InventorySlotData:
		var slot := entry_variant as InventorySlotData
		return slot.quantity if slot != null and not slot.is_empty() else 0

	if not (entry_variant is Dictionary):
		return 0

	var entry := entry_variant as Dictionary
	return maxi(1, int(entry.get("quantity", 1)))


func _get_total_quantity_from_entries(entries: Array[Dictionary]) -> int:
	var total_quantity := 0

	for entry in entries:
		total_quantity += int(entry.get("quantity", 0))

	return total_quantity


func _find_recipe_for_selection(
	selection_entries: Array[Dictionary],
	total_selected_quantity: int,
	station_tags: PackedStringArray,
	require_station_match: bool
) -> RecipeData:
	for recipe in load_recipes():
		if _selection_matches_recipe(
			selection_entries,
			total_selected_quantity,
			recipe,
			station_tags,
			require_station_match
		):
			return recipe

	return null


func _selection_matches_recipe(
	selection_entries: Array[Dictionary],
	total_selected_quantity: int,
	recipe: RecipeData,
	station_tags: PackedStringArray,
	require_station_match: bool
) -> bool:
	if recipe == null or recipe.result_item == null:
		return false

	if require_station_match and not _get_missing_station_tags(recipe.required_station_tags, station_tags).is_empty():
		return false

	var recipe_entries := _normalize_item_entries(recipe.get_ingredients())
	var total_required_quantity := _get_total_quantity_from_entries(recipe_entries)

	if total_required_quantity != total_selected_quantity:
		return false

	if recipe_entries.size() != selection_entries.size():
		return false

	for recipe_entry in recipe_entries:
		var item_data := recipe_entry.get("item_data") as ItemData
		var required_quantity := int(recipe_entry.get("quantity", 0))

		if item_data == null:
			return false

		if _get_quantity_for_item(selection_entries, item_data) != required_quantity:
			return false

	return true


func _has_partial_recipe_match(
	selection_entries: Array[Dictionary],
	total_selected_quantity: int,
	station_tags: PackedStringArray
) -> bool:
	for recipe in load_recipes():
		if recipe == null:
			continue

		if not _get_missing_station_tags(recipe.required_station_tags, station_tags).is_empty():
			continue

		if _selection_is_subset_of_recipe(selection_entries, total_selected_quantity, recipe):
			return true

	return false


func _selection_is_subset_of_recipe(
	selection_entries: Array[Dictionary],
	total_selected_quantity: int,
	recipe: RecipeData
) -> bool:
	var recipe_entries := _normalize_item_entries(recipe.get_ingredients())
	var total_required_quantity := _get_total_quantity_from_entries(recipe_entries)

	if total_selected_quantity >= total_required_quantity:
		return false

	for selection_entry in selection_entries:
		var item_data := selection_entry.get("item_data") as ItemData
		var quantity := int(selection_entry.get("quantity", 0))

		if item_data == null or quantity <= 0:
			return false

		var required_quantity := _get_quantity_for_item(recipe_entries, item_data)

		if required_quantity <= 0 or quantity > required_quantity:
			return false

	return true


func _get_quantity_for_item(entries: Array[Dictionary], item_data: ItemData) -> int:
	if item_data == null:
		return 0

	for entry in entries:
		var entry_item := entry.get("item_data") as ItemData

		if entry_item == null or not entry_item.matches(item_data):
			continue

		return int(entry.get("quantity", 0))

	return 0


func _contains_matching_item(item_list: Array, item_data: ItemData) -> bool:
	if item_data == null:
		return false

	for list_item_variant in item_list:
		var list_item := list_item_variant as ItemData

		if list_item != null and list_item.matches(item_data):
			return true

	return false


func _find_item_entry_index(entries: Array[Dictionary], item_data: ItemData) -> int:
	if item_data == null:
		return -1

	for entry_index in range(entries.size()):
		var entry := entries[entry_index]
		var entry_item := entry.get("item_data") as ItemData

		if entry_item != null and entry_item.matches(item_data):
			return entry_index

	return -1


func _get_storage_node(storage_entry: Variant) -> Object:
	if storage_entry is Dictionary:
		return (storage_entry as Dictionary).get("storage", null) as Object

	return storage_entry as Object


func _get_storage_slots(storage_entry: Variant) -> Array:
	if storage_entry is Dictionary:
		var entry := storage_entry as Dictionary

		if entry.has("slots"):
			var slots_variant: Variant = entry.get("slots", [])

			if slots_variant is Array:
				return slots_variant

			return []

		var storage := entry.get("storage", null) as Object

		if storage != null and storage.has_method("get_slots"):
			var storage_slots_variant: Variant = storage.call("get_slots")
			return storage_slots_variant if storage_slots_variant is Array else []

		return []

	var storage_object := storage_entry as Object

	if storage_object != null and storage_object.has_method("get_slots"):
		var storage_object_slots: Variant = storage_object.call("get_slots")
		return storage_object_slots if storage_object_slots is Array else []

	return []


func _get_missing_station_tags(
	required_station_tags: PackedStringArray,
	station_tags: PackedStringArray
) -> PackedStringArray:
	var missing_tags := PackedStringArray()

	for required_tag in required_station_tags:
		if station_tags.has(required_tag):
			continue

		missing_tags.append(required_tag)

	return missing_tags


func _format_station_tag_list(tags: PackedStringArray) -> String:
	var formatted_tags: Array[String] = []

	for tag in tags:
		formatted_tags.append(_format_station_tag(tag))

	return ", ".join(formatted_tags)


func _format_station_tag(tag: String) -> String:
	match tag.strip_edges().to_lower():
		"fire":
			return "огонь"
		"water":
			return "вода"
		"electricity":
			return "электричество"
		"fuel":
			return "топливо"
		_:
			return tag.replace("_", " ").strip_edges()


func _format_missing_ingredient_list(missing_ingredients: Array[Dictionary]) -> String:
	var formatted_items: Array[String] = []

	for ingredient_report in missing_ingredients:
		var item_name := String(ingredient_report.get("item_name", STATUS_UNKNOWN_ITEM_TEXT)).strip_edges()
		var missing_quantity: int = maxi(1, int(ingredient_report.get("missing_quantity", 1)))
		formatted_items.append("%s x%d" % [item_name, missing_quantity])

	return ", ".join(formatted_items)


func _build_success_message(recipe: RecipeData) -> String:
	if recipe == null or recipe.result_item == null:
		return STATUS_READY_TEXT

	if max(1, recipe.result_count) == 1:
		return CRAFT_SUCCESS_TEMPLATE % recipe.result_item.get_display_name()

	return CRAFT_SUCCESS_WITH_COUNT_TEMPLATE % [
		recipe.result_item.get_display_name(),
		max(1, recipe.result_count),
	]


func _get_recipe_id(recipe: RecipeData) -> String:
	if recipe == null:
		return ""

	var trimmed_id := recipe.id.strip_edges()

	if not trimmed_id.is_empty():
		return trimmed_id

	return recipe.resource_path.get_file().get_basename().strip_edges()


func _get_item_name(item_data: ItemData) -> String:
	if item_data == null:
		return STATUS_UNKNOWN_ITEM_TEXT

	return item_data.get_display_name()


func _sort_recipes_by_name(left: RecipeData, right: RecipeData) -> bool:
	if left == null:
		return false

	if right == null:
		return true

	return left.get_display_name().nocasecmp_to(right.get_display_name()) < 0


func _sort_recipe_reports(left: Dictionary, right: Dictionary) -> bool:
	var left_available := bool(left.get("is_available", false))
	var right_available := bool(right.get("is_available", false))

	if left_available != right_available:
		return left_available and not right_available

	var left_name := String(left.get("display_name", ""))
	var right_name := String(right.get("display_name", ""))
	return left_name.nocasecmp_to(right_name) < 0


func _sort_supply_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_name := String(left.get("display_name", ""))
	var right_name := String(right.get("display_name", ""))
	return left_name.nocasecmp_to(right_name) < 0
