extends Control

signal menu_requested
signal next_level_requested(level_id: int)
signal settings_requested

const GAME_CONTROLLER_SCRIPT := preload("res://scripts/gameplay/game_controller.gd")
const LEVEL_01 := preload("res://data/levels/level_01.tres")
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/audio/audio_manager.gd")
const IMPACT_FX_LAYER_SCRIPT := preload("res://scripts/ui/impact_fx_layer.gd")

@export_range(1, 9) var level_number: int = 1

@onready var game_controller: Node = $GameController
@onready var board_controller: Control = $BoardController
@onready var spawn_director: Node = $SpawnDirector
@onready var hammer_controller: Control = $HammerController
@onready var hud: Control = $HUD
@onready var session_overlay: Control = $SessionOverlay
var save_manager: Node
var audio_manager: Node
var monetization_service: MonetizationService
var _last_lives: int = 3
var _shown_hints: Dictionary = {}
var _shake_tween: Tween
var _base_position: Vector2
var _impact_fx_layer: Control
var _suppressed_bonus_escapes: Dictionary = {}
var _resume_after_platform_pause := false

var _level_config: LevelConfig = LEVEL_01


func _ready() -> void:
	_base_position = position
	if save_manager == null:
		save_manager = $SaveManager
	if audio_manager == null:
		audio_manager = AUDIO_MANAGER_SCRIPT.new()
		audio_manager.name = "RuntimeAudioManager"
		add_child(audio_manager)
	_impact_fx_layer = IMPACT_FX_LAYER_SCRIPT.new()
	_impact_fx_layer.name = "ImpactFxLayer"
	add_child(_impact_fx_layer)
	audio_manager.apply_settings(save_manager.load_data())
	board_controller.slot_tapped.connect(_on_slot_tapped)
	board_controller.character_hit.connect(_on_character_hit)
	board_controller.character_escaped.connect(_on_character_escaped)
	board_controller.character_spawned.connect(_on_character_spawned)
	hammer_controller.impact.connect(_on_hammer_impact)
	game_controller.score_changed.connect(hud.set_score)
	game_controller.combo_changed.connect(_on_combo_changed)
	game_controller.lives_changed.connect(_on_lives_changed)
	game_controller.time_changed.connect(hud.set_time)
	game_controller.time_changed.connect(spawn_director.set_remaining_time)
	game_controller.countdown_changed.connect(_on_countdown_changed)
	game_controller.state_changed.connect(_on_state_changed)
	game_controller.game_finished.connect(_on_game_finished)
	game_controller.golden_hits_changed.connect(hud.set_golden_progress)
	game_controller.confusion_changed.connect(_on_confusion_changed)
	game_controller.feedback_requested.connect(hud.show_feedback)
	hud.pause_pressed.connect(_on_pause_pressed)
	session_overlay.resume_requested.connect(_on_resume_requested)
	session_overlay.retry_requested.connect(_on_retry_requested)
	session_overlay.menu_requested.connect(func() -> void: menu_requested.emit())
	session_overlay.next_requested.connect(func() -> void: next_level_requested.emit(mini(level_number + 1, 9)))
	session_overlay.settings_requested.connect(func() -> void: settings_requested.emit())
	session_overlay.configure_monetization(monetization_service)

	_load_level(level_number)
	_configure_level()
	_start_level()


func configure(requested_level: int, shared_save_manager: Node, shared_audio_manager: Node = null, shared_monetization_service: MonetizationService = null) -> void:
	level_number = clampi(requested_level, 1, 9)
	save_manager = shared_save_manager
	audio_manager = shared_audio_manager
	monetization_service = shared_monetization_service


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and game_controller != null:
		if game_controller.state == GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
			game_controller.pause_level()


func _configure_level() -> void:
	spawn_director.configure(board_controller, _level_config)
	spawn_director.set_remaining_time(_level_config.duration)
	hud.set_level(_level_config.level_id, _level_config.target_score, _level_config.required_golden_hits)


func _load_level(value: int) -> void:
	var path := "res://data/levels/level_%02d.tres" % clampi(value, 1, 9)
	var loaded := load(path) as LevelConfig
	if loaded != null:
		_level_config = loaded


func _start_level() -> void:
	spawn_director.stop()
	spawn_director.prepare_level()
	board_controller.clear_all()
	audio_manager.play_music_for_level(level_number)
	game_controller.start_level(
		_level_config.duration,
		_level_config.target_score,
		true,
		_level_config.required_max_combo,
		_level_config.required_golden_hits,
		_level_config.max_time_bonus
	)


