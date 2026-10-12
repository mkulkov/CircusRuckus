extends Node

signal cloud_initialization_completed
signal cloud_sync_failed

const SAVE_VERSION := 2
const TUTORIAL_VERSION := 1
const ENDLESS_RULES_VERSION := 1
const MAX_SAFE_INTEGER := 9007199254740991
const LESSON_IDS := ["normal", "misses", "bomb", "two", "series", "golden", "fast", "clock", "glutton", "endless_rules"]
const RECORD_FIELDS := ["best_run_score", "best_run_combo", "best_run_rounds", "best_run_active_seconds"]
const SETTINGS_FIELDS := ["music_enabled", "sound_enabled", "haptics_enabled"]
const DEFAULT_LEGACY: Dictionary = {
	"highest_unlocked_level": 1, "completed_levels": [], "best_scores": {}, "best_combos": {}
}
const DEFAULT_DATA: Dictionary = {
	"save_version": 2, "tutorial_version": 1, "endless_rules_version": 1,
	"learned_lessons": [], "best_run_score": 0, "best_run_combo": 0,
	"best_run_rounds": 0, "best_run_active_seconds": 0.0,
	"music_enabled": true, "sound_enabled": true, "haptics_enabled": true,
	"ads_removed": false, "legacy_campaign": DEFAULT_LEGACY
}
const CLOUD_INITIALIZATION_TIMEOUT_MSEC := 5000
const MAX_CLOUD_ATTEMPTS := 3

var _save_path: String = "user://clown_smash_save.json"
var _open_file_func: Callable = Callable(FileAccess, "open")
var _replace_file_func: Callable = Callable(DirAccess, "rename_absolute")
var _cloud_bridge: Variant
var _cloud_load_callback: JavaScriptObject
var _cloud_save_callback: JavaScriptObject
var _cloud_ready := false
var _cloud_initialization_pending := false
var _cloud_retry_seconds := 0.0
var _cloud_save_retry_needed := false
var _cloud_initialization_attempts := 0
var _cloud_save_attempts := 0
var _last_save_error: Error = OK
var _writes_blocked := false
var _session_lessons: Array[String] = []
var _session_path := ""

var data: Dictionary:
	get:
		return load_data()


func _init() -> void:
	if OS.is_debug_build():
		var testing_path := str(ProjectSettings.get_setting("clown_smash/testing/save_path", ""))
		if not testing_path.is_empty() and testing_path.is_absolute_path():
			_save_path = testing_path


func _process(delta: float) -> void:
	if not OS.has_feature("web") or not OS.has_feature("vk_mini_apps") or OS.has_feature("monetization_demo"):
		return
	_cloud_retry_seconds += delta
	if _cloud_retry_seconds < 30.0:
		return
	_cloud_retry_seconds = 0.0
	if not _cloud_ready and not _cloud_initialization_pending:
		initialize_cloud()
	elif _cloud_save_retry_needed and _cloud_save_attempts < MAX_CLOUD_ATTEMPTS:
		_push_cloud_data(load_data())


func set_save_path_for_tests(save_path: String) -> void:
	_save_path = save_path
	_writes_blocked = false


func set_open_file_for_tests(open_file_func: Callable) -> void:
	_open_file_func = open_file_func


func set_replace_file_for_tests(replace_file_func: Callable) -> void:
	_replace_file_func = replace_file_func


func delete_save_for_tests() -> void:
	for suffix in ["", ".tmp", ".backup", ".backup.tmp", ".v1.backup", ".corrupt.backup"]:
		if FileAccess.file_exists(_save_path + suffix):
			DirAccess.remove_absolute(_save_path + suffix)
	_writes_blocked = false
	_session_lessons.clear()


