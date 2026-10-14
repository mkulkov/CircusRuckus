class_name RoundProfile
extends Resource

const MAX_SAFE_INTEGER := 9007199254740991
@export var display_name: String = "recovery"
@export var duration: float = 25.0
@export var spawn_interval_min: float = 0.8695652174
@export var spawn_interval_max: float = 1.0869565217
@export var end_spawn_interval_multiplier: float = 1.0
@export var max_active_characters: int = 4
@export var max_decision_targets: int = 1
@export var double_spawn_chance: float = 0.0
@export var normal_weight: float = 76.0
@export var fast_weight: float = 4.0
@export var golden_weight: float = 8.0
@export var bomb_weight: float = 4.0
@export var clock_weight: float = 4.0
@export var glutton_weight: float = 4.0
@export var drunk_weight: float = 0.0
@export var normal_visible_time: float = 1.8
@export var fast_visible_time: float = 0.7
@export var golden_visible_time: float = 1.65
@export var bomb_visible_time: float = 1.125
@export var clock_visible_time: float = 1.425
@export var glutton_visible_time: float = 1.65
@export var drunk_visible_time: float = 1.65
@export var max_clock_spawns: int = 3
@export var max_time_bonus: float = 30.0
@export var recovery_hits_required: int = 20
@export var allowed_patterns: PackedStringArray = ["steady", "golden_series"]
var phase_index: int = 0
var pattern: String = "steady"
var assist_step: int = 0
var is_tutorial: bool = false


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(duration) or duration != 25.0:
		errors.append("duration must be 25")
	if max_active_characters < 1 or max_active_characters > 6 or max_decision_targets < 1 or max_decision_targets > 2 or max_decision_targets > max_active_characters:
		errors.append("occupancy/decision limits")
	if not is_finite(spawn_interval_min) or not is_finite(spawn_interval_max) or not is_finite(end_spawn_interval_multiplier) or spawn_interval_min < 0.6347 or spawn_interval_max < spawn_interval_min or spawn_interval_min * end_spawn_interval_multiplier < 0.5839 - 0.000001 or end_spawn_interval_multiplier < 0.92 or end_spawn_interval_multiplier > 1.0:
		errors.append("spawn interval bounds")
	if not is_finite(double_spawn_chance) or double_spawn_chance < 0.0 or double_spawn_chance > 0.22:
		errors.append("double bounds")
	var total := 0.0
	for kind in ["normal", "fast", "golden", "bomb", "clock", "glutton", "drunk"]:
		var weight: float = get(kind + "_weight")
		if not is_finite(weight) or weight < 0.0:
			errors.append("invalid weight " + kind)
		total += weight
		var window: float = get(kind + "_visible_time")
		if not is_finite(window) or window <= 0.0:
			errors.append("invalid window " + kind)
	if total <= 0.0 or drunk_weight != 0.0:
		errors.append("enabled mix")
	var introductions := 0
	for kind in ["normal", "fast", "golden", "bomb", "clock", "glutton"]:
		if float(get(kind + "_weight")) > 0.0:
			introductions += 1
	if spawn_interval_max > 0.0 and floori(duration / spawn_interval_max) < introductions:
		errors.append("guarantee quota exceeds scheduling capacity")
	if normal_visible_time < 1.125 or fast_visible_time < 0.55 or golden_visible_time < 1.2 or bomb_visible_time < 1.125 or clock_visible_time < 1.425 or glutton_visible_time < 1.65:
		errors.append("availability bounds")
	if max_clock_spawns != 3 or max_time_bonus != 30.0 or recovery_hits_required < 15 or recovery_hits_required > 25:
		errors.append("bonus limits")
	for value in allowed_patterns:
		if value not in ["steady", "pairs", "precision", "golden_series"]:
			errors.append("unknown pattern")
	if allowed_patterns.is_empty():
		errors.append("empty pattern bag")
	return errors
