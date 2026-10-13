extends Node

signal score_changed(value: int)
signal combo_changed(value: int)
signal lives_changed(value: int)
signal time_changed(value: float)
signal countdown_changed(text: String)
signal state_changed(value: GameState)
signal game_finished(won: bool)
signal golden_hits_changed(value: int)
signal confusion_changed(remaining: int)
signal feedback_requested(text: String)
signal progress_changed
signal active_time_advanced(elapsed: float)
signal round_finished
signal recovery_changed
signal life_restored(source: String)
signal spawn_slowdown_requested(duration: float)

enum GameState {
	LOADING,
	COUNTDOWN,
	RUNNING,
	PAUSED,
	ROUND_TRANSITION,
	FINISHED_LOSS,
}

const MAX_LIVES := 3
const MISSES_PER_LIFE := 3
const COUNTDOWN_LABELS := ["3", "2", "1", "COUNTDOWN_GO"]
const DRUNK_CONFUSION_STRIKES := 1

@export var countdown_step_duration: float = 0.65

var state: GameState = GameState.LOADING
var score: int = 0
var combo_count: int = 0
var max_combo: int = 0
var lives: int = MAX_LIVES
var consecutive_misses: int = 0
var remaining_time: float = 25.0
var golden_hits: int = 0
var confused_strikes_remaining: int = 0
var max_time_bonus: float = 30.0
var time_bonus_awarded: float = 0.0
var active_elapsed: float = 0.0

var round_elapsed: float = 0.0
var completed_rounds: int = 0
var run_generation: int = 0
var round_generation: int = 0
var is_practice := false
var recovery_hits: int = 0
var recovery_used := false
var round_profile: RoundProfile
var round_stats: Dictionary = {}
var finish_reason := ""
var pause_reasons: Dictionary = {}
var _paused_state: GameState = GameState.RUNNING

var _countdown_index: int = 0
var _countdown_time_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func _process(delta: float) -> void:
	if not pause_reasons.is_empty():
		return
	if state == GameState.COUNTDOWN:
		_process_countdown(delta)
	elif state == GameState.RUNNING:
		var elapsed := minf(delta, remaining_time)
		if not is_practice:
			active_elapsed = minf(active_elapsed + elapsed, float(RoundProfile.MAX_SAFE_INTEGER))
			active_time_advanced.emit(elapsed)
		round_elapsed += elapsed
		remaining_time = maxf(remaining_time - delta, 0.0)
		time_changed.emit(remaining_time)
		if state == GameState.RUNNING and remaining_time <= 0.0:
			complete_round()


func start_run(profile: RoundProfile = null, use_countdown: bool = true, practice: bool = false, run_rng: RandomNumberGenerator = null) -> void:
	run_generation += 1
	pause_reasons.clear()
	get_tree().paused = false
	is_practice = practice
	score = 0
	combo_count = 0
	max_combo = 0
	lives = MAX_LIVES
	consecutive_misses = 0
	golden_hits = 0
	confused_strikes_remaining = 0
	active_elapsed = 0.0
	completed_rounds = 0
	recovery_used = false
	finish_reason = ""
	if run_rng != null:
		_rng = run_rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	score_changed.emit(score)
	combo_changed.emit(combo_count)
	lives_changed.emit(lives)
	golden_hits_changed.emit(golden_hits)
	confusion_changed.emit(0)
	start_round(profile if profile != null else RoundProfile.new(), use_countdown)


func start_round(profile: RoundProfile, use_countdown: bool = false) -> void:
	round_generation += 1
	round_profile = profile
	remaining_time = profile.duration
	round_elapsed = 0.0
	max_time_bonus = profile.max_time_bonus
	time_bonus_awarded = 0.0
	round_stats = {"scoring_hits": 0, "scoring_escapes": 0, "empty_hits": 0, "bomb_hits": 0, "glutton_escapes": 0, "lives_lost": 0}
	recovery_hits = 0
	if profile.phase_index == 0:
		recovery_used = false
	recovery_changed.emit()
	time_changed.emit(remaining_time)
	if use_countdown:
		_countdown_index = 0
		_countdown_time_left = countdown_step_duration
		_set_state(GameState.COUNTDOWN)
		countdown_changed.emit(_get_countdown_label(_countdown_index))
	else:
		begin_running()


func complete_round() -> void:
	if state != GameState.RUNNING:
		return
	if lives <= 0:
		finish_run("lives")
		return
	# Set the barrier before observers can schedule another transition.
	_set_state(GameState.ROUND_TRANSITION)
	if not is_practice:
		completed_rounds = mini(completed_rounds + 1, RoundProfile.MAX_SAFE_INTEGER)
	round_finished.emit()


func begin_running() -> void:
	countdown_changed.emit("")
	_set_state(GameState.RUNNING)


func pause_level(reason: StringName = &"manual") -> void:
	if state == GameState.FINISHED_LOSS or state == GameState.LOADING:
		return
	if pause_reasons.is_empty():
		_paused_state = state
	pause_reasons[reason] = true
	_set_state(GameState.PAUSED)
	get_tree().paused = true


func resume_level(reason: StringName = &"manual") -> void:
	pause_reasons.erase(reason)
	if state != GameState.PAUSED or not pause_reasons.is_empty():
		return
	get_tree().paused = false
	_set_state(_paused_state)