func load_data() -> Dictionary:
	if _session_path != _save_path:
		_session_path = _save_path
		_session_lessons.clear()
	var current := _load_persisted_data()
	if not _writes_blocked and current["tutorial_version"] == TUTORIAL_VERSION:
		for id in _session_lessons:
			if id not in current["learned_lessons"]:
				current["learned_lessons"].append(id)
		current = _normalize_save_data(current)
	return current


func _load_persisted_data() -> Dictionary:
	_writes_blocked = false
	if not FileAccess.file_exists(_save_path):
		# A valid recovery copy is still readable after an interrupted replacement.
		return _read_recovery_data()
	var content := FileAccess.get_file_as_string(_save_path)
	var parsed: Variant = _parse_document(content)
	if typeof(parsed) == TYPE_DICTIONARY and _has_newer_schema(parsed):
		_writes_blocked = true
		push_warning("Unsupported save/content version; original save is protected from writes.")
		return _default_data()
	if typeof(parsed) != TYPE_DICTIONARY or not _is_valid_save_data(parsed):
		push_warning("Invalid save; using recoverable backup or safe defaults.")
		return _read_recovery_data()
	var normalized := _normalize_save_data(parsed)
	if _as_int(parsed.get("save_version")) == 1:
		# _write_local_data preserves the original bytes before attempting migration.
		_write_local_data(normalized)
	return normalized


func _parse_document(content: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(content) == OK else null


func _has_newer_schema(value: Dictionary) -> bool:
	if _as_int(value.get("save_version")) > SAVE_VERSION:
		return true
	return _as_int(value.get("save_version")) == SAVE_VERSION and (
		_as_int(value.get("tutorial_version")) > TUTORIAL_VERSION or
		_as_int(value.get("endless_rules_version")) > ENDLESS_RULES_VERSION)


func _read_recovery_data() -> Dictionary:
	for suffix in [".backup", ".v1.backup"]:
		if not FileAccess.file_exists(_save_path + suffix):
			continue
		var parsed: Variant = _parse_document(FileAccess.get_file_as_string(_save_path + suffix))
		if typeof(parsed) == TYPE_DICTIONARY and _is_valid_save_data(parsed):
			return _normalize_save_data(parsed)
	return _default_data()


func configure_web_profile() -> void:
	if not OS.has_feature("web") or not OS.has_feature("vk_mini_apps") or OS.has_feature("monetization_demo"):
		return
	var bridge: Variant = JavaScriptBridge.get_interface("ClownSmashPlatform")
	if bridge == null:
		return
	bridge.configureVkPayments(str(ProjectSettings.get_setting("monetization/vk/payments_base_url", "")))
	var profile := str(bridge.getSaveProfile())
	if not profile.is_empty() and profile.is_valid_filename():
		_save_path = "user://clown_smash_%s.json" % profile


func initialize_cloud() -> void:
	if not OS.has_feature("web") or OS.has_feature("monetization_demo") or _cloud_initialization_pending or _cloud_ready or _cloud_initialization_attempts >= MAX_CLOUD_ATTEMPTS:
		return
	_cloud_initialization_attempts += 1
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
		push_warning("Platform cloud initialization timed out; local progress remains available.")


func _on_cloud_loaded(arguments: Array) -> void:
	_cloud_initialization_pending = false
	var response := _decode_callback_dictionary(arguments)
	if not bool(response.get("success", false)):
		cloud_initialization_completed.emit()
		return

	_cloud_ready = true
	var local_data := load_data()
	var cloud_value: Variant = response.get("data")
	if typeof(cloud_value) == TYPE_DICTIONARY and (_has_newer_schema(cloud_value) or not _is_valid_save_data(cloud_value)):
		_cloud_ready = false
		cloud_sync_failed.emit()
		push_warning("Unsupported cloud save; local progress remains available and cloud is not overwritten.")
		cloud_initialization_completed.emit()
		return
	var merged := local_data
	if typeof(cloud_value) == TYPE_DICTIONARY and _is_valid_save_data(cloud_value):
		merged = _merge_save_data(local_data, _normalize_save_data(cloud_value))
	if _write_local_data(merged) == OK:
		_push_cloud_data(merged)
	cloud_initialization_completed.emit()


func save_data(value: Dictionary) -> Error:
	var error := _write_local_data(value)
	if error == OK:
		_cloud_save_attempts = 0
		_push_cloud_data(_normalize_save_data(value))
	return error


func _write_local_data(value: Dictionary) -> Error:
	_last_save_error = OK
	if _writes_blocked or _has_newer_schema(value) or not _is_valid_save_data(value):
		return _save_error(ERR_INVALID_DATA)
	var old_bytes := PackedByteArray()
	if FileAccess.file_exists(_save_path):
		old_bytes = FileAccess.get_file_as_bytes(_save_path)
		var previous: Variant = _parse_document(old_bytes.get_string_from_utf8())
		if typeof(previous) == TYPE_DICTIONARY and _has_newer_schema(previous):
			_writes_blocked = true
			return _save_error(ERR_INVALID_DATA)
		if typeof(previous) == TYPE_DICTIONARY and _is_valid_save_data(previous):
			if _as_int(previous.get("save_version")) == 1 and not FileAccess.file_exists(_save_path + ".v1.backup"):
				var migration_error := _copy_original(".v1.backup", old_bytes)
				if migration_error != OK:
					return _save_error(migration_error)
			var backup_error := _copy_original(".backup", old_bytes)
			if backup_error != OK:
				return _save_error(backup_error)
		elif not FileAccess.file_exists(_save_path + ".corrupt.backup"):
			var corrupt_error := _copy_original(".corrupt.backup", old_bytes)
			if corrupt_error != OK:
				return _save_error(corrupt_error)
	var normalized := _normalize_save_data(value)
	# Legacy campaign stays nested; no campaign runtime fields are persisted.
	for field in DEFAULT_LEGACY:
		normalized.erase(field)
	var encoded := JSON.stringify(normalized)
	var temporary_path := _save_path + ".tmp"
	var file: Object = _open_file_func.call(temporary_path, FileAccess.WRITE)
	if file == null:
		return _save_error(FAILED)
	file.store_string(encoded)
	var error: Error = file.get_error()
	if error == OK:
		file.flush()
		error = file.get_error()
	file.close()
	# FileAccess.close has no return code; verify the closed file bytes and schema.
	if error == OK:
		error = file.get_error()
	if error == OK and FileAccess.get_file_as_string(temporary_path) != encoded:
		error = ERR_FILE_CANT_WRITE
	if error == OK:
		error = _replace_file_func.call(temporary_path, _save_path)
	if error != OK and FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)
	return _save_error(error)


