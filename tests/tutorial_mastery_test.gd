extends SceneTree

const TUTORIAL := preload("res://scripts/gameplay/tutorial_controller.gd")
const BOARD := preload("res://scripts/gameplay/board_controller.gd")
const GAME := preload("res://scripts/gameplay/game_controller.gd")
const SAVE := preload("res://scripts/save/save_manager.gd")

class PracticeOverlay extends Control:
	signal tutorial_continue_requested
	signal tutorial_next_requested
	signal rules_requested
	var card := false
	var next_visible := false
	var pause_visible := false
	func show_tutorial(_title: String, _body: String, _icon: Texture2D = null) -> void:
		card = true
	func hide_overlay() -> void:
		card = false
		pause_visible = false
	func show_pause() -> void:
		card = false
		pause_visible = true
	func show_tutorial_advance(enabled: bool) -> void:
		next_visible = enabled

class PracticeHud extends Control:
	var feedback := ""
	func show_feedback(text: String) -> void:
		feedback = text

class PracticeSpawner extends Node:
	var _running := false
	var slowdown_remaining := 0.0
	func apply_slowdown(duration: float) -> void:
		slowdown_remaining = duration
	func start() -> void:
		_running = true
	func stop() -> void:
		_running = false

class PracticeOwner extends Control:
	var game_controller: Node
	var board_controller: Control
	var save_manager: Node
	var session_overlay: Control
	var hud: Control
	var spawn_director: Node
	var monetization_service: Node = null

var failures := 0
var owner: PracticeOwner
var tutorial: Node
var completed_count := 0


