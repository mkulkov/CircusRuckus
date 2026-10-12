extends SceneTree

const Manager = preload("res://scripts/save/save_manager.gd")
var failures := 0
var checks := 0
var manager: Node
var path: String

class FailedFile extends RefCounted:
	var stage: String
	var error: Error = OK
	var closed := false
	func _init(failure_stage: String) -> void:
		stage = failure_stage
	func store_string(_text: String) -> void:
		if stage == "store": error = ERR_FILE_CANT_WRITE
	func flush() -> void:
		if stage == "flush": error = ERR_FILE_CANT_WRITE
	func close() -> void:
		closed = true
		if stage == "close": error = ERR_FILE_CANT_WRITE
	func get_error() -> Error:
		return error


func _init() -> void:
	path = ProjectSettings.globalize_path("res://builds/debug/verification/save-v2-%s.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	ProjectSettings.set_setting("clown_smash/testing/save_path", path)
	call_deferred("run")


func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func write(value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func v1() -> Dictionary:
	return {"save_version": 1, "highest_unlocked_level": 3, "completed_levels": [1, 2],
		"best_scores": {"1": 120}, "best_combos": {"1": 7},
		"music_enabled": false, "sound_enabled": true, "haptics_enabled": false, "ads_removed": true}


func run() -> void:
	manager = Manager.new()
	root.add_child(manager)
	manager.delete_save_for_tests()
	expect(manager._save_path == path, "debug path hook runs before Boot can load")
	expect(manager.data.save_version == 2 and manager.data.best_run_score == 0, "clean profile is v2")
	var original := JSON.stringify(v1(), "  ") + "\n"
	write(original)
	var migrated: Dictionary = manager.load_data()
	expect(migrated.save_version == 2 and migrated.legacy_campaign.best_scores["1"] == 120, "v1 history migration")
	expect(migrated.learned_lessons.is_empty() and migrated.best_run_score == 0, "campaign never implies mastery or records")
	expect(not migrated.music_enabled and migrated.ads_removed, "migration preserves settings and local purchase")
	expect(FileAccess.get_file_as_string(path + ".v1.backup") == original, "migration backup contains original bytes")
	var bytes := FileAccess.get_file_as_bytes(path)
	expect(manager.load_data() == migrated and FileAccess.get_file_as_bytes(path) == bytes, "migration is idempotent")
	expect(manager.learn_lesson("normal") and manager.learn_lesson("normal"), "mastery saves idempotently")
	expect(manager.data.learned_lessons == ["normal"] and not manager.learn_lesson("fake"), "only known unique lessons")
	for id in Manager.LESSON_IDS: manager.learn_lesson(id)
	expect(manager.tutorials_complete(), "all ten lessons complete")
	expect(manager.record_run(100, 5, 2, 90.5), "first run records")
	expect(manager.record_run(80, 10, 1, 120.0), "independent records")
	var current: Dictionary = manager.data
	expect(current.best_run_score == 100 and current.best_run_combo == 10 and current.best_run_rounds == 2 and current.best_run_active_seconds == 120.0, "records are independent maxima")
	bytes = FileAccess.get_file_as_bytes(path)
	expect(manager.record_run(100, 10, 2, 120.0) and FileAccess.get_file_as_bytes(path) == bytes, "ties need no write")
	expect(not manager.record_run(INF, 1, 1, 1.0) and not manager.record_run(1, 1, 1, NAN) and not manager.record_run(9007199254740992, 1, 1, 1), "unsafe numbers rejected before casts")
	for stage in ["store", "flush", "close"]:
		var fake := FailedFile.new(stage)
		manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object: return fake)
		expect(not manager.record_run(999, 20, 3, 140), "%s failure returned" % stage)
		expect(fake.closed and FileAccess.get_file_as_bytes(path) == bytes, "%s failure preserves old bytes and closes file" % stage)
	manager.set_open_file_for_tests(Callable(FileAccess, "open"))
	manager.set_replace_file_for_tests(func(_source: String, _target: String) -> Error: return ERR_FILE_CANT_WRITE)
	expect(not manager.record_run(999, 20, 3, 140) and FileAccess.get_file_as_bytes(path) == bytes, "replace failure preserves old bytes")
	manager.set_replace_file_for_tests(Callable(DirAccess, "rename_absolute"))
	expect(FileAccess.get_file_as_string(path + ".v1.backup") == original, "migration backup never overwritten")
	var malformed := current.duplicate(true)
	malformed.best_run_score = INF
	malformed.best_run_combo = -3
	malformed.best_run_rounds = 1.5
	malformed.best_run_active_seconds = NAN
	malformed.learned_lessons = ["normal", "normal", "foreign", {"bad": true}]
	malformed.foreign = {"injected": true}
	var normalized: Dictionary = manager._normalize_save_data(malformed)
	expect(normalized.best_run_score == 0 and normalized.best_run_combo == 0 and normalized.best_run_rounds == 0 and normalized.best_run_active_seconds == 0, "invalid record fields normalized independently")
	expect(normalized.learned_lessons == ["normal"] and not normalized.has("foreign") and not normalized.music_enabled and normalized.legacy_campaign.best_scores["1"] == 120, "normalization drops arbitrary keys but keeps settings/history")
	var cloud: Dictionary = manager._default_data()
	cloud.learned_lessons = ["bomb"]
	cloud.best_run_score = 500
	cloud.ads_removed = true
	var local: Dictionary = manager._default_data()
	local.learned_lessons = ["normal"]
	local.best_run_combo = 12
	var merged: Dictionary = manager._merge_save_data(local, cloud)
	expect(merged.learned_lessons == ["normal", "bomb"] and merged.best_run_score == 500 and merged.best_run_combo == 12, "cloud union and per-record max")
	expect(not merged.ads_removed, "arbitrary cloud cannot grant purchase rights")
	expect(manager._merge_save_data(current, v1()).best_run_score == 100, "late v1 cloud cannot erase v2")
	cloud.tutorial_version = 2
	cloud.endless_rules_version = 2
	merged = manager._merge_save_data(local, cloud)
	expect(merged.learned_lessons == ["normal"] and merged.best_run_score == 0, "different versions never mix mastery/records")
	var future_content := current.duplicate(true)
	future_content.tutorial_version = 2
	write(JSON.stringify(future_content))
	bytes = FileAccess.get_file_as_bytes(path)
	manager.load_data()
	expect(manager.update_settings(true, false, true) != OK and FileAccess.get_file_as_bytes(path) == bytes, "unknown tutorial content remains protected")
	manager.set_save_path_for_tests(path)
	future_content.endless_rules_version = 2
	expect(manager.save_data(future_content) != OK, "future content cannot be submitted as current schema")
	write('{"save_version":99,"future":"keep me"}')
	bytes = FileAccess.get_file_as_bytes(path)
	manager.load_data()
	expect(manager.update_settings(true, false, true) != OK and FileAccess.get_file_as_bytes(path) == bytes, "unknown newer schema is read-only")
	manager.delete_save_for_tests()
	expect(manager.save_data(current) == OK, "valid profile persisted after reset")
	manager.update_settings(true, true, true)
	write('{corrupt')
	var recovered: Dictionary = manager.load_data()
	expect(recovered.best_run_score == 100 and recovered.legacy_campaign.best_scores["1"] == 120, "invalid document uses valid rolling backup")
	expect(manager.save_data(recovered) == OK and FileAccess.get_file_as_string(path + ".corrupt.backup") == '{corrupt', "corrupt original retained before repair")
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(not persisted.has("best_scores") and persisted.has("legacy_campaign"), "campaign fields only stored inside legacy")
	manager.delete_save_for_tests()
	manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object: return null)
	for id in Manager.LESSON_IDS:
		expect(not manager.learn_lesson(id), "failed mastery write reported")
	expect(manager.tutorials_complete(), "mastery survives unavailable disk in same SaveManager process")
	manager.delete_save_for_tests()
	expect(not manager.tutorials_complete(), "isolated profile reset clears session mastery")
	manager.free()
	ProjectSettings.set_setting("clown_smash/testing/save_path", "")
	print("SAVE V2: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
