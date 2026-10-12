extends SceneTree

const GAME := preload("res://scripts/gameplay/game_controller.gd")
const DIRECTOR := preload("res://scripts/gameplay/round_director.gd")
const GAMEPLAY := preload("res://scenes/gameplay/Gameplay.tscn")
var failures := 0
var checks := 0

func _init() -> void:
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/endless/runtime")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory + "/save.json")
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var d := DIRECTOR.new()
	var other := DIRECTOR.new()
	d.start_run(7246)
	other.start_run(7246)
	var previous: RoundProfile
	var repeats := 0
	var last := ""
	for index in range(5000):
		var p: RoundProfile = d.next_profile()
		var q: RoundProfile = other.next_profile()
		check(p.validation_errors().is_empty(), "effective profile bounds %s" % index)
		check(d.phase_index == index % 5 and d.cycle_index == index / 5 + 1, "five phase cycle")
		check(p.pattern == q.pattern and p.normal_weight == q.normal_weight, "same seed repeats effective plan")
		repeats = repeats + 1 if p.pattern == last else 1
		last = p.pattern
		check(repeats <= 2, "pattern repetition bound")
		if index % 5 == 0 and previous != null:
			check(p.max_decision_targets < previous.max_decision_targets and p.normal_visible_time > previous.normal_visible_time * 1.1 and p.spawn_interval_min > previous.spawn_interval_min * 1.1, "recovery softer than assisted peak")
		previous = p
	d.start_run(42)
	d.observe_round({"scoring_hits": 1, "scoring_escapes": 8})
	check(d.assist_step == 0 and not d.has_accuracy, "small sample neutral")
	d.observe_round({"lives_lost": 1})
	check(d.assist_step == 1, "life loss helps even with small sample")
	d.observe_round({"lives_lost": 2})
	check(d.assist_step == 2, "one assist step per round capped2")
	d.observe_round({"scoring_hits": 20})
	d.observe_round({"scoring_hits": 20})
	check(d.assist_step == 1, "two success rounds restore one step")
	d.free()
	other.free()
	var c := GAME.new()
	root.add_child(c)
	var profile := RoundProfile.new()
	c.start_run(profile, false)
	c.set_process(false)
	c.lives = 2
	for index in range(19): c.resolve_scoring_hit()
	check(c.lives == 2 and c.recovery_hits == 19, "19 cannot heal")
	c.resolve_scoring_hit()
	check(c.lives == 3 and c.recovery_used, "20 restore exactly one")
	c.lose_life()
	for index in range(20): c.resolve_scoring_hit()
	check(c.lives == 2, "no second cycle recovery")
	c.start_round(profile)
	c.set_process(false)
	c.resolve_scoring_hit()
	c.resolve_empty_hit()
	check(c.recovery_hits == 0, "empty error clears recovery")
	c.resolve_scoring_hit()
	c.resolve_scoring_miss()
	check(c.recovery_hits == 0, "escape clears recovery")
	c.lives = 1
	c.restore_life()
	check(c.lives == 2, "Glutton independent recovery")
	c.combo_count = 8
	c.consecutive_misses = 2
	c.score = 555
	c.active_elapsed = 47
	c.add_time(10)
	var transitions := [0]
	c.round_finished.connect(func() -> void: transitions[0] += 1)
	c.complete_round()
	c.complete_round()
	check(transitions[0] == 1 and c.completed_rounds == 1, "transition barrier once")
	c.start_round(load("res://data/round_profiles/build.tres"))
	check(c.lives == 2 and c.score == 555 and c.combo_count == 8 and c.consecutive_misses == 2 and c.active_elapsed == 47, "state carries across boundary")
	check(c.remaining_time == 25 and c.time_bonus_awarded == 0, "local quota resets")
	c.pause_level(&"manual")
	c.pause_level(&"platform")
	c.resume_level(&"platform")
	check(c.state == GAME.GameState.PAUSED and paused, "platform return cannot close manual pause")
	c.resume_level()
	check(c.state == GAME.GameState.RUNNING and not paused, "manual owner resumes")
	c.resolve_empty_hit()
	check(c.lives == 1 and c.consecutive_misses == 0, "third miss carries across boundary")
	var finishes := [0]
	c.game_finished.connect(func(_won: bool) -> void: finishes[0] += 1)
	c.lose_life()
	c.finish_run()
	c.complete_round()
	c.restore_life()
	check(finishes[0] == 1 and c.lives == 0, "zero lives finish once no resurrection")
	c.start_run(profile, false, true)
	c.set_process(false)
	c.lives = 2
	for index in range(20): c.resolve_scoring_hit()
	c._process(1)
	check(c.recovery_hits == 0 and c.active_elapsed == 0 and c.round_stats.scoring_hits == 0, "practice excluded")
	c.queue_free()
	await process_frame
	var g := GAMEPLAY.instantiate()
	g.deterministic_seed = 42
	root.add_child(g)
	await process_frame
	g.game_controller.begin_running()
	g.game_controller.set_process(false)
	g.spawn_director.stop()
	for index in [9, 999]:
		g.round_director.round_index = index
		g.game_controller.lives = 2
		g.game_controller.score = 770
		g.game_controller.combo_count = 5
		g.game_controller.consecutive_misses = 2
		g.board_controller.spawn_normal(4, 5)
		while not g.board_controller.get_slot(4).is_hittable():
			await process_frame
		g._on_slot_tapped(4)
		check(g.game_controller.score == 780, "accepted last-frame tap")
		g.game_controller.remaining_time = .001
		g.game_controller._process(.01)
		check(g.game_controller.state == GAME.GameState.ROUND_TRANSITION and g.board_controller.get_occupied_slot_count() > 0, "scene keeps accepted strike animation at barrier")
		while not g._round_result_ready:
			await process_frame
		check(g.session_overlay.is_showing_round_result(), "Round results precede continuation")
		g.session_overlay.round_continue_requested.emit()
		g.game_controller.set_process(false)
		g.spawn_director.stop()
		check(g.round_director.round_index == index + 1 and g.game_controller.lives == 2 and g.game_controller.score == 780, "9->10 and999->1000")
		check(g.game_controller.combo_count == 6 and g.game_controller.consecutive_misses == 0, "accepted result survives transition")
		g._on_hammer_impact(4)
		check(g.game_controller.score == 780, "old impact cannot double")
	g.game_controller.pause_level()
	g.handle_platform_pause()
	g.handle_platform_resume()
	check(g.session_overlay.is_showing_pause() and g.game_controller.state == GAME.GameState.PAUSED, "scene pause owner")
	g.game_controller.resume_level()
	# Warm-up then real scene 10-cycle soak with accelerated boundary timer only.
	var nodes := g.get_child_count()
	var connections: int = g.board_controller.character_hit.get_connections().size()
	g._start_run()
	g.game_controller.begin_running()
	g.game_controller.set_process(false)
	for index in range(50):
		g.spawn_director.stop()
		g.board_controller.clear_all()
		g.board_controller.spawn_normal(index % 9, 5)
		while not g.board_controller.get_slot(index % 9).is_hittable():
			await process_frame
		g.hammer_controller._last_strike_time = -10
		g._on_slot_tapped(index % 9)
		g.game_controller.remaining_time = .001
		g.game_controller._process(.01)
		while not g._round_result_ready:
			await process_frame
		g.session_overlay.round_continue_requested.emit()
		check(g.game_controller.lives == 3 and g.get_child_count() == nodes and g.board_controller.character_hit.get_connections().size() == connections, "scene soak stable node/signal count")
		check(g.spawn_director._guaranteed_queue.size() <= 6, "bounded spawn queues")
	check(g.round_director.round_index == 51, "ten actual scene cycles")
	g._leave_run()
	g.queue_free()
	await process_frame
	print("ENDLESS RESULT: ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

