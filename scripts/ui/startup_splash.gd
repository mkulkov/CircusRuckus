extends Control

signal completed

const SPLASH_RU := preload("res://assets/generated/startup_splash.png")
const SPLASH_EN := preload("res://assets/generated/startup_splash_en.png")

@export_range(0.0, 2.0, 0.05) var fade_duration := 0.25
@export_range(0.0, 10.0, 0.05) var display_duration := 1.75

var _is_finishing := false


func _ready() -> void:
	_apply_localized_art()
	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, fade_duration)
	await fade_in.finished
	get_tree().create_timer(display_duration).timeout.connect(finish, CONNECT_ONE_SHOT)


func _apply_localized_art() -> void:
	var locale := TranslationServer.get_locale().to_lower()
	$Art.texture = SPLASH_EN if locale.begins_with("en") else SPLASH_RU


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		finish()
	elif event is InputEventMouseButton and event.pressed:
		finish()


func finish() -> void:
	if _is_finishing:
		return
	_is_finishing = true
	var fade_out := create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, fade_duration)
	await fade_out.finished
	completed.emit()
