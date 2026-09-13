extends Control

signal impact(slot_index: int)

const HAMMER_STRIKE_SCRIPT := preload("res://scripts/gameplay/hammer_strike.gd")

@export var hammer_swing_duration: float = 0.22
@export var debounce_seconds: float = 0.08

var _last_strike_time: float = -10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func strike(slot_index: int, target_position: Vector2) -> bool:
	if not can_strike():
		return false
	var now_seconds := Time.get_ticks_msec() / 1000.0
	_last_strike_time = now_seconds

	var hammer := HAMMER_STRIKE_SCRIPT.new() as Control
	add_child(hammer)
	hammer.impact.connect(_on_hammer_impact)
	hammer.play(target_position, slot_index, hammer_swing_duration)
	return true


func can_strike() -> bool:
	var now_seconds := Time.get_ticks_msec() / 1000.0
	return now_seconds - _last_strike_time >= debounce_seconds


func _on_hammer_impact(slot_index: int) -> void:
	impact.emit(slot_index)
