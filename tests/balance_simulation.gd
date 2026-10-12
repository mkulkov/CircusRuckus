extends SceneTree

# Accelerated, deterministic model. Controllers and scheduling/fairness are real;
# visual tweens and human recognition/motor behavior are an explicit approximation.
const SEEDS := 100
const HORIZON := 1800.0
const READABLE_DELAY := 0.18 # .08 lid + quart rise until the head target y <= 80
const POP_DURATION := 0.68
const HIT_OCCUPANCY := 0.22 + 0.18 + 0.62 * 0.80 + 0.20
const ESCAPE_OCCUPANCY := 0.62 + 0.20
const DEBOUNCE := 0.08
const STYLES := ["ideal", "confident", "novice", "cautious", "idle", "spam"]
const Controller = preload("res://scripts/gameplay/game_controller.gd")
const Director = preload("res://scripts/gameplay/spawn_director.gd")
const Rounds = preload("res://scripts/gameplay/round_director.gd")
const OUTPUT := "res://docs/endless_balance_simulation.json"

class SimDirector extends Director:
	var now := 0.0
	var pending: Array[Dictionary] = []
	var cancelled_callbacks := 0
	var peak_pending := 0
	func _spawn_second_after_delay() -> void:
		pending.append({"at": now + _rng.randf_range(0.08, 0.20), "generation": _generation})
		peak_pending = maxi(peak_pending, pending.size())
	func tick(delta: float) -> void:
		while not pending.is_empty() and pending.front().at <= now + 0.000001:
			var callback: Dictionary = pending.pop_front()
			if callback.generation == _generation and _running:
				if _board.get_occupied_slot_count() < _config.max_active_characters and _board.get_decision_target_count() < _config.max_decision_targets:
					_spawn_one(true)
			else:
				cancelled_callbacks += 1
		_process(delta)

