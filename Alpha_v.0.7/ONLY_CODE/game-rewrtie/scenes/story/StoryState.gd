extends Node

const SaveDataUtils = preload("res://scenes/main/SaveDataUtils.gd")

signal primary_objective_changed(objective: Dictionary)
signal runa_prologue_completed_changed(is_completed: bool)

const DEFAULT_QUEST_TITLE := "Найти деньги на аренду"
const DEFAULT_QUEST_DETAILS := "Нужно срочно найти способ оплатить аренду. Осмотреть квартиру, проверить телефон и понять, кто может помочь или дать работу."

var _primary_objective: Dictionary = {}
var _runa_prologue_completed := false


func _ready() -> void:
	if not has_current_quest():
		set_current_quest(DEFAULT_QUEST_TITLE, DEFAULT_QUEST_DETAILS)


func has_seen_runa_prologue() -> bool:
	return _runa_prologue_completed


func mark_runa_prologue_completed() -> void:
	if _runa_prologue_completed:
		return

	_runa_prologue_completed = true
	runa_prologue_completed_changed.emit(true)


func set_primary_objective(
	title: String,
	description: String = "",
	details: Array[String] = [],
	metadata: Dictionary = {}
) -> void:
	var normalized_details: Array[String] = []

	for detail in details:
		var detail_text := String(detail).strip_edges()

		if detail_text.is_empty():
			continue

		normalized_details.append(detail_text)

	_primary_objective = {
		"title": title.strip_edges(),
		"description": description.strip_edges(),
		"details": normalized_details,
		"metadata": metadata.duplicate(true),
	}

	primary_objective_changed.emit(get_primary_objective())


func clear_primary_objective() -> void:
	if _primary_objective.is_empty():
		return

	_primary_objective.clear()
	primary_objective_changed.emit({})


func has_primary_objective() -> bool:
	return not String(_primary_objective.get("title", "")).strip_edges().is_empty()


func get_primary_objective() -> Dictionary:
	return _primary_objective.duplicate(true)


func set_current_quest(
	title: String,
	details: String = "",
	metadata: Dictionary = {},
	extra_details: Array[String] = []
) -> void:
	set_primary_objective(title, details, extra_details, metadata)


func clear_current_quest() -> void:
	clear_primary_objective()


func has_current_quest() -> bool:
	return has_primary_objective()


func get_current_quest() -> Dictionary:
	return get_primary_objective()


func build_save_data() -> Dictionary:
	return {
		"primary_objective": get_primary_objective(),
		"runa_prologue_completed": _runa_prologue_completed,
	}


func apply_save_data(data: Dictionary) -> void:
	_primary_objective = SaveDataUtils.sanitize_dictionary(data.get("primary_objective", {}))
	_runa_prologue_completed = bool(data.get("runa_prologue_completed", false))
	primary_objective_changed.emit(get_primary_objective())
	runa_prologue_completed_changed.emit(_runa_prologue_completed)


func reset_state() -> void:
	_primary_objective.clear()
	_runa_prologue_completed = false

	if not has_current_quest():
		set_current_quest(DEFAULT_QUEST_TITLE, DEFAULT_QUEST_DETAILS)
	else:
		primary_objective_changed.emit(get_primary_objective())

	runa_prologue_completed_changed.emit(_runa_prologue_completed)
