extends SceneTree
## Ordinary-speed real tweens and input; Clock is intentionally left neutral for three30s boundaries.
func _init() -> void:
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/endless/desktop")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory + "/save.json")
	_run.call_deferred()

func _run() -> void:
	var game: Control = load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.deterministic_seed = 42
	root.add_child(game)
	game.game_controller.begin_running()
	var pending: Dictionary = {}
	var elapsed := 0.0
	var next_tap := 0.0
	var boundaries := 0
	var previous_round := 1
	var seen := {}
	var failed := false
	while boundaries < 3 and elapsed < 160.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		if game.session_overlay.is_showing_round_result():
			game.session_overlay.round_continue_requested.emit()
		var state: int = game.game_controller.state
		if state == game.game_controller.GameState.FINISHED_LOSS:
			failed = true
			break
		var current: int = game.round_director.round_index
		if current != previous_round:
			boundaries += 1
			print("DESKTOP boundary=", current, " lives=", game.game_controller.lives, " score=", game.game_controller.score, " phase=", game.round_director.phase_index)
			previous_round = current
			pending.clear()
			if boundaries == 2:
				# Continue at peak using the ordinary runtime profile, no timer/lifecycle acceleration.
				game.spawn_director.stop()
				game.board_controller.clear_all()
				game.round_director.round_index = 4
				game._round_profile = game.round_director.next_profile()
				game._configure_round()
				game.game_controller.start_round(game._round_profile)
				previous_round = 5
		if state != game.game_controller.GameState.RUNNING:
			continue
		seen[game.round_director.phase_index] = true
		for index in range(9):
			var slot: Control = game.board_controller.get_slot(index)
			if not slot.is_hittable() or slot.get_character_type() in [&"bomb", &"clock"]:
				continue
			var key := "%d:%d" % [index, slot._lifecycle_id]
			if not pending.has(key): pending[key] = elapsed + .35 + .05 * (index % 3)
			if elapsed < pending[key] or elapsed < next_tap:
				continue
			var point: Vector2 = game.board_controller.get_slot_impact_position(index)
			if game.board_controller.get_slot_index_for_tap(point) != index:
				failed = true
			game.board_controller.slot_tapped.emit(index)
			next_tap = elapsed + .15
			pending.erase(key)
			break
		# Remove stale recognitions: scene soak should not grow model queues either.
		for key in pending.keys():
			var bits: PackedStringArray = str(key).split(":")
			var slot: Control = game.board_controller.get_slot(int(bits[0]))
			if slot._lifecycle_id != int(bits[1]) or not slot.is_hittable(): pending.erase(key)
	failed = failed or boundaries < 3 or not seen.has(0) or not seen.has(1) or not seen.has(4)
	print("DESKTOP_BALANCE_RUNTIME ", "FAIL" if failed else "PASS", " boundaries=", boundaries, " active=", game.game_controller.active_elapsed, " phases=", seen.keys())
	game._leave_run()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
