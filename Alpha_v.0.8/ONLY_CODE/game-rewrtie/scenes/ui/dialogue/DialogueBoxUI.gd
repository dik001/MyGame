class_name DialogueBoxUI
extends CanvasLayer

signal dialogue_shown(speaker_name: String, text: String, speaker_id: String)
signal dialogue_hidden

const RUNA_PORTRAIT := preload("res://art/ui/dialogue/portret.png")
const MAMA_PORTRAIT := preload("res://art/ui/dialogue/Unknown.png")
const SHOW_DURATION := 0.16
const HIDE_DURATION := 0.12
const CONTINUE_HINT_TEXT := "E / Enter - далее"

@onready var root: Control = $Root
@onready var bottom_anchor: Control = $Root/BottomAnchor
@onready var dialogue_panel: PanelContainer = $Root/BottomAnchor/DialoguePanel
@onready var portrait_texture: TextureRect = $Root/BottomAnchor/DialoguePanel/MarginContainer/Row/PortraitFrame/PortraitTexture
@onready var name_label: Label = $Root/BottomAnchor/DialoguePanel/MarginContainer/Row/TextColumn/NameLabel
@onready var text_label: Label = $Root/BottomAnchor/DialoguePanel/MarginContainer/Row/TextColumn/TextLabel
@onready var hint_label: Label = $Root/BottomAnchor/DialoguePanel/MarginContainer/Row/TextColumn/HintLabel
@onready var advance_label: Label = $Root/BottomAnchor/DialoguePanel/AdvanceLabel

var _portraits := {
	"runa": RUNA_PORTRAIT,
	"руна": RUNA_PORTRAIT,
	"mama": MAMA_PORTRAIT,
	"мама": MAMA_PORTRAIT,
	"хлоя": MAMA_PORTRAIT,
}
var _current_speaker_id := ""
var _transition_tween: Tween = null
var _is_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.text = CONTINUE_HINT_TEXT
	_apply_hidden_state()


func show_dialogue_line(speaker_name: String, text: String, speaker_id: String = "", portrait: Texture2D = null, show_continue_hint := true, instant := false) -> void:
	var resolved_speaker_name := speaker_name.strip_edges()

	if resolved_speaker_name.is_empty():
		resolved_speaker_name = "..."

	var resolved_speaker_id := _normalize_speaker_id(speaker_id if not speaker_id.strip_edges().is_empty() else resolved_speaker_name)

	if portrait != null:
		_portraits[resolved_speaker_id] = portrait

	_current_speaker_id = resolved_speaker_id
	name_label.text = resolved_speaker_name
	text_label.text = text.strip_edges()
	portrait_texture.texture = _resolve_portrait(resolved_speaker_id)
	hint_label.text = CONTINUE_HINT_TEXT
	hint_label.visible = show_continue_hint
	advance_label.visible = show_continue_hint
	_show_box(instant)
	dialogue_shown.emit(resolved_speaker_name, text_label.text, resolved_speaker_id)


func hide_dialogue_box(instant := false) -> void:
	if not _is_visible and not bottom_anchor.visible:
		return

	_is_visible = false

	if _transition_tween != null and is_instance_valid(_transition_tween):
		_transition_tween.kill()

	if instant:
		_apply_hidden_state()
		dialogue_hidden.emit()
		return

	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_QUAD)
	_transition_tween.set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(bottom_anchor, "modulate:a", 0.0, HIDE_DURATION)
	await _transition_tween.finished

	if not _is_visible:
		_apply_hidden_state()
		dialogue_hidden.emit()


func set_portrait(speaker_id: String, portrait: Texture2D) -> void:
	if portrait == null:
		return

	_portraits[_normalize_speaker_id(speaker_id)] = portrait


func is_dialogue_visible() -> bool:
	return _is_visible


func _show_box(instant: bool) -> void:
	var was_visible := _is_visible and bottom_anchor.visible
	_is_visible = true
	bottom_anchor.visible = true

	if _transition_tween != null and is_instance_valid(_transition_tween):
		_transition_tween.kill()

	if instant or was_visible:
		bottom_anchor.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	transition_from_hidden()


func transition_from_hidden() -> void:
	bottom_anchor.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_QUAD)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(bottom_anchor, "modulate:a", 1.0, SHOW_DURATION)


func _apply_hidden_state() -> void:
	bottom_anchor.visible = false
	bottom_anchor.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _normalize_speaker_id(speaker_id: String) -> String:
	return speaker_id.strip_edges().to_lower()


func _resolve_portrait(speaker_id: String) -> Texture2D:
	if _portraits.has(speaker_id):
		return _portraits[speaker_id]

	return MAMA_PORTRAIT
