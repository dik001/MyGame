class_name MentalStateConfig
extends Resource

@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var default_mood: float = 62.0
@export var default_stress: float = 18.0
@export var base_mood: float = 60.0
@export var base_stress: float = 18.0
@export var natural_mood_recovery_per_hour: float = 0.45
@export var natural_mood_decay_above_base_per_hour: float = 0.30
@export var natural_stress_relief_per_hour: float = 0.90
@export var natural_stress_build_up_to_base_per_hour: float = 0.15
@export var stress_to_mood_pressure_threshold: float = 55.0
@export var stress_to_mood_pressure_per_hour_at_max: float = 2.60
@export var notification_duration: float = 3.2
@export var safe_room_scene_paths: Array[String] = [
	"res://scenes/rooms/apartament.tscn",
]
@export var mood_thresholds: Dictionary = {
	"excellent": 78.0,
	"normal": 45.0,
	"low": 22.0,
}
@export var stress_thresholds: Dictionary = {
	"calm": 24.0,
	"tense": 49.0,
	"high": 74.0,
}
@export var mood_state_definitions: Dictionary = {
	"excellent": {
		"title": "Отличное настроение",
		"status_text": "Легче собраться с силами",
		"description": "Руна держится ровно, отдых чувствуется сильнее, а привычные дела меньше выматывают.",
		"severity": 0,
		"condition_visible": false,
		"effect_bonuses": {
			"sleep_recovery_multiplier": 0.12,
			"work_energy_cost_multiplier": -0.08,
		},
	},
	"normal": {
		"title": "Нормальное настроение",
		"status_text": "Без заметного давления",
		"description": "Эмоциональный фон пока не мешает ни отдыху, ни работе.",
		"severity": 0,
		"condition_visible": false,
		"effect_bonuses": {},
	},
	"low": {
		"title": "Плохое настроение",
		"status_text": "Восстанавливаться сложнее",
		"description": "Мысли вязнут, любая мелочь цепляет сильнее обычного, а отдых даёт меньше отдачи.",
		"severity": 1,
		"condition_visible": true,
		"effect_bonuses": {
			"sleep_recovery_multiplier": -0.10,
			"work_energy_cost_multiplier": 0.08,
		},
	},
	"depressed": {
		"title": "Подавленность",
		"status_text": "Силы утекают сквозь пальцы",
		"description": "Руна эмоционально выжата. Отдых помогает хуже, работа режет по силам сильнее, а стресс липнет быстрее.",
		"severity": 2,
		"condition_visible": true,
		"effect_bonuses": {
			"sleep_recovery_multiplier": -0.22,
			"work_energy_cost_multiplier": 0.18,
		},
	},
}
@export var stress_state_definitions: Dictionary = {
	"calm": {
		"title": "Спокойствие",
		"status_text": "Нервы отпускают",
		"description": "Руна дышит ровнее и легче восстанавливается после обычных дел.",
		"severity": 0,
		"condition_visible": false,
		"effect_bonuses": {
			"sleep_recovery_multiplier": 0.06,
			"work_energy_cost_multiplier": -0.05,
		},
	},
	"tense": {
		"title": "Напряжение",
		"status_text": "Фон тревоги уже заметен",
		"description": "Напряжение ещё не ломает день, но уже мешает нормально расслабиться и незаметно съедает силы.",
		"severity": 1,
		"condition_visible": true,
		"effect_bonuses": {
			"sleep_recovery_multiplier": -0.04,
			"work_energy_cost_multiplier": 0.05,
		},
	},
	"high": {
		"title": "Высокий стресс",
		"status_text": "Нервы на пределе",
		"description": "В голове слишком шумно. Работать и отдыхать становится ощутимо тяжелее, а настроение проседает само по себе.",
		"severity": 2,
		"condition_visible": true,
		"effect_bonuses": {
			"sleep_recovery_multiplier": -0.12,
			"work_energy_cost_multiplier": 0.12,
		},
	},
	"panic": {
		"title": "Критический стресс",
		"status_text": "Собраться почти невозможно",
		"description": "Руна на грани паники. Отдых помогает слабо, работа выматывает сильнее всего, а плохие мысли давят сами по себе.",
		"severity": 3,
		"condition_visible": true,
		"effect_bonuses": {
			"sleep_recovery_multiplier": -0.22,
			"work_energy_cost_multiplier": 0.25,
		},
	},
}
@export var hunger_stage_modifiers: Dictionary = {
	"hunger_hungry": {
		"mood_delta_per_hour": -0.30,
		"stress_delta_per_hour": 0.20,
		"tags": ["hunger", "physical_pressure"],
	},
	"hunger_very_hungry": {
		"mood_delta_per_hour": -0.65,
		"stress_delta_per_hour": 0.55,
		"tags": ["hunger", "physical_pressure"],
	},
	"hunger_exhausted": {
		"mood_delta_per_hour": -1.10,
		"stress_delta_per_hour": 0.90,
		"tags": ["hunger", "physical_pressure"],
	},
	"hunger_starving": {
		"mood_delta_per_hour": -1.70,
		"stress_delta_per_hour": 1.30,
		"tags": ["hunger", "physical_pressure"],
	},
}
@export var sleep_stage_modifiers: Dictionary = {
	"sleep_tired": {
		"mood_delta_per_hour": -0.25,
		"stress_delta_per_hour": 0.20,
		"tags": ["sleep", "fatigue"],
	},
	"sleep_very_tired": {
		"mood_delta_per_hour": -0.55,
		"stress_delta_per_hour": 0.45,
		"tags": ["sleep", "fatigue"],
	},
	"sleep_critical": {
		"mood_delta_per_hour": -1.00,
		"stress_delta_per_hour": 0.85,
		"tags": ["sleep", "fatigue"],
	},
}
@export var hygiene_stage_modifiers: Dictionary = {
	"hygiene_untidy": {
		"mood_delta_per_hour": -0.10,
		"stress_delta_per_hour": 0.10,
		"tags": ["hygiene", "body"],
	},
	"hygiene_dirty": {
		"mood_delta_per_hour": -0.45,
		"stress_delta_per_hour": 0.35,
		"tags": ["hygiene", "body"],
	},
	"hygiene_unsanitary": {
		"mood_delta_per_hour": -0.95,
		"stress_delta_per_hour": 0.75,
		"tags": ["hygiene", "body"],
	},
}
@export var eye_strain_modifier: Dictionary = {
	"title": "Перенапряжение",
	"status_text": "Голова не отдыхает",
	"description": "После долгой смены за экраном напряжение не отпускает и постепенно поднимает стресс.",
	"mood_delta_per_hour": -0.20,
	"stress_delta_per_hour": 0.55,
	"show_in_ui": false,
	"tags": ["work", "eye_strain"],
}
@export var home_safe_zone_modifier: Dictionary = {
	"title": "Безопасное место",
	"status_text": "Можно выдохнуть",
	"description": "Дома напряжение отпускает быстрее, а настроение медленно ползёт вверх.",
	"mood_delta_per_hour": 0.35,
	"stress_delta_per_hour": -0.60,
	"show_in_ui": false,
	"tags": ["safe_zone", "home"],
}
@export var poverty_rules: Dictionary = {
	"poor_threshold": 120,
	"broke_threshold": 35,
	"poor_modifier": {
		"title": "Денежное давление",
		"status_text": "Нужно считать каждую покупку",
		"description": "Деньги заканчиваются. Это пока не катастрофа, но фон тревоги уже тянет вниз.",
		"mood_delta_per_hour": -0.20,
		"stress_delta_per_hour": 0.35,
		"show_in_ui": true,
		"tags": ["poverty", "money"],
	},
	"broke_modifier": {
		"title": "Почти без денег",
		"status_text": "Любая трата бьёт по нервам",
		"description": "Запасов почти не осталось. Мысли о еде, аренде и следующем дне давят заметно сильнее.",
		"mood_delta_per_hour": -0.45,
		"stress_delta_per_hour": 0.75,
		"show_in_ui": true,
		"tags": ["poverty", "money"],
	},
}
@export var rent_state_modifiers: Dictionary = {
	"due": {
		"title": "Аренда сегодня",
		"status_text": "Срок оплаты уже пришёл",
		"description": "День сжимается вокруг одной мысли: нужно закрыть аренду до того, как всё станет хуже.",
		"mood_delta_per_hour": -0.35,
		"stress_delta_per_hour": 0.65,
		"show_in_ui": true,
		"tags": ["rent", "money_pressure"],
	},
	"overdue": {
		"title": "Просрочка по аренде",
		"status_text": "Давление только растёт",
		"description": "Просрочка по аренде давит постоянно и не даёт выдохнуть даже в спокойные минуты.",
		"mood_delta_per_hour": -0.80,
		"stress_delta_per_hour": 1.25,
		"show_in_ui": true,
		"tags": ["rent", "money_pressure"],
	},
}
@export var event_presets: Dictionary = {
	"consume_food": {
		"mood_delta": 4.0,
		"stress_delta": -3.0,
		"tags": ["food", "positive"],
	},
	"bath_completed": {
		"mood_delta": 7.0,
		"stress_delta": -10.0,
		"tags": ["bath", "relief"],
		"modifier": {
			"id": "bath_relief",
			"title": "Передышка после ванны",
			"status_text": "Тело наконец отпустило",
			"description": "После горячей воды телу и голове немного легче. Напряжение спадает быстрее обычного.",
			"duration_minutes": 240,
			"mood_delta_per_hour": 0.20,
			"stress_delta_per_hour": -0.80,
			"show_in_ui": false,
			"stack_policy": "refresh_duration",
			"tags": ["bath", "relief"],
		},
	},
	"sleep_completed": {
		"mood_delta": 6.0,
		"stress_delta": -8.0,
		"tags": ["sleep", "rest"],
		"modifier": {
			"id": "sleep_afterglow",
			"title": "Свежая голова",
			"status_text": "После сна легче держаться",
			"description": "Нормальный сон ненадолго выравнивает фон и помогает быстрее сбрасывать стресс.",
			"duration_minutes": 360,
			"mood_delta_per_hour": 0.18,
			"stress_delta_per_hour": -0.60,
			"show_in_ui": false,
			"stack_policy": "refresh_duration",
			"tags": ["sleep", "rest"],
		},
	},
	"forced_blackout_sleep_completed": {
		"mood_delta": 3.0,
		"stress_delta": -4.0,
		"tags": ["sleep", "forced_rest"],
	},
	"freelance_success": {
		"mood_delta": 4.0,
		"stress_delta": -1.5,
		"tags": ["work", "positive"],
	},
	"freelance_fail": {
		"mood_delta": -8.0,
		"stress_delta": 10.0,
		"tags": ["work", "negative"],
	},
	"cashier_shift_success": {
		"mood_delta": 2.0,
		"stress_delta": 4.0,
		"tags": ["work", "shop", "dirty_work"],
	},
	"cashier_shift_fail": {
		"mood_delta": -6.0,
		"stress_delta": 9.0,
		"tags": ["work", "shop", "dirty_work", "negative"],
	},
	"rent_due_today": {
		"mood_delta": -4.0,
		"stress_delta": 8.0,
		"tags": ["rent", "negative"],
	},
	"rent_overdue": {
		"mood_delta": -8.0,
		"stress_delta": 12.0,
		"tags": ["rent", "negative"],
	},
	"rent_paid": {
		"mood_delta": 6.0,
		"stress_delta": -12.0,
		"tags": ["rent", "relief"],
	},
	"hygiene_humiliation_comment": {
		"mood_delta": -6.0,
		"stress_delta": 9.0,
		"tags": ["social", "humiliation"],
	},
}


