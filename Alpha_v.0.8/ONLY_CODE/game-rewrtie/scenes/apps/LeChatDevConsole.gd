class_name LeChatDevConsole
extends RefCounted

const ACTIVATION_PHRASE := "921895"
const DEV_SESSION_CHAT_ID := "landlord_dev_console"
const DEV_DISPLAY_NAME := "Арендодатель [DEV]"
const DEV_STATUS_TEXT := "Админ-консоль разработчика"
const DEV_INPUT_PLACEHOLDER := "/help, /stats, /mood, /stress, /time ..."
const DEV_SENDER_ID := "lechat_dev_console"
const DEV_SENDER_NAME := "Dev Console"
const DEV_SAVE_SLOT := 10
const REQUIRE_DEBUG_BUILD := false
const GAME_SCENE_PATH := "res://scenes/main/game.tscn"
const ROOM_SCENE_DIRECTORY := "res://scenes/rooms"
const ITEM_RESOURCE_DIRECTORY := "res://resources/items"

const GROUP_ORDER := [
	"Основное",
	"Игрок",
	"Время",
	"Локация",
	"Состояние",
	"Инвентарь",
	"Фриланс",
	"Отладка",
]

const ROOM_ALIAS_OVERRIDES := {
	"apartament": "res://scenes/rooms/apartament.tscn",
	"apartment": "res://scenes/rooms/apartament.tscn",
	"квартира": "res://scenes/rooms/apartament.tscn",
	"enterance": "res://scenes/rooms/enterance.tscn",
	"entrance": "res://scenes/rooms/enterance.tscn",
	"подъезд": "res://scenes/rooms/enterance.tscn",
	"подьезд": "res://scenes/rooms/enterance.tscn",
	"elevator": "res://scenes/rooms/elevator.tscn",
	"лифт": "res://scenes/rooms/elevator.tscn",
	"town": "res://scenes/rooms/town.tscn",
	"улица": "res://scenes/rooms/town.tscn",
	"supermarket": "res://scenes/rooms/supermarket.tscn",
	"shop": "res://scenes/rooms/supermarket.tscn",
	"магазин": "res://scenes/rooms/supermarket.tscn",
}

var _window = null
var _active := false
var _commands: Dictionary = {}
var _command_order: Array[String] = []
var _aliases: Dictionary = {}
var _history: Array[String] = []
var _history_index := -1
var _history_draft := ""
var _room_entries: Array[Dictionary] = []
var _room_aliases: Dictionary = {}
var _item_entries: Array[Dictionary] = []
var _item_aliases: Dictionary = {}


func _init(window_ref = null) -> void:
	_window = window_ref
	_register_commands()


func is_active() -> bool:
	return _active


func deactivate() -> void:
	_active = false
	_reset_history_navigation()


func get_session_chat_id() -> String:
	return DEV_SESSION_CHAT_ID


func get_display_name() -> String:
	return DEV_DISPLAY_NAME


func get_status_text() -> String:
	return DEV_STATUS_TEXT


func get_input_placeholder() -> String:
	return DEV_INPUT_PLACEHOLDER


func get_sender_id() -> String:
	return DEV_SENDER_ID


func get_sender_name() -> String:
	return DEV_SENDER_NAME


func should_handle_submission(text: String) -> bool:
	var trimmed_text: String = text.strip_edges()

	if trimmed_text.is_empty():
		return _active

	if _active:
		return true

	return trimmed_text == ACTIVATION_PHRASE


func handle_submission(text: String) -> Dictionary:
	var trimmed_text: String = text.strip_edges()

	if not _active:
		if trimmed_text != ACTIVATION_PHRASE:
			return {"handled": false}

		if REQUIRE_DEBUG_BUILD and not OS.is_debug_build():
			return _error_response(
				"Dev-консоль отключена для этого билда.",
				false
			)

		_active = true
		_reset_history_navigation()

		var activation_result := _base_result()
		_append_console_message(
			activation_result,
			"Админ-консоль разработчика активирована.\nВведите /help, чтобы посмотреть список команд.\n\nБыстрый старт: /stats, /time, /money, /rent, /orders, /save."
		)
		return activation_result

	if trimmed_text.is_empty():
		return _base_result()

	if not trimmed_text.begins_with("/"):
		return _error_response(
			"Это режим админ-консоли. Используйте команды, начинающиеся с '/'.\nПодсказка: /help",
			false
		)

	_push_history(trimmed_text)

	var parsed: Dictionary = _parse_command(trimmed_text)
	var command_result := _base_result()
	command_result["append_player_message"] = true
	command_result["player_text"] = trimmed_text

	if not bool(parsed.get("ok", false)):
		_append_console_message(command_result, String(parsed.get("error", "Не удалось разобрать команду.")))
		return command_result

	var raw_command_name: String = String(parsed.get("name", "")).to_lower()
	var command_name: String = _resolve_command_name(raw_command_name)

	if command_name.is_empty():
		_append_console_message(
			command_result,
			"Неизвестная команда '%s'. Введите /help." % raw_command_name
		)
		return command_result

	var entry: Dictionary = _commands.get(command_name, {})

	if entry.is_empty():
		_append_console_message(
			command_result,
			"Команда '%s' зарегистрирована некорректно." % command_name
		)
		return command_result

	var handler_name: String = String(entry.get("handler", "")).strip_edges()
	var handler := Callable(self, handler_name)

	if not handler.is_valid():
		_append_console_message(
			command_result,
			"Для команды '%s' не найден обработчик." % command_name
		)
		return command_result

	var handler_result_variant: Variant = handler.call(parsed.get("args", []), entry)
	var handler_result: Dictionary = handler_result_variant if handler_result_variant is Dictionary else {}
	return _merge_results(command_result, handler_result)


func navigate_history(direction: int, current_text: String) -> String:
	if not _active or _history.is_empty():
		return current_text

	var step := 0

	if direction < 0:
		step = -1
	elif direction > 0:
		step = 1
	else:
		return current_text

	if _history_index < 0:
		_history_draft = current_text
		_history_index = _history.size()

	_history_index = clampi(_history_index + step, 0, _history.size())

	if _history_index >= _history.size():
		return _history_draft

	return _history[_history_index]


