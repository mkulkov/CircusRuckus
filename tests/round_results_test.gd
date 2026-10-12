extends SceneTree
const GAMEPLAY := preload("res://scenes/gameplay/Gameplay.tscn")
var failures := 0
func _init() -> void:
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/round30")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory + "/results_save.json")
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
func _run() -> void:
	var g := GAMEPLAY.instantiate()
	root.add_child(g)
	g.game_controller.begin_running()
	g.game_controller.set_process(false)
	g.spawn_director.stop()
	check(g.game_controller.remaining_time == 25, "Base round is 25 seconds")
	for index in 4: g.game_controller.resolve_character_hit(&"clock")
	check(g.game_controller.remaining_time == 25 and g.spawn_director.slowdown_remaining == 5, "Repeated Clock hits refresh slowdown without extending round")
	g.board_controller.spawn_normal(4, 5)
	while not g.board_controller.get_slot(4).is_hittable(): await process_frame
	g._on_slot_tapped(4)
	g.board_controller.spawn_character(2, &"glutton", 5)
	g.game_controller.remaining_time = 0
	g.game_controller._process(.01)
	check(not g.session_overlay.is_showing_round_result() and g.board_controller.get_slot(4).clown.visible, "Timeout preserves reserved hit animation without early modal")
	var score: int = g.game_controller.score
	g._on_slot_tapped(0)
	check(g.game_controller.score == score and g.game_controller.consecutive_misses == 0, "Input blocked after timeout")
	var deadline := Time.get_ticks_msec() + 5000
	while not g._round_result_ready and Time.get_ticks_msec() < deadline:
		if g.board_controller.get_occupied_slot_count() > 0:
			check(not g.session_overlay.is_showing_round_result(), "Modal waits for occupied visual lifecycle")
		await process_frame
	check(g.session_overlay.is_showing_round_result() and g.game_controller.lives == 3 and g.game_controller.consecutive_misses == 0, "Animation completion shows results without Glutton escape penalty")
	check(g.session_overlay._result_score == 10 and g.session_overlay._result_details.total_score == 10, "Round and total score are distinct result fields")
	var active: float = g.game_controller.active_elapsed
	await create_timer(1.2).timeout
	check(g.round_director.round_index == 1 and g.game_controller.active_elapsed == active and not g.spawn_director._running, "Results wait for Continue without time or spawning")
	g.session_overlay._resume_button.pressed.emit()
	g.session_overlay.round_continue_requested.emit()
	check(g.round_director.round_index == 2 and g.game_controller.score == 10 and g.game_controller.lives == 3 and g.game_controller.combo_count == 1, "Continue advances exactly once and preserves state")
	g.game_controller.set_process(false)
	g.spawn_director.stop()
	g.board_controller.spawn_normal(4, 5)
	g.game_controller.complete_round()
	g._start_run()
	await create_timer(1.5).timeout
	check(not g.session_overlay.is_showing_round_result() and g.round_director.round_index == 1, "Restart cancels old animation waiter")
	g.game_controller.begin_running()
	g.spawn_director.stop()
	g._on_game_finished(false)
	await create_timer(.6).timeout
	check(not g.session_overlay.is_showing_result(), "Unexpected stale finish notification cannot end a live game")
	g.game_controller.finish_run("menu")
	await create_timer(.6).timeout
	check(not g.session_overlay.is_showing_result(), "Menu exit with remaining lives does not show a defeat modal")
	g._start_run()
	g.game_controller.begin_running()
	g.spawn_director.stop()
	for index in 3: g.game_controller.lose_life()
	g._start_run()
	await create_timer(.7).timeout
	check(not g.session_overlay.is_showing_result(), "Old zero-life modal cannot overlay a new game")
	g._leave_run()
	g.queue_free()
	await process_frame
	print("ROUND RESULTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