func _copy_original(suffix: String, original: PackedByteArray) -> Error:
	var target := _save_path + suffix
	var temporary := target + ".tmp"
	var copy_error := DirAccess.copy_absolute(_save_path, temporary)
	if copy_error != OK:
		return copy_error
	if FileAccess.get_file_as_bytes(temporary) != original:
		DirAccess.remove_absolute(temporary)
		return ERR_FILE_CANT_WRITE
	var replace_error := DirAccess.rename_absolute(temporary, target)
	if replace_error != OK:
		DirAccess.remove_absolute(temporary)
	return replace_error


func _save_error(error: Error) -> Error:
	_last_save_error = error
	return error


func _push_cloud_data(value: Dictionary) -> void:
	if not _cloud_ready or _cloud_bridge == null or _writes_blocked or _cloud_save_attempts >= MAX_CLOUD_ATTEMPTS:
		return
	_cloud_save_attempts += 1
	if _cloud_save_callback == null:
		_cloud_save_callback = JavaScriptBridge.create_callback(_on_cloud_saved)
	var normalized := _normalize_save_data(value)
	for field in DEFAULT_LEGACY:
		normalized.erase(field)
	_cloud_bridge.saveCloudSave(JSON.stringify(normalized), _cloud_save_callback)


func _on_cloud_saved(arguments: Array) -> void:
	var response := _decode_callback_dictionary(arguments)
	_cloud_save_retry_needed = not bool(response.get("success", false)) and _cloud_save_attempts < MAX_CLOUD_ATTEMPTS
	if not bool(response.get("success", false)):
		cloud_sync_failed.emit()
		push_warning("Platform cloud save failed; local v2 remains available. No v1 fallback is sent.")


