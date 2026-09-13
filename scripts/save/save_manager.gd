extends Node

signal cloud_initialization_completed

const DEFAULT_DATA: Dictionary = {
	"save_version": 1,
	"highest_unlocked_level": 1,
	"completed_levels": [],
	"best_scores": {},
	"best_combos": {},
	"music_enabled": true,
	"sound_enabled": true,
	"haptics_enabled": true,
	"ads_removed": false
}
const CLOUD_INITIALIZATION_TIMEOUT_MSEC := 5000

var _save_path: String = "user://clown_smash_save.json"
var _open_file_func: Callable = Callable(FileAccess, "open")
var _cloud_bridge: Variant
var _cloud_load_callback: JavaScriptObject
var _cloud_save_callback: JavaScriptObject
var _cloud_ready := false
var _cloud_initialization_pending := false


func set_save_path_for_tests(save_path: String) -> void:
	_save_path = save_path


func set_open_file_for_tests(open_file_func: Callable) -> void:
	_open_file_func = open_file_func


func delete_save_for_tests() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	DirAccess.remove_absolute(_save_path)


func load_data() -> Dictionary:
	if not FileAccess.file_exists(_save_path):
		return _default_data()

	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return _default_data()
	var content: String = file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return _default_data()

	var parser := JSON.new()
	var parse_error: Error = parser.parse(content)
	if parse_error != OK:
		return _default_data()
	var parsed: Variant = parser.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		return _default_data()

	var data: Dictionary = parsed
	if not _is_valid_save_data(data):
		return _default_data()

	return _normalize_save_data(data)


func initialize_cloud() -> void:
	if not OS.has_feature("web") or _cloud_initialization_pending or _cloud_ready:
		return
	_cloud_bridge = JavaScriptBridge.get_interface("ClownSmashPlatform")
	if _cloud_bridge == null:
		return
	_cloud_initialization_pending = true
	_cloud_load_callback = JavaScriptBridge.create_callback(_on_cloud_loaded)
	_cloud_bridge.loadCloudSave(_cloud_load_callback)
	var started_at := Time.get_ticks_msec()
	while _cloud_initialization_pending and Time.get_ticks_msec() - started_at < CLOUD_INITIALIZATION_TIMEOUT_MSEC:
		await get_tree().process_frame
	if _cloud_initialization_pending:
		_cloud_initialization_pending = false
		push_warning("Yandex cloud initialization timed out; local progress remains available.")


func _on_cloud_loaded(arguments: Array) -> void:
	_cloud_initialization_pending = false
	var response := _decode_callback_dictionary(arguments)
	if not bool(response.get("success", false)):
		cloud_initialization_completed.emit()
		return

	_cloud_ready = true
	var local_data := load_data()
	var cloud_value: Variant = response.get("data")
	var merged := local_data
	if typeof(cloud_value) == TYPE_DICTIONARY and _is_valid_save_data(cloud_value):
		merged = _merge_save_data(local_data, _normalize_save_data(cloud_value))
	_write_local_data(merged)
	_push_cloud_data(merged)
	cloud_initialization_completed.emit()


func save_data(data: Dictionary) -> Error:
	var error := _write_local_data(data)
	if error == OK:
		_push_cloud_data(data)
	return error


func _write_local_data(data: Dictionary) -> Error:
	_last_save_error = OK
	var file: Object = _open_file_func.call(_save_path, FileAccess.WRITE)
	if file == null:
		_last_save_error = FAILED
		return FAILED

	var encoded: String = JSON.stringify(data)
	file.store_string(encoded)
	var error: Error = file.get_error()
	if error == OK:
		file.flush()
		error = file.get_error()

	file.close()
	_last_save_error = error

	return error


func _push_cloud_data(data: Dictionary) -> void:
	if not _cloud_ready or _cloud_bridge == null:
		return
	_cloud_save_callback = JavaScriptBridge.create_callback(_on_cloud_saved)
	_cloud_bridge.saveCloudSave(JSON.stringify(data), _cloud_save_callback)


func _on_cloud_saved(arguments: Array) -> void:
	var response := _decode_callback_dictionary(arguments)
	if not bool(response.get("success", false)):
		push_warning("Yandex cloud save failed; local progress remains available.")


func _decode_callback_dictionary(arguments: Array) -> Dictionary:
	if arguments.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(str(arguments[0]))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _merge_save_data(local_data: Dictionary, cloud_data: Dictionary) -> Dictionary:
	var merged := cloud_data.duplicate(true)
	merged["highest_unlocked_level"] = maxi(
		int(local_data.get("highest_unlocked_level", 1)),
		int(cloud_data.get("highest_unlocked_level", 1))
	)

	var completed: Array[int] = []
	for source: Dictionary in [local_data, cloud_data]:
		for level_value in source.get("completed_levels", []):
			var level := int(level_value)
			if level not in completed:
				completed.append(level)
	completed.sort()
	merged["completed_levels"] = completed

	for field in ["best_scores", "best_combos"]:
		var values: Dictionary = cloud_data.get(field, {}).duplicate(true)
		for key in local_data.get(field, {}):
			values[key] = maxi(int(values.get(key, 0)), int(local_data[field][key]))
		merged[field] = values

	merged["ads_removed"] = bool(local_data.get("ads_removed", false)) or bool(cloud_data.get("ads_removed", false))
	return _normalize_save_data(merged)


