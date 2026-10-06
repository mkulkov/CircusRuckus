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

enum GameState {
	LOADING,
	COUNTDOWN,
	RUNNING,
	PAUSED,
	FINISHED_WIN,
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
var remaining_time: float = 60.0
var target_score: int = 250
var required_max_combo: int = 0
var required_golden_hits: int = 0
var golden_hits: int = 0
var confused_strikes_remaining: int = 0
var max_time_bonus: float = 30.0
var time_bonus_awarded: float = 0.0

var _countdown_index: int = 0
var _countdown_time_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func _process(delta: float) -> void:
	if state == GameState.COUNTDOWN:
		_process_countdown(delta)
	elif state == GameState.RUNNING:
		remaining_time = maxf(remaining_time - delta, 0.0)
		time_changed.emit(remaining_time)
		if remaining_time <= 0.0:
			finish_level(objectives_met() and lives > 0)


func start_level(
	duration: float = 60.0,
	required_score: int = 250,
	use_countdown: bool = true,
	required_combo: int = 0,
	required_golden: int = 0,
	clock_bonus_cap: float = 30.0
) -> void:
	if get_tree().paused:
		get_tree().paused = false
	score = 0
	combo_count = 0
	max_combo = 0
	lives = MAX_LIVES
	consecutive_misses = 0
	remaining_time = duration
	target_score = required_score
	required_max_combo = required_combo
	required_golden_hits = required_golden
	golden_hits = 0
	confused_strikes_remaining = 0
	max_time_bonus = clock_bonus_cap
	time_bonus_awarded = 0.0
	score_changed.emit(score)
	combo_changed.emit(combo_count)
	lives_changed.emit(lives)
	time_changed.emit(remaining_time)
	golden_hits_changed.emit(golden_hits)
	confusion_changed.emit(confused_strikes_remaining)

	if use_countdown:
		_countdown_index = 0
		_countdown_time_left = countdown_step_duration
		_set_state(GameState.COUNTDOWN)
		countdown_changed.emit(_get_countdown_label(_countdown_index))
	else:
		begin_running()


func begin_running() -> void:
	countdown_changed.emit("")
	_set_state(GameState.RUNNING)


func pause_level() -> void:
	if state != GameState.RUNNING:
		return
	_set_state(GameState.PAUSED)
	get_tree().paused = true


func resume_level() -> void:
	if state != GameState.PAUSED:
		return
	get_tree().paused = false
	_set_state(GameState.RUNNING)


func finish_level(won: bool) -> void:
	if state == GameState.FINISHED_WIN or state == GameState.FINISHED_LOSS:
		return
	if get_tree().paused:
		get_tree().paused = false
	_set_state(GameState.FINISHED_WIN if won else GameState.FINISHED_LOSS)
	game_finished.emit(won)


func resolve_scoring_hit() -> void:
	if state != GameState.RUNNING:
		return
	consecutive_misses = 0
	score += 10
	combo_count += 1
	max_combo = maxi(max_combo, combo_count)
	score_changed.emit(score)
	combo_changed.emit(combo_count)


func resolve_character_hit(character_type: StringName) -> void:
	if state != GameState.RUNNING:
		return
	consecutive_misses = 0
	match character_type:
		&"normal", &"fast", &"golden":
			resolve_scoring_hit()
			if character_type == &"golden":
				golden_hits += 1
				golden_hits_changed.emit(golden_hits)
				feedback_requested.emit(tr("GOLD_BONUS"))
		&"bomb":
			reset_combo()
			feedback_requested.emit(tr("BOMB_LIFE"))
			lose_life()
		&"clock":
			var awarded := add_time(10.0)
		&"glutton":
			restore_life()
		&"drunk":
			reset_combo()
			confused_strikes_remaining = DRUNK_CONFUSION_STRIKES
			confusion_changed.emit(confused_strikes_remaining)
			feedback_requested.emit(tr("CONFUSION_STRIKES") % DRUNK_CONFUSION_STRIKES)


func resolve_character_escape(character_type: StringName) -> void:
	if state != GameState.RUNNING:
		return
	if character_type in [&"normal", &"fast", &"golden"]:
		resolve_scoring_miss()
	elif character_type == &"glutton":
		reset_combo()


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


func objectives_met() -> bool:
	return score >= target_score and max_combo >= required_max_combo and golden_hits >= required_golden_hits


func resolve_empty_hit() -> void:
	_register_miss()


func resolve_scoring_miss() -> void:
	_register_miss()


func _register_miss() -> void:
	if state != GameState.RUNNING:
		return
	reset_combo()
	consecutive_misses += 1
	if consecutive_misses >= MISSES_PER_LIFE:
		consecutive_misses = 0
		feedback_requested.emit(tr("THREE_MISSES_LIFE"))
		lose_life()


func lose_life() -> void:
	if state != GameState.RUNNING:
		return
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	if lives == 0:
		finish_level(false)


func restore_life() -> void:
	if state != GameState.RUNNING:
		return
	lives = mini(lives + 1, MAX_LIVES)
	lives_changed.emit(lives)


func reset_combo() -> void:
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