func _decode_callback_dictionary(arguments: Array) -> Dictionary:
	if arguments.is_empty():
		return {}
	var parsed: Variant = _parse_document(str(arguments[0]))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _merge_save_data(local_value: Dictionary, cloud_value: Dictionary) -> Dictionary:
	var local := _normalize_save_data(local_value)
	var cloud := _normalize_save_data(cloud_value)
	var merged := local.duplicate(true)
	# Preserve the existing cloud-wins settings policy; entitlements stay local.
	for field in SETTINGS_FIELDS:
		merged[field] = cloud[field]
	merged["legacy_campaign"] = _merge_legacy(local["legacy_campaign"], cloud["legacy_campaign"])
	if local["tutorial_version"] == cloud["tutorial_version"]:
		for lesson in cloud["learned_lessons"]:
			if lesson not in merged["learned_lessons"]:
				merged["learned_lessons"].append(lesson)
	if local["endless_rules_version"] == cloud["endless_rules_version"]:
		for field in RECORD_FIELDS:
			merged[field] = max(local[field], cloud[field])
	return _normalize_save_data(merged)


func _merge_legacy(first: Dictionary, second: Dictionary) -> Dictionary:
	var merged := first.duplicate(true)
	merged["highest_unlocked_level"] = maxi(first["highest_unlocked_level"], second["highest_unlocked_level"])
	for level in second["completed_levels"]:
		if level not in merged["completed_levels"]:
			merged["completed_levels"].append(level)
	merged["completed_levels"].sort()
	for field in ["best_scores", "best_combos"]:
		for key in second[field]:
			merged[field][key] = maxi(merged[field].get(key, 0), second[field][key])
	return merged


func learn_lesson(id: String) -> bool:
	if id not in LESSON_IDS:
		return false
	var current := load_data()
	if current["tutorial_version"] != TUTORIAL_VERSION or _writes_blocked:
		return false
	if id in current["learned_lessons"]:
		return true
	current["learned_lessons"].append(id)
	_session_lessons.append(id)
	return save_data(current) == OK


func tutorials_complete() -> bool:
	var current := load_data()
	return current["tutorial_version"] == TUTORIAL_VERSION and current["learned_lessons"].size() == LESSON_IDS.size()


func record_run(score: Variant, combo: Variant, rounds: Variant, active_seconds: Variant) -> bool:
	if not _is_integer_numeric(score) or not _is_integer_numeric(combo) or not _is_integer_numeric(rounds) or not _is_nonnegative_number(active_seconds):
		return false
	var current := load_data()
	if current["endless_rules_version"] != ENDLESS_RULES_VERSION or _writes_blocked:
		return false
	var values := [int(score), int(combo), int(rounds), float(active_seconds)]
	var changed := false
	for index in RECORD_FIELDS.size():
		var field: String = RECORD_FIELDS[index]
		if values[index] > current[field]:
			current[field] = values[index]
			changed = true
	return not changed or save_data(current) == OK


func get_last_save_error() -> Error:
	return _last_save_error


func update_settings(music_enabled: bool, sound_enabled: bool, haptics_enabled: bool) -> Error:
	var current := load_data()
	current["music_enabled"] = music_enabled
	current["sound_enabled"] = sound_enabled
	current["haptics_enabled"] = haptics_enabled
	return save_data(current)


func set_ads_removed(value: bool) -> Error:
	var current := load_data()
	current["ads_removed"] = value
	return save_data(current)


