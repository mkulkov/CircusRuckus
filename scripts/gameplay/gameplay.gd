extends Control

signal new_game_requested
signal menu_requested
signal retry_requested
signal settings_requested

const GAME_CONTROLLER_SCRIPT := preload("res://scripts/gameplay/game_controller.gd")
const RECOVERY := preload("res://data/round_profiles/recovery.tres")
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/audio/audio_manager.gd")
const IMPACT_FX_LAYER_SCRIPT := preload("res://scripts/ui/impact_fx_layer.gd")
const ANALYTICS := preload("res://scripts/analytics/analytics_events.gd")
const TUTORIAL_SCRIPT := preload("res://scripts/gameplay/tutorial_controller.gd")

@export var deterministic_seed: int = 0
var mode: String = "endless"
var tutorial_round: int = 1
@onready var round_director: Node = $RoundDirector

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
var _shake_tween: Tween
var _base_position: Vector2
var _impact_fx_layer: Control
var _suppressed_bonus_escapes: Dictionary = {}
var _analytics_attempt := ""
var _analytics_duration := 0.0
var _analytics_finished := false
var _tutorial: Node
var _attempt_generation := 0

var _round_profile: RoundProfile = RECOVERY
var _round_result_ready := false
var _round_start_score := 0
var _round_best_combo := 0
var _previous_best := 0
var _waiting_training_start := false


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
	# Hammer impact is visual only; accepted input owns the authoritative result.
	game_controller.score_changed.connect(hud.set_score)
	game_controller.combo_changed.connect(_on_combo_changed)
	game_controller.lives_changed.connect(_on_lives_changed)
	game_controller.time_changed.connect(hud.set_time)
	game_controller.progress_changed.connect(_update_run_details)
	game_controller.countdown_changed.connect(_on_countdown_changed)
	game_controller.state_changed.connect(_on_state_changed)
	game_controller.game_finished.connect(_on_game_finished)
	game_controller.round_finished.connect(_on_round_finished)
	if monetization_service != null:
		game_controller.active_time_advanced.connect(monetization_service.record_active_play)
	game_controller.recovery_changed.connect(_update_run_details)
	game_controller.life_restored.connect(_on_life_restored)
	game_controller.spawn_slowdown_requested.connect(spawn_director.apply_slowdown)
	game_controller.confusion_changed.connect(_on_confusion_changed)
	game_controller.feedback_requested.connect(hud.show_feedback)
	hud.pause_pressed.connect(_on_pause_pressed)
	session_overlay.resume_requested.connect(_on_resume_requested)
	session_overlay.round_continue_requested.connect(_start_next_round)
	session_overlay.game_start_requested.connect(_on_training_start_pressed)
	session_overlay.retry_requested.connect(_on_retry_requested)
	session_overlay.menu_requested.connect(_leave_run)
	session_overlay.settings_requested.connect(func() -> void: settings_requested.emit())
	_tutorial = TUTORIAL_SCRIPT.new()
	add_child(_tutorial)
	_tutorial.configure(self)
	_tutorial.round_requested.connect(_start_practice_round)
	_tutorial.completed.connect(_on_training_completed)
	_tutorial.round_mastered.connect(func(_number: int) -> void: session_overlay.show_tutorial_advance(true))
	if mode == "endless":
		_start_run()
	else:
		_tutorial.start(mode == "training_repeat")


func configure(requested_mode: String, shared_save_manager: Node, shared_audio_manager: Node = null, shared_monetization_service: MonetizationService = null) -> void:
	mode = requested_mode
	save_manager = shared_save_manager
	audio_manager = shared_audio_manager
	monetization_service = shared_monetization_service


func _notification(what: int) -> void:
	if game_controller == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		handle_platform_pause()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		handle_platform_resume()


func _configure_round() -> void:
	_round_result_ready = false
	_round_start_score = game_controller.score
	_round_best_combo = game_controller.combo_count
	spawn_director.set_profile(_round_profile)
	spawn_director.prepare_round()
	var phase := "tutorial" if game_controller.is_practice else str(round_director.PROFILE_PATHS[round_director.phase_index])
	hud.set_round(tutorial_round if game_controller.is_practice else round_director.round_index, phase, _round_profile.pattern)


func _start_run() -> void:
	_waiting_training_start = false
	_attempt_generation += 1
	_tutorial.reset_attempt()
	game_controller.set_process(true)
	hammer_controller.clear_strikes()
	_suppressed_bonus_escapes.clear()
	spawn_director.stop()
	board_controller.clear_all()
	round_director.start_run(deterministic_seed)
	_round_profile = round_director.next_profile()
	spawn_director.configure(board_controller, _round_profile, round_director.get_run_rng())
	hud.show_feedback("")
	_previous_best = int(save_manager.load_data().get("best_run_score", 0))
	_analytics_finished = false
	audio_manager.play_music_for_run()
	game_controller.start_run(_round_profile, true, false, round_director.get_run_rng())
	_configure_round()
	_begin_round_analytics()