class SimBoard extends Control:
	var now := 0.0
	var slots: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	var profile: RoundProfile
	var reaction := 0.12
	var skip := 0.0
	var hazard_error := 0.0
	var empty_error := 0.0
	var spawned: Dictionary = {}
	var hits: Dictionary = {}
	var escapes: Dictionary = {}
	var cancelled: Dictionary = {}
	var violations: Dictionary = {}
	var peak_occupied := 0
	var peak_decisions := 0
	var max_error_streak := 0
	var error_streak := 0
	func violation(label: String) -> void:
		violations[label] = int(violations.get(label, 0)) + 1
	func count(bucket: Dictionary, kind: StringName) -> void:
		bucket[str(kind)] = int(bucket.get(str(kind), 0)) + 1
	func get_free_slot_indices() -> Array[int]:
		var result: Array[int] = []
		for index in range(9):
			if not slots.has(index): result.append(index)
		return result
	func get_occupied_slot_count() -> int:
		return slots.size()
	func get_decision_target_count() -> int:
		var count := 0
		for item in slots.values():
			if item.phase == 0: count += 1
		return count
	func get_active_character_types() -> Array[StringName]:
		var result: Array[StringName] = []
		for item in slots.values(): result.append(item.type)
		return result
	func check_limits() -> void:
		var occupied := get_occupied_slot_count()
		var decisions := get_decision_target_count()
		peak_occupied = maxi(peak_occupied, occupied)
		peak_decisions = maxi(peak_decisions, decisions)
		if occupied > profile.max_active_characters: violation("occupancy")
		if decisions > profile.max_decision_targets: violation("decision_limit")
		var active := get_active_character_types()
		if &"bomb" in active and &"glutton" in active: violation("bomb_glutton")
		if &"fast" in active and &"glutton" in active: violation("fast_glutton")
		if &"drunk" in active: violation("drunk_enabled")
	func spawn_character(index: int, kind: StringName, visible: float) -> bool:
		if slots.has(index):
			violation("occupied_overwrite_attempt")
			return false
		var hittable := now + READABLE_DELAY
		var actionable := kind != &"bomb" or rng.randf() < hazard_error
		var skipped := rng.randf() < skip or not actionable
		slots[index] = {"type": kind, "phase": 0, "hittable": hittable, "escape": hittable + visible,
			"decision": hittable + reaction * rng.randf_range(0.65, 1.55), "skip": skipped, "release": 0.0}
		count(spawned, kind)
		check_limits()
		return true
	func register_error() -> void:
		error_streak += 1
		max_error_streak = maxi(max_error_streak, error_streak)
	func strike(index: int, controller: Node) -> void:
		if slots.has(index) and slots[index].phase == 0 and now >= slots[index].hittable and now < slots[index].escape:
			var item: Dictionary = slots[index]
			item.phase = 1
			item.release = now + HIT_OCCUPANCY
			count(hits, item.type)
			if item.type == &"bomb": register_error()
			else: error_streak = 0
			controller.resolve_character_hit(item.type)
		else:
			register_error()
			count(hits, &"empty")
			controller.resolve_empty_hit()
	func tick(controller: Node) -> void:
		for index in slots.keys():
			if controller.state != controller.GameState.RUNNING: return
			var item: Dictionary = slots[index]
			if item.phase == 0 and now >= item.escape - 0.000001:
				item.phase = 1
				item.release = now + ESCAPE_OCCUPANCY
				count(escapes, item.type)
				if item.type in [&"normal", &"fast", &"golden", &"glutton"]: register_error()
				controller.resolve_character_escape(item.type)
			elif item.phase == 1 and now >= item.release - 0.000001:
				slots.erase(index)
	func clear_all() -> void:
		for item in slots.values():
			if item.phase == 0: count(cancelled, item.type)
		slots.clear()
	func next_event(now_value: float, next_tap: float, style: String) -> float:
		var due := HORIZON
		for item in slots.values():
			if item.phase == 1:
				due = minf(due, item.release)
			else:
				due = minf(due, item.escape)
				if style not in ["idle", "spam"] and not item.skip:
					due = minf(due, maxf(item.decision, next_tap))
		return maxf(now_value + 0.00001, due)
	func choose_target() -> int:
		var chosen := -1
		var deadline := INF
		for index in slots:
			var item: Dictionary = slots[index]
			if item.phase == 0 and not item.skip and now >= item.decision - 0.000001 and now < item.escape and item.escape < deadline:
				chosen = index
				deadline = item.escape
		return chosen

func _init() -> void:
	# No SaveManager or Boot is instantiated; protect accidental future scene additions.
	ProjectSettings.set_setting("clown_smash/testing/save_path", ProjectSettings.globalize_path("res://builds/debug/verification/balance-disposable.json"))
	call_deferred("run")

