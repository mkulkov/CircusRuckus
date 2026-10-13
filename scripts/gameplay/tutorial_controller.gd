extends Node

signal completed
signal round_requested(round_index: int)
signal round_mastered(round_index: int)

const REQUIRED_LESSONS: Array[StringName] = [
	&"normal", &"misses", &"bomb", &"two", &"series", &"golden", &"fast", &"clock", &"glutton", &"endless_rules",
]
const ROUND_LESSONS := [
	[&"normal", &"misses"], [&"bomb", &"two", &"series"],
	[&"golden", &"fast"], [&"clock", &"glutton", &"endless_rules"],
]
const DEMO_WINDOW := 5.0
const PAUSE_REASON := &"tutorial"

# Compatibility cache only. Configure reads the selected save profile.
static var learned: Dictionary = {}
var gameplay: Control
var teaching: StringName = &""
var demonstrating := false
var demo_slots: Array[int] = []
var rules_only := false
var current_round := 1
var active := false
var _mastered: Dictionary = {}
var _repeat_mastered: Dictionary = {}
var _repeating := false
var _generation := 0
var _step_generation := 0
var _hits := 0
var _misses := 0
var _stage := 0
var _round_ready := false
var _snapshot: Dictionary = {}


func configure(owner_game: Control) -> void:
	gameplay = owner_game
	_mastered.clear()
	var data: Dictionary = gameplay.save_manager.load_data()
	var saved: Variant = data.get("learned_lessons", [])
	if saved is Array:
		for lesson in saved:
			var lesson_id := StringName(str(lesson))
			if lesson_id in REQUIRED_LESSONS:
				_mastered[lesson_id] = true
	learned = _mastered.duplicate()
	gameplay.session_overlay.tutorial_continue_requested.connect(_continue)
	gameplay.session_overlay.rules_requested.connect(_repeat_rules)
	if gameplay.session_overlay.has_signal("tutorial_next_requested"):
		gameplay.session_overlay.connect("tutorial_next_requested", advance_round)


func start(repeat: bool = false) -> void:
	reset_attempt()
	active = true
	_repeating = repeat
	_repeat_mastered.clear()
	current_round = 1
	if not repeat:
		while current_round <= 4 and _round_is_mastered(current_round):
			current_round += 1
	if current_round > 4:
		active = false
		completed.emit()
		return
	round_requested.emit(current_round)


func begin_round(round_index: int) -> void:
	_generation += 1
	_step_generation += 1
	teaching = &""
	demonstrating = false
	demo_slots.clear()
	_snapshot.clear()
	active = true
	current_round = clampi(round_index, 1, 4)
	_round_ready = false
	_set_advance(false)
	_next_lesson(_generation)


func advance_round() -> void:
	if not active or not _round_ready or teaching != &"" or rules_only:
		return
	_round_ready = false
	_set_advance(false)
	_generation += 1
	if current_round == 4:
		active = false
		completed.emit()
	else:
		current_round += 1
		round_requested.emit(current_round)


func consider(_character_type: StringName) -> void:
	# Lessons have an explicit order independent of random spawning.
	pass


func allows_tap(index: int) -> bool:
	if rules_only or (active and not demonstrating and not _round_ready):
		return false
	if not demonstrating:
		return teaching == &""
	if teaching == &"bomb" or (teaching == &"glutton" and _stage == 0):
		return false
	var slot: Control = gameplay.board_controller.get_slot(index)
	if slot == null:
		return false
	if teaching == &"misses" and _stage in [1, 2]:
		return index == 4 and slot.is_idle()
	return index in demo_slots and slot.is_hittable()


func hit(index: int) -> void:
	if not _demo_is_current() or index not in demo_slots:
		return
	demo_slots.erase(index)
	if teaching == &"misses":
		if _stage == 0:
			_stage = 1
			_begin_empty_practice(_generation, _step_generation)
		elif _stage == 3 and gameplay.game_controller.consecutive_misses == 0:
			_complete_lesson()
		return
	_hits += 1
	var required := 2 if teaching in [&"normal", &"two", &"golden", &"fast"] else 1
	if teaching == &"series":
		required = 3
	if teaching == &"glutton" and (_stage != 1 or gameplay.game_controller.lives != 3):
		_retry_demo.call_deferred(_generation, _step_generation, teaching)
		return
	if teaching == &"clock" and gameplay.spawn_director.slowdown_remaining < 5.0:
		_retry_demo.call_deferred(_generation, _step_generation, teaching)
		return
	if _hits >= required and demo_slots.is_empty():
		_complete_lesson()
	elif demo_slots.is_empty():
		_retry_demo.call_deferred(_generation, _step_generation, teaching)