func _start_practice_round(number: int) -> void:
	_attempt_generation += 1
	_suppressed_bonus_escapes.clear()
	tutorial_round = number
	_round_profile = load("res://data/tutorial/practice_%02d.tres" % number).duplicate(true) as RoundProfile
	_round_profile.is_tutorial = true
	spawn_director.stop()
	board_controller.clear_all()
	hammer_controller.clear_strikes()
	spawn_director.configure(board_controller, _round_profile)
	game_controller.set_process(true)
	game_controller.start_run(_round_profile, false, true)
	_configure_round()
	_tutorial.begin_round(number)


func _on_training_completed() -> void:
	_waiting_training_start = true
	spawn_director.stop()
	game_controller.set_process(false)
	game_controller.pause_level(&"tutorial")
	session_overlay.show_training_complete()


func _on_training_start_pressed() -> void:
	if not _waiting_training_start:
		return
	_waiting_training_start = false
	if new_game_requested.get_connections().is_empty():
		mode = "endless"
		_start_run()
	else:
		new_game_requested.emit()


func _begin_round_analytics() -> void:
	_analytics_attempt = ANALYTICS.new_operation()
	_analytics_duration = 0.0
	_analytics_finished = false
	ANALYTICS.record("level_start", {"level_id": _analytics_level_id(), "difficulty": "normal"}, _analytics_attempt)


func _process(delta: float) -> void:
	if game_controller.state == GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		if not game_controller.is_practice:
			_analytics_duration += delta
		spawn_director.set_elapsed_time(game_controller.round_elapsed)


func _on_round_finished() -> void:
	spawn_director.stop()
	_suppressed_bonus_escapes.clear()
	_round_result_ready = false
	var generation := _attempt_generation
	var round_generation: int = game_controller.round_generation
	var saved := _checkpoint()
	if not game_controller.is_practice:
		round_director.observe_round(game_controller.round_stats)
		ANALYTICS.record("level_complete", {"level_id": _analytics_level_id(), "duration_sec": _analytics_duration}, _analytics_attempt)
	board_controller.finish_round_animations()
	while board_controller.get_occupied_slot_count() > 0 or hammer_controller.get_child_count() > 0:
		await get_tree().process_frame
		if generation != _attempt_generation or round_generation != game_controller.round_generation:
			return
	if generation != _attempt_generation or round_generation != game_controller.round_generation:
		return
	_round_result_ready = true
	session_overlay.show_round_result(tutorial_round if game_controller.is_practice else round_director.round_index, game_controller.score - _round_start_score, game_controller.score, _round_best_combo, game_controller.lives, not saved, game_controller.is_practice)


func _start_next_round() -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.ROUND_TRANSITION or game_controller.lives <= 0 or not _round_result_ready:
		return
	_round_result_ready = false
	if game_controller.is_practice:
		if _tutorial.round_is_mastered(tutorial_round):
			_tutorial.advance_round()
		else:
			_start_practice_round(tutorial_round)
		return
	var generation := _attempt_generation
	var continue_round := func() -> void:
		while game_controller.state == GAME_CONTROLLER_SCRIPT.GameState.PAUSED:
			await get_tree().process_frame
			if not is_inside_tree() or generation != _attempt_generation:
				return
		if not is_inside_tree() or generation != _attempt_generation or game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.ROUND_TRANSITION:
			return
		_round_profile = round_director.next_profile()
		_configure_round()
		game_controller.start_round(_round_profile)
		_begin_round_analytics()
	if monetization_service != null:
		monetization_service.show_transition_ad(MonetizationService.AD_PLACEMENT_CYCLE_END, continue_round, game_controller.completed_rounds)
	else:
		continue_round.call()


func _analytics_level_id() -> int:
	return round_director.phase_index + 1


func _on_slot_tapped(slot_index: int) -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return
	if not hammer_controller.can_strike():
		return
	if not _tutorial.allows_tap(slot_index):
		return
	var actual_slot: int = game_controller.redirect_gameplay_slot(slot_index, 9)
	if actual_slot != slot_index:
		hud.show_feedback(tr("HAMMER_CONFUSED"))
	var impact_position: Vector2 = board_controller.get_slot_impact_position(actual_slot)
	if hammer_controller.strike(actual_slot, impact_position):
		_resolve_accepted_tap(actual_slot)


