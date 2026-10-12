extends SceneTree

const GAMEPLAY := preload("res://scenes/gameplay/Gameplay.tscn")
const SAVE := preload("res://scripts/save/save_manager.gd")
const TUTORIAL := preload("res://scripts/gameplay/tutorial_controller.gd")
var failures := 0
var g: Control
var save: Node
var observed_clock_duration := 0.0
var observed_glutton_loss := false
var observed_glutton_restore := false


func _init() -> void:
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/endless/tutorial")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory + "/save.json")
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	Engine.time_scale = 1.0
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", false)
	save = SAVE.new()
	root.add_child(save)
	save.set_save_path_for_tests("res://builds/debug/verification/endless/tutorial/tutorial_resume_disposable.json")
	save.delete_save_for_tests()
	g = GAMEPLAY.instantiate()
	g.configure("training", save)
	root.add_child(g)
	g.game_controller.spawn_slowdown_requested.connect(func(value: float) -> void:
		if g._tutorial.teaching == &"clock":
			observed_clock_duration = maxf(observed_clock_duration, value))
	g.game_controller.lives_changed.connect(func(value: int) -> void:
		if g._tutorial.teaching == &"glutton":
			observed_glutton_loss = observed_glutton_loss or value == 2
			observed_glutton_restore = observed_glutton_restore or (observed_glutton_loss and value == 3))
	check(g.session_overlay.is_showing_tutorial() and g._tutorial.teaching == &"normal", "Real scene immediately presents first missing lesson")
	check(not g.debug_tap_slot(4), "Modal card rejects gameplay input")
	g.board_controller.clear_all()
	g._tutorial.demo_slots.clear()
	g.session_overlay.tutorial_continue_requested.emit()
	await create_timer(0.8, true).timeout
	check(g.board_controller.get_occupied_slot_count() == 1 and g._tutorial.demo_slots == [4], "Removed old target yields fresh center practice")
	var frozen: float = g.game_controller.remaining_time
	await create_timer(6.5, true).timeout
	check(g._tutorial.demonstrating and g.board_controller.get_occupied_slot_count() > 0, "Real expired practice target retries without a card")
	check(is_equal_approx(g.game_controller.remaining_time, frozen) and g.game_controller.lives == 3, "Real retry freezes timer without life penalty")
	await _tap(4)
	check(g._tutorial.teaching == &"normal", "Real scene requires second separate Normal hit")
	g.board_controller.get_slot(4).hide_duration = 1.60
	await _tap(4)
	g.board_controller.get_slot(4).hide_duration = 0.62
	check(g._tutorial.teaching == &"misses", "Two accepted hits persist Normal mastery")
	g.session_overlay.tutorial_continue_requested.emit()
	await _tap(4)
	for index in range(3):
		await create_timer(0.12, true).timeout
		check(g.debug_tap_slot(4), "Real empty-box tap is accepted in misses exercise")
	check(g.game_controller.lives == 2 and g.game_controller.combo_count == 0, "Real three misses show penalty and reset series")
	await create_timer(0.12, true).timeout
	check(g.debug_tap_slot(4), "Fourth practice miss leaves a counter to reset")
	await _tap(4)
	await process_frame
	check(g._tutorial.round_is_mastered(1) and g.game_controller.lives == 3, "Resetting hit masters misses and restores safe snapshot")
	var before_free: float = g.game_controller.remaining_time
	await create_timer(0.15, true).timeout
	check(g.game_controller.remaining_time < before_free and g.spawn_director._running, "Mastered scene resumes free-practice timer and spawner")
	g.session_overlay.tutorial_next_requested.emit()
	g.session_overlay.tutorial_continue_requested.emit()
	await create_timer(0.7, true).timeout
	check(not g.debug_tap_slot(4), "Bomb demonstration blocks dangerous hit")
	await create_timer(6.5, true).timeout
	check(g._tutorial.teaching == &"two", "Natural Bomb escape advances the real lesson chain")
	g.session_overlay.tutorial_continue_requested.emit()
	await _tap(3)
	check(g._tutorial.teaching == &"two", "First distinct target does not complete two-target lesson")
	await _tap(5)
	check(g._tutorial.teaching == &"series", "Two actual distinct taps complete two-target practice")
	g.session_overlay.tutorial_continue_requested.emit()
	await _tap(4)
	check(g._tutorial.teaching == &"series", "Single actual hit does not complete series practice")
	await _tap(4)
	await _tap(4)
	await process_frame
	g.session_overlay.tutorial_next_requested.emit()
	for lesson in [&"golden", &"fast"]:
		check(g._tutorial.teaching == lesson, "Real scene presents expected scoring variant")
		g.session_overlay.tutorial_continue_requested.emit()
		await _tap(4)
		check(g._tutorial.teaching == lesson, "Variant requires two actual hits")
		await _tap(4)
	await process_frame
	g.session_overlay.tutorial_next_requested.emit()
	var clock_before: float = g.game_controller.remaining_time
	g.session_overlay.tutorial_continue_requested.emit()
	await _tap(4)
	check(observed_clock_duration == 5.0 and g.game_controller.remaining_time <= clock_before, "Real Clock hit activates five-second slowdown without extending time")
	check(g._tutorial.teaching == &"glutton", "Clock action advances to survival lesson")
	g.session_overlay.tutorial_continue_requested.emit()
	await create_timer(6.0, true).timeout
	check(observed_glutton_loss and g.game_controller.lives == 2, "Real Glutton escape safely demonstrates life loss")
	await _tap(4)
	check(observed_glutton_restore and g._tutorial.teaching == &"endless_rules", "Glutton accepted hit restores third life before completion")
	check(not save.tutorials_complete(), "Final rules require explicit acknowledgement")
	g.session_overlay.tutorial_continue_requested.emit()
	await process_frame
	check(save.tutorials_complete() and g.game_controller.is_practice and g.session_overlay.is_showing_training_complete(), "Final confirmation shows training completion without starting a run")
	var frozen_completion_time: float = g.game_controller.remaining_time
	await create_timer(.2, true).timeout
	check(g.game_controller.remaining_time == frozen_completion_time and not g.spawn_director._running and g.session_overlay._continue_button.text == tr("START_GAME"), "Completion waits with Start game and freezes gameplay")
	g.session_overlay._continue_button.pressed.emit()
	g.session_overlay.game_start_requested.emit()
	await process_frame
	check(not g.game_controller.is_practice and g.round_director.round_index == 1, "Start game starts exactly one new ordinary run")
	check(g.round_director.round_index == 1 and g.game_controller.completed_rounds == 0, "Training stages never enter ordinary round counter")
	check(g.game_controller.score == 0 and g.game_controller.combo_count == 0 and g.game_controller.max_combo == 0 and g.game_controller.lives == 3 and g.game_controller.time_bonus_awarded == 0 and g.game_controller.remaining_time == 25 and g.game_controller.active_elapsed == 0 and g.game_controller.consecutive_misses == 0 and g.game_controller.golden_hits == 0, "New ordinary game clears every training score, series, time bonus and miss")
	var data: Dictionary = save.load_data()
	check(data.best_run_score == 0 and data.best_run_combo == 0 and data.best_run_rounds == 0, "Tutorial never improves endless records")
	g.spawn_director.stop()
	g._tutorial.reset_attempt()
	g.game_controller.pause_level(&"manual")
	g.session_overlay.rules_requested.emit()
	g.session_overlay.tutorial_continue_requested.emit()
	check(g.session_overlay.is_showing_pause() and g.game_controller.pause_reasons.has(&"manual"), "Rules return to the actual manual pause")
	g.game_controller.resume_level(&"manual")
	g.queue_free()
	await process_frame
	# Persist a partial chain and verify only the first missing lesson is resumed.
	data.learned_lessons.erase("fast")
	save.save_data(data)
	save.queue_free()
	await process_frame
	save = SAVE.new()
	root.add_child(save)
	save.set_save_path_for_tests("res://builds/debug/verification/endless/tutorial/tutorial_resume_disposable.json")
	TUTORIAL.learned.clear()
	g = GAMEPLAY.instantiate()
	g.configure("training", save)
	root.add_child(g)
	check(g.tutorial_round == 3 and g._tutorial.teaching == &"fast", "Restart resumes first missing save lesson without replaying mastered content")
	g.session_overlay.tutorial_continue_requested.emit()
	await create_timer(0.7, true).timeout
	g._tutorial._hits = 1
	check(g.debug_tap_slot(4), "Final practice hit starts animation completion wait")
	check("fast" in save.load_data().learned_lessons and not g.session_overlay.is_showing_tutorial(), "Mastery persists immediately while the next card waits")
	var generation: int = g._tutorial._generation
	var step: int = g._tutorial._step_generation
	g._leave_run()
	await create_timer(1.4, true).timeout
	g._tutorial._retry_demo(generation, step, &"fast")
	check(g.board_controller.get_occupied_slot_count() == 0 and not g._tutorial.demonstrating, "Menu invalidates old tutorial generation and cannot reopen board")
	g.queue_free()
	save.delete_save_for_tests()
	save.queue_free()
	await process_frame
	paused = false
	print("TUTORIAL RESUME ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _tap(index: int) -> void:
	await create_timer(0.7, true).timeout
	check(g.debug_tap_slot(index), "Real Gameplay accepted target tap")
	var slot: Control = g.board_controller.get_slot(index)
	check(slot.clown.visible and not g.session_overlay.is_showing_tutorial(), "Accepted action keeps character visible without opening the next card")
	await create_timer(0.35, true).timeout
	check(slot.clown.visible and not g.session_overlay.is_showing_tutorial(), "Next card remains hidden during the real impact and retreat")
	var deadline := Time.get_ticks_msec() + 4000
	var early_card := false
	while slot.state in [slot.SlotState.HIT, slot.SlotState.HIDING, slot.SlotState.COOLDOWN] and Time.get_ticks_msec() < deadline:
		early_card = early_card or g.session_overlay.is_showing_tutorial()
		await process_frame
	check(not early_card and slot.state not in [slot.SlotState.HIT, slot.SlotState.HIDING, slot.SlotState.COOLDOWN], "Card waits for actual animation completion including a longer hide duration")
	await process_frame