func empty_hit(index: int) -> bool:
	if not demonstrating:
		return false
	if teaching != &"misses" or not _demo_is_current() or index != 4 or _stage not in [1, 2]:
		return true
	gameplay.game_controller.resolve_empty_hit()
	_misses += 1
	if _stage == 1 and _misses == 3:
		# Show the real penalty with a safe practice life floor.
		_stage = 2
		gameplay.hud.show_feedback(tr("TUTORIAL_MISSES_RESET"))
	elif _stage == 2:
		# A fourth empty strike leaves a nonzero counter for the next
		# accepted hit to visibly reset, after showing the three-miss penalty.
		_stage = 3
		_retry_demo.call_deferred(_generation, _step_generation, teaching)
	return true


func escape(index: int) -> bool:
	if not _demo_is_current() or index not in demo_slots:
		return false
	if teaching == &"bomb":
		_complete_lesson()
	elif teaching == &"glutton" and _stage == 0:
		gameplay.game_controller.resolve_character_escape(&"glutton")
		_stage = 1
		_retry_demo.call_deferred(_generation, _step_generation, teaching)
	else:
		if teaching in [&"two", &"series"]:
			_hits = 0
			gameplay.game_controller.reset_combo()
		_retry_demo.call_deferred(_generation, _step_generation, teaching)
	return true


func reset_attempt() -> void:
	_generation += 1
	_step_generation += 1
	active = false
	teaching = &""
	demonstrating = false
	rules_only = false
	_round_ready = false
	demo_slots.clear()
	_snapshot.clear()
	if is_instance_valid(gameplay):
		gameplay.game_controller.set_process(true)
		gameplay.game_controller.resume_level(PAUSE_REASON)
		_set_advance(false)


func _continue() -> void:
	if rules_only:
		rules_only = false
		gameplay.session_overlay.show_pause()
		return
	if not active or teaching == &"" or demonstrating:
		return
	if teaching == &"endless_rules":
		_complete_lesson()
		return
	demonstrating = true
	gameplay.game_controller.resume_level(PAUSE_REASON)
	gameplay.game_controller.set_process(false)
	gameplay.spawn_director.stop()
	gameplay.session_overlay.hide_overlay()
	_hits = 0
	_misses = 0
	_stage = 0
	if teaching == &"misses" or teaching == &"glutton":
		gameplay.game_controller.lives = 3
		gameplay.game_controller.lives_changed.emit(3)
	if teaching == &"misses":
		gameplay.game_controller.consecutive_misses = 0
		gameplay.game_controller.reset_combo()
	if teaching == &"clock":
		gameplay.spawn_director.slowdown_remaining = 0.0
	_spawn_demo()


func _next_lesson(generation: int) -> void:
	if generation != _generation or not active or not is_instance_valid(gameplay):
		return
	for lesson in ROUND_LESSONS[current_round - 1]:
		if not _lesson_is_mastered(lesson):
			_present(lesson)
			return
	_round_ready = true
	if current_round == 4:
		_restore_banner()
		advance_round()
		return
	gameplay.session_overlay.hide_overlay()
	gameplay.game_controller.set_process(true)
	gameplay.game_controller.resume_level(PAUSE_REASON)
	if gameplay.game_controller.state == gameplay.game_controller.GameState.RUNNING:
		gameplay.spawn_director.start()
	_restore_banner()
	_set_advance(true)
	round_mastered.emit(current_round)


func _present(lesson: StringName) -> void:
	_step_generation += 1
	teaching = lesson
	demonstrating = false
	demo_slots.clear()
	_save_snapshot()
	gameplay.spawn_director.stop()
	gameplay.game_controller.set_process(false)
	gameplay.game_controller.pause_level(PAUSE_REASON)
	_clear_board()
	if gameplay.monetization_service != null:
		gameplay.monetization_service.show_banner(false)
	var key := String(lesson).to_upper()
	var kind := _character_kind()
	var icon: Texture2D = null
	var path := "res://assets/generated/%s_clown.png" % kind
	if ResourceLoader.exists(path):
		icon = load(path) as Texture2D
	var body := tr("TUTORIAL_%s_BODY" % key)
	if lesson == &"normal":
		body = tr("TRAINING_MODE_INTRO") + "\n" + body
	gameplay.session_overlay.show_tutorial(tr("TUTORIAL_%s_TITLE" % key), body, icon)


