extends Node

const PROFILE_PATHS := ["recovery", "build", "variation", "pressure", "peak"]
var round_index: int = 0
var cycle_index: int = 1
var phase_index: int = 0
var assist_step: int = 0
var accuracy_ema: float = 0.0
var has_accuracy := false
var seed_value: int = 0
var _good_rounds: int = 0
var _rng := RandomNumberGenerator.new()
var _bag: Array[String] = []
var _last_pattern := ""
var _pattern_streak := 0
var debug_plan: Dictionary = {}


func start_run(seed_number: int = 0) -> void:
	_rng.randomize()
	if seed_number != 0:
		_rng.seed = seed_number
	seed_value = _rng.seed
	round_index = 0
	assist_step = 0
	has_accuracy = false
	accuracy_ema = 0.0
	_good_rounds = 0
	_bag.clear()
	_last_pattern = ""
	_pattern_streak = 0


func get_run_rng() -> RandomNumberGenerator:
	return _rng


func observe_round(stats: Dictionary) -> void:
	var opportunities := int(stats.get("scoring_hits", 0)) + int(stats.get("scoring_escapes", 0))
	var valid := opportunities >= 10
	if valid:
		var accuracy := float(stats.get("scoring_hits", 0)) / opportunities
		accuracy_ema = lerpf(accuracy_ema, accuracy, 0.25) if has_accuracy else accuracy
		has_accuracy = true
	if int(stats.get("lives_lost", 0)) > 0 or (valid and accuracy_ema < 0.65):
		assist_step = mini(assist_step + 1, 2)
		_good_rounds = 0
	elif valid and accuracy_ema > 0.90:
		_good_rounds += 1
		if _good_rounds >= 2:
			assist_step = maxi(assist_step - 1, 0)
			_good_rounds = 0
	else:
		_good_rounds = 0


func next_profile() -> RoundProfile:
	round_index = mini(round_index + 1, RoundProfile.MAX_SAFE_INTEGER)
	cycle_index = floori(float(round_index - 1) / 5.0) + 1
	phase_index = (round_index - 1) % 5
	var profile := load("res://data/round_profiles/%s.tres" % PROFILE_PATHS[phase_index]).duplicate(true) as RoundProfile
	profile.phase_index = phase_index
	profile.assist_step = assist_step
	profile.pattern = _choose_pattern(profile.allowed_patterns)
	match profile.pattern:
		"steady": profile.double_spawn_chance = 0.0
		"precision":
			var added := minf(2.0, 10.0 - profile.bomb_weight)
			profile.bomb_weight += added
			profile.fast_weight = maxf(0.0, profile.fast_weight - added)
			profile.double_spawn_chance = 0.0
		"golden_series":
			var added := minf(4.0, 16.0 - profile.golden_weight)
			profile.golden_weight += added
			profile.normal_weight -= added
			profile.double_spawn_chance = 0.0
	var help_multiplier := 1.0 + 0.05 * assist_step
	profile.spawn_interval_min *= help_multiplier
	profile.spawn_interval_max *= help_multiplier
	profile.normal_visible_time *= help_multiplier
	profile.fast_visible_time *= help_multiplier
	profile.golden_visible_time *= help_multiplier
	debug_plan = {"round": round_index, "cycle": cycle_index, "phase": PROFILE_PATHS[phase_index], "pattern": profile.pattern, "seed": seed_value, "assist": assist_step,
		"interval_min": profile.spawn_interval_min, "interval_max": profile.spawn_interval_max, "end_multiplier": profile.end_spawn_interval_multiplier,
		"normal_window": profile.normal_visible_time, "fast_window": profile.fast_visible_time, "golden_window": profile.golden_visible_time}
	return profile


func _choose_pattern(allowed: PackedStringArray) -> String:
	for index in range(_bag.size() - 1, -1, -1):
		if _bag[index] not in allowed:
			_bag.remove_at(index)
	if _bag.is_empty():
		for candidate in allowed:
			_bag.append(candidate)
		for index in range(_bag.size() - 1, 0, -1):
			var other := _rng.randi_range(0, index)
			var value := _bag[index]
			_bag[index] = _bag[other]
			_bag[other] = value
	var choice := _bag.size() - 1
	if _pattern_streak >= 2 and _bag[choice] == _last_pattern:
		for candidate in allowed:
			if candidate != _last_pattern:
				_bag.append(candidate)
				choice = _bag.size() - 1
				break
	var result: String = _bag.pop_at(choice)
	_pattern_streak = _pattern_streak + 1 if result == _last_pattern else 1
	_last_pattern = result
	return result

