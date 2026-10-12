extends SceneTree

const SPAWNER := preload("res://scripts/gameplay/spawn_director.gd")
const PLANNER := preload("res://scripts/gameplay/round_director.gd")

class FairBoard extends Control:
	var slots: Dictionary = {}
	var decisions: Dictionary = {}
	var records: Array[Dictionary] = []
	var failed_attempts := 0
	var overwrite_attempts := 0
	var reject_next := false
	var auto_clear := false
	var available_ids: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	func get_free_slot_indices() -> Array[int]:
		var free: Array[int] = []
		for index in available_ids:
			if not slots.has(index):
				free.append(index)
		return free
	func get_occupied_slot_count() -> int:
		return slots.size()
	func get_decision_target_count() -> int:
		return decisions.size()
	func get_active_character_types() -> Array[StringName]:
		var kinds: Array[StringName] = []
		for kind in slots.values():
			kinds.append(kind)
		return kinds
	func spawn_character(index: int, kind: StringName, window: float) -> bool:
		if slots.has(index):
			overwrite_attempts += 1
			return false
		if reject_next:
			reject_next = false
			failed_attempts += 1
			return false
		slots[index] = kind
		decisions[index] = true
		records.append({"slot": index, "kind": kind, "window": window})
		if auto_clear:
			clear_all()
		return true
	func hold(index: int, kind: StringName, decision: bool = true) -> void:
		slots[index] = kind
		if decision:
			decisions[index] = true
	func clear_all() -> void:
		slots.clear()
		decisions.clear()
	func clear_slot(index: int) -> void:
		slots.erase(index)
		decisions.erase(index)

var checks := 0
var failures := 0
var board: FairBoard
var spawner: Node


func _init() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _profile(kinds: Array[StringName] = [&"normal"]) -> RoundProfile:
	var result := RoundProfile.new()
	result.max_active_characters = 6
	result.max_decision_targets = 2
	for kind in SPAWNER.ENABLED_CHARACTER_TYPES:
		result.set(String(kind) + "_weight", 1.0 if kind in kinds else 0.0)
	result.double_spawn_chance = 0.0
	return result


func _reset(profile: RoundProfile) -> void:
	spawner.stop()
	board.clear_all()
	board.records.clear()
	board.auto_clear = false
	board.reject_next = false
	board.available_ids.assign([0, 1, 2, 3, 4, 5, 6, 7, 8])
	spawner.set_profile(profile)
	spawner.prepare_round()
	spawner.start()
	spawner.set_process(false)