func simulate(seed_number: int, style: String, horizon: float = HORIZON) -> Dictionary:
	var board := SimBoard.new()
	var director := SimDirector.new()
	var controller := Controller.new()
	var rounds := Rounds.new()
	for node in [board, director, controller, rounds]:
		root.add_child(node)
		node.set_process(false)
	board.rng.seed = seed_number * 17 + 3
	director.deterministic_seed = seed_number
	var serial_tap := DEBOUNCE
	match style:
		"confident": board.reaction = 0.28; board.skip = 0.05; board.hazard_error = 0.015; board.empty_error = 0.002; serial_tap = 0.15
		"novice": board.reaction = 0.48; board.skip = 0.15; board.hazard_error = 0.06; board.empty_error = 0.015; serial_tap = 0.28
		"cautious": board.reaction = 0.95; board.skip = 0.08; board.hazard_error = 0.005; serial_tap = 0.40
		"idle", "spam": board.skip = 1.0
	rounds.start_run(seed_number)
	var profile: RoundProfile = rounds.next_profile()
	board.profile = profile
	director.configure(board, profile)
	director.prepare_round()
	director.start()
	controller.start_run(profile, false)
	controller._rng.seed = seed_number * 19 + 5
	var phases: Array[Dictionary] = []
	for phase in range(5): phases.append({"active_seconds": 0.0, "life_seconds": [0.0, 0.0, 0.0, 0.0], "lives_lost": 0, "glutton_restores": 0, "recovery_restores": 0, "decisions_seconds": 0.0, "occupied_seconds": 0.0, "spawned": 0, "rounds_completed": 0})
	controller.life_restored.connect(func(source: String) -> void:
		phases[rounds.phase_index]["glutton_restores" if source == "glutton" else "recovery_restores"] += 1)
	var previous_life := {"value": controller.lives}
	controller.lives_changed.connect(func(new_lives: int) -> void:
		if new_lives < previous_life.value: phases[rounds.phase_index].lives_lost += previous_life.value - new_lives
		previous_life.value = new_lives
		if controller.lives < 0 or controller.lives > 3: board.violation("lives_range"))
	var elapsed := 0.0
	var next_tap := 0.0
	var iterations := 0
	var maximum_assist := 0
	var peak_generation_pending := 0
	while controller.state != controller.GameState.FINISHED_LOSS and elapsed < horizon - 0.000001:
		board.now = elapsed
		director.now = elapsed
		board.tick(controller)
		if controller.state == controller.GameState.FINISHED_LOSS: break
		if style == "spam" and elapsed >= next_tap - 0.000001:
			board.strike(board.rng.randi_range(0, 8), controller)
			next_tap = elapsed + 0.10
		elif style not in ["idle", "spam"] and elapsed >= next_tap - 0.000001:
			var target := board.choose_target()
			if target >= 0:
				if board.rng.randf() < board.empty_error:
					board.slots[target].skip = true
					var free := board.get_free_slot_indices()
					if not free.is_empty(): target = free.front()
				board.strike(target, controller)
				next_tap = elapsed + maxf(DEBOUNCE, serial_tap)
		if controller.state == controller.GameState.FINISHED_LOSS: break
		var current_phase: Dictionary = phases[rounds.phase_index]
		var before_spawns: int = board.spawned.values().reduce(func(a: int, b: int) -> int: return a + b, 0)
		# Every step ends on the next visual/input/spawn/timer event. No round RNG reset.
		var due := minf(horizon, elapsed + controller.remaining_time)
		due = minf(due, elapsed + maxf(0.00001, director._time_until_spawn))
		due = minf(due, board.next_event(elapsed, next_tap, style))
		if style == "spam": due = minf(due, next_tap)
		if not director.pending.is_empty(): due = minf(due, maxf(elapsed + 0.00001, director.pending.front().at))
		var delta := maxf(0.00001, due - elapsed)
		current_phase.active_seconds += delta
		current_phase.life_seconds[controller.lives] += delta
		current_phase.decisions_seconds += board.get_decision_target_count() * delta
		current_phase.occupied_seconds += board.get_occupied_slot_count() * delta
		elapsed += delta
		board.now = elapsed
		director.now = elapsed
		director.set_elapsed_time(controller.round_elapsed + delta)
		director.tick(delta)
		current_phase.spawned += board.spawned.values().reduce(func(a: int, b: int) -> int: return a + b, 0) - before_spawns
		controller._process(delta)
		iterations += 1
		board.check_limits()
		if controller.time_bonus_awarded > 30.0 or int(director._spawn_counts.get(&"clock", 0)) > 3: board.violation("clock_cap")
		if director.pending.size() > 1: board.violation("pending_queue_growth")
		peak_generation_pending = maxi(peak_generation_pending, director.pending.size())
		if controller.state == controller.GameState.ROUND_TRANSITION:
			current_phase.rounds_completed += 1
			director.stop()
			board.clear_all()
			rounds.observe_round(controller.round_stats)
			maximum_assist = maxi(maximum_assist, rounds.assist_step)
			profile = rounds.next_profile()
			if not profile.validation_errors().is_empty(): board.violation("effective_profile_bounds")
			board.profile = profile
			director.set_profile(profile)
			director.prepare_round()
			controller.start_round(profile)
			director.start()
			if rounds.phase_index != (rounds.round_index - 1) % 5: board.violation("phase_sequence")
			if rounds.assist_step < 0 or rounds.assist_step > 2: board.violation("assist_bounds")
	var result := {"seed": seed_number, "survival_seconds": controller.active_elapsed, "censored": controller.state != controller.GameState.FINISHED_LOSS,
		"score": controller.score, "max_combo": controller.max_combo, "completed_rounds": controller.completed_rounds,
		"spawned": board.spawned.duplicate(), "hits": board.hits.duplicate(), "escapes": board.escapes.duplicate(), "cancelled_at_boundary": board.cancelled.duplicate(),
		"phases": phases, "maximum_assist": maximum_assist, "maximum_error_streak": board.max_error_streak, "peak_occupied": board.peak_occupied,
		"peak_decisions": board.peak_decisions, "peak_pending": peak_generation_pending, "event_steps": iterations,
		"cancelled_second_callbacks": director.cancelled_callbacks, "violations": board.violations.duplicate()}
	for node in [board, director, controller, rounds]: node.free()
	return result