func _register_commands() -> void:
	_register_command(
		"help",
		"_cmd_help",
		"Основное",
		"Показать все команды или подробную помощь по одной.",
		["/help", "/help <команда>"],
		["?"]
	)
	_register_command(
		"exit",
		"_cmd_exit",
		"Основное",
		"Выключить dev-консоль и вернуть обычный чат арендодателя.",
		["/exit"],
		["close"]
	)
	_register_command(
		"clear",
		"_cmd_clear",
		"Основное",
		"Очистить историю сообщений dev-консоли.",
		["/clear"]
	)
	_register_command(
		"echo",
		"_cmd_echo",
		"Основное",
		"Вернуть переданный текст обратно в консоль.",
		["/echo <text>"]
	)
	_register_command(
		"version",
		"_cmd_version",
		"Основное",
		"Показать информацию о сборке, движке и runtime-сцене.",
		["/version"]
	)
	_register_command(
		"stats",
		"_cmd_stats",
		"Игрок",
		"Краткая сводка по HP, голоду, энергии, деньгам и времени.",
		["/stats"]
	)
	_register_command(
		"hp",
		"_cmd_hp",
		"Игрок",
		"Показать или изменить HP игрока.",
		["/hp", "/hp set <value>", "/hp add <value>", "/hp sub <value>"]
	)
	_register_command(
		"energy",
		"_cmd_energy",
		"Игрок",
		"Показать или изменить энергию игрока.",
		["/energy", "/energy set <value>", "/energy add <value>", "/energy sub <value>"]
	)
	_register_command(
		"hunger",
		"_cmd_hunger",
		"Игрок",
		"Показать или изменить голод игрока.",
		["/hunger", "/hunger set <value>", "/hunger add <value>", "/hunger sub <value>"]
	)
	_register_command(
		"hygiene",
		"_cmd_hygiene",
		"РРіСЂРѕРє",
		"РџРѕРєР°Р·Р°С‚СЊ РёР»Рё РёР·РјРµРЅРёС‚СЊ СЃРєСЂС‹С‚СѓСЋ РіРёРіРёРµРЅСѓ РїРµСЂСЃРѕРЅР°Р¶Р°.",
		["/hygiene", "/hygiene set <value>", "/hygiene add <value>", "/hygiene sub <value>"]
	)
	_register_command(
		"mood",
		"_cmd_mood",
		"Игрок",
		"Показать или изменить настроение персонажа.",
		["/mood", "/mood set <value>", "/mood add <value>", "/mood sub <value>"]
	)
	_register_command(
		"stress",
		"_cmd_stress",
		"Игрок",
		"Показать или изменить текущий стресс персонажа.",
		["/stress", "/stress set <value>", "/stress add <value>", "/stress sub <value>"]
	)
	_register_command(
		"mental",
		"_cmd_mental",
		"Игрок",
		"Показать подробный debug-срез настроения, стресса и активных mental-модификаторов.",
		["/mental"]
	)
	_register_command(
		"money",
		"_cmd_money",
		"Игрок",
		"Показать или изменить наличные деньги игрока.",
		["/money", "/money set <value>", "/money add <value>", "/money sub <value>"]
	)
	_register_command(
		"bank",
		"_cmd_bank",
		"Игрок",
		"Показать или изменить баланс в банке.",
		["/bank", "/bank set <value>", "/bank add <value>", "/bank sub <value>"]
	)
	_register_command(
		"time",
		"_cmd_time",
		"Время",
		"Показать время, установить часы или промотать вперёд.",
		["/time", "/time set <hour> <minute>", "/time add <hours>", "/time pause", "/time resume"]
	)
	_register_command(
		"day",
		"_cmd_day",
		"Время",
		"Показать или установить текущий игровой день.",
		["/day", "/day set <value>"]
	)
	_register_command(
		"where",
		"_cmd_where",
		"Локация",
		"Показать текущую игровую локацию и активную runtime-сцену.",
		["/where"]
	)
	_register_command(
		"pos",
		"_cmd_pos",
		"Локация",
		"Показать текущие координаты игрока или последний сохранённый runtime-снимок.",
		["/pos"]
	)
	_register_command(
		"rooms",
		"_cmd_rooms",
		"Локация",
		"Показать доступные room id для быстрого телепорта.",
		["/rooms"]
	)
	_register_command(
		"tp",
		"_cmd_tp",
		"Локация",
		"Поставить игрока в координаты или сменить целевую локацию.",
		["/tp <x> <y>", "/tp <location_id_or_name>"]
	)
	_register_command(
		"reload",
		"_cmd_reload",
		"Локация",
		"Перезагрузить текущую игровую комнату.",
		["/reload"]
	)
	_register_command(
		"save",
		"_cmd_save",
		"Состояние",
		"Быстрое dev-сохранение в резервный слот консоли.",
		["/save"]
	)
	_register_command(
		"load",
		"_cmd_load",
		"Состояние",
		"Загрузить dev-сохранение или последнее доступное.",
		["/load", "/load latest"]
	)
	_register_command(
		"quest",
		"_cmd_quest",
		"Состояние",
		"Показать или изменить текущую основную цель истории.",
		["/quest", "/quest list", "/quest set <title> [description] [detail...]", "/quest clear"]
	)
	_register_command(
		"rent",
		"_cmd_rent",
		"Состояние",
		"Показать состояние аренды или попробовать оплатить её.",
		["/rent", "/rent pay"]
	)
	_register_command(
		"inv",
		"_cmd_inv",
		"Инвентарь",
		"Показать содержимое инвентаря игрока.",
		["/inv"]
	)
	_register_command(
		"item",
		"_cmd_item",
		"Инвентарь",
		"Добавить, убрать или перечислить доступные предметы.",
		["/item add <id> [count]", "/item remove <id> [count]", "/item list [filter]"]
	)
	_register_command(
		"fridge",
		"_cmd_fridge",
		"Инвентарь",
		"Показать содержимое холодильника.",
		["/fridge"]
	)
	_register_command(
		"delivery",
		"_cmd_delivery",
		"Инвентарь",
		"Показать активные и завершённые доставки.",
		["/delivery"]
	)
	_register_command(
		"orders",
		"_cmd_orders",
		"Фриланс",
		"Показать доступные заказы фриланса.",
		["/orders"]
	)
	_register_command(
		"order",
		"_cmd_order",
		"Фриланс",
		"Запустить, завершить или провалить конкретный заказ.",
		["/order start <id>", "/order finish <id> <accuracy>", "/order fail <id>"]
	)
	_register_command(
		"debug",
		"_cmd_debug",
		"Отладка",
		"Краткий debug-срез по игроку, сцене, аренде, фрилансу или save-слою.",
		["/debug player", "/debug scene", "/debug rent", "/debug freelance", "/debug save"]
	)


func _register_command(
	name: String,
	handler_name: String,
	group_name: String,
	summary: String,
	usage_lines: Array,
	aliases: Array = []
) -> void:
	var normalized_name: String = name.strip_edges().to_lower()

	if normalized_name.is_empty():
		return

	var normalized_usage: Array[String] = []

	for usage_line in usage_lines:
		var text: String = String(usage_line).strip_edges()

		if text.is_empty():
			continue

		normalized_usage.append(text)

	var normalized_aliases: Array[String] = []

	for alias_value in aliases:
		var alias_text: String = String(alias_value).strip_edges().to_lower()

		if alias_text.is_empty():
			continue

		normalized_aliases.append(alias_text)
		_aliases[alias_text] = normalized_name

	_commands[normalized_name] = {
		"name": normalized_name,
		"handler": handler_name,
		"group": group_name,
		"summary": summary.strip_edges(),
		"usage": normalized_usage,
		"aliases": normalized_aliases,
	}
	_command_order.append(normalized_name)


