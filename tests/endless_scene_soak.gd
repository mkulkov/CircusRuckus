extends SceneTree
const GAMEPLAY := preload("res://scenes/gameplay/Gameplay.tscn")
var failures := 0
func _init() -> void:
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/endless/soak")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory + "/save.json")
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	_run.call_deferred()
func _count(node: Node) -> int:
	var result := 1
	for child in node.get_children(): result += _count(child)
	return result
func _run() -> void:
	Engine.time_scale = 4.0
	var g := GAMEPLAY.instantiate()
	g.deterministic_seed = 13579
	root.add_child(g)
	g.game_controller.begin_running()
	g.game_controller.remaining_time = 4.0
	var previous := 1
	var nodes_by_phase := {}
	var tween_peak := 0
	var node_peak := 0
	var elapsed := 0.0
	var connections: int = g.board_controller.character_hit.get_connections().size()
	while g.round_director.round_index < 51 and elapsed < 300.0:
		await process_frame
		elapsed += root.get_process_delta_time()
		if g.session_overlay.is_showing_round_result():
			g.session_overlay.round_continue_requested.emit()
		if g.game_controller.state == g.game_controller.GameState.FINISHED_LOSS:
			failures += 1
			push_error("Ideal actual scene soak lost life")
			break
		if g.round_director.round_index != previous:
			previous = g.round_director.round_index
			g.game_controller.remaining_time = 4.0
		if g.game_controller.state == g.game_controller.GameState.RUNNING:
			for slot_index in range(9):
				var slot: Control = g.board_controller.get_slot(slot_index)
				if slot.is_hittable() and slot.get_character_type() not in [&"bomb", &"clock"] and g.hammer_controller.can_strike():
					g.board_controller.slot_tapped.emit(slot_index)
					break
		var nodes := _count(g)
		var tweens := get_processed_tweens().size()
		node_peak = maxi(node_peak, nodes)
		tween_peak = maxi(tween_peak, tweens)
		var phase: int = g.round_director.phase_index
		if previous <= 11:
			nodes_by_phase[phase] = maxi(nodes, int(nodes_by_phase.get(phase, 0)))
		elif nodes > int(nodes_by_phase.get(phase, 0)) + 12:
			failures += 1
			push_error("Scene nodes exceed warmed phase allowance")
			break
		if tweens > 90 or g.spawn_director._guaranteed_queue.size() > 6 or g.board_controller.character_hit.get_connections().size() != connections:
			failures += 1
			push_error("Scene queues/tweens/connections unbounded")
			break
	if previous != 51: failures += 1
	print("SCENE SOAK ", "PASS" if failures == 0 else "FAIL", " rounds=", previous - 1, " nodes_peak=", node_peak, " tweens_peak=", tween_peak, " life=", g.game_controller.lives, " score=", g.game_controller.score, " warm_phase_nodes=", nodes_by_phase)
	g._leave_run()
	g.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	quit(0 if failures == 0 else 1)
