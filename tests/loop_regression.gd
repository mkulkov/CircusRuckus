extends SceneTree

var failures := 0
const GAMEPLAY := preload("res://scenes/gameplay/Gameplay.tscn")
const TUTORIAL := preload("res://scripts/gameplay/tutorial_controller.gd")


func _init() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)


func _run() -> void:
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/endless/loop")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory + "/save.json")
	var g := GAMEPLAY.instantiate()
	root.add_child(g)
	await process_frame
	g.save_manager.set_save_path_for_tests("res://builds/debug/verification/endless/loop/interaction.json")
	g.game_controller.begin_running()
	g.spawn_director.stop()
	g.game_controller.set_process(false)
	var c: Node = g.game_controller
	var board: Control = g.board_controller
	board.spawn_normal(0, 0.50)
	check(not board.get_slot(0).is_hittable(), "Invisible opening cannot be hit")
	var elapsed := 0.0
	while not board.get_slot(0).is_hittable() and elapsed < 1.0:
		await create_timer(0.01).timeout
		elapsed += 0.01
	print("READABLE_HEAD_SECONDS=", elapsed)
	check(board.get_slot(0).state == board.get_slot(0).SlotState.OPENING, "Readable head during pop accepts input")
	check(board.get_slot_index_for_tap(board.get_slot_impact_position(0)) == 0, "Head and box route to same logical target")
	board.get_slot(0)._visible_time_remaining = 0.01
	check(g.debug_tap_slot(0), "Tap just before deadline accepted")
	check(c.score == 10 and c.combo_count == 1, "Accepted tap scores immediately")
	g._on_hammer_impact(0)
	check(c.score == 10, "Legacy late impact cannot score twice")
	await create_timer(0.10).timeout
	check(g.debug_tap_slot(0) and c.score == 10, "Second accepted tap cannot score the reserved target twice")
	board.clear_all()
	board.spawn_normal(0, 3.0)
	await create_timer(0.25).timeout
	g._on_hammer_impact(0)
	check(c.score == 10 and board.get_slot(0).is_hittable(), "Late old impact cannot hit new occupant")
	board.get_slot(0)._visible_time_remaining = 0.001
	await create_timer(0.06).timeout
	g.hammer_controller._last_strike_time = -10.0
	g.debug_tap_slot(0)
	check(c.score == 10, "Tap after closed window is a miss")
	c.start_run(RoundProfile.new(), false)
	c.set_process(false)
	board.clear_all()
	board.spawn_character(1, &"bomb", 2.0)
	await create_timer(0.25).timeout
	g.hammer_controller._last_strike_time = -10.0
	g.debug_tap_slot(1)
	g._on_hammer_impact(1)
	check(c.lives == 2, "Bomb removes exactly one life")
	c.resolve_character_hit(&"normal")
	c.resolve_character_hit(&"clock")
	c.resolve_character_hit(&"glutton")
	check(c.combo_count == 1 and c.lives == 3, "Both bonus hits preserve series")
	c.consecutive_misses = 2
	c.resolve_character_escape(&"glutton")
	check(c.lives == 2 and c.combo_count == 0 and c.consecutive_misses == 0, "Glutton escape is one distinct penalty and resets misses")
	check(c.consecutive_misses == 0, "Authoritative miss counter resets")
	c.resolve_empty_hit()
	c.resolve_empty_hit()
	check(c.consecutive_misses == 2, "Authoritative miss counter before third miss")
	g.spawn_director.set_elapsed_time(20.0)
	c.add_time(10.0)
	check(is_equal_approx(g.spawn_director._round_progress, 20.0 / 25.0), "Clock cannot rewind spawn progression")
	board.clear_all()
	board.spawn_normal(2, 2.0)
	await create_timer(0.25).timeout
	c.remaining_time = 0.001
	g.hammer_controller._last_strike_time = -10.0
	g.debug_tap_slot(2)
	var score_before: int = c.score
	c._process(0.01)
	check(c.score == score_before and c.state == c.GameState.ROUND_TRANSITION, "Accepted final-frame result precedes expiry")
	g._start_run()
	g.spawn_director.stop()
	g._on_hammer_impact(2)
	check(c.score == 0, "Restart rejects old strike results")
	await create_timer(0.55).timeout
	check(not g.session_overlay.is_showing_result(), "Old finish timer cannot overlay restarted round")
	g.queue_free()
	await process_frame
	print("LOOP REGRESSION ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