func get_mood_state_definition(state_id: StringName) -> Dictionary:
	return _duplicate_dictionary(mood_state_definitions.get(String(state_id), mood_state_definitions.get("normal", {})))


func get_stress_state_definition(state_id: StringName) -> Dictionary:
	return _duplicate_dictionary(stress_state_definitions.get(String(state_id), stress_state_definitions.get("calm", {})))


func get_event_preset(event_id: StringName) -> Dictionary:
	return _duplicate_dictionary(event_presets.get(String(event_id), {}))


func get_hunger_stage_modifier(stage_id: StringName) -> Dictionary:
	return _duplicate_dictionary(hunger_stage_modifiers.get(String(stage_id), {}))


func get_sleep_stage_modifier(stage_id: StringName) -> Dictionary:
	return _duplicate_dictionary(sleep_stage_modifiers.get(String(stage_id), {}))


func get_hygiene_stage_modifier(stage_id: StringName) -> Dictionary:
	return _duplicate_dictionary(hygiene_stage_modifiers.get(String(stage_id), {}))


func get_eye_strain_modifier() -> Dictionary:
	return _duplicate_dictionary(eye_strain_modifier)


func get_home_safe_zone_modifier(room_scene_path: String) -> Dictionary:
	var resolved_room: String = room_scene_path.strip_edges()

	if resolved_room.is_empty():
		return {}

	if not safe_room_scene_paths.has(resolved_room):
		return {}

	return _duplicate_dictionary(home_safe_zone_modifier)


func get_poverty_modifier(total_money: int) -> Dictionary:
	var rules := poverty_rules.duplicate(true)
	var broke_threshold: int = int(rules.get("broke_threshold", -1))
	var poor_threshold: int = int(rules.get("poor_threshold", -1))

	if broke_threshold >= 0 and total_money <= broke_threshold:
		return _duplicate_dictionary(rules.get("broke_modifier", {}))

	if poor_threshold >= 0 and total_money <= poor_threshold:
		return _duplicate_dictionary(rules.get("poor_modifier", {}))

	return {}


func get_rent_state_modifier(state_id: String) -> Dictionary:
	return _duplicate_dictionary(rent_state_modifiers.get(state_id.strip_edges().to_lower(), {}))


func _duplicate_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return (raw_value as Dictionary).duplicate(true)

	return {}