func finish_run(reason: String = "lives") -> void:
	if state == GameState.FINISHED_LOSS:
		return
	finish_reason = reason
	run_generation += 1
	round_generation += 1
	pause_reasons.clear()
	get_tree().paused = false
	_set_state(GameState.FINISHED_LOSS)
	game_finished.emit(false)


static func scoring_points(character_type: StringName) -> int:
	match character_type:
		&"golden": return 50
		&"fast": return 20
	return 10


func resolve_scoring_hit(character_type: StringName = &"normal") -> void:
	if state != GameState.RUNNING:
		return
	consecutive_misses = 0
	score = mini(score + scoring_points(character_type), RoundProfile.MAX_SAFE_INTEGER)
	combo_count = mini(combo_count + 1, RoundProfile.MAX_SAFE_INTEGER)
	max_combo = maxi(max_combo, combo_count)
	_stat("scoring_hits")
	_progress_recovery()
	score_changed.emit(score)
	combo_changed.emit(combo_count)
	progress_changed.emit()


func resolve_character_hit(character_type: StringName) -> void:
	if state != GameState.RUNNING:
		return
	consecutive_misses = 0
	match character_type:
		&"normal", &"fast", &"golden":
			resolve_scoring_hit(character_type)
			if character_type == &"golden":
				golden_hits += 1
				golden_hits_changed.emit(golden_hits)
				progress_changed.emit()
				feedback_requested.emit(tr("GOLD_BONUS"))
		&"bomb":
			_stat("bomb_hits")
			reset_combo()
			feedback_requested.emit(tr("BOMB_LIFE"))
			lose_life()
		&"clock":
			spawn_slowdown_requested.emit(5.0)
		&"glutton":
			restore_life("glutton")
		&"drunk":
			reset_combo()
			confused_strikes_remaining = DRUNK_CONFUSION_STRIKES
			confusion_changed.emit(confused_strikes_remaining)
	progress_changed.emit()


func resolve_character_escape(character_type: StringName) -> void:
	if state != GameState.RUNNING:
		return
	if character_type in [&"normal", &"fast", &"golden"]:
		resolve_scoring_miss()
	elif character_type == &"glutton":
		_stat("glutton_escapes")
		reset_combo()
		consecutive_misses = 0
		feedback_requested.emit(tr("GLUTTON_ESCAPED"))
		lose_life()
	progress_changed.emit()


func redirect_gameplay_slot(requested_slot: int, slot_count: int = 9) -> int:
	if confused_strikes_remaining <= 0 or slot_count <= 0:
		return requested_slot
	var actual_slot := _rng.randi_range(0, slot_count - 1)
	confused_strikes_remaining -= 1
	confusion_changed.emit(confused_strikes_remaining)
	return actual_slot


func add_time(seconds: float) -> float:
	if state != GameState.RUNNING:
		return 0.0
	var awarded := minf(maxf(seconds, 0.0), maxf(max_time_bonus - time_bonus_awarded, 0.0))
	if awarded <= 0.0:
		return 0.0
	time_bonus_awarded += awarded
	remaining_time += awarded
	time_changed.emit(remaining_time)
	return awarded


func resolve_empty_hit() -> void:
	if state == GameState.RUNNING:
		_stat("empty_hits")
	_register_miss()


func resolve_scoring_miss() -> void:
	if state == GameState.RUNNING:
		_stat("scoring_escapes")
	_register_miss()


func _stat(key: String) -> void:
	if not is_practice:
		round_stats[key] = int(round_stats.get(key, 0)) + 1


func _progress_recovery() -> void:
	if is_practice or round_profile == null or round_profile.phase_index != 0 or recovery_used or lives >= MAX_LIVES:
		return
	recovery_hits += 1
	if recovery_hits >= round_profile.recovery_hits_required:
		recovery_used = true
		restore_life("recovery")
	recovery_changed.emit()


func _register_miss() -> void:
	if state != GameState.RUNNING:
		return
	reset_combo()
	consecutive_misses += 1
	if consecutive_misses >= MISSES_PER_LIFE:
		consecutive_misses = 0
		feedback_requested.emit(tr("THREE_MISSES_LIFE"))
		lose_life()
	progress_changed.emit()


func lose_life() -> void:
	if state != GameState.RUNNING:
		return
	_stat("lives_lost")
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	if lives == 0:
		finish_run("lives")


func restore_life(source: String = "glutton") -> void:
	if state != GameState.RUNNING:
		return
	var previous := lives
	lives = mini(lives + 1, MAX_LIVES)
	if lives == MAX_LIVES:
		recovery_hits = 0
	lives_changed.emit(lives)
	recovery_changed.emit()
	if lives > previous:
		life_restored.emit(source)


func reset_combo() -> void:
	recovery_hits = 0
	recovery_changed.emit()
	if combo_count == 0:
		return
	combo_count = 0
	combo_changed.emit(combo_count)


func _process_countdown(delta: float) -> void:
	_countdown_time_left -= delta
	if _countdown_time_left > 0.0:
		return
	_countdown_index += 1
	if _countdown_index >= COUNTDOWN_LABELS.size():
		begin_running()
		return
	_countdown_time_left += countdown_step_duration
	countdown_changed.emit(_get_countdown_label(_countdown_index))


func _get_countdown_label(index: int) -> String:
	var label := str(COUNTDOWN_LABELS[index])
	return tr(label) if label == "COUNTDOWN_GO" else label


func _set_state(value: GameState) -> void:
	state = value
	state_changed.emit(state)