func quantile(values: Array[float], probability: float) -> float:
	values.sort()
	return values[clampi(roundi((values.size() - 1) * probability), 0, values.size() - 1)]

func aggregate(samples: Array[Dictionary]) -> Dictionary:
	var durations: Array[float] = []
	var summary := {"runs": samples.size(), "censored": 0, "defeats": 0, "totals": {}, "phases": [], "peak_occupied": 0, "peak_decisions": 0, "peak_pending": 0, "maximum_error_streak": 0, "violations": {}}
	for phase in range(5): summary.phases.append({"active_seconds": 0.0, "life_seconds": [0.0, 0.0, 0.0, 0.0], "lives_lost": 0, "glutton_restores": 0, "recovery_restores": 0, "decisions_seconds": 0.0, "occupied_seconds": 0.0, "spawned": 0, "rounds_completed": 0})
	for field in ["cancelled_second_callbacks", "completed_rounds", "event_steps", "score"]: summary[field] = 0
	for sample in samples:
		for field in ["cancelled_second_callbacks", "completed_rounds", "event_steps", "score"]: summary[field] += sample[field]
		durations.append(sample.survival_seconds)
		summary.censored += int(sample.censored)
		summary.defeats += int(not sample.censored)
		for key in ["spawned", "hits", "escapes", "cancelled_at_boundary", "violations"]:
			if not summary.totals.has(key): summary.totals[key] = {}
			for kind in sample[key]: summary.totals[key][kind] = int(summary.totals[key].get(kind, 0)) + sample[key][kind]
		for key in ["peak_occupied", "peak_decisions", "peak_pending", "maximum_error_streak"]: summary[key] = maxi(summary[key], sample[key])
		for index in range(5):
			for key in sample.phases[index]:
				if key == "life_seconds":
					for life in range(4): summary.phases[index].life_seconds[life] += sample.phases[index].life_seconds[life]
				else: summary.phases[index][key] += sample.phases[index][key]
	summary.violations = summary.totals.violations
	summary.survival_p10_seconds = quantile(durations, 0.10)
	summary.survival_p50_seconds = quantile(durations, 0.50)
	summary.survival_p90_seconds = quantile(durations, 0.90)
	summary.quantiles_are_observed_lower_bounds_when_censored = summary.censored > 0
	for phase in summary.phases:
		phase.mean_decisions = phase.decisions_seconds / maxf(phase.active_seconds, 0.000001)
		phase.mean_occupied = phase.occupied_seconds / maxf(phase.active_seconds, 0.000001)
		phase.spawns_per_active_second = phase.spawned / maxf(phase.active_seconds, 0.000001)
	summary.active_seconds = summary.phases.reduce(func(total: float, phase: Dictionary) -> float: return total + float(phase.active_seconds), 0.0)
	for kind in ["clock", "glutton"]:
		for bucket in ["spawned", "hits", "escapes"]:
			summary[kind + "_" + bucket + "_per_active_minute"] = 60.0 * int(summary.totals[bucket].get(kind, 0)) / maxf(summary.active_seconds, 0.000001)
	return summary

