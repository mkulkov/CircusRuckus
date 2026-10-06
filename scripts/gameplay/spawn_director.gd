extends Node

@export var deterministic_seed: int = 0

# Temporarily keep the reaction and confusion types out of normal gameplay.
# Their scenes remain available for debug/manual checks.
const ENABLED_CHARACTER_TYPES: Array[StringName] = [&"normal", &"bomb", &"clock", &"glutton"]
const REQUIRED_CHARACTER_TYPES: Array[StringName] = ENABLED_CHARACTER_TYPES
const GUARANTEE_PROGRESS_START := 0.10
const GUARANTEE_PROGRESS_END := 0.75

var _board: Control
var _config: LevelConfig
var _rng := RandomNumberGenerator.new()
var _time_until_spawn: float = 0.35
var _running: bool = false
var _confusion_active: bool = false
var _round_progress: float = 0.0
var _last_slot: int = -1
var _same_slot_streak: int = 0
var _spawn_counts: Dictionary = {}
var _guaranteed_queue: Array[StringName] = []
var _guaranteed_deadlines: Array[float] = []


func configure(board: Control, config: LevelConfig = null) -> void:
	_board = board
	_config = config
	if deterministic_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = deterministic_seed
	_round_progress = 0.0


func set_remaining_time(remaining_time: float) -> void:
	if _config == null or _config.duration <= 0.0:
		_round_progress = 0.0
		return
	# Bonus time never makes the opening spawn rate slower than the round start.
	_round_progress = clampf(1.0 - remaining_time / _config.duration, 0.0, 1.0)


func start() -> void:
	_running = true


func prepare_level() -> void:
	_time_until_spawn = 0.35
	_last_slot = -1
	_same_slot_streak = 0
	_spawn_counts.clear()
	_guaranteed_queue.clear()
	_guaranteed_deadlines.clear()
	if _config != null:
		_guaranteed_queue.assign(REQUIRED_CHARACTER_TYPES)
		_shuffle_guaranteed_queue()
		_schedule_guaranteed_spawns()


func stop() -> void:
	_running = false


func set_confusion_remaining(remaining: int) -> void:
	_confusion_active = remaining > 0


func _process(delta: float) -> void:
	if not _running or _board == null or _config == null:
		return
	_time_until_spawn -= delta
	if _time_until_spawn > 0.0:
		return
	_attempt_spawn()
	_time_until_spawn = _next_spawn_interval()


func _next_spawn_interval() -> float:
	var multiplier := lerpf(1.0, _config.end_spawn_interval_multiplier, _round_progress)
	return _rng.randf_range(_config.spawn_interval_min, _config.spawn_interval_max) * multiplier


func _attempt_spawn() -> void:
	if _board.get_occupied_slot_count() >= _config.max_active_characters:
		return
	if not _spawn_one():
		return
	if _board.get_occupied_slot_count() < _config.max_active_characters and _rng.randf() < _config.double_spawn_chance:
		_spawn_second_after_delay()


func _spawn_second_after_delay() -> void:
	await get_tree().create_timer(_rng.randf_range(0.08, 0.20), false).timeout
	if _running and _board.get_occupied_slot_count() < _config.max_active_characters:
		_spawn_one()


func _spawn_one() -> bool:
	var free_slots: Array[int] = _board.get_free_slot_indices()
	if free_slots.is_empty():
		return false
	if _same_slot_streak >= 2 and free_slots.size() > 1:
		free_slots.erase(_last_slot)
	var character_type := _choose_character_type()
	if character_type == StringName():
		return false
	var slot_index := free_slots[_rng.randi_range(0, free_slots.size() - 1)]
	if not _board.spawn_character(slot_index, character_type, _visible_time_for(character_type)):
		return false
	if slot_index == _last_slot:
		_same_slot_streak += 1
	else:
		_last_slot = slot_index
		_same_slot_streak = 1
	_spawn_counts[character_type] = int(_spawn_counts.get(character_type, 0)) + 1
	return true


func _choose_character_type() -> StringName:
	var allowed := _allowed_character_types()
	if allowed.is_empty():
		return StringName()
	if not _guaranteed_queue.is_empty() and _round_progress >= _guaranteed_deadlines.front():
		var guaranteed: StringName = _guaranteed_queue.front()
		if guaranteed in allowed:
			_guaranteed_queue.pop_front()
			_guaranteed_deadlines.pop_front()
			return guaranteed
	var total_weight := 0.0
	for character_type in allowed:
		total_weight += _weight_for(character_type)
	if total_weight <= 0.0:
		return &"normal" if &"normal" in allowed else allowed[0]
	var roll := _rng.randf_range(0.0, total_weight)
	for character_type in allowed:
		roll -= _weight_for(character_type)
		if roll <= 0.0:
			return character_type
	return allowed.back()


func _shuffle_guaranteed_queue() -> void:
	for index in range(_guaranteed_queue.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var saved_type := _guaranteed_queue[index]
		_guaranteed_queue[index] = _guaranteed_queue[swap_index]
		_guaranteed_queue[swap_index] = saved_type


func _schedule_guaranteed_spawns() -> void:
	var count := _guaranteed_queue.size()
	for index in range(count):
		var segment_progress := (float(index) + _rng.randf()) / float(count)
		_guaranteed_deadlines.append(lerpf(
			GUARANTEE_PROGRESS_START,
			GUARANTEE_PROGRESS_END,
			segment_progress
		))


func _allowed_character_types() -> Array[StringName]:
	var result: Array[StringName] = []
	var active: Array[StringName] = _board.get_active_character_types()
	for character_type in ENABLED_CHARACTER_TYPES:
		if _weight_for(character_type) <= 0.0:
			continue
		if character_type == &"drunk" and _confusion_active:
			continue
		if character_type == &"glutton" and &"glutton" in active:
			continue
		if character_type == &"bomb" and &"bomb" in active:
			continue
		if character_type == &"clock" and int(_spawn_counts.get(&"clock", 0)) >= _config.max_clock_spawns:
			continue
		if _config.level_id <= 8 and not active.is_empty():
			if character_type in [&"bomb", &"drunk"] and _contains_hazard(active):
				continue
			if (character_type == &"bomb" and &"glutton" in active) or (character_type == &"glutton" and &"bomb" in active):
				continue
			if (character_type == &"fast" and &"glutton" in active) or (character_type == &"glutton" and &"fast" in active):
				continue
		result.append(character_type)
	return result


func _contains_hazard(character_types: Array[StringName]) -> bool:
	return &"bomb" in character_types or &"drunk" in character_types


func _weight_for(character_type: StringName) -> float:
	match character_type:
		&"normal": return _config.normal_weight
		&"fast": return _config.fast_weight
		&"golden": return _config.golden_weight
		&"bomb": return _config.bomb_weight
		&"clock": return _config.clock_weight
		&"glutton": return _config.glutton_weight
		&"drunk": return _config.drunk_weight
	return 0.0


func _visible_time_for(character_type: StringName) -> float:
	match character_type:
		&"normal": return _config.normal_visible_time
		&"fast": return _config.fast_visible_time
		&"golden": return _config.golden_visible_time
		&"bomb": return _config.bomb_visible_time
		&"clock": return _config.clock_visible_time
		&"glutton": return _config.glutton_visible_time
		&"drunk": return _config.drunk_visible_time
	return _config.normal_visible_time