func _init() -> void:
	var directory := ProjectSettings.globalize_path("res://builds/debug/verification/endless/tutorial")
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("clown_smash/testing/save_path", directory + "/save.json")
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	Engine.time_scale = 5.0
	owner = PracticeOwner.new()
	owner.size = Vector2(1080, 1920)
	root.add_child(owner)
	owner.game_controller = GAME.new()
	owner.board_controller = BOARD.new()
	owner.save_manager = SAVE.new()
	owner.save_manager.set_save_path_for_tests("res://builds/debug/verification/endless/tutorial/tutorial_mastery_disposable.json")
	owner.save_manager.delete_save_for_tests()
	owner.session_overlay = PracticeOverlay.new()
	owner.hud = PracticeHud.new()
	owner.spawn_director = PracticeSpawner.new()
	owner.game_controller.spawn_slowdown_requested.connect(owner.spawn_director.apply_slowdown)
	for node in [owner.game_controller, owner.board_controller, owner.save_manager, owner.session_overlay, owner.hud, owner.spawn_director]:
		owner.add_child(node)
	tutorial = TUTORIAL.new()
	owner.add_child(tutorial)
	tutorial.configure(owner)
	tutorial.round_requested.connect(_start_round)
	tutorial.completed.connect(func() -> void: completed_count += 1)
	owner.board_controller.character_hit.connect(_hit)
	owner.board_controller.character_escaped.connect(_escape)
	tutorial.start()
	check(tutorial.teaching == &"normal" and owner.session_overlay.card, "Clean save starts the first required lesson")
	check(not tutorial.allows_tap(4), "Modal card blocks board taps")
	owner.board_controller.clear_all()
	owner.session_overlay.tutorial_continue_requested.emit()
	await create_timer(0.8, true).timeout
	check(owner.board_controller.get_occupied_slot_count() == 1 and tutorial.demo_slots == [4], "Continue creates a fresh central fallback target")
	var frozen: float = owner.game_controller.remaining_time
	await create_timer(6.0, true).timeout
	check(tutorial.demonstrating and owner.board_controller.get_occupied_slot_count() == 1, "Missed Normal repeats safely without another card")
	check(owner.game_controller.remaining_time == frozen and owner.game_controller.lives == 3, "Controlled practice freezes time and preserves lives")
	await _tap(4)
	check(tutorial.teaching == &"normal" and not tutorial._mastered.has(&"normal"), "One accepted Normal hit does not grant mastery")
	await _tap(4)
	check(tutorial.teaching == &"misses", "Two separate accepted Normal hits advance to misses")
	owner.session_overlay.tutorial_continue_requested.emit()
	await _tap(4)
	check(tutorial._stage == 1 and owner.game_controller.combo_count == 1, "Misses exercise establishes series with an actual hit")
	for count in range(3):
		check(tutorial.allows_tap(4) and tutorial.empty_hit(4), "Accepted empty-box practice tap")
	check(owner.game_controller.lives == 2 and owner.game_controller.combo_count == 0, "Three real misses reset series and show one-life penalty")
	check(tutorial.teaching == &"misses", "Penalty demonstration alone does not grant misses mastery")
	tutorial.empty_hit(4)
	check(owner.game_controller.consecutive_misses == 1, "Practice exposes a nonzero miss counter")
	await _tap(4)
	check(tutorial.teaching == &"" and owner.game_controller.lives == 3 and owner.game_controller.score == 0, "Actual resetting hit restores lesson snapshot without future damage")
	check(owner.session_overlay.next_visible and owner.spawn_director._running and owner.game_controller.is_processing(), "Mastered round resumes free practice and offers explicit next")
	owner.session_overlay.tutorial_next_requested.emit()
	check(tutorial.teaching == &"bomb", "Explicit next enters Bomb lesson")
	owner.session_overlay.tutorial_continue_requested.emit()
	await create_timer(0.8, true).timeout
	check(not tutorial.allows_tap(4), "Bomb practice blocks dangerous accepted input")
	await create_timer(6.5, true).timeout
	check(tutorial.teaching == &"two" and owner.game_controller.lives == 3, "Waiting for actual Bomb escape grants mastery safely")
	owner.session_overlay.tutorial_continue_requested.emit()
	await _tap(3)
	check(not tutorial._mastered.has(&"two"), "First simultaneous target alone does not finish two-target lesson")
	await _tap(5)
	check(tutorial.teaching == &"series", "Distinct accepted target taps complete two-target lesson")
	owner.session_overlay.tutorial_continue_requested.emit()
	await _tap(4)
	check(tutorial.teaching == &"series", "One scoring hit is insufficient for series mastery")
	await create_timer(6.0, true).timeout
	check(tutorial._hits == 0 and not tutorial._mastered.has(&"series"), "Escaped series target resets action streak and retries safely")
	await _tap(4)
	await _tap(4)
	await _tap(4)
	check(tutorial._mastered.has(&"series"), "Three consecutive scoring hits complete series")
	owner.session_overlay.tutorial_next_requested.emit()
	for lesson in [&"golden", &"fast"]:
		check(tutorial.teaching == lesson, "Expected scoring variant lesson")
		owner.session_overlay.tutorial_continue_requested.emit()
		await _tap(4)
		check(not tutorial._mastered.has(lesson), "Scoring variant requires two accepted hits")
		await _tap(4)
	owner.session_overlay.tutorial_next_requested.emit()
	check(tutorial.teaching == &"clock", "Fourth practice round begins Clock")
	owner.session_overlay.tutorial_continue_requested.emit()
	await _tap(4)
	check(tutorial.teaching == &"glutton", "Real Clock award completes Clock action lesson")
	owner.session_overlay.tutorial_continue_requested.emit()
	await create_timer(0.8, true).timeout
	check(not tutorial.allows_tap(4), "Glutton penalty stage requires safely observing escape")
	await create_timer(5.3, true).timeout
	check(tutorial._stage == 1 and owner.game_controller.lives == 2, "Actual Glutton escape demonstrates life loss")
	await _tap(4)
	check(tutorial.teaching == &"endless_rules" and tutorial._mastered.has(&"glutton"), "Hit from two lives restores third and grants mastery")
	check(completed_count == 0 and not tutorial._mastered.has(&"endless_rules"), "Final explanation needs explicit confirmation")
	owner.session_overlay.tutorial_continue_requested.emit()
	await process_frame
	check(owner.save_manager.tutorials_complete() and completed_count == 1, "All ten stable lessons immediately finish training")
	owner.session_overlay.tutorial_next_requested.emit()
	owner.session_overlay.tutorial_next_requested.emit()
	check(completed_count == 1, "Repeated next cannot complete training twice")
	var data: Dictionary = owner.save_manager.load_data()
	check(data.best_run_score == 0 and data.best_run_combo == 0 and data.best_run_rounds == 0, "Real tutorial actions leave endless records untouched")
	# Save-derived configure, not a static cache, controls continuation.
	tutorial.queue_free()
	await process_frame
	TUTORIAL.learned.clear()
	tutorial = TUTORIAL.new()
	owner.add_child(tutorial)
	tutorial.configure(owner)
	tutorial.completed.connect(func() -> void: completed_count += 1)
	tutorial.start()
	check(completed_count == 2 and not tutorial.active, "New controller recognizes save mastery even when static cache is cleared")
	tutorial.round_requested.connect(_start_round)
	tutorial.start(true)
	check(tutorial.teaching == &"normal" and owner.save_manager.tutorials_complete(), "Explicit replay begins practice without erasing permanent mastery")
	owner.session_overlay.tutorial_continue_requested.emit()
	await create_timer(0.8, true).timeout
	var old_generation: int = tutorial._generation
	var old_step: int = tutorial._step_generation
	tutorial.reset_attempt()
	owner.board_controller.clear_all()
	tutorial._retry_demo(old_generation, old_step, &"normal")
	check(owner.board_controller.get_occupied_slot_count() == 0 and not tutorial.demonstrating, "Old generation cannot spawn after cancellation")
	owner.game_controller.pause_level(&"manual")
	owner.session_overlay.rules_requested.emit()
	owner.session_overlay.tutorial_continue_requested.emit()
	check(owner.session_overlay.pause_visible and owner.game_controller.pause_reasons.has(&"manual"), "Repeated rules return to owning manual pause")
	owner.game_controller.resume_level(&"manual")
	tutorial.queue_free()
	await process_frame
	owner.save_manager.delete_save_for_tests()
	owner.save_manager.set_save_path_for_tests("res://builds/debug/verification/endless/tutorial/tutorial_failed_write_disposable.json")
	owner.save_manager.delete_save_for_tests()
	owner.save_manager.set_replace_file_for_tests(func(_source: String, _destination: String) -> Error: return ERR_CANT_CREATE)
	tutorial = TUTORIAL.new()
	owner.add_child(tutorial)
	tutorial.configure(owner)
	tutorial.round_requested.connect(_start_round)
	tutorial.start()
	owner.session_overlay.tutorial_continue_requested.emit()
	await _tap(4)
	await _tap(4)
	check(tutorial._mastered.has(&"normal") and tutorial.teaching == &"misses", "Save replacement failure keeps mastered lesson and advances practice")
	check("normal" in owner.save_manager.load_data().learned_lessons, "Shared save manager preserves failed-write mastery within process")
	tutorial.reset_attempt()
	owner.save_manager.delete_save_for_tests()
	owner.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	paused = false
	print("TUTORIAL MASTERY ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _start_round(index: int) -> void:
	owner.game_controller.start_run(RoundProfile.new(), false, true)
	tutorial.begin_round(index)


func _tap(index: int) -> void:
	await create_timer(0.8, true).timeout
	check(tutorial.allows_tap(index) and owner.board_controller.hit_slot(index), "Real visible target accepts tutorial tap")
	await create_timer(1.3, true).timeout


func _hit(index: int, kind: StringName) -> void:
	owner.game_controller.resolve_character_hit(kind)
	tutorial.hit(index)


func _escape(index: int, kind: StringName) -> void:
	if not tutorial.escape(index):
		owner.game_controller.resolve_character_escape(kind)