func record_completed_level(level_id: int, score: int, combo: int) -> Dictionary:
	if level_id < 1 or level_id > 9:
		return load_data()
	if score < 0 or combo < 0:
		return load_data()

	var old_data := load_data()
	var data := old_data.duplicate(true)
	var level_key := str(level_id)

	if not data["completed_levels"].has(level_id):
		data["completed_levels"].append(level_id)

	var next_unlocked: int = min(9, level_id + 1)
	if next_unlocked > data["highest_unlocked_level"]:
		data["highest_unlocked_level"] = next_unlocked

	var best_scores := data["best_scores"] as Dictionary
	if not best_scores.has(level_key) or score > int(best_scores[level_key]):
		best_scores[level_key] = score
	data["best_scores"] = best_scores

	var best_combos := data["best_combos"] as Dictionary
	if not best_combos.has(level_key) or combo > int(best_combos[level_key]):
		best_combos[level_key] = combo
	data["best_combos"] = best_combos

	if save_data(data) != OK:
		return old_data
	return data


func get_last_save_error() -> Error:
	return _last_save_error


func update_settings(music_enabled: bool, sound_enabled: bool, haptics_enabled: bool) -> Error:
	var data := load_data()
	data["music_enabled"] = music_enabled
	data["sound_enabled"] = sound_enabled
	data["haptics_enabled"] = haptics_enabled
	return save_data(data)


func set_ads_removed(value: bool) -> Error:
	var data := load_data()
	data["ads_removed"] = value
	return save_data(data)


var _last_save_error: Error = OK


func _default_data() -> Dictionary:
	return DEFAULT_DATA.duplicate(true)


func _is_valid_save_data(data: Dictionary) -> bool:
	if not data.has("save_version") or not _is_supported_version(data["save_version"]):
		return false

	var highest_level: int = _as_int(data.get("highest_unlocked_level"))
	if not data.has("highest_unlocked_level") or highest_level < 1 or highest_level > 9:
		return false

	if not data.has("completed_levels") or typeof(data["completed_levels"]) != TYPE_ARRAY:
		return false
	if not data.has("best_scores") or typeof(data["best_scores"]) != TYPE_DICTIONARY:
		return false
	if not data.has("best_combos") or typeof(data["best_combos"]) != TYPE_DICTIONARY:
		return false
	if not data.has("music_enabled") or typeof(data["music_enabled"]) != TYPE_BOOL:
		return false
	if not data.has("sound_enabled") or typeof(data["sound_enabled"]) != TYPE_BOOL:
		return false
	if not data.has("haptics_enabled") or typeof(data["haptics_enabled"]) != TYPE_BOOL:
		return false

	var seen_levels: Dictionary = {}
	var required_unlocked: int = 1
	for value in data["completed_levels"]:
		var level: int = _as_int(value)
		if level < 1 or level > 9:
			return false
		if seen_levels.has(str(level)):
			return false
		seen_levels[str(level)] = true
		required_unlocked = max(required_unlocked, min(9, level + 1))

	if highest_level < required_unlocked:
		return false

	for key in data["best_scores"]:
		var level_key := str(key)
		if not _is_level_key_valid(level_key):
			return false
		if not _is_integer_numeric(data["best_scores"][key]):
			return false
		if int(data["best_scores"][key]) < 0:
			return false

	for key in data["best_combos"]:
		var level_key := str(key)
		if not _is_level_key_valid(level_key):
			return false
		if not _is_integer_numeric(data["best_combos"][key]):
			return false
		if int(data["best_combos"][key]) < 0:
			return false

	return true


func _is_supported_version(value: Variant) -> bool:
	var version: int = _as_int(value)
	return version == 1


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		var float_value: float = float(value)
		if absf(float_value - int(float_value)) > 0.000001:
			return -1
		return int(float_value)
	return -1


func _is_integer_numeric(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var float_value: float = float(value)
		return absf(float_value - int(float_value)) <= 0.000001
	return false


func _normalize_save_data(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	normalized["save_version"] = _as_int(data["save_version"])
	normalized["highest_unlocked_level"] = _as_int(data["highest_unlocked_level"])
	var normalized_levels: Array[int] = []
	for level in data["completed_levels"]:
		normalized_levels.append(_as_int(level))
	normalized["completed_levels"] = normalized_levels

	var normalized_best_scores: Dictionary = {}
	for level: String in data["best_scores"]:
		normalized_best_scores[level] = int(data["best_scores"][level])
	normalized["best_scores"] = normalized_best_scores

	var normalized_best_combos: Dictionary = {}
	for level: String in data["best_combos"]:
		normalized_best_combos[level] = int(data["best_combos"][level])
	normalized["best_combos"] = normalized_best_combos

	normalized["music_enabled"] = data["music_enabled"]
	normalized["sound_enabled"] = data["sound_enabled"]
	normalized["haptics_enabled"] = data["haptics_enabled"]
	normalized["ads_removed"] = bool(data.get("ads_removed", false))

	return normalized.duplicate(true)


func _is_level_key_valid(level_key: String) -> bool:
	if not level_key.is_valid_int():
		return false

	var level: int = level_key.to_int()
	if level < 1 or level > 9:
		return false
	return str(level) == level_key