func _on_slot_tapped(slot_index: int) -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return
	if not hammer_controller.can_strike():
		return
	var actual_slot: int = game_controller.redirect_gameplay_slot(slot_index, 9)
	if actual_slot != slot_index:
		hud.show_feedback(tr("HAMMER_CONFUSED"))
	var impact_position: Vector2 = board_controller.get_slot_impact_position(actual_slot)
	hammer_controller.strike(actual_slot, impact_position)


func _on_hammer_impact(slot_index: int) -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return
	audio_manager.play_event(&"hammer_bonk")
	if not board_controller.hit_slot(slot_index):
		board_controller.play_empty_hit(slot_index)
		var active_types: Array[StringName] = board_controller.get_active_character_types()
		var missed_bonus := &"clock" in active_types or &"glutton" in active_types
		game_controller.resolve_empty_hit(missed_bonus)
		if missed_bonus:
			var impact_global: Vector2 = board_controller.get_global_transform() * board_controller.get_slot_impact_position(slot_index)
			for active_type in active_types:
				if active_type in [&"clock", &"glutton"]:
					_suppressed_bonus_escapes[active_type] = int(_suppressed_bonus_escapes.get(active_type, 0)) + 1
			_impact_fx_layer.show_score(impact_global, tr("BONUS_MISSED"), true)
		else:
			var impact_global: Vector2 = board_controller.get_global_transform() * board_controller.get_slot_impact_position(slot_index)
			_impact_fx_layer.show_score(impact_global, tr("MISS_LIFE"))
		audio_manager.play_event(&"empty_hit")


func _on_character_hit(_slot_index: int, character_type: StringName) -> void:
	_consume_suppressed_bonus_escape(character_type)
	var impact_global: Vector2 = board_controller.get_global_transform() * board_controller.get_slot_impact_position(_slot_index)
	var lives_before: int = game_controller.lives
	var time_bonus_before: float = game_controller.time_bonus_awarded
	game_controller.resolve_character_hit(character_type)
	if character_type in [&"normal", &"fast", &"golden"]:
		audio_manager.play_event(&"correct_hit")
		_shake(3.0, 0.08)
		_impact_fx_layer.show_score(impact_global)
	elif character_type == &"bomb":
		audio_manager.play_event(&"bomb")
		_shake(8.0, 0.15)
		_impact_fx_layer.show_bomb_confetti(impact_global)
	elif character_type == &"clock":
		audio_manager.play_event(&"clock")
		var clock_text := tr("SECONDS_BONUS") if game_controller.time_bonus_awarded > time_bonus_before else tr("TIME_LIMIT")
		_impact_fx_layer.show_score(impact_global, clock_text, true)
	elif character_type == &"glutton":
		audio_manager.play_event(&"apple_restore")
		_impact_fx_layer.show_score(impact_global, tr("LIFE_BONUS") if lives_before < 3 else tr("FULL"), true)
		if lives_before < 3:
			hud.fly_hammer_to_hud(impact_global)
	elif character_type == &"drunk":
		audio_manager.play_event(&"drunk")


func _on_character_escaped(slot_index: int, character_type: StringName) -> void:
	var impact_global: Vector2 = board_controller.get_global_transform() * board_controller.get_slot_impact_position(slot_index)
	game_controller.resolve_character_escape(character_type)
	var escape_feedback_suppressed := _consume_suppressed_bonus_escape(character_type)
	if character_type in [&"normal", &"fast", &"golden"]:
		audio_manager.play_event(&"clown_miss")
	elif character_type == &"clock" and not escape_feedback_suppressed:
		_impact_fx_layer.show_score(impact_global, tr("CLOCK_ESCAPED"), true)
	elif character_type == &"glutton":
		if not escape_feedback_suppressed:
			_impact_fx_layer.show_score(impact_global, tr("GLUTTON_ESCAPED"), true)
		audio_manager.play_event(&"glutton_escape")


func _consume_suppressed_bonus_escape(character_type: StringName) -> bool:
	var remaining := int(_suppressed_bonus_escapes.get(character_type, 0))
	if remaining <= 0:
		return false
	if remaining == 1:
		_suppressed_bonus_escapes.erase(character_type)
	else:
		_suppressed_bonus_escapes[character_type] = remaining - 1
	return true


