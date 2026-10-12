extends SceneTree

const GAMEPLAY := preload("res://scenes/gameplay/Gameplay.tscn")
const HUD := preload("res://scripts/ui/gameplay_hud.gd")
var failures := 0
var checks := 0


func _init() -> void:
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/refactor_2026-10-11")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory.path_join("test_save.json"))
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)


func _run() -> void:
	var game := GAMEPLAY.instantiate()
	root.add_child(game)
	var seed_number: int = game.round_director.seed_value
	var original := _sample_run(game)
	game.deterministic_seed = seed_number
	game._start_run()
	check(_sample_run(game) == original, "Recorded production seed replays profiles, slots, types and intervals")
	game.spawn_director._last_slot = 4
	game.spawn_director._same_slot_streak = 2
	game.spawn_director.prepare_round()
	check(game.spawn_director._last_slot == 4 and game.spawn_director._same_slot_streak == 2, "Round boundary preserves consecutive-slot fairness")
	for attempt in range(30):
		game.spawn_director._last_slot = 4
		game.spawn_director._same_slot_streak = 2
		game.board_controller.clear_all()
		game.spawn_director._spawn_one()
		check(game.board_controller.get_slot(4).is_idle(), "Fairness excludes previous slot when alternatives exist")
	game._start_run()
	check(game.spawn_director._last_slot == -1 and game.spawn_director._same_slot_streak == 0, "New run resets slot history")
	game.game_controller.begin_running()
	game.game_controller.set_process(false)
	game.spawn_director.stop()
	game.board_controller.clear_all()
	await _test_bonus_feedback(game)
	await _test_slot_lifecycle(game)
	game.queue_free()
	await process_frame
	await _test_hud()
	print("REFACTOR CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _sample_run(game: Control) -> Array:
	var result: Array = []
	game.game_controller.begin_running()
	game.game_controller.set_process(false)
	game.spawn_director.stop()
	for round_number in range(3):
		result.append(game.round_director.debug_plan.duplicate(true))
		for event in range(12):
			game.board_controller.clear_all()
			game.spawn_director.set_elapsed_time(event * 2.0)
			game.spawn_director._spawn_one()
			for index in range(9):
				var slot: Control = game.board_controller.get_slot(index)
				if not slot.is_idle():
					result.append([index, slot.get_character_type(), slot._visible_time_remaining])
			result.append(game.spawn_director._next_spawn_interval())
		game.board_controller.clear_all()
		game.game_controller.complete_round()
		game._start_next_round()
		game.spawn_director.stop()
	return result


func _wait_hittable(slot: Control) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while not slot.is_hittable() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(slot.is_hittable(), "Target becomes readable within bounded wait")


func _test_bonus_feedback(game: Control) -> void:
	var slot: Control = game.board_controller.get_slot(4)
	game.board_controller.spawn_character(4, &"glutton", 5.0)
	await _wait_hittable(slot)
	game._resolve_accepted_tap(8)
	game._resolve_accepted_tap(8)
	slot._escape_character()
	check(game.game_controller.lives == 2 and game.game_controller.consecutive_misses == 0, "Glutton keeps its separate penalty after two empty strikes")
	check(game._suppressed_bonus_escapes.is_empty(), "Repeated misses do not leak feedback suppression into future occupants")
	slot.force_clear()
	game.board_controller.spawn_character(4, &"glutton", 5.0)
	await _wait_hittable(slot)
	var labels_before: int = game._impact_fx_layer._floating_labels.size()
	slot._escape_character()
	check(game._impact_fx_layer._floating_labels.size() == labels_before + 1, "Next Glutton escape gets its own feedback")
	game.board_controller.clear_all()


func _test_slot_lifecycle(game: Control) -> void:
	var slot: Control = game.board_controller.get_slot(0)
	slot.play_empty_hit()
	await create_timer(0.04).timeout
	slot.force_clear()
	check(is_zero_approx(slot.rotation), "Clear restores empty-hit rotation immediately")
	await create_timer(0.04).timeout
	check(is_zero_approx(slot.rotation), "Old empty-hit tween cannot move a cleared slot")
	game.board_controller.spawn_normal(0, 5.0)
	await _wait_hittable(slot)
	var head: Vector2 = game.board_controller.get_slot_impact_position(0)
	game._resolve_accepted_tap(0)
	var label: Dictionary = game._impact_fx_layer._floating_labels.back()
	var expected: Vector2 = game._impact_fx_layer.get_global_transform_with_canvas().affine_inverse() * (game.board_controller.get_global_transform() * head)
	check(Vector2(label.position).distance_to(expected) < 0.01, "Score feedback uses the reserved head position")
	check(slot.get_local_impact_position() == Vector2(145, 145), "Further empty strike targets the box, not the already-hit clown")
	await create_timer(0.26).timeout
	slot.force_clear()
	game.board_controller.spawn_normal(0, 5.0)
	await create_timer(0.03).timeout
	check(is_zero_approx(slot._impact_flash), "Old hit flash cannot affect the next occupant")
	game.board_controller.clear_all()
	var other: Control = game.board_controller.get_slot(1)
	check(slot._open_box_image == other._open_box_image and slot._closed_box_image == other._closed_box_image, "Nine boxes share immutable CPU hit-test images")


func _test_hud() -> void:
	var hud := HUD.new()
	root.add_child(hud)
	hud.set_lives(2)
	await create_timer(0.10).timeout
	hud.set_lives(1)
	await create_timer(0.35).timeout
	check(is_equal_approx(hud._hammer_scales[1], 1.0) and is_equal_approx(hud._hammer_scales[2], 1.0), "Rapid life losses finish both hammer animations")
	hud.set_lives(2)
	hud.fly_hammer_to_hud(Vector2(400, 900))
	await create_timer(0.5).timeout
	check(hud._flying_hammer_position.distance_to(Vector2(902, 68)) < 0.01, "Restored second hammer flies to the second HUD slot")
	hud.queue_free()
	await process_frame