func _run() -> void:
	board = FairBoard.new()
	root.add_child(board)
	spawner = SPAWNER.new()
	root.add_child(spawner)
	spawner.deterministic_seed = 72843
	spawner.configure(board, _profile())
	spawner.set_process(false)
	_reset(_profile())
	spawner.set_elapsed_time(25.0)
	board.reject_next = true
	var guarantees: Array[StringName] = spawner._guaranteed_queue.duplicate()
	var deadlines: Array[float] = spawner._guaranteed_deadlines.duplicate()
	spawner._attempt_spawn()
	check(board.failed_attempts == 1 and board.records.is_empty(), "Rejected board spawn creates no event")
	check(spawner._guaranteed_queue == guarantees and spawner._guaranteed_deadlines == deadlines and spawner._spawn_counts.is_empty(), "Rejected spawn preserves guarantee, deadline and quota")
	spawner._attempt_spawn()
	check(board.records.size() == 1 and spawner._guaranteed_queue.is_empty(), "Successful spawn alone fulfills due guarantee")
	_reset(_profile([&"normal", &"bomb", &"glutton"]))
	board.hold(0, &"bomb", false)
	spawner._guaranteed_queue.assign([&"glutton"])
	spawner._guaranteed_deadlines.assign([0.0])
	spawner._attempt_spawn()
	check(board.records.size() == 1 and board.records[0].kind == &"normal", "Blocked overdue Glutton guarantee does not block a legal event")
	check(spawner._guaranteed_queue == [&"glutton"], "Fairness-deferred guarantee remains outstanding")
	_reset(_profile())
	for index in range(6): board.hold(index, &"normal", false)
	spawner._attempt_spawn()
	check(board.records.is_empty(), "Hiding occupants enforce occupancy limit separately from decisions")
	_reset(_profile())
	board.hold(0, &"normal")
	board.hold(1, &"golden")
	spawner._attempt_spawn()
	check(board.records.is_empty(), "Decision cap blocks spawn with spare physical capacity")
	_reset(_profile())
	board.available_ids.assign([4, 5])
	spawner._last_slot = 4
	spawner._same_slot_streak = 2
	check(spawner._spawn_one() and board.records.back().slot == 5, "Two repeated slots force another available IDLE slot")
	board.clear_slot(4)
	board.available_ids.assign([4])
	spawner._last_slot = 4
	spawner._same_slot_streak = 2
	check(spawner._spawn_one() and board.records.back().slot == 4, "Only available slot remains playable rather than stalling")
	_reset(_profile([&"clock"]))
	# Generate Clock early, before its guarantee deadline, then exhaust quota.
	spawner._guaranteed_queue.assign([&"clock"])
	spawner._guaranteed_deadlines.assign([0.75])
	for index in range(3):
		check(spawner._spawn_one(), "Clock below quota spawns successfully")
		board.clear_all()
	spawner.set_elapsed_time(25.0)
	for attempt in range(10): check(not spawner._spawn_one(), "Clock cannot bypass three-spawn quota")
	check(spawner._spawn_counts.get(&"clock", 0) == 3, "Clock count is exactly three")
	check(&"clock" not in spawner._guaranteed_queue, "Clock quota removes unfulfillable future guarantees")
	await _test_delayed_guards()
	var planner := PLANNER.new()
	planner.start_run(31992)
	var random := RandomNumberGenerator.new()
	random.seed = 2094
	var indices := [1, 9, 10, 999, 1000, 99999, 1000000, RoundProfile.MAX_SAFE_INTEGER - 5]
	for number in indices:
		for offset in range(5):
			planner.round_index = number + offset - 1
			var profile: RoundProfile = planner.next_profile()
			# Check synchronous fairness; delayed obligations tested separately.
			profile.double_spawn_chance = 0.0
			_reset(profile)
			for event in range(160):
				spawner.set_elapsed_time(float(event % 80))
				spawner._attempt_spawn()
				var kinds: Array[StringName] = board.get_active_character_types()
				check(board.overwrite_attempts == 0, "No occupied overwrite at round %s" % planner.round_index)
				check(kinds.count(&"bomb") <= 1 and kinds.count(&"glutton") <= 1, "Singleton hazards remain bounded at any round")
				check(not (&"bomb" in kinds and &"glutton" in kinds) and not (&"fast" in kinds and &"glutton" in kinds), "Prohibited pairs remain absent at any round")
				check(board.get_occupied_slot_count() <= profile.max_active_characters and board.get_decision_target_count() <= profile.max_decision_targets, "Both caps hold at any round")
				check(spawner._spawn_counts.get(&"clock", 0) <= 3, "Clock quota holds at any round")
				# Mix decision targets with occupied visual cooldown slots.
				if not board.decisions.is_empty():
					var key: int = board.decisions.keys()[0]
					board.decisions.erase(key)
				if not board.slots.is_empty() and random.randf() < 0.7:
					var occupied: Array = board.slots.keys()
					board.clear_slot(occupied[random.randi_range(0, occupied.size() - 1)])
	planner.free()
	spawner.stop()
	board.queue_free()
	spawner.queue_free()
	await process_frame
	paused = false
	print("ENDLESS FAIRNESS ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)


func _test_delayed_guards() -> void:
	_reset(_profile())
	spawner._spawn_second_after_delay()
	spawner.stop()
	await create_timer(0.25, true).timeout
	spawner._process(0.25)
	check(board.records.is_empty(), "Stopped delayed spawn is canceled")
	_reset(_profile())
	spawner._spawn_second_after_delay()
	spawner.prepare_round()
	await create_timer(0.25, true).timeout
	spawner._process(0.25)
	check(board.records.is_empty(), "Round generation invalidates stale second spawn")
	_reset(_profile())
	spawner._spawn_second_after_delay()
	board.hold(0, &"normal")
	board.hold(1, &"normal")
	await create_timer(0.25, true).timeout
	spawner._process(0.25)
	check(board.records.is_empty(), "Delayed second rechecks decision limit")
	_reset(_profile())
	spawner._spawn_second_after_delay()
	for index in range(6): board.hold(index, &"normal", false)
	await create_timer(0.25, true).timeout
	spawner._process(0.25)
	check(board.records.is_empty(), "Delayed second rechecks occupied hiding limit")
	_reset(_profile())
	board.auto_clear = true
	for duplicate in range(20): spawner._spawn_second_after_delay()
	await create_timer(0.25, true).timeout
	spawner._process(0.25)
	check(board.records.size() == 1, "At most one delayed second obligation can be pending")
	_reset(_profile())
	spawner._spawn_second_after_delay()
	spawner.stop()
	paused = true
	var paused_interval: float = spawner._time_until_spawn
	for index in range(20): spawner._process(10.0)
	check(spawner._time_until_spawn == paused_interval, "Paused/stopped spawner accumulates no time debt")
	await create_timer(0.25, true).timeout
	spawner._process(0.25)
	check(board.records.is_empty(), "Delayed second cannot fire through pause")
	paused = false
	spawner.start()
	await create_timer(0.25, true).timeout
	spawner._process(0.25)
	check(board.records.is_empty(), "Canceled pause obligation does not burst on resume")
	# A large delta still requests only one ordinary event, not a catch-up loop.
	board.auto_clear = true
	spawner._process(50.0)
	check(board.records.size() == 1, "Long elapsed step never emits an accumulated spawn burst")
