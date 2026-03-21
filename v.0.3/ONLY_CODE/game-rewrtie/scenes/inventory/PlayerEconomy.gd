class_name PlayerEconomyState
extends Node

signal dollars_changed(new_value: int)

const DEFAULT_STARTING_DOLLARS := 25

var dollars := DEFAULT_STARTING_DOLLARS


func _ready() -> void:
	dollars = max(0, dollars)
	dollars_changed.emit(dollars)


func add_dollars(amount: int) -> void:
	if amount <= 0:
		return

	dollars += amount
	dollars_changed.emit(dollars)


func spend_dollars(amount: int) -> bool:
	if amount <= 0:
		return true

	if not can_afford(amount):
		return false

	dollars -= amount
	dollars_changed.emit(dollars)
	return true


func can_afford(amount: int) -> bool:
	if amount <= 0:
		return true

	return dollars >= amount


func get_dollars() -> int:
	return dollars
