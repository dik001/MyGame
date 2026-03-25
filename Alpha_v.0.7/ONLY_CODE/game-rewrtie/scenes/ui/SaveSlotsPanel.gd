class_name SaveSlotsPanel
extends PanelContainer

const SaveDataUtils = preload("res://scenes/main/SaveDataUtils.gd")
const StyledConfirmationDialog = preload("res://scenes/ui/StyledConfirmationDialog.gd")

const MODE_LOAD := "load"
const MODE_SAVE := "save"

var _mode := MODE_LOAD
var _title_label: Label
var _subtitle_label: Label
var _status_label: Label
var _rows_container: VBoxContainer
var _overwrite_dialog: StyledConfirmationDialog
var _pending_overwrite_slot_index := -1


func _ready() -> void:
	_build_ui()

	if SaveManager != null:
		if not SaveManager.save_slots_changed.is_connected(refresh_panel):
			SaveManager.save_slots_changed.connect(refresh_panel)

		if not SaveManager.operation_succeeded.is_connected(_on_operation_succeeded):
			SaveManager.operation_succeeded.connect(_on_operation_succeeded)

		if not SaveManager.operation_failed.is_connected(_on_operation_failed):
			SaveManager.operation_failed.connect(_on_operation_failed)

	refresh_panel()


func configure(mode: String) -> void:
	_mode = MODE_SAVE if mode == MODE_SAVE else MODE_LOAD

	if is_inside_tree():
		refresh_panel()


func refresh_panel() -> void:
	if _rows_container == null:
		return

	_title_label.text = "Сохранения" if _mode == MODE_LOAD else "Ручное сохранение"
	_subtitle_label.text = (
		"Выберите слот для загрузки." if _mode == MODE_LOAD
		else "Автосейв только для чтения. Ручные слоты можно перезаписывать."
	)

	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()

	_rows_container.add_child(_build_slot_row(SaveManager.AUTOSAVE_SLOT_KIND, 0, "Автосейв"))

	for slot_index in range(1, SaveManager.MAX_MANUAL_SLOTS + 1):
		_rows_container.add_child(_build_slot_row(SaveManager.MANUAL_SLOT_KIND, slot_index, "Слот %02d" % slot_index))


func clear_status() -> void:
	if _status_label != null:
		_status_label.text = ""


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	content.add_child(_subtitle_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	content.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows_container)

	_overwrite_dialog = StyledConfirmationDialog.new()
	_overwrite_dialog.dialog_text = "Этот слот уже занят. Перезаписать сохранение?"
	_overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	_overwrite_dialog.canceled.connect(_on_overwrite_canceled)
	add_child(_overwrite_dialog)


func _build_slot_row(slot_kind: String, slot_index: int, slot_title: String) -> Control:
	var summary_entry := SaveManager.get_slot_summary(slot_kind, slot_index)
	var has_data := not summary_entry.is_empty()
	var summary: Dictionary = SaveDataUtils.sanitize_dictionary(summary_entry.get("summary", {}))
	var saved_at_unix := int(summary_entry.get("saved_at_unix", 0))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_row_style(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title_label := Label.new()
	title_label.text = slot_title
	title_label.add_theme_font_size_override("font_size", 22)
	layout.add_child(title_label)

	var meta_label := Label.new()
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.add_theme_font_size_override("font_size", 16)
	meta_label.text = _build_slot_meta_text(summary, saved_at_unix) if has_data else "Пусто"
	layout.add_child(meta_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	layout.add_child(action_row)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(164.0, 0.0)
	action_row.add_child(action_button)

	if _mode == MODE_LOAD:
		action_button.text = "Загрузить" if has_data else "Недоступно"
		action_button.disabled = not has_data
	else:
		if slot_kind == SaveManager.AUTOSAVE_SLOT_KIND:
			action_button.text = "Только чтение"
			action_button.disabled = true
		else:
			action_button.text = "Перезаписать" if has_data else "Сохранить"
			action_button.disabled = false

	action_button.pressed.connect(_on_slot_action_pressed.bind(slot_kind, slot_index, has_data))

	return panel


func _build_slot_meta_text(summary: Dictionary, saved_at_unix: int) -> String:
	var room_name := String(summary.get("room_name", "Неизвестно"))
	var day := int(summary.get("day", 1))
	var hours := int(summary.get("hours", 0))
	var minutes := int(summary.get("minutes", 0))
	var cash_dollars := int(summary.get("cash_dollars", 0))
	var bank_dollars := int(summary.get("bank_dollars", 0))
	var saved_at_text := ""

	if saved_at_unix > 0:
		saved_at_text = Time.get_datetime_string_from_unix_time(saved_at_unix, true)

	var lines: Array[String] = [
		"Локация: %s" % room_name,
		"Игровое время: день %d, %02d:%02d" % [day, hours, minutes],
		"Деньги: наличные $%d, банк $%d" % [cash_dollars, bank_dollars],
	]

	if not saved_at_text.is_empty():
		lines.append("Сохранено: %s" % saved_at_text)

	return "\n".join(lines)


func _apply_row_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.17, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.52, 0.66, 0.82, 0.26)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)


func _on_slot_action_pressed(slot_kind: String, slot_index: int, has_data: bool) -> void:
	clear_status()

	if _mode == MODE_LOAD:
		SaveManager.request_load_slot(slot_kind, slot_index)
		return

	if slot_kind == SaveManager.AUTOSAVE_SLOT_KIND:
		return

	if has_data:
		_pending_overwrite_slot_index = slot_index
		_overwrite_dialog.popup_centered()
		return

	SaveManager.save_to_manual_slot(slot_index)


func _on_overwrite_confirmed() -> void:
	if _pending_overwrite_slot_index < 1:
		return

	var slot_index := _pending_overwrite_slot_index
	_pending_overwrite_slot_index = -1
	SaveManager.save_to_manual_slot(slot_index)


func _on_overwrite_canceled() -> void:
	_pending_overwrite_slot_index = -1


func _on_operation_succeeded(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _on_operation_failed(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