func _on_character_spawned(character_type: StringName) -> void:
	audio_manager.play_event(&"box_pop")
	if level_number != 8 or _shown_hints.has(character_type):
		return
	var hint := ""
	if character_type == &"clock":
		hint = tr("HINT_CLOCK")
	elif character_type == &"glutton":
		hint = tr("HINT_GLUTTON")
	elif character_type == &"drunk":
		hint = tr("HINT_DRUNK")
	if not hint.is_empty():
		_shown_hints[character_type] = true
		hud.show_feedback(hint)


func _on_combo_changed(value: int) -> void:
	hud.set_combo(value)
	if value >= 3:
		audio_manager.play_event(&"combo")


func _on_lives_changed(value: int) -> void:
	hud.set_lives(value)
	if value < _last_lives:
		audio_manager.play_event(&"life_lost")
	_last_lives = value


func _on_countdown_changed(text: String) -> void:
	session_overlay.show_countdown(text)
	if not text.is_empty():
		audio_manager.play_event(&"countdown")


func _on_confusion_changed(remaining: int) -> void:
	hud.set_confusion(remaining)
	spawn_director.set_confusion_remaining(remaining)


func _on_pause_pressed() -> void:
	game_controller.pause_level()


func _on_resume_requested() -> void:
	game_controller.resume_level()


func _on_retry_requested() -> void:
	_start_level()


func _on_state_changed(value: int) -> void:
	var is_running := value == GAME_CONTROLLER_SCRIPT.GameState.RUNNING
	if monetization_service != null and not monetization_service.is_platform_lifecycle_active():
		monetization_service.set_gameplay_active(is_running)
	hud.set_pause_enabled(is_running)
	if is_running:
		session_overlay.hide_overlay()
		spawn_director.start()
		_show_level_hint_once()
	elif value == GAME_CONTROLLER_SCRIPT.GameState.COUNTDOWN:
		spawn_director.stop()
		board_controller.clear_all()
	elif value == GAME_CONTROLLER_SCRIPT.GameState.PAUSED:
		spawn_director.stop()
		session_overlay.show_pause()
	else:
		spawn_director.stop()


func handle_platform_pause() -> void:
	_resume_after_platform_pause = game_controller.state == GAME_CONTROLLER_SCRIPT.GameState.RUNNING
	if _resume_after_platform_pause:
		game_controller.pause_level()


func handle_platform_resume() -> void:
	if _resume_after_platform_pause and game_controller.state == GAME_CONTROLLER_SCRIPT.GameState.PAUSED:
		game_controller.resume_level()
	_resume_after_platform_pause = false


func _on_game_finished(won: bool) -> void:
	board_controller.clear_all()
	var save_error := false
	audio_manager.play_event(&"victory" if won else &"defeat")
	if won:
		save_manager.record_completed_level(level_number, game_controller.score, game_controller.max_combo)
		save_error = save_manager.get_last_save_error() != OK
	await get_tree().create_timer(0.5, true, false, true).timeout
	if not is_inside_tree():
		return
	session_overlay.show_result(
		won,
		game_controller.score,
		game_controller.max_combo,
		game_controller.target_score,
		save_error,
		won and level_number < 9
	)


func _show_level_hint_once() -> void:
	if _shown_hints.has(level_number):
		return
	var hint := ""
	match level_number:
		1:
			hint = tr("HINT_TAP")
		6:
			hint = tr("HINT_BOMB")
	if not hint.is_empty():
		_shown_hints[level_number] = true
		hud.show_feedback(hint)


func _shake(amount: float, duration: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	position = _base_position
	_shake_tween = create_tween()
	var step := duration / 4.0
	_shake_tween.tween_property(self, "position", _base_position + Vector2(amount, -amount * 0.35), step)
	_shake_tween.tween_property(self, "position", _base_position + Vector2(-amount, amount * 0.25), step)
	_shake_tween.tween_property(self, "position", _base_position + Vector2(amount * 0.45, 0.0), step)
	_shake_tween.tween_property(self, "position", _base_position, step)


func debug_spawn_normal(slot_index: int, visible_time: float = 1.5) -> bool:
	return board_controller.spawn_normal(slot_index, visible_time)


func debug_spawn_character(slot_index: int, character_type: StringName, visible_time: float = 1.5) -> bool:
	return board_controller.spawn_character(slot_index, character_type, visible_time)


func debug_set_level(value: int) -> void:
	level_number = clampi(value, 1, 9)
	_load_level(level_number)
	_configure_level()
	_start_level()


func debug_tap_slot(slot_index: int) -> bool:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return false
	var impact_position: Vector2 = board_controller.get_slot_impact_position(slot_index)
	return hammer_controller.strike(slot_index, impact_position)