func _spawn_demo() -> void:
	_step_generation += 1
	_clear_board()
	demo_slots.assign([3, 5] if teaching == &"two" else [4])
	for index in demo_slots:
		gameplay.board_controller.spawn_character(index, _character_kind(), DEMO_WINDOW * 0.5 if teaching == &"fast" else DEMO_WINDOW)
	var hint := "HINT_TAP"
	if teaching == &"bomb":
		hint = "HINT_BOMB"
	elif teaching == &"glutton" and _stage == 0:
		hint = "TUTORIAL_GLUTTON_WAIT"
	gameplay.hud.show_feedback(tr(hint))


func _retry_demo(generation: int, step: int, lesson: StringName) -> void:
	if generation != _generation or step != _step_generation or teaching != lesson or not demonstrating:
		return
	if await _wait_for_demo_exit(generation, step):
		_spawn_demo()


func _begin_empty_practice(generation: int, step: int) -> void:
	if await _wait_for_demo_exit(generation, step):
		_clear_board()
		gameplay.hud.show_feedback(tr("TUTORIAL_MISSES_PRACTICE"))


func _wait_for_demo_exit(generation: int, step: int) -> bool:
	# Hits are recorded immediately, but cards and replacements must wait for
	# the real strike, retreat and lid closure. Never guess their duration.
	while generation == _generation and step == _step_generation and active and is_instance_valid(gameplay):
		if gameplay.board_controller.get_occupied_slot_count() == 0:
			return true
		await get_tree().process_frame
	return false


func _character_kind() -> StringName:
	return &"normal" if teaching in [&"two", &"series", &"misses", &"endless_rules"] else teaching


func _demo_is_current() -> bool:
	return active and demonstrating and is_instance_valid(gameplay) and gameplay.game_controller.state == gameplay.game_controller.GameState.RUNNING


func _complete_lesson() -> void:
	var lesson := teaching
	if lesson == &"" or not active:
		return
	_step_generation += 1
	_mastered[lesson] = true
	_repeat_mastered[lesson] = true
	learned[lesson] = true
	gameplay.save_manager.learn_lesson(String(lesson))
	demonstrating = false
	var generation := _generation
	var step := _step_generation
	if not await _wait_for_demo_exit(generation, step):
		return
	teaching = &""
	_clear_board()
	_restore_snapshot()
	gameplay.game_controller.set_process(false)
	gameplay.game_controller.pause_level(PAUSE_REASON)
	_next_lesson.call_deferred(_generation)


func _save_snapshot() -> void:
	_snapshot.clear()
	_snapshot["spawn_slowdown"] = gameplay.spawn_director.slowdown_remaining
	for field in ["score", "combo_count", "max_combo", "lives", "consecutive_misses", "remaining_time", "time_bonus_awarded", "golden_hits"]:
		_snapshot[field] = gameplay.game_controller.get(field)


func _restore_snapshot() -> void:
	if _snapshot.is_empty():
		return
	for field in _snapshot:
		if field == "spawn_slowdown":
			gameplay.spawn_director.slowdown_remaining = _snapshot[field]
		else:
			gameplay.game_controller.set(field, _snapshot[field])
	var game: Node = gameplay.game_controller
	game.score_changed.emit(game.score)
	game.combo_changed.emit(game.combo_count)
	game.lives_changed.emit(game.lives)
	game.time_changed.emit(game.remaining_time)
	game.golden_hits_changed.emit(game.golden_hits)
	if game.has_signal("progress_changed"):
		game.emit_signal("progress_changed")
	_snapshot.clear()


func _clear_board() -> void:
	demo_slots.clear()
	gameplay.board_controller.clear_all()


func _lesson_is_mastered(lesson: StringName) -> bool:
	return _repeat_mastered.has(lesson) if _repeating else _mastered.has(lesson)


func _round_is_mastered(index: int) -> bool:
	for lesson in ROUND_LESSONS[index - 1]:
		if not _lesson_is_mastered(lesson):
			return false
	return true


func round_is_mastered(index: int) -> bool:
	return index >= 1 and index <= 4 and _round_is_mastered(index)


func _set_advance(enabled: bool) -> void:
	if gameplay.session_overlay.has_method("show_tutorial_advance"):
		gameplay.session_overlay.show_tutorial_advance(enabled)


func _restore_banner() -> void:
	if gameplay.monetization_service != null:
		gameplay.monetization_service.show_banner(false)


func _repeat_rules() -> void:
	rules_only = true
	gameplay.session_overlay.show_tutorial(tr("RULES"), tr("RULES_BODY"))