func _default_data() -> Dictionary:
	return _normalize_save_data(DEFAULT_DATA)


func _is_valid_save_data(value: Dictionary) -> bool:
	if not _is_supported_version(value.get("save_version")):
		return false
	for field in SETTINGS_FIELDS:
		if typeof(value.get(field)) != TYPE_BOOL:
			return false
	if value.has("ads_removed") and typeof(value["ads_removed"]) != TYPE_BOOL:
		return false
	if _as_int(value["save_version"]) == 1:
		return _is_valid_legacy(value)
	return _as_int(value.get("tutorial_version")) >= 1 and _as_int(value.get("endless_rules_version")) >= 1


func _is_valid_legacy(value: Dictionary) -> bool:
	var highest := _as_int(value.get("highest_unlocked_level"))
	if highest < 1 or highest > 9 or typeof(value.get("completed_levels")) != TYPE_ARRAY:
		return false
	var seen: Array[int] = []
	for raw in value["completed_levels"]:
		var level := _as_int(raw)
		if level < 1 or level > 9 or level in seen or highest < mini(9, level + 1):
			return false
		seen.append(level)
	for field in ["best_scores", "best_combos"]:
		if typeof(value.get(field)) != TYPE_DICTIONARY:
			return false
		for key in value[field]:
			if not _is_level_key_valid(str(key)) or not _is_integer_numeric(value[field][key]):
				return false
	return true


func _is_supported_version(value: Variant) -> bool:
	return _as_int(value) in [1, SAVE_VERSION]


func _as_int(value: Variant) -> int:
	return int(value) if _is_integer_numeric(value) else -1


func _is_integer_numeric(value: Variant) -> bool:
	return _is_nonnegative_number(value) and float(value) == floorf(float(value))


func _is_nonnegative_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number <= MAX_SAFE_INTEGER


func _normalize_save_data(value: Dictionary) -> Dictionary:
	var normalized := DEFAULT_DATA.duplicate(true)
	for field in SETTINGS_FIELDS:
		if typeof(value.get(field)) == TYPE_BOOL:
			normalized[field] = value[field]
	normalized["ads_removed"] = value.get("ads_removed", false) == true
	var legacy_value: Variant = value if _as_int(value.get("save_version")) == 1 else value.get("legacy_campaign", DEFAULT_LEGACY)
	if typeof(legacy_value) == TYPE_DICTIONARY and _is_valid_legacy(legacy_value):
		var legacy := DEFAULT_LEGACY.duplicate(true)
		legacy["highest_unlocked_level"] = _as_int(legacy_value["highest_unlocked_level"])
		for level in legacy_value["completed_levels"]:
			legacy["completed_levels"].append(int(level))
		legacy["completed_levels"].sort()
		for field in ["best_scores", "best_combos"]:
			for key in legacy_value[field]:
				legacy[field][str(key)] = int(legacy_value[field][key])
		normalized["legacy_campaign"] = legacy
	if _as_int(value.get("save_version")) == SAVE_VERSION:
		for field in ["tutorial_version", "endless_rules_version"]:
			if _as_int(value.get(field)) >= 1:
				normalized[field] = _as_int(value[field])
		if typeof(value.get("learned_lessons")) == TYPE_ARRAY:
			for id in LESSON_IDS:
				if id in value["learned_lessons"]:
					normalized["learned_lessons"].append(id)
		for field in RECORD_FIELDS:
			var numeric: Variant = value.get(field)
			if field == "best_run_active_seconds" and _is_nonnegative_number(numeric):
				normalized[field] = float(numeric)
			elif field != "best_run_active_seconds" and _is_integer_numeric(numeric):
				normalized[field] = int(numeric)
	return normalized


func _is_level_key_valid(level_key: String) -> bool:
	return level_key.length() == 1 and level_key.is_valid_int() and level_key.to_int() >= 1 and level_key.to_int() <= 9
