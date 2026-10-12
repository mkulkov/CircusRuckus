extends SceneTree

const GAMEPLAY := preload("res://scenes/gameplay/Gameplay.tscn")
var failures := 0

func _init() -> void:
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	ProjectSettings.set_setting("clown_smash/testing/save_path", "user://clock_slowdown_test.json")
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var g := GAMEPLAY.instantiate()
	root.add_child(g)
	var c: Node = g.game_controller
	var s: Node = g.spawn_director
	c.begin_running()
	c.set_process(false)
	s.set_process(false)
	c.resolve_character_hit(&"normal")
	c.resolve_character_hit(&"clock")
	check(c.remaining_time == 25 and c.combo_count == 1 and c.score == 10, "Clock preserves timer, series and score")
	s._time_until_spawn = 100.0
	s._process(2.0)
	check(s.slowdown_remaining == 3 and s._time_until_spawn == 99, "Spawn countdown advances at half speed")
	c.resolve_character_hit(&"clock")
	check(s.slowdown_remaining == 5, "Repeated Clock refreshes duration")
	c.pause_level()
	s._process(2.0)
	check(s.slowdown_remaining == 5 and s._time_until_spawn == 99, "Pause freezes slowdown and spawn countdown")
	c.resume_level()
	s._process(6.0)
	check(s.slowdown_remaining == 0 and s._time_until_spawn == 95.5, "Expiry splits slowed and ordinary portions of frame")
	s._process(1.0)
	check(s._time_until_spawn == 94.5, "Ordinary speed resumes")
	c.resolve_character_hit(&"clock")
	s._second_spawn_pending = true
	s._second_spawn_time_left = 1.0
	s._process(0.5)
	check(s._second_spawn_time_left == 0.75, "Pending second spawn is slowed too")
	s.prepare_round()
	check(s.slowdown_remaining == 0 and not s._second_spawn_pending, "New round clears effect and pending spawn")
	var expected := {"recovery": 0.7, "build": 0.675, "variation": 0.625, "pressure": 0.6, "peak": 0.55}
	for phase in expected:
		var profile: RoundProfile = load("res://data/round_profiles/" + phase + ".tres")
		check(is_equal_approx(profile.fast_visible_time, expected[phase]), "Fast window doubled: " + phase)
		check(profile.validation_errors().is_empty(), "Profile valid: " + phase)
	g.queue_free()
	await process_frame
	print("CLOCK SLOWDOWN TEST: ", failures, " failures")
	quit(1 if failures else 0)