func _resolve_accepted_tap(slot_index: int) -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return
	audio_manager.play_event(&"hammer_bonk")
	if not board_controller.hit_slot(slot_index):
		board_controller.play_empty_hit(slot_index)
		if _tutorial.empty_hit(slot_index):
			return
		game_controller.resolve_empty_hit()
		_remember_missed_bonuses()
		var impact_global: Vector2 = board_controller.get_global_transform() * board_controller.get_slot_impact_position(slot_index)
		_impact_fx_layer.show_score(impact_global, tr("MISS"))
		audio_manager.play_event(&"empty_hit")


func _on_character_hit(_slot_index: int, character_type: StringName) -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return
	_consume_suppressed_bonus_escape(_slot_index)
	var impact_global: Vector2 = board_controller.get_global_transform() * board_controller.get_slot_impact_position(_slot_index, true)
	var lives_before: int = game_controller.lives
	game_controller.resolve_character_hit(character_type)
	_update_run_details()
	_tutorial.hit(_slot_index)
	if character_type in [&"normal", &"fast", &"golden"]:
		audio_manager.play_event(&"correct_hit")
		_shake(3.0, 0.08)
		_impact_fx_layer.show_score(impact_global, "+%d" % GAME_CONTROLLER_SCRIPT.scoring_points(character_type))
	elif character_type == &"bomb":
		audio_manager.play_event(&"bomb")
		_shake(8.0, 0.15)
		_impact_fx_layer.show_bomb_confetti(impact_global)
	elif character_type == &"clock":
		audio_manager.play_event(&"clock")
	elif character_type == &"glutton":
		audio_manager.play_event(&"apple_restore")
		hud.show_feedback(tr("LIFE_BONUS") if lives_before < 3 else tr("FULL"))
		_impact_fx_layer.show_score(impact_global, tr("LIFE_BONUS") if lives_before < 3 else tr("FULL"), true)
		if lives_before < 3:
			hud.fly_hammer_to_hud(impact_global)
	elif character_type == &"drunk":
		audio_manager.play_event(&"drunk")


func _on_character_escaped(slot_index: int, character_type: StringName) -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return
	if _tutorial.escape(slot_index):
		return
	var impact_global: Vector2 = board_controller.get_global_transform() * board_controller.get_slot_impact_position(slot_index)
	game_controller.resolve_character_escape(character_type)
	var escape_feedback_suppressed := _consume_suppressed_bonus_escape(slot_index)
	if character_type in [&"normal", &"fast", &"golden"]:
		audio_manager.play_event(&"clown_miss")
	elif character_type == &"glutton":
		if not escape_feedback_suppressed:
			_impact_fx_layer.show_score(impact_global, tr("GLUTTON_ESCAPED"))
		audio_manager.play_event(&"glutton_escape")


func _remember_missed_bonuses() -> void:
	# One suppression belongs to one occupant, however many empty strikes occur.
	for index in range(9):
		var slot: Control = board_controller.get_slot(index)
		if slot.is_hittable() and slot.get_character_type() in [&"clock", &"glutton"]:
			_suppressed_bonus_escapes[index] = slot.get_lifecycle_id()


func _consume_suppressed_bonus_escape(slot_index: int) -> bool:
	var lifecycle := int(_suppressed_bonus_escapes.get(slot_index, -1))
	_suppressed_bonus_escapes.erase(slot_index)
	var slot: Control = board_controller.get_slot(slot_index)
	# Hit/escape advances the lifecycle before emitting its signal.
	return slot != null and lifecycle >= 0 and lifecycle + 1 == slot.get_lifecycle_id()


func _on_character_spawned(character_type: StringName) -> void:
	audio_manager.play_event(&"box_pop")
	_tutorial.consider(character_type)


func _on_combo_changed(value: int) -> void:
	_round_best_combo = maxi(_round_best_combo, value)
	hud.set_combo(value)
	_update_run_details()
	if value in [3, 5, 10]:
		audio_manager.play_event(&"combo")


func _on_lives_changed(value: int) -> void:
	hud.set_lives(value)
	if value < _last_lives:
		audio_manager.play_event(&"life_lost")
	_last_lives = value
	_update_run_details()


func _on_countdown_changed(text: String) -> void:
	session_overlay.show_countdown(text)
	if not text.is_empty():
		audio_manager.play_event(&"countdown")


func _on_confusion_changed(remaining: int) -> void:
	spawn_director.set_confusion_remaining(remaining)


func _on_pause_pressed() -> void:
	game_controller.pause_level()


func _on_resume_requested() -> void:
	game_controller.resume_level()