func _cmd_help(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		var result := _base_result()
		_append_console_message(result, "Доступные команды.\nДля подробностей: /help <команда>")

		for group_name in GROUP_ORDER:
			var commands_in_group: Array[String] = []

			for command_name in _command_order:
				var grouped_command_entry: Dictionary = _commands.get(command_name, {})

				if String(grouped_command_entry.get("group", "")) != group_name:
					continue

				commands_in_group.append(
					"/%s - %s" % [
						command_name,
						String(grouped_command_entry.get("summary", "")).strip_edges(),
					]
				)

			if commands_in_group.is_empty():
				continue

			_append_console_message(result, "%s\n%s" % [group_name, "\n".join(commands_in_group)])

		return result

	var requested_name: String = _resolve_command_name(String(args[0]).to_lower())

	if requested_name.is_empty():
		return _reply("Команда '%s' не найдена. Введите /help." % String(args[0]))

	var requested_command_entry: Dictionary = _commands.get(requested_name, {})
	var usage_lines: Array = requested_command_entry.get("usage", [])
	var aliases: Array = requested_command_entry.get("aliases", [])
	var lines: Array[String] = [
		"/%s" % requested_name,
		String(requested_command_entry.get("summary", "")).strip_edges(),
	]

	if not usage_lines.is_empty():
		lines.append("Синтаксис:")

		for usage_line in usage_lines:
			lines.append("- %s" % String(usage_line))

	if not aliases.is_empty():
		lines.append("Алиасы: %s" % ", ".join(PackedStringArray(aliases)))

	return _reply("\n".join(lines))


func _cmd_exit(_args: Array, _entry: Dictionary) -> Dictionary:
	var result := _reply("Dev-консоль отключена. Чат арендодателя возвращён в обычный режим.")
	result["deactivate_console"] = true
	return result


func _cmd_clear(_args: Array, _entry: Dictionary) -> Dictionary:
	var result := _reply("История dev-консоли очищена.")
	result["clear_messages"] = true
	return result


func _cmd_echo(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		return _reply("Использование: /echo <text>")

	return _reply("echo: %s" % " ".join(PackedStringArray(_stringify_args(args))))


func _cmd_version(_args: Array, _entry: Dictionary) -> Dictionary:
	var tree := _get_scene_tree()
	var current_scene_path := ""

	if tree != null and tree.current_scene != null:
		current_scene_path = tree.current_scene.scene_file_path

	var version_info: Dictionary = Engine.get_version_info()
	var lines: Array[String] = [
		"Игра: %s" % String(ProjectSettings.get_setting("application/config/name", "Unknown")),
		"Godot: %s" % String(version_info.get("string", "unknown")),
		"Билд: %s" % ("debug" if OS.is_debug_build() else "release"),
	]

	if not current_scene_path.is_empty():
		lines.append("Runtime scene: %s" % current_scene_path)

	return _reply("\n".join(lines))


func _cmd_stats(_args: Array, _entry: Dictionary) -> Dictionary:
	var stats: Dictionary = _get_player_stats()

	if stats.is_empty():
		return _reply("Система PlayerStats недоступна.")

	var time_data: Dictionary = _get_time_snapshot()
	var room_scene_path: String = _get_runtime_room_scene_path()
	var mental_snapshot := _get_mental_state_snapshot()
	var lines: Array[String] = [
		"HP: %d/%d" % [int(stats.get("hp", 0)), int(stats.get("max_hp", 0))],
		"Энергия: %s/%s" % [
			_format_float(float(stats.get("energy", 0.0))),
			_format_float(float(stats.get("max_energy", 0.0))),
		],
		"Голод: %d/%d" % [int(stats.get("hunger", 0)), int(stats.get("max_hunger", 0))],
		"Наличные: $%d" % _get_cash_dollars(),
		"Банк: $%d" % _get_bank_dollars(),
	]

	if not mental_snapshot.is_empty():
		var mood_state := SaveDataUtils.sanitize_dictionary(mental_snapshot.get("mood_state", {}))
		var stress_state := SaveDataUtils.sanitize_dictionary(mental_snapshot.get("stress_state", {}))
		lines.append(
			"Настроение: %s/100 [%s]" % [
				_format_float(float(mental_snapshot.get("mood", 0.0))),
				String(mood_state.get("id", "normal")),
			]
		)
		lines.append(
			"Стресс: %s/100 [%s]" % [
				_format_float(float(mental_snapshot.get("stress", 0.0))),
				String(stress_state.get("id", "calm")),
			]
		)

	if not time_data.is_empty():
		lines.append("Время: %s" % _format_time_data(time_data))

	if not room_scene_path.is_empty():
		lines.append("Локация: %s" % SaveDataUtils.format_room_name(room_scene_path))

	return _reply("\n".join(lines))


func _cmd_hp(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_player_stat_command("hp", args)


func _cmd_energy(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_player_stat_command("energy", args)


func _cmd_hunger(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_player_stat_command("hunger", args)


func _cmd_hygiene(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_player_stat_command("hygiene", args)


func _cmd_mood(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_mental_stat_command("mood", args)


func _cmd_stress(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_mental_stat_command("stress", args)


func _cmd_mental(_args: Array, _entry: Dictionary) -> Dictionary:
	var mental_snapshot := _get_mental_state_snapshot()

	if mental_snapshot.is_empty():
		return _reply("Система PlayerMentalState недоступна.")

	var mood_state := SaveDataUtils.sanitize_dictionary(mental_snapshot.get("mood_state", {}))
	var stress_state := SaveDataUtils.sanitize_dictionary(mental_snapshot.get("stress_state", {}))
	var modifiers: Array = SaveDataUtils.sanitize_array(mental_snapshot.get("active_modifiers", []))
	var lines: Array[String] = [
		"Настроение: %s/100 [%s]" % [
			_format_float(float(mental_snapshot.get("mood", 0.0))),
			String(mood_state.get("title", mood_state.get("id", "normal"))),
		],
		"Стресс: %s/100 [%s]" % [
			_format_float(float(mental_snapshot.get("stress", 0.0))),
			String(stress_state.get("title", stress_state.get("id", "calm"))),
		],
	]

	if modifiers.is_empty():
		lines.append("Активные модификаторы: нет")
	else:
		lines.append("Активные модификаторы:")

		for modifier_variant in modifiers:
			if not (modifier_variant is Dictionary):
				continue

			var modifier: Dictionary = modifier_variant
			var remaining_minutes := int(modifier.get("remaining_minutes", -1))
			var remaining_text := "постоянно" if remaining_minutes < 0 else "%d мин." % remaining_minutes
			lines.append(
				"- %s | mood %s/h | stress %s/h | %s" % [
					String(modifier.get("title", modifier.get("id", "modifier"))),
					_format_float(float(modifier.get("mood_delta_per_hour", 0.0))),
					_format_float(float(modifier.get("stress_delta_per_hour", 0.0))),
					remaining_text,
				]
			)

	return _reply("\n".join(lines))


func _cmd_money(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_money_command("cash", args)


func _cmd_bank(args: Array, _entry: Dictionary) -> Dictionary:
	return _handle_money_command("bank", args)


func _cmd_time(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		var time_data: Dictionary = _get_time_snapshot()

		if time_data.is_empty():
			return _reply("Система времени недоступна.")

		return _reply("Игровое время: %s" % _format_time_data(time_data))

	var mode: String = String(args[0]).to_lower()

	match mode:
		"set":
			if args.size() != 3:
				return _reply("Использование: /time set <hour> <minute>")

			var hour_result := _parse_int_value(args[1], "hour")
			var minute_result := _parse_int_value(args[2], "minute")

			if not bool(hour_result.get("ok", false)):
				return _reply(String(hour_result.get("error", "Некорректный час.")))

			if not bool(minute_result.get("ok", false)):
				return _reply(String(minute_result.get("error", "Некорректные минуты.")))

			var hours: int = int(hour_result.get("value", 0))
			var minutes: int = int(minute_result.get("value", 0))

			if hours < 0 or hours > 23 or minutes < 0 or minutes > 59:
				return _reply("Время должно быть в диапазоне 00:00-23:59.")

			GameTime.set_time(hours, minutes)
			return _reply("Время установлено: %s" % _format_time_data(_get_time_snapshot()))
		"add":
			if args.size() != 2:
				return _reply("Использование: /time add <hours>")

			var hours_result := _parse_float_value(args[1], "hours")

			if not bool(hours_result.get("ok", false)):
				return _reply(String(hours_result.get("error", "Некорректное смещение времени.")))

			var added_minutes: int = int(round(float(hours_result.get("value", 0.0)) * 60.0))

			if added_minutes == 0:
				return _reply("Смещение времени равно 0.")

			GameTime.advance_minutes(added_minutes)
			return _reply("Время сдвинуто: %s" % _format_time_data(_get_time_snapshot()))
		"pause":
			GameTime.set_clock_paused(true)
			return _reply("Игровые часы поставлены на паузу.")
		"resume":
			GameTime.set_clock_paused(false)
			return _reply("Игровые часы снова идут.")
		_:
			return _reply("Неизвестный режим для /time. Доступно: set, add, pause, resume.")


func _cmd_day(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		return _reply("Текущий день: %d" % int(GameTime.get_day()))

	if args.size() != 2 or String(args[0]).to_lower() != "set":
		return _reply("Использование: /day set <value>")

	var day_result := _parse_int_value(args[1], "day")

	if not bool(day_result.get("ok", false)):
		return _reply(String(day_result.get("error", "Некорректный день.")))

	var next_day: int = int(day_result.get("value", 0))

	if next_day <= 0:
		return _reply("День должен быть положительным числом.")

	GameTime.set_time(GameTime.get_hours(), GameTime.get_minutes(), next_day)
	return _reply("Текущий день установлен: %d" % next_day)


func _handle_player_stat_command(stat_name: String, args: Array) -> Dictionary:
	var stats: Dictionary = _get_player_stats()

	if stats.is_empty():
		return _reply("Система PlayerStats недоступна.")

	var current_value: float = float(stats.get(stat_name, 0.0))
	var max_key: String = "max_%s" % stat_name
	var max_value: float = float(stats.get(max_key, 0.0))
	var display_name: String = _get_stat_display_name(stat_name)

	if stat_name == "hygiene":
		display_name = "Гигиена"

	if args.is_empty():
		return _reply("%s: %s/%s" % [
			display_name,
			_format_stat_value(stat_name, current_value),
			_format_stat_value(stat_name, max_value),
		])

	if args.size() != 2:
		return _reply("Использование: /%s <set|add|sub> <value>" % stat_name)

	var mode: String = String(args[0]).to_lower()
	var value_result := _parse_float_value(args[1], "value")

	if not bool(value_result.get("ok", false)):
		return _reply(String(value_result.get("error", "Некорректное значение.")))

	var numeric_value: float = float(value_result.get("value", 0.0))
	var next_value: float = current_value

	match mode:
		"set":
			next_value = numeric_value
		"add":
			next_value = current_value + numeric_value
		"sub":
			next_value = current_value - numeric_value
		_:
			return _reply("Неизвестный режим для /%s. Доступно: set, add, sub." % stat_name)

	next_value = clampf(next_value, 0.0, max_value)
	var delta_value: float = next_value - current_value

	if absf(delta_value) <= 0.0001:
		return _reply("%s не изменён: %s/%s" % [
			display_name,
			_format_stat_value(stat_name, current_value),
			_format_stat_value(stat_name, max_value),
		])

	var delta: Dictionary = {}

	match stat_name:
		"hp":
			delta["hp"] = int(round(delta_value))
		"hunger":
			delta["hunger"] = int(round(delta_value))
		"energy":
			delta["energy"] = delta_value
		"hygiene":
			delta["hygiene"] = int(round(delta_value))

	PlayerStats.apply_delta(delta, StringName("dev_console_%s" % stat_name))
	var updated_stats: Dictionary = _get_player_stats()

	return _reply("%s: %s/%s" % [
		display_name,
		_format_stat_value(stat_name, float(updated_stats.get(stat_name, 0.0))),
		_format_stat_value(stat_name, float(updated_stats.get(max_key, 0.0))),
	])


func _handle_mental_stat_command(stat_name: String, args: Array) -> Dictionary:
	var mental_snapshot := _get_mental_state_snapshot()

	if mental_snapshot.is_empty() or PlayerMentalState == null:
		return _reply("Система PlayerMentalState недоступна.")

	var current_value: float = float(mental_snapshot.get(stat_name, 0.0))
	var max_value: float = float(mental_snapshot.get("max_value", 100.0))
	var display_name := "Настроение" if stat_name == "mood" else "Стресс"

	if args.is_empty():
		return _reply("%s: %s/%s" % [
			display_name,
			_format_float(current_value),
			_format_float(max_value),
		])

	if args.size() != 2:
		return _reply("Использование: /%s <set|add|sub> <value>" % stat_name)

	var mode: String = String(args[0]).to_lower()
	var value_result := _parse_float_value(args[1], "value")

	if not bool(value_result.get("ok", false)):
		return _reply(String(value_result.get("error", "Некорректное значение.")))

	var numeric_value: float = float(value_result.get("value", 0.0))
	var next_value: float = current_value

	match mode:
		"set":
			next_value = numeric_value
		"add":
			next_value = current_value + numeric_value
		"sub":
			next_value = current_value - numeric_value
		_:
			return _reply("Неизвестный режим для /%s. Доступно: set, add, sub." % stat_name)

	next_value = clampf(next_value, 0.0, max_value)
	var delta_value: float = next_value - current_value

	if absf(delta_value) <= 0.0001:
		return _reply("%s не изменён: %s/%s" % [
			display_name,
			_format_float(current_value),
			_format_float(max_value),
		])

	if stat_name == "mood":
		PlayerMentalState.apply_delta(delta_value, 0.0, &"dev_console_mood", ["dev_console"])
	else:
		PlayerMentalState.apply_delta(0.0, delta_value, &"dev_console_stress", ["dev_console"])

	var updated_snapshot := _get_mental_state_snapshot()
	return _reply("%s: %s/%s" % [
		display_name,
		_format_float(float(updated_snapshot.get(stat_name, 0.0))),
		_format_float(float(updated_snapshot.get("max_value", max_value))),
	])


func _handle_money_command(wallet_type: String, args: Array) -> Dictionary:
	var display_name: String = "Наличные" if wallet_type == "cash" else "Банк"
	var current_value: int = _get_cash_dollars() if wallet_type == "cash" else _get_bank_dollars()

	if args.is_empty():
		return _reply("%s: $%d" % [display_name, current_value])

	if args.size() != 2:
		return _reply("Использование: /%s <set|add|sub> <value>" % wallet_type)

	var mode: String = String(args[0]).to_lower()
	var value_result := _parse_int_value(args[1], "value")

	if not bool(value_result.get("ok", false)):
		return _reply(String(value_result.get("error", "Некорректная сумма.")))

	var amount: int = int(value_result.get("value", 0))

	if amount < 0:
		return _reply("Сумма не может быть отрицательной.")

	match wallet_type:
		"cash":
			match mode:
				"set":
					PlayerEconomy.set_cash_dollars(amount)
				"add":
					PlayerEconomy.add_cash_dollars(amount, false)
				"sub":
					if not PlayerEconomy.spend_cash_dollars(amount, false):
						return _reply("Недостаточно наличных для списания.")
				_:
					return _reply("Неизвестный режим для /money. Доступно: set, add, sub.")
		"bank":
			match mode:
				"set":
					PlayerEconomy.set_bank_dollars(amount)
				"add":
					PlayerEconomy.add_bank_dollars(amount, false)
				"sub":
					if not PlayerEconomy.remove_bank_dollars(amount, false):
						return _reply("Недостаточно денег на банковском счёте.")
				_:
					return _reply("Неизвестный режим для /bank. Доступно: set, add, sub.")

	var updated_value: int = _get_cash_dollars() if wallet_type == "cash" else _get_bank_dollars()
	return _reply("%s: $%d" % [display_name, updated_value])


func _cmd_where(_args: Array, _entry: Dictionary) -> Dictionary:
	var room_scene_path: String = _get_runtime_room_scene_path()
	var lines: Array[String] = []

	if room_scene_path.is_empty():
		lines.append("Текущая локация не определена.")
	else:
		lines.append("Локация: %s" % SaveDataUtils.format_room_name(room_scene_path))
		lines.append("Room scene: %s" % room_scene_path)

	var tree := _get_scene_tree()

	if tree != null and tree.current_scene != null:
		lines.append("Runtime scene: %s" % tree.current_scene.scene_file_path)

	return _reply("\n".join(lines))


func _cmd_pos(_args: Array, _entry: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _get_runtime_world_snapshot()
	var player_data: Dictionary = SaveDataUtils.sanitize_dictionary(snapshot.get("player", {}))

	if player_data.is_empty():
		return _reply("Позиция игрока недоступна.")

	var position: Vector2 = SaveDataUtils.dict_to_vector2(player_data.get("position", {}), Vector2.ZERO)
	var lines: Array[String] = [
		"Позиция игрока: x=%s y=%s" % [_format_float(position.x), _format_float(position.y)],
	]

	if player_data.has("grid_cell"):
		var grid_cell: Vector2i = SaveDataUtils.dict_to_vector2i(player_data.get("grid_cell", {}), Vector2i.ZERO)
		lines.append("Grid cell: (%d, %d)" % [grid_cell.x, grid_cell.y])

	return _reply("\n".join(lines))


func _cmd_rooms(args: Array, _entry: Dictionary) -> Dictionary:
	_ensure_room_catalog_loaded()

	if _room_entries.is_empty():
		return _reply("Каталог комнат недоступен.")

	var filter_text: String = String(args[0]).to_lower() if not args.is_empty() else ""
	var lines: Array[String] = []

	for room_entry in _room_entries:
		var room_id: String = String(room_entry.get("id", ""))
		var display_name: String = String(room_entry.get("display_name", ""))
		var scene_path: String = String(room_entry.get("scene_path", ""))
		var haystack: String = "%s %s %s" % [room_id, display_name.to_lower(), scene_path.to_lower()]

		if not filter_text.is_empty() and not haystack.contains(filter_text):
			continue

		lines.append("%s -> %s" % [room_id, display_name])

	if lines.is_empty():
		return _reply("Комнаты по фильтру не найдены.")

	return _reply("Доступные комнаты:\n%s" % "\n".join(lines))


func _cmd_tp(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		return _reply("Использование: /tp <x> <y> или /tp <location_id_or_name>")

	var snapshot: Dictionary = _get_runtime_world_snapshot()

	if snapshot.is_empty():
		return _reply("Runtime snapshot мира недоступен. Сначала войдите в игру и откройте Le Chat заново.")

	if args.size() == 2 and _looks_like_number(args[0]) and _looks_like_number(args[1]):
		var x_result := _parse_float_value(args[0], "x")
		var y_result := _parse_float_value(args[1], "y")

		if not bool(x_result.get("ok", false)):
			return _reply(String(x_result.get("error", "Некорректная координата x.")))

		if not bool(y_result.get("ok", false)):
			return _reply(String(y_result.get("error", "Некорректная координата y.")))

		var player_data: Dictionary = SaveDataUtils.sanitize_dictionary(snapshot.get("player", {}))
		player_data["position"] = SaveDataUtils.vector2_to_dict(
			Vector2(float(x_result.get("value", 0.0)), float(y_result.get("value", 0.0)))
		)
		player_data.erase("grid_cell")
		snapshot["player"] = player_data
		var applied_immediately: bool = _commit_runtime_world_snapshot(snapshot)

		return _reply(
			"Новая позиция игрока: x=%s y=%s%s" % [
				_format_float(float(x_result.get("value", 0.0))),
				_format_float(float(y_result.get("value", 0.0))),
				_build_apply_suffix(applied_immediately),
			]
		)

	var target_room_path: String = _resolve_room_scene_path(" ".join(PackedStringArray(_stringify_args(args))))

	if target_room_path.is_empty():
		return _reply("Локация не найдена. Посмотрите /rooms.")

	snapshot["room_scene_path"] = target_room_path
	snapshot["player"] = {}
	var applied_to_room: bool = _commit_runtime_world_snapshot(snapshot)

	return _reply(
		"Целевая локация переключена на %s%s" % [
			SaveDataUtils.format_room_name(target_room_path),
			_build_apply_suffix(applied_to_room),
		]
	)


func _cmd_reload(_args: Array, _entry: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _get_runtime_world_snapshot()

	if snapshot.is_empty():
		return _reply("Runtime snapshot недоступен, перезагрузка невозможна.")

	var applied_immediately: bool = _commit_runtime_world_snapshot(snapshot)
	return _reply("Текущая комната будет перезагружена%s" % _build_apply_suffix(applied_immediately))


func _cmd_save(_args: Array, _entry: Dictionary) -> Dictionary:
	if SaveManager.save_to_manual_slot(DEV_SAVE_SLOT):
		return _reply("Dev-сохранение записано в слот %d." % DEV_SAVE_SLOT)

	return _reply("Сохранение не выполнено. Проверьте, доступен ли runtime snapshot мира.")


func _cmd_load(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		if SaveManager.has_slot(SaveManager.MANUAL_SLOT_KIND, DEV_SAVE_SLOT):
			SaveManager.request_load_slot(SaveManager.MANUAL_SLOT_KIND, DEV_SAVE_SLOT)
			return _reply("Загрузка dev-слота %d запрошена." % DEV_SAVE_SLOT)

		SaveManager.request_load_latest_save()
		return _reply("Dev-слот не найден. Запрошена загрузка последнего сохранения.")

	if args.size() == 1 and String(args[0]).to_lower() == "latest":
		SaveManager.request_load_latest_save()
		return _reply("Запрошена загрузка последнего сохранения.")

	return _reply("Использование: /load или /load latest")


func _cmd_quest(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty() or String(args[0]).to_lower() == "list":
		var quest: Dictionary = StoryState.get_current_quest()

		if quest.is_empty():
			return _reply("Активная цель истории отсутствует.")

		return _reply(_format_quest(quest))

	var mode: String = String(args[0]).to_lower()

	match mode:
		"set":
			if args.size() < 2:
				return _reply("Использование: /quest set <title> [description] [detail...]")

			var title: String = String(args[1]).strip_edges()
			var description := String(args[2]).strip_edges() if args.size() >= 3 else ""
			var extra_details: Array[String] = []

			for index in range(3, args.size()):
				var detail_text: String = String(args[index]).strip_edges()

				if detail_text.is_empty():
					continue

				extra_details.append(detail_text)

			StoryState.set_current_quest(title, description, {}, extra_details)
			return _reply("Текущая цель обновлена.\n%s" % _format_quest(StoryState.get_current_quest()))
		"clear":
			StoryState.clear_current_quest()
			return _reply("Текущая цель очищена.")
		_:
			return _reply("Неизвестный режим для /quest. Доступно: list, set, clear.")


func _cmd_rent(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		return _reply(_format_rent_snapshot(ApartmentRentState.get_current_rent_snapshot()))

	if args.size() == 1 and String(args[0]).to_lower() == "pay":
		var result: Dictionary = ApartmentRentState.pay_current_rent()
		var message: String = String(result.get("message", "")).strip_edges()

		if message.is_empty():
			message = "Результат оплаты аренды обновлён."

		return _reply("%s\n%s" % [message, _format_rent_snapshot(ApartmentRentState.get_current_rent_snapshot())])

	return _reply("Использование: /rent или /rent pay")


func _cmd_inv(_args: Array, _entry: Dictionary) -> Dictionary:
	return _reply(_format_inventory("Инвентарь игрока", PlayerInventory.get_slots()))


func _cmd_item(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		return _reply("Использование: /item add <id> [count], /item remove <id> [count], /item list [filter]")

	var mode: String = String(args[0]).to_lower()

	match mode:
		"list":
			var filter_text := String(args[1]).to_lower() if args.size() >= 2 else ""
			return _reply(_format_item_catalog(filter_text))
		"add":
			if args.size() < 2 or args.size() > 3:
				return _reply("Использование: /item add <id> [count]")

			var item_data: ItemData = _resolve_item_data(String(args[1]))

			if item_data == null:
				return _reply("Предмет не найден.")

			var count: int = 1

			if args.size() == 3:
				var count_result := _parse_int_value(args[2], "count")

				if not bool(count_result.get("ok", false)):
					return _reply(String(count_result.get("error", "Некорректное количество.")))

				count = int(count_result.get("value", 0))

			if count <= 0:
				return _reply("Количество должно быть положительным.")

			if not PlayerInventory.add_item(item_data, count):
				return _reply("Не удалось добавить предмет. Возможно, в инвентаре нет места.")

			return _reply("Добавлено: %s x%d" % [item_data.get_display_name(), count])
		"remove":
			if args.size() < 2 or args.size() > 3:
				return _reply("Использование: /item remove <id> [count]")

			var target_item: ItemData = _resolve_item_data(String(args[1]))

			if target_item == null:
				return _reply("Предмет не найден.")

			var remove_count: int = 1

			if args.size() == 3:
				var remove_result := _parse_int_value(args[2], "count")

				if not bool(remove_result.get("ok", false)):
					return _reply(String(remove_result.get("error", "Некорректное количество.")))

				remove_count = int(remove_result.get("value", 0))

			if remove_count <= 0:
				return _reply("Количество должно быть положительным.")

			var removed_count: int = _remove_inventory_item(PlayerInventory, target_item, remove_count)

			if removed_count <= 0:
				return _reply("Предмета нет в инвентаре.")

			return _reply("Удалено: %s x%d" % [target_item.get_display_name(), removed_count])
		_:
			return _reply("Неизвестный режим для /item. Доступно: add, remove, list.")


func _cmd_fridge(_args: Array, _entry: Dictionary) -> Dictionary:
	return _reply(_format_inventory("Холодильник", FridgeInventory.get_slots()))


func _cmd_delivery(_args: Array, _entry: Dictionary) -> Dictionary:
	var active_deliveries: Array = DeliveryManager.get_active_deliveries()
	var completed_deliveries: Array = DeliveryManager.get_delivered_deliveries()
	var lines: Array[String] = []

	if active_deliveries.is_empty():
		lines.append("Активных доставок нет.")
	else:
		lines.append("Активные доставки:")

		for delivery_variant in active_deliveries:
			var delivery: Dictionary = delivery_variant if delivery_variant is Dictionary else {}

			if delivery.is_empty():
				continue

			lines.append(
				"- #%d, осталось %d мин., статус: %s" % [
					int(delivery.get("id", -1)),
					DeliveryManager.get_remaining_minutes(delivery),
					String(delivery.get("status", "unknown")),
				]
			)

	if completed_deliveries.is_empty():
		lines.append("Завершённых доставок нет.")
	else:
		lines.append("Завершённых доставок: %d" % completed_deliveries.size())

	return _reply("\n".join(lines))


func _cmd_orders(_args: Array, _entry: Dictionary) -> Dictionary:
	var orders: Array = FreelanceState.get_current_orders()

	if orders.is_empty():
		return _reply("Заказы фриланса сейчас не сгенерированы.")

	var lines: Array[String] = ["Заказы фриланса:"]

	for order_variant in orders:
		var order: Dictionary = order_variant if order_variant is Dictionary else {}

		if order.is_empty():
			continue

		lines.append(
			"- #%d %s | %s | статус: %s | награда: $%d" % [
				int(order.get("id", -1)),
				String(order.get("title", "Без названия")),
				String(order.get("difficulty", "unknown")),
				String(order.get("status", "unknown")),
				int(order.get("reward_final_estimate", order.get("reward_base", 0))),
			]
		)

	return _reply("\n".join(lines))


func _cmd_order(args: Array, _entry: Dictionary) -> Dictionary:
	if args.size() < 2:
		return _reply("Использование: /order start <id>, /order finish <id> <accuracy>, /order fail <id>")

	var mode: String = String(args[0]).to_lower()
	var id_result := _parse_int_value(args[1], "id")

	if not bool(id_result.get("ok", false)):
		return _reply(String(id_result.get("error", "Некорректный id заказа.")))

	var order_id: int = int(id_result.get("value", 0))
	var result: Dictionary = {}

	match mode:
		"start":
			if args.size() != 2:
				return _reply("Использование: /order start <id>")

			result = FreelanceState.start_order(order_id)
		"finish":
			if args.size() != 3:
				return _reply("Использование: /order finish <id> <accuracy>")

			var accuracy_result := _parse_float_value(args[2], "accuracy")

			if not bool(accuracy_result.get("ok", false)):
				return _reply(String(accuracy_result.get("error", "Некорректная точность.")))

			var accuracy_value: float = float(accuracy_result.get("value", 0.0))

			if accuracy_value > 1.0:
				accuracy_value /= 100.0

			result = FreelanceState.finish_order(order_id, accuracy_value)
		"fail":
			if args.size() != 2:
				return _reply("Использование: /order fail <id>")

			result = FreelanceState.fail_order(order_id)
		_:
			return _reply("Неизвестный режим для /order. Доступно: start, finish, fail.")

	var message: String = String(result.get("message", "")).strip_edges()

	if message.is_empty():
		message = "Команда выполнена." if bool(result.get("success", false)) else "Операция не выполнена."

	return _reply(message)


func _cmd_debug(args: Array, _entry: Dictionary) -> Dictionary:
	if args.is_empty():
		return _reply("Использование: /debug player|scene|rent|freelance|save")

	match String(args[0]).to_lower():
		"player":
			return _reply(_format_debug_player())
		"scene":
			return _reply(_format_debug_scene())
		"rent":
			return _reply(_format_dictionary_block("ApartmentRentState", ApartmentRentState.get_debug_snapshot(), 6))
		"freelance":
			return _reply(_format_dictionary_block("FreelanceState", FreelanceState.get_debug_snapshot(), 6))
		"save":
			return _reply(_format_debug_save())
		_:
			return _reply("Неизвестный раздел debug. Доступно: player, scene, rent, freelance, save.")


func _base_result() -> Dictionary:
	return {
		"handled": true,
		"append_player_message": false,
		"player_text": "",
		"messages": [],
		"clear_messages": false,
		"deactivate_console": false,
	}


func _reply(text: String) -> Dictionary:
	var result := _base_result()
	_append_console_message(result, text)
	return result


func _error_response(text: String, append_player_message := false, player_text: String = "") -> Dictionary:
	var result := _reply(text)
	result["append_player_message"] = append_player_message
	result["player_text"] = player_text
	return result


func _merge_results(base_result: Dictionary, extra_result: Dictionary) -> Dictionary:
	var merged: Dictionary = base_result.duplicate(true)
	var extra_messages: Array = extra_result.get("messages", [])
	var merged_messages: Array = merged.get("messages", [])

	for message in extra_messages:
		merged_messages.append(String(message))

	merged["messages"] = merged_messages

	if bool(extra_result.get("append_player_message", false)):
		merged["append_player_message"] = true
		merged["player_text"] = String(extra_result.get("player_text", ""))

	if bool(extra_result.get("clear_messages", false)):
		merged["clear_messages"] = true

	if bool(extra_result.get("deactivate_console", false)):
		merged["deactivate_console"] = true

	return merged


func _append_console_message(result: Dictionary, text: String) -> void:
	var trimmed_text: String = text.strip_edges()

	if trimmed_text.is_empty():
		return

	var messages: Array = result.get("messages", [])
	messages.append(trimmed_text)
	result["messages"] = messages


func _resolve_command_name(raw_name: String) -> String:
	var normalized_name: String = raw_name.strip_edges().to_lower()

	if normalized_name.is_empty():
		return ""

	if _commands.has(normalized_name):
		return normalized_name

	if _aliases.has(normalized_name):
		return String(_aliases.get(normalized_name, ""))

	return ""


func _push_history(text: String) -> void:
	if text.is_empty():
		return

	if _history.is_empty() or _history[_history.size() - 1] != text:
		_history.append(text)

	_reset_history_navigation()


func _reset_history_navigation() -> void:
	_history_index = -1
	_history_draft = ""


func _parse_command(text: String) -> Dictionary:
	var body: String = text.strip_edges()

	if body.begins_with("/"):
		body = body.substr(1)

	body = body.strip_edges()

	if body.is_empty():
		return {
			"ok": false,
			"error": "Пустая команда. Введите /help.",
		}

	var tokens_result: Dictionary = _tokenize_command_body(body)

	if not bool(tokens_result.get("ok", false)):
		return tokens_result

	var tokens: Array = tokens_result.get("tokens", [])

	if tokens.is_empty():
		return {
			"ok": false,
			"error": "Пустая команда. Введите /help.",
		}

	var args: Array = []

	for index in range(1, tokens.size()):
		args.append(String(tokens[index]))

	return {
		"ok": true,
		"name": String(tokens[0]),
		"args": args,
	}


func _tokenize_command_body(body: String) -> Dictionary:
	var tokens: Array[String] = []
	var current := ""
	var quote_char := ""
	var escaping := false

	for index in range(body.length()):
		var char_text: String = body.substr(index, 1)

		if escaping:
			current += char_text
			escaping = false
			continue

		if not quote_char.is_empty() and char_text == "\\":
			escaping = true
			continue

		if char_text == "\"" or char_text == "'":
			if quote_char.is_empty():
				quote_char = char_text
				continue

			if quote_char == char_text:
				quote_char = ""
				continue

			current += char_text
			continue

		if quote_char.is_empty() and (char_text == " " or char_text == "\t"):
			if not current.is_empty():
				tokens.append(current)
				current = ""

			continue

		current += char_text

	if escaping or not quote_char.is_empty():
		return {
			"ok": false,
			"error": "Команда содержит незакрытую строку.",
		}

	if not current.is_empty():
		tokens.append(current)

	return {
		"ok": true,
		"tokens": tokens,
	}


func _stringify_args(args: Array) -> Array[String]:
	var result: Array[String] = []

	for arg in args:
		result.append(String(arg))

	return result


func _parse_int_value(raw_value: Variant, label: String) -> Dictionary:
	var text: String = String(raw_value).strip_edges()

	if text.is_empty():
		return {
			"ok": false,
			"error": "Не указан аргумент %s." % label,
		}

	if not text.is_valid_int():
		return {
			"ok": false,
			"error": "Аргумент %s должен быть целым числом." % label,
		}

	return {
		"ok": true,
		"value": int(text),
	}


func _parse_float_value(raw_value: Variant, label: String) -> Dictionary:
	var text: String = String(raw_value).strip_edges().replace(",", ".")

	if text.is_empty():
		return {
			"ok": false,
			"error": "Не указан аргумент %s." % label,
		}

	if not text.is_valid_float() and not text.is_valid_int():
		return {
			"ok": false,
			"error": "Аргумент %s должен быть числом." % label,
		}

	return {
		"ok": true,
		"value": float(text),
	}


func _looks_like_number(raw_value: Variant) -> bool:
	var text: String = String(raw_value).strip_edges().replace(",", ".")
	return text.is_valid_int() or text.is_valid_float()


func _get_scene_tree() -> SceneTree:
	if _window == null or not is_instance_valid(_window):
		return null

	return _window.get_tree()


func _get_live_game_root() -> Node:
	var tree := _get_scene_tree()

	if tree == null or tree.current_scene == null:
		return null

	if tree.current_scene.scene_file_path != GAME_SCENE_PATH:
		return null

	return tree.current_scene


func _build_live_world_snapshot() -> Dictionary:
	var game_root := _get_live_game_root()

	if game_root == null or not game_root.has_method("build_save_data"):
		return {}

	var snapshot_variant: Variant = game_root.call("build_save_data")

	if snapshot_variant is Dictionary:
		var snapshot: Dictionary = (snapshot_variant as Dictionary).duplicate(true)

		if not snapshot.is_empty() and GameManager.has_method("set_runtime_world_snapshot"):
			GameManager.set_runtime_world_snapshot(snapshot)

		return snapshot

	return {}


func _get_runtime_world_snapshot() -> Dictionary:
	var live_snapshot: Dictionary = _build_live_world_snapshot()

	if not live_snapshot.is_empty():
		return live_snapshot

	if GameManager != null and GameManager.has_method("get_runtime_world_snapshot"):
		var snapshot_variant: Variant = GameManager.get_runtime_world_snapshot()

		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)

	return {}


func _commit_runtime_world_snapshot(snapshot: Dictionary) -> bool:
	var normalized_snapshot: Dictionary = SaveDataUtils.sanitize_dictionary(snapshot)

	if normalized_snapshot.is_empty():
		return false

	if GameManager != null and GameManager.has_method("set_runtime_world_snapshot"):
		GameManager.set_runtime_world_snapshot(normalized_snapshot)

	if GameManager != null and GameManager.has_method("queue_runtime_world_restore"):
		GameManager.queue_runtime_world_restore(normalized_snapshot)

	var game_root := _get_live_game_root()

	if game_root != null and game_root.has_method("apply_loaded_world_state"):
		game_root.call("apply_loaded_world_state", normalized_snapshot)
		return true

	return false


func _build_apply_suffix(applied_immediately: bool) -> String:
	return ". Применено сразу." if applied_immediately else ". Применится после выхода из рабочего стола."


func _get_runtime_room_scene_path() -> String:
	var snapshot: Dictionary = _get_runtime_world_snapshot()
	var room_scene_path: String = String(snapshot.get("room_scene_path", "")).strip_edges()

	if not room_scene_path.is_empty():
		return room_scene_path

	if GameManager != null and GameManager.has_method("get_current_room_scene_path"):
		return String(GameManager.get_current_room_scene_path()).strip_edges()

	return ""


func _get_time_snapshot() -> Dictionary:
	if GameTime == null or not GameTime.has_method("get_current_time_data"):
		return {}

	var snapshot_variant: Variant = GameTime.get_current_time_data()
	return snapshot_variant if snapshot_variant is Dictionary else {}


func _get_player_stats() -> Dictionary:
	if PlayerStats == null or not PlayerStats.has_method("get_stats"):
		return {}

	var stats_variant: Variant = PlayerStats.get_stats()
	var stats: Dictionary = stats_variant if stats_variant is Dictionary else {}

	if stats.is_empty():
		return stats

	if PlayerStats.has_method("get_hygiene_value"):
		stats["hygiene"] = int(PlayerStats.get_hygiene_value())

	if PlayerStats.has_method("get_max_hygiene_value"):
		stats["max_hygiene"] = int(PlayerStats.get_max_hygiene_value())

	if PlayerStats.has_method("get_hygiene_stage_id"):
		stats["hygiene_stage_id"] = String(PlayerStats.get_hygiene_stage_id())

	return stats


func _get_mental_state_snapshot() -> Dictionary:
	if PlayerMentalState == null or not PlayerMentalState.has_method("get_state"):
		return {}

	var snapshot_variant: Variant = PlayerMentalState.get_state()
	return snapshot_variant if snapshot_variant is Dictionary else {}


func _get_cash_dollars() -> int:
	return int(PlayerEconomy.get_cash_dollars()) if PlayerEconomy != null else 0


func _get_bank_dollars() -> int:
	return int(PlayerEconomy.get_bank_dollars()) if PlayerEconomy != null else 0


func _format_time_data(time_data: Dictionary) -> String:
	var day: int = int(time_data.get("day", 1))
	var hours: int = int(time_data.get("hours", 0))
	var minutes: int = int(time_data.get("minutes", 0))
	var paused_suffix: String = " [PAUSE]" if bool(time_data.get("clock_paused", GameTime.is_clock_paused())) else ""
	return "день %d, %02d:%02d%s" % [day, hours, minutes, paused_suffix]


func _format_float(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))

	return "%.2f" % value


func _get_stat_display_name(stat_name: String) -> String:
	match stat_name:
		"hp":
			return "HP"
		"energy":
			return "Энергия"
		"hunger":
			return "Голод"
		_:
			return stat_name.capitalize()


func _format_stat_value(stat_name: String, value: float) -> String:
	return _format_float(value) if stat_name == "energy" else "%d" % int(round(value))


func _format_quest(quest: Dictionary) -> String:
	if quest.is_empty():
		return "Цель не задана."

	var lines: Array[String] = ["Текущая цель: %s" % String(quest.get("title", "Без названия"))]
	var description: String = String(quest.get("description", "")).strip_edges()

	if not description.is_empty():
		lines.append(description)

	var details: Array = quest.get("details", [])

	for detail in details:
		lines.append("- %s" % String(detail))

	return "\n".join(lines)


func _format_rent_snapshot(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return "Состояние аренды недоступно."

	var amount: int = int(snapshot.get("rent_amount", snapshot.get("current_rent_amount", 0)))
	var lines: Array[String] = [
		"Аренда: $%d" % amount,
		"Due day: %d" % int(snapshot.get("due_day", 0)),
	]

	if bool(snapshot.get("is_overdue", false)):
		lines.append("Статус: просрочка (%d д.)" % int(snapshot.get("days_overdue", 0)))
	elif bool(snapshot.get("is_due", false)):
		lines.append("Статус: к оплате сегодня")
	elif bool(snapshot.get("can_pay", false)):
		lines.append("Статус: счёт активен")
	elif bool(snapshot.get("is_paid", false)):
		lines.append("Статус: оплачено")
	else:
		lines.append("Статус: ожидается")

	return "\n".join(lines)


func _format_inventory(title: String, slots: Array) -> String:
	var lines: Array[String] = [title + ":"]
	var item_lines: Array[String] = []

	for index in range(slots.size()):
		var slot: InventorySlotData = slots[index] as InventorySlotData

		if slot == null or slot.is_empty():
			continue

		var item_data: ItemData = slot.item_data
		var freshness_text: String = slot.get_freshness_text() if slot.has_freshness() else ""
		var freshness_suffix: String = " [%s]" % freshness_text if not freshness_text.is_empty() else ""
		item_lines.append(
			"- [%d] %s x%d%s" % [
				index,
				item_data.get_display_name(),
				slot.quantity,
				freshness_suffix,
			]
		)

	if item_lines.is_empty():
		lines.append("Пусто.")
	else:
		lines.append_array(item_lines)

	return "\n".join(lines)


func _ensure_item_catalog_loaded() -> void:
	if not _item_entries.is_empty():
		return

	var directory := DirAccess.open(ITEM_RESOURCE_DIRECTORY)

	if directory == null:
		return

	directory.list_dir_begin()

	while true:
		var file_name: String = directory.get_next()

		if file_name.is_empty():
			break

		if directory.current_is_dir() or not file_name.ends_with(".tres"):
			continue

		var resource_path: String = "%s/%s" % [ITEM_RESOURCE_DIRECTORY, file_name]
		var item_data: ItemData = load(resource_path) as ItemData

		if item_data == null:
			continue

		var item_id: String = String(item_data.id).strip_edges()

		if item_id.is_empty():
			item_id = file_name.get_basename()

		var entry := {
			"id": item_id,
			"display_name": item_data.get_display_name(),
			"resource_path": resource_path,
		}
		_item_entries.append(entry)
		_add_lookup_alias(_item_aliases, item_id, resource_path)
		_add_lookup_alias(_item_aliases, file_name.get_basename(), resource_path)
		_add_lookup_alias(_item_aliases, item_data.get_display_name(), resource_path)

	directory.list_dir_end()
	_item_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)


func _format_item_catalog(filter_text: String = "") -> String:
	_ensure_item_catalog_loaded()

	if _item_entries.is_empty():
		return "Каталог предметов недоступен."

	var lines: Array[String] = ["Доступные предметы:"]
	var shown_count := 0

	for item_entry in _item_entries:
		var item_id: String = String(item_entry.get("id", ""))
		var display_name: String = String(item_entry.get("display_name", ""))
		var haystack: String = "%s %s" % [item_id.to_lower(), display_name.to_lower()]

		if not filter_text.is_empty() and not haystack.contains(filter_text):
			continue

		lines.append("- %s -> %s" % [item_id, display_name])
		shown_count += 1
		if shown_count >= 20 and filter_text.is_empty():
			lines.append("... используйте /item list <filter>, чтобы сузить список.")
			break

	if shown_count <= 0:
		return "Предметы по фильтру не найдены."

	return "\n".join(lines)


func _resolve_item_data(raw_id: String) -> ItemData:
	_ensure_item_catalog_loaded()

	var normalized_key: String = _normalize_lookup_key(raw_id)

	if _item_aliases.has(normalized_key):
		var resource_path: String = String(_item_aliases.get(normalized_key, ""))
		return load(resource_path) as ItemData

	if ResourceLoader.exists(raw_id, "ItemData"):
		return load(raw_id) as ItemData

	return null


func _remove_inventory_item(inventory_state: Node, target_item: ItemData, count: int) -> int:
	if inventory_state == null or target_item == null or count <= 0:
		return 0

	var removed_total := 0
	var slots: Array = inventory_state.get_slots()

	for index in range(slots.size() - 1, -1, -1):
		if removed_total >= count:
			break

		var slot: InventorySlotData = slots[index] as InventorySlotData

		if slot == null or slot.is_empty() or not slot.item_data.matches(target_item):
			continue

		var removable_count: int = min(slot.quantity, count - removed_total)

		if inventory_state.remove_item_at(index, removable_count):
			removed_total += removable_count

	return removed_total


func _ensure_room_catalog_loaded() -> void:
	if not _room_entries.is_empty():
		return

	var directory := DirAccess.open(ROOM_SCENE_DIRECTORY)

	if directory == null:
		return

	directory.list_dir_begin()

	while true:
		var file_name: String = directory.get_next()

		if file_name.is_empty():
			break

		if directory.current_is_dir() or not file_name.ends_with(".tscn"):
			continue

		var scene_path: String = "%s/%s" % [ROOM_SCENE_DIRECTORY, file_name]
		var room_id: String = file_name.get_basename()
		var entry := {
			"id": room_id,
			"display_name": SaveDataUtils.format_room_name(scene_path),
			"scene_path": scene_path,
		}
		_room_entries.append(entry)
		_add_lookup_alias(_room_aliases, room_id, scene_path)
		_add_lookup_alias(_room_aliases, SaveDataUtils.format_room_name(scene_path), scene_path)

	directory.list_dir_end()

	for alias_key in ROOM_ALIAS_OVERRIDES.keys():
		_add_lookup_alias(_room_aliases, String(alias_key), String(ROOM_ALIAS_OVERRIDES[alias_key]))

	_room_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)


func _resolve_room_scene_path(raw_value: String) -> String:
	_ensure_room_catalog_loaded()

	var direct_path: String = raw_value.strip_edges()

	if ResourceLoader.exists(direct_path, "PackedScene"):
		return direct_path

	var normalized_key: String = _normalize_lookup_key(raw_value)

	if _room_aliases.has(normalized_key):
		return String(_room_aliases.get(normalized_key, ""))

	return ""


func _add_lookup_alias(target: Dictionary, raw_key: String, resolved_value: String) -> void:
	var normalized_key: String = _normalize_lookup_key(raw_key)

	if normalized_key.is_empty() or resolved_value.is_empty():
		return

	if not target.has(normalized_key):
		target[normalized_key] = resolved_value


func _normalize_lookup_key(raw_value: String) -> String:
	return raw_value.strip_edges().to_lower().replace("ё", "е")


func _format_debug_player() -> String:
	var stats: Dictionary = _get_player_stats()
	var mental_snapshot := _get_mental_state_snapshot()
	var quest: Dictionary = StoryState.get_current_quest()
	var lines: Array[String] = ["Player debug:"]

	if stats.is_empty():
		lines.append("PlayerStats недоступен.")
	else:
		lines.append("HP: %d/%d" % [int(stats.get("hp", 0)), int(stats.get("max_hp", 0))])
		lines.append("Энергия: %s/%s" % [
			_format_float(float(stats.get("energy", 0.0))),
			_format_float(float(stats.get("max_energy", 0.0))),
		])
		lines.append("Голод: %d/%d" % [int(stats.get("hunger", 0)), int(stats.get("max_hunger", 0))])
		lines.append("Гигиена: %d/%d" % [int(stats.get("hygiene", 0)), int(stats.get("max_hygiene", 0))])

	if not mental_snapshot.is_empty():
		lines.append("Настроение: %s/100" % _format_float(float(mental_snapshot.get("mood", 0.0))))
		lines.append("Стресс: %s/100" % _format_float(float(mental_snapshot.get("stress", 0.0))))
		lines.append("Mental modifiers: %d" % SaveDataUtils.sanitize_array(mental_snapshot.get("active_modifiers", [])).size())

	lines.append("Наличные: $%d" % _get_cash_dollars())
	lines.append("Банк: $%d" % _get_bank_dollars())

	if not quest.is_empty():
		lines.append("Цель: %s" % String(quest.get("title", "Без названия")))

	return "\n".join(lines)


func _format_debug_scene() -> String:
	var tree := _get_scene_tree()
	var snapshot: Dictionary = _get_runtime_world_snapshot()
	var lines: Array[String] = ["Scene debug:"]

	if tree != null and tree.current_scene != null:
		lines.append("Runtime scene: %s" % tree.current_scene.scene_file_path)

	var room_scene_path: String = String(snapshot.get("room_scene_path", "")).strip_edges()

	if not room_scene_path.is_empty():
		lines.append("Room scene: %s" % room_scene_path)
		lines.append("Room name: %s" % SaveDataUtils.format_room_name(room_scene_path))

	var player_data: Dictionary = SaveDataUtils.sanitize_dictionary(snapshot.get("player", {}))

	if not player_data.is_empty():
		var position: Vector2 = SaveDataUtils.dict_to_vector2(player_data.get("position", {}), Vector2.ZERO)
		lines.append("Player position: (%s, %s)" % [_format_float(position.x), _format_float(position.y)])

	return "\n".join(lines)


func _format_debug_save() -> String:
	var lines: Array[String] = ["Save debug:"]
	lines.append("Любые сейвы: %s" % ("yes" if SaveManager.has_any_saves() else "no"))

	var dev_summary: Dictionary = SaveManager.get_slot_summary(SaveManager.MANUAL_SLOT_KIND, DEV_SAVE_SLOT)

	if dev_summary.is_empty():
		lines.append("Dev slot %d: empty" % DEV_SAVE_SLOT)
	else:
		lines.append(
			"Dev slot %d: %s" % [
				DEV_SAVE_SLOT,
				_format_dictionary_block("summary", SaveDataUtils.sanitize_dictionary(dev_summary.get("summary", {})), 4),
			]
		)

	var continue_summary: Dictionary = SaveManager.get_continue_summary()

	if continue_summary.is_empty():
		lines.append("Последний сейв: отсутствует")
	else:
		lines.append(
			"Последний сейв: %s" % _format_dictionary_block(
				"summary",
				SaveDataUtils.sanitize_dictionary(continue_summary.get("summary", {})),
				4
			)
		)

	return "\n".join(lines)


func _format_dictionary_block(title: String, data: Dictionary, max_entries: int = 10) -> String:
	if data.is_empty():
		return "%s: empty" % title

	var keys: Array[String] = []

	for key_variant in data.keys():
		keys.append(String(key_variant))

	keys.sort()

	var lines: Array[String] = []
	var shown_count := 0

	for key in keys:
		if shown_count >= max_entries:
			lines.append("...")
			break

		lines.append("%s=%s" % [key, _format_variant_compact(data.get(key))])
		shown_count += 1

	return "%s{%s}" % [title, ", ".join(PackedStringArray(lines))]


func _format_variant_compact(value: Variant) -> String:
	if value is Dictionary or value is Array:
		var serialized: String = JSON.stringify(value)
		return serialized.substr(0, 80) + "..." if serialized.length() > 80 else serialized

	if value is float:
		return _format_float(float(value))

	return String(value)
