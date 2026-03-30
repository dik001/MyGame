class_name CashierPartTimeConfig
extends RefCounted

const SHIFT_START_HOUR := 6
const SHIFT_END_HOUR := 13
const SHIFT_DURATION_MINUTES := 120
const TARGET_ITEM_COUNT := 30
const MAX_MISTAKES := 3
const TIME_PER_ITEM_SECONDS := 3.0
const SUCCESS_PAYOUT := 120
const SHIFT_ENERGY_COST := 18.0
const SHIFT_HUNGER_DELTA := 10
const SHIFT_HYGIENE_INTENSITY := 1.0
const SUCCESS_MENTAL_EVENT: StringName = &"cashier_shift_success"
const FAIL_MENTAL_EVENT: StringName = &"cashier_shift_fail"

const DEFAULT_GREETING_SEQUENCE := [
	{
		"speaker_name": "Кассир",
		"speaker_id": "cashier",
		"text": "Касса свободна. Что тебе нужно?",
	},
]

const JOB_UNAVAILABLE_SEQUENCES := {
	"too_early": [
		{
			"speaker_name": "Кассир",
			"speaker_id": "cashier",
			"text": "Подработка начинается с шести утра. Приходи позже.",
		},
	],
	"too_late": [
		{
			"speaker_name": "Кассир",
			"speaker_id": "cashier",
			"text": "Смену на сортировке беру только до часу дня. На сегодня уже поздно.",
		},
	],
	"already_worked": [
		{
			"speaker_name": "Кассир",
			"speaker_id": "cashier",
			"text": "На сегодня хватит. Вторую смену не дам.",
		},
	],
	"shift_active": [
		{
			"speaker_name": "Кассир",
			"speaker_id": "cashier",
			"text": "Ты уже на смене. Сначала закончи работу.",
		},
	],
}

const BIN_DEFINITIONS := [
	{
		"id": "glass",
		"label": "Стекло",
		"hint": "1 / A",
		"action": "trash_sort_glass",
		"icon_path": "res://art/Minigame_magazine/Bin_Glass.png",
	},
	{
		"id": "plastic",
		"label": "Пластик",
		"hint": "2 / S",
		"action": "trash_sort_plastic",
		"icon_path": "res://art/Minigame_magazine/Bin_Plastick.png",
	},
	{
		"id": "paper",
		"label": "Бумага",
		"hint": "3 / D",
		"action": "trash_sort_paper",
		"icon_path": "res://art/Minigame_magazine/Bin_Paper.png",
	},
]

const TRASH_ITEMS := [
	{
		"id": "glass_bottles",
		"display_name": "Стеклянные бутылки",
		"category": "glass",
		"icon_path": "res://art/Minigame_magazine/GlassBottle.png",
	},
	{
		"id": "glass_jars",
		"display_name": "Стеклянные банки",
		"category": "glass",
		"icon_path": "res://art/Minigame_magazine/Container.png",
	},
	{
		"id": "glass_shards",
		"display_name": "Осколки стеклянной посуды",
		"category": "glass",
		"icon_path": "res://art/Minigame_magazine/BrokenGlass.png",
	},
	{
		"id": "glass_vials",
		"display_name": "Флаконы от духов или лекарств",
		"category": "glass",
		"icon_path": "res://art/Minigame_magazine/Bottle.png",
	},
	{
		"id": "plastic_bottles",
		"display_name": "Пластиковые бутылки",
		"category": "plastic",
		"icon_path": "res://art/Minigame_magazine/Bottle.png",
	},
	{
		"id": "plastic_bags",
		"display_name": "Пакеты",
		"category": "plastic",
		"icon_path": "res://art/Minigame_magazine/Package.png",
	},
	{
		"id": "food_containers",
		"display_name": "Контейнеры от еды",
		"category": "plastic",
		"icon_path": "res://art/Minigame_magazine/Container.png",
	},
	{
		"id": "newspapers",
		"display_name": "Газеты",
		"category": "paper",
		"icon_path": "res://art/Minigame_magazine/Magazine.png",
	},
	{
		"id": "magazines",
		"display_name": "Журналы",
		"category": "paper",
		"icon_path": "res://art/Minigame_magazine/Magazine.png",
	},
	{
		"id": "cardboard_boxes",
		"display_name": "Картонные коробки",
		"category": "paper",
		"icon_path": "res://art/Minigame_magazine/box.png",
	},
	{
		"id": "paper_notes",
		"display_name": "Тетради и листы бумаги",
		"category": "paper",
		"icon_path": "res://art/Minigame_magazine/Napkin.png",
	},
]


static func get_default_greeting_sequence() -> Array[Dictionary]:
	return _duplicate_dictionary_array(DEFAULT_GREETING_SEQUENCE)


static func get_job_unavailable_sequence(reason: StringName) -> Array[Dictionary]:
	return _duplicate_dictionary_array(
		JOB_UNAVAILABLE_SEQUENCES.get(String(reason), JOB_UNAVAILABLE_SEQUENCES.get("too_late", []))
	)


static func get_bin_definitions() -> Array[Dictionary]:
	return _duplicate_dictionary_array(BIN_DEFINITIONS)


static func get_trash_items() -> Array[Dictionary]:
	return _duplicate_dictionary_array(TRASH_ITEMS)


static func build_shift_items(rng: RandomNumberGenerator, total_items: int = TARGET_ITEM_COUNT) -> Array[Dictionary]:
	var item_pool: Array[Dictionary] = get_trash_items()
	var result: Array[Dictionary] = []
	var resolved_total_items: int = max(1, total_items)

	if item_pool.is_empty():
		return result

	for _index in range(resolved_total_items):
		var source_entry: Dictionary = item_pool[rng.randi_range(0, item_pool.size() - 1)]
		result.append(source_entry.duplicate(true))

	return result


static func get_bin_label(category: StringName) -> String:
	for bin_definition in BIN_DEFINITIONS:
		if String(bin_definition.get("id", "")) == String(category):
			return String(bin_definition.get("label", ""))

	return String(category)


static func load_texture(texture_path: String) -> Texture2D:
	var normalized_path := texture_path.strip_edges()

	if normalized_path.is_empty():
		return null

	if not ResourceLoader.exists(normalized_path):
		return null

	return load(normalized_path) as Texture2D


static func build_result_status_text(success: bool, processed_count: int, mistake_count: int) -> String:
	if success:
		return "Смена закрыта. Отсортировано %d из %d предметов." % [processed_count, TARGET_ITEM_COUNT]

	return "Смена сорвана. Ошибок: %d из %d." % [mistake_count, MAX_MISTAKES]


static func build_result_reward_text(payout: int) -> String:
	if payout > 0:
		return "Оплата: +$%d наличными" % payout

	return "Оплата: без выплаты"


static func _duplicate_dictionary_array(source: Array) -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []

	for entry in source:
		if entry is Dictionary:
			duplicated.append((entry as Dictionary).duplicate(true))

	return duplicated