func _on_retry_requested() -> void:
	if game_controller.is_practice:
		_start_practice_round(tutorial_round)
	else:
		if game_controller.finish_reason != "lives":
			game_controller.finish_run("restart")
		retry_requested.emit()


func _on_state_changed(value: int) -> void:
	var is_running := value == GAME_CONTROLLER_SCRIPT.GameState.RUNNING
	if monetization_service != null:
		monetization_service.show_banner(is_running and not game_controller.is_practice)
	if monetization_service != null and not monetization_service.is_platform_lifecycle_active():
		monetization_service.set_gameplay_active(is_running)
	hud.set_pause_enabled(is_running)
	if is_running:
		session_overlay.hide_overlay()
		if not _tutorial.demonstrating:
			spawn_director.start()
		if game_controller.is_practice and _tutorial.round_is_mastered(tutorial_round):
			session_overlay.show_tutorial_advance(true)
	elif value == GAME_CONTROLLER_SCRIPT.GameState.COUNTDOWN:
		spawn_director.stop()
		board_controller.clear_all()
	elif value == GAME_CONTROLLER_SCRIPT.GameState.PAUSED:
		spawn_director.stop()
		if game_controller.pause_reasons.has(&"manual"):
			session_overlay.show_pause()
	else:
		spawn_director.stop()


func handle_platform_pause() -> void:
	_checkpoint()
	game_controller.pause_level(&"platform")


func handle_platform_resume() -> void:
	game_controller.resume_level(&"platform")


func _checkpoint() -> bool:
	if game_controller.is_practice:
		return true
	return save_manager.record_run(game_controller.score, game_controller.max_combo, game_controller.completed_rounds, game_controller.active_elapsed)


func _leave_run() -> void:
	if not game_controller.is_practice:
		game_controller.finish_run("menu")
	_attempt_generation += 1
	_tutorial.reset_attempt()
	spawn_director.stop()
	board_controller.clear_all()
	menu_requested.emit()


func _on_game_finished(_won: bool) -> void:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.FINISHED_LOSS:
		return
	var generation := _attempt_generation
	spawn_director.stop()
	board_controller.clear_all()
	hammer_controller.clear_strikes()
	if game_controller.is_practice:
		_start_practice_round.call_deferred(tutorial_round)
		return
	var saved := _checkpoint()
	if game_controller.finish_reason != "lives" or game_controller.lives > 0:
		return
	var run_generation: int = game_controller.run_generation
	audio_manager.play_event(&"defeat")
	if not _analytics_finished:
		_analytics_finished = true
		ANALYTICS.record("level_fail", {"level_id": _analytics_level_id(), "reason": "failed"}, _analytics_attempt)
	await get_tree().create_timer(0.5, true, false, true).timeout
	if not is_inside_tree() or generation != _attempt_generation or run_generation != game_controller.run_generation or game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.FINISHED_LOSS or game_controller.lives > 0:
		return
	session_overlay.show_run_result(game_controller.score, game_controller.max_combo, game_controller.completed_rounds,
		game_controller.active_elapsed, _previous_best, not saved)


func _on_life_restored(source: String) -> void:
	if source == "recovery":
		hud.fly_hammer_to_hud(board_controller.global_position + board_controller.size * 0.5)
		hud.show_feedback(tr("RECOVERY_LIFE"))


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
	game_controller.is_practice = true
	return board_controller.spawn_normal(slot_index, visible_time)


func debug_spawn_character(slot_index: int, character_type: StringName, visible_time: float = 1.5) -> bool:
	game_controller.is_practice = true
	return board_controller.spawn_character(slot_index, character_type, visible_time)


func debug_set_round(value: int) -> void:
	if not OS.is_debug_build():
		return
	game_controller.is_practice = true
	spawn_director.stop()
	board_controller.clear_all()
	round_director.round_index = maxi(value - 1, 0)
	_round_profile = round_director.next_profile()
	_configure_round()
	game_controller.start_round(_round_profile)


func debug_tap_slot(slot_index: int) -> bool:
	if game_controller.state != GAME_CONTROLLER_SCRIPT.GameState.RUNNING:
		return false
	if not hammer_controller.can_strike() or not _tutorial.allows_tap(slot_index):
		return false
	_on_slot_tapped(slot_index)
	return true


func _update_run_details() -> void:
	var recovery_available: bool = not game_controller.is_practice and _round_profile.phase_index == 0 and not game_controller.recovery_used and game_controller.lives < 3
	hud.set_run_details(game_controller.max_combo, game_controller.recovery_hits, recovery_available)


func _on_hammer_impact(_slot_index: int) -> void:
	# Kept as a visual-only legacy callback. Never resolve gameplay here.
	pass