func reaggregate() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("raw_runs"):
		push_error("Reaggregation needs the completed new endless report")
		quit(1)
		return
	for style in STYLES:
		var samples: Array[Dictionary] = []
		for value in parsed.raw_runs[style]: samples.append(value)
		parsed.styles[style] = aggregate(samples)
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	print("ENDLESS_BALANCE_AGGREGATION %s retained_runs=600" % ("PASS" if error == OK else "FAIL"))
	quit(0 if error == OK else 1)

func run() -> void:
	if "--aggregate-only" in OS.get_cmdline_user_args():
		reaggregate()
		return
	var report := {"horizon_active_seconds": HORIZON, "seeds_per_style": SEEDS,
		"model": "real GameController/SpawnDirector/RoundDirector, approximate visual lifecycle; readable opening .18s, full pop .68s, hit occupancy 1.096s, escape .82s, debounce .08s; serialized earliest-deadline decisions; event stepping; no wall-time transitions included",
		"human_models": {"ideal": {"reaction": 0.12, "skip": 0.0}, "confident": {"reaction": 0.28, "skip": 0.05, "hazard_error": 0.015, "empty_error": 0.002, "serial_tap": 0.15}, "novice": {"reaction": 0.48, "skip": 0.15, "hazard_error": 0.06, "empty_error": 0.015, "serial_tap": 0.28}, "cautious": {"reaction": 0.95, "skip": 0.08, "hazard_error": 0.005, "serial_tap": 0.40}, "idle": "no input", "spam": "random slot each .10s"},
		"styles": {}, "checks": {}, "raw_runs": {}}
	var ok := true
	for style in STYLES:
		var samples: Array[Dictionary] = []
		for seed_number in range(1, SEEDS + 1): samples.append(simulate(seed_number, style))
		var summary := aggregate(samples)
		report.styles[style] = summary
		report.raw_runs[style] = samples
		if not summary.violations.is_empty(): ok = false
		var repeat_a := simulate(42, style, 300.0)
		var repeat_b := simulate(42, style, 300.0)
		report.checks[style + "_repeatable"] = repeat_a == repeat_b
		if repeat_a != repeat_b: ok = false
		print("ENDLESS_BALANCE style=%s P10=%.2f P50=%.2f P90=%.2f censored=%d violations=%s" % [style, summary.survival_p10_seconds, summary.survival_p50_seconds, summary.survival_p90_seconds, summary.censored, summary.violations])
		await process_frame
	report.checks.ideal_no_unfair_defeats = report.styles.ideal.defeats == 0
	report.checks.novice_median_at_least_180 = report.styles.novice.survival_p50_seconds >= 180.0
	report.checks.confident_median_at_least_480 = report.styles.confident.survival_p50_seconds >= 480.0
	report.checks.idle_never_recovers = report.styles.idle.phases.reduce(func(total: int, phase: Dictionary) -> int: return total + int(phase.glutton_restores) + int(phase.recovery_restores), 0) == 0
	report.checks.spam_not_sustainable = report.styles.spam.censored == 0 and report.styles.spam.survival_p50_seconds < report.styles.novice.survival_p50_seconds
	report.checks.recovery_fewer_decisions_than_peak = report.styles.ideal.phases[0].mean_decisions < report.styles.ideal.phases[4].mean_decisions
	report.checks.pending_queue_bounded = report.styles.ideal.peak_pending <= 1
	for value in report.checks.values(): ok = ok and bool(value)
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write new endless report")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.flush()
	var write_error := output.get_error()
	output.close()
	print("ENDLESS_BALANCE_RESULT %s runs=600 horizon=1800 output=%s checks=%s" % ["PASS" if ok and write_error == OK else "FAIL", OUTPUT, JSON.stringify(report.checks)])
	quit(0 if ok and write_error == OK else 1)
