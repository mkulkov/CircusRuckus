extends SceneTree

var _failures: int = 0


class TestSaveFileAccess:
	var _get_error: Error = OK
	var _fail_on: StringName = &""
	var _closed: bool = false

	func _init(fail_on: StringName = &"") -> void:
		_fail_on = fail_on

	func store_string(_value: String) -> void:
		if _fail_on == &"store":
			_get_error = ERR_FILE_CANT_WRITE

	func flush() -> void:
		if _fail_on == &"flush":
			_get_error = ERR_FILE_CANT_WRITE

	func close() -> void:
		_closed = true

	func get_error() -> Error:
		return _get_error


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_project_configuration()
	_test_localization()
	await _test_audio_manager()
	_test_scoring_and_combo()
	_test_all_character_rules()
	_test_save_data_defaults()
	_test_save_data_record_completed_level()
	_test_save_settings_round_trip()
	await _test_monetization_demo_contract()
	_test_yandex_platform_contract()
	_test_save_data_invalid_fallback()
	_test_save_data_semantic_validation()
	_test_save_data_write_failure_and_rollback()
	_test_save_data_write_failure_with_open_file()
	_test_level_one_config()
	_test_all_level_configs_and_assets()
	await _test_session_rules()
	await _test_main_scene_loads()
	await _test_menu_and_navigation_flow()
	await _test_scene_router_flow()
	await _test_spawn_director_deterministic_seed()
	_test_spawn_rate_accelerates_over_round()
	await _test_core_interaction_scene()
	await _test_gameplay_completion_save_integration()
	await _test_special_character_scene_interactions()

	if _failures == 0:
		print("TEST RESULT: PASS")
		quit(0)
		return

	push_error("TEST RESULT: FAIL (%d failure(s))" % _failures)
	quit(1)


func _test_monetization_demo_contract() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	var save_manager := save_manager_script.new() as Node
	var test_path := "user://clown_smash_monetization_demo_test.json"
	save_manager.set_save_path_for_tests(test_path)
	save_manager.delete_save_for_tests()

	var adapter := DebugMonetizationAdapter.new()
	adapter.virtual_purchase_success = true
	var service := MonetizationService.new()
	service.configure(save_manager)
	service._adapter = adapter
	adapter.purchase_finished.connect(service._on_purchase_finished)
	service.purchase_remove_ads()
	await process_frame
	_expect_true(service.is_ads_removed(), "Demo purchase grants the durable ads_removed entitlement")
	_expect_true(bool(save_manager.load_data()["ads_removed"]), "Demo purchase persists ads_removed to disk")

	var restarted_service := MonetizationService.new()
	restarted_service.configure(save_manager)
	_expect_true(restarted_service.is_ads_removed(), "Restart restores ads_removed from the saved entitlement")
	var level_opened := [false]
	restarted_service.show_level_start_ad(2, func() -> void: level_opened[0] = true)
	_expect_true(bool(level_opened[0]), "Restored ads_removed bypasses the level-start ad")
	var first_level_opened := [false]
	restarted_service.ads_removed = false
	restarted_service.show_level_start_ad(1, func() -> void: first_level_opened[0] = true)
	_expect_true(bool(first_level_opened[0]), "Level 1 never requests an in-game interstitial")
	_expect_true(not restarted_service._pending_interstitial.is_valid(), "Level 1 leaves no pending interstitial request")

	var presenter := MonetizationDemoPresenter.new()
	root.add_child(presenter)
	await process_frame
	var banner := presenter.get_node("DemoBanner") as Control
	_expect_true(banner != null and banner.anchor_bottom == 1.0, "Demo banner uses the bottom advertising slot")
	presenter.set_banner_visible(false)
	_expect_true(not banner.visible, "Demo banner hides after ads are removed")
	_expect_true(load("res://assets/video/demo_ad_4s.ogv") != null, "Four-second demo advertising video loads")
	presenter.queue_free()
	save_manager.delete_save_for_tests()


func _test_yandex_platform_contract() -> void:
	var shell := FileAccess.get_file_as_string("res://web/portrait_shell.html")
	_expect_equal(shell.count("YaGames.init()"), 1, "Yandex SDK initializes through one shared promise")
	_expect_true(shell.contains("GameplayAPI?.start()"), "Yandex Gameplay API start is integrated")
	_expect_true(shell.contains("GameplayAPI?.stop()"), "Yandex Gameplay API stop is integrated")
	_expect_true(shell.contains("game_api_pause"), "Yandex platform pause event is subscribed")
	_expect_true(shell.contains("game_api_resume"), "Yandex platform resume event is subscribed")
	_expect_true(shell.contains("ysdk.getPlayer()"), "Yandex Player is initialized for guest and authorized cloud saves")
	_expect_true(shell.contains("player.getData(['clown_smash_save'])"), "Yandex cloud progress is loaded")
	_expect_true(shell.contains("player.setData({ clown_smash_save: data }, true)"), "Yandex cloud progress is flushed immediately")
	_expect_true(shell.contains("getBannerAdvStatus()"), "Sticky banner status is checked before requesting display")
	_expect_true(shell.contains("showBannerAdv()"), "Sticky banner display is requested through the SDK")

	var web_adapter := WebMonetizationAdapter.new()
	var callback_data: Dictionary = web_adapter._decode_callback_dictionary(['{"platform":"yandex","visible":true}'])
	_expect_equal(callback_data.get("platform"), "yandex", "JavaScriptBridge callback arrays decode platform data")
	_expect_true(bool(callback_data.get("visible", false)), "JavaScriptBridge callback arrays decode banner status")

	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	var manager := save_manager_script.new() as Node
	var local_data: Dictionary = manager.DEFAULT_DATA.duplicate(true)
	local_data["highest_unlocked_level"] = 3
	local_data["completed_levels"] = [1, 2]
	local_data["best_scores"] = {"1": 300, "2": 200}
	var cloud_data: Dictionary = manager.DEFAULT_DATA.duplicate(true)
	cloud_data["highest_unlocked_level"] = 2
	cloud_data["completed_levels"] = [1]
	cloud_data["best_scores"] = {"1": 250}
	cloud_data["music_enabled"] = false
	var merged: Dictionary = manager._merge_save_data(local_data, cloud_data)
	_expect_equal(merged["highest_unlocked_level"], 3, "Cloud merge preserves the highest unlocked level")
	_expect_equal(merged["completed_levels"], [1, 2], "Cloud merge preserves completed levels from both stores")
	_expect_equal(merged["best_scores"]["1"], 300, "Cloud merge preserves the best score")
	_expect_true(not bool(merged["music_enabled"]), "Cloud settings win when a valid cloud save exists")


func _test_project_configuration() -> void:
	_expect_equal(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		1080,
		"Base viewport width is 1080"
	)
	_expect_equal(
		ProjectSettings.get_setting("display/window/size/viewport_height"),
		1920,
		"Base viewport height is 1920"
	)
	_expect_equal(
		ProjectSettings.get_setting("display/window/stretch/mode"),
		"canvas_items",
		"Stretch mode is canvas_items"
	)
	_expect_equal(
		ProjectSettings.get_setting("display/window/stretch/aspect"),
		"expand",
		"Stretch aspect is expand"
	)
	_expect_equal(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"gl_compatibility",
		"Compatibility renderer is selected"
	)
	_expect_equal(
		ProjectSettings.get_setting("application/boot_splash/image"),
		"res://assets/generated/boot_splash_clown_chase.png",
		"Branded clown-chase boot splash is configured"
	)
	_expect_true(
		load(ProjectSettings.get_setting("application/boot_splash/image")) is Texture2D,
		"Branded clown-chase boot splash loads"
	)


func _test_localization() -> void:
	var localization_script := load("res://scripts/platform/localization_manager.gd") as GDScript
	_expect_true(localization_script != null, "LocalizationManager script loads")
	if localization_script == null:
		return
	var manager := localization_script.new() as Node
	root.add_child(manager)
	_expect_equal(manager.normalize_locale("en-US"), "en", "English platform locale selects English")
	_expect_equal(manager.normalize_locale("ru_RU"), "ru", "Russian platform locale selects Russian")
	_expect_equal(manager.normalize_locale("de-DE"), "ru", "Unsupported platform locale falls back to Russian")
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_expect_equal(TranslationServer.translate("MENU_PLAY"), "PLAY", "English menu translation is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_1"), "CIRCUS", "English game title first line is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_2"), "RUCKUS", "English game title second line is available")
	TranslationServer.set_locale("ru")
	_expect_equal(TranslationServer.translate("MENU_PLAY"), "ИГРАТЬ", "Russian menu translation is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_1"), "ЦИРКОВОЙ", "Russian game title first line is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_2"), "ПЕРЕПОЛОХ", "Russian game title second line is available")
	TranslationServer.set_locale(previous_locale)
	manager.queue_free()


func _test_audio_manager() -> void:
	var script := load("res://scripts/audio/audio_manager.gd") as Script
	_expect_true(script != null, "AudioManager script loads")
	if script == null:
		return
	var manager: Node = script.new()
	root.add_child(manager)
	await process_frame
	_expect_true(AudioServer.get_bus_index(&"Music") >= 0, "Music audio bus exists")
	_expect_true(AudioServer.get_bus_index(&"SFX") >= 0, "SFX audio bus exists")
	_expect_true(manager.get_node_or_null("MusicPlayer") != null, "Looping music player exists")
	_expect_equal(manager.get_music_track_count(), 2, "Two background music tracks are registered")
	_expect_equal(manager.get_clown_miss_sound_count(), 2, "Two clown-miss sounds are registered")
	manager.set_music_random_seed_for_tests(20260912)
	manager.play_music_for_level(1)
	var first_music_track: String = manager.get_current_music_track_path()
	_expect_true(first_music_track.ends_with(".ogg"), "Level music uses an imported OGG track")
	manager.play_music_for_level(2)
	_expect_true(first_music_track != manager.get_current_music_track_path(), "Consecutive levels do not repeat the same music track")
	var events: Array[StringName] = [
		&"box_pop", &"hammer_bonk", &"correct_hit", &"empty_hit", &"bomb", &"life_lost",
		&"clock", &"apple_restore", &"glutton_escape", &"clown_miss", &"drunk", &"combo", &"countdown",
		&"victory", &"defeat", &"ui_button"
	]
	for event_name in events:
		manager.play_event(event_name)
		_expect_equal(manager.get_event_count(event_name), 1, "Audio hook exists: %s" % event_name)
	_expect_true(manager.get_bomb_sound_path().ends_with("bomb_normalized.ogg"), "Bomb event uses the normalized bomb sound")
	_expect_true(manager.get_current_clown_miss_sound_path().ends_with(".ogg"), "Clown miss selects an imported OGG sound")
	manager.apply_settings({"music_enabled": false, "sound_enabled": false, "haptics_enabled": false})
	_expect_true(not manager.music_enabled and not manager.sound_enabled and not manager.haptics_enabled, "Audio and haptics settings disable all categories")
	manager.apply_settings({"music_enabled": true, "sound_enabled": true, "haptics_enabled": true})
	_expect_true(manager.music_enabled and manager.sound_enabled and manager.haptics_enabled, "Audio and haptics settings re-enable all categories")
	manager.queue_free()
	await process_frame


func _test_main_scene_loads() -> void:
	var main_scene_path: String = ProjectSettings.get_setting(
		"application/run/main_scene",
		""
	)
	_expect_true(not main_scene_path.is_empty(), "Main scene is configured")
	if main_scene_path.is_empty():
		return

	var packed_scene := load(main_scene_path) as PackedScene
	_expect_true(packed_scene != null, "Main scene resource loads")
	if packed_scene == null:
		return

	var scene_instance := packed_scene.instantiate()
	root.add_child(scene_instance)
	await process_frame
	_expect_true(is_instance_valid(scene_instance), "Main scene instance runs for a frame")
	scene_instance.queue_free()
	await process_frame


func _test_menu_and_navigation_flow() -> void:
	var menu_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var level_select_scene := load("res://scenes/ui/LevelSelect.tscn") as PackedScene
	_expect_true(menu_scene != null, "Main Menu scene exists")
	_expect_true(level_select_scene != null, "Level Select scene exists")
	if menu_scene == null or level_select_scene == null:
		return
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	_expect_true(menu.has_method("configure"), "Main Menu accepts persisted progress")
	_expect_true(menu.get_node_or_null("PlayButton") != null, "Main Menu exposes Play action")
	_expect_true(menu.get_node_or_null("LevelsButton") != null, "Main Menu exposes Levels action")
	_expect_true(menu.get_node_or_null("SettingsButton") != null, "Main Menu exposes Settings action")
	_expect_true(menu.get_node_or_null("AboutButton") != null, "Main Menu exposes About action")
	var remove_ads := menu.get_node_or_null("RemoveAdsButton") as Button
	_expect_true(menu.get_node_or_null("MenuPanel") == null, "Main Menu has no enclosing action frame")
	_expect_true(remove_ads != null and not remove_ads.visible, "Main Menu hides Remove Ads without a purchase service")
	if remove_ads != null:
		var about_button := menu.get_node_or_null("AboutButton") as Button
		remove_ads.visible = true
		menu._layout()
		_expect_true(
			about_button != null and about_button.get_global_rect().end.y < remove_ads.get_global_rect().position.y,
			"Main Menu separates About and Remove Ads actions"
		)
	menu.queue_free()
	await process_frame
	var levels := level_select_scene.instantiate()
	levels.configure({"highest_unlocked_level": 2, "completed_levels": [1], "best_scores": {"1": 250}})
	root.add_child(levels)
	await process_frame
	_expect_equal(levels.get_level_button_count(), 9, "Level Select exposes exactly nine levels")
	_expect_true(levels.is_level_enabled(2), "Highest unlocked level is selectable")
	_expect_true(not levels.is_level_enabled(3), "Locked level is not selectable")
	_expect_true(levels.is_level_completed(1), "Completed level state is visible")
	levels.queue_free()
	await process_frame


func _test_scene_router_flow() -> void:
	var boot := (load("res://scenes/boot/Boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	var test_path := "user://clown_smash_router_test.json"
	boot.save_manager.set_save_path_for_tests(test_path)
	boot.save_manager.delete_save_for_tests()
	_expect_equal(boot._current_screen.name, "StartupSplash", "SceneRouter starts at StartupSplash")
	boot.skip_startup_splash()
	await create_timer(0.30).timeout
	_expect_equal(boot._current_screen.name, "MainMenu", "SceneRouter starts at Main Menu")
	boot.show_level_select()
	await process_frame
	_expect_equal(boot._current_screen.name, "LevelSelect", "SceneRouter opens Level Select")
	boot.start_level(2)
	await process_frame
	_expect_equal(boot._current_screen.name, "LevelSelect", "SceneRouter rejects locked levels")
	boot.save_manager.record_completed_level(1, 300, 5)
	boot.start_level(2)
	await process_frame
	_expect_equal(boot._current_screen.name, "Gameplay", "SceneRouter starts an unlocked level")
	_expect_equal(boot._current_screen.level_number, 2, "SceneRouter configures requested level")
	boot._current_screen.game_controller.begin_running()
	boot._current_screen.game_controller.pause_level()
	boot.show_main_menu()
	await process_frame
	_expect_true(not paused, "Returning to menu clears SceneTree pause")
	_expect_equal(boot._current_screen.name, "MainMenu", "SceneRouter returns to Main Menu")
	boot.save_manager.delete_save_for_tests()
	boot.queue_free()
	await process_frame


func _test_scoring_and_combo() -> void:
	var game_controller_script := load("res://scripts/gameplay/game_controller.gd") as GDScript
	var game_controller := game_controller_script.new() as Node
	root.add_child(game_controller)
	game_controller.start_level(90.0, 250, false)

	game_controller.resolve_scoring_hit()
	_expect_equal(game_controller.score, 10, "Normal hit adds exactly 10 score")
	_expect_equal(game_controller.combo_count, 1, "Normal hit increases combo")
	game_controller.resolve_scoring_hit()
	_expect_equal(game_controller.score, 20, "Second Normal hit adds exactly 10 score")
	_expect_equal(game_controller.combo_count, 2, "Second Normal hit increases combo")
	game_controller.resolve_empty_hit()
	_expect_equal(game_controller.score, 20, "Empty hit preserves score")
	_expect_equal(game_controller.combo_count, 0, "Empty hit resets combo")
	_expect_equal(game_controller.lives, 2, "Empty hit removes one life")
	game_controller.resolve_scoring_hit()
	game_controller.resolve_scoring_miss()
	_expect_equal(game_controller.combo_count, 0, "Missed Normal resets combo")
	game_controller.queue_free()


func _test_level_one_config() -> void:
	var level_config := load("res://data/levels/level_01.tres") as LevelConfig
	_expect_true(level_config != null, "Level 1 config loads")
	if level_config == null:
		return
	_expect_equal(level_config.level_id, 1, "Level 1 config has ID 1")
	_expect_equal(level_config.duration, 60.0, "Level 1 duration is 60 seconds")
	_expect_equal(level_config.target_score, 150, "Level 1 target score is 150")
	_expect_equal(level_config.spawn_interval_min, 0.25, "Level 1 minimum spawn interval is 0.25 seconds")
	_expect_equal(level_config.spawn_interval_max, 0.31, "Level 1 maximum spawn interval is 0.31 seconds")
	_expect_equal(level_config.max_active_characters, 1, "Level 1 allows one active character")


func _test_all_level_configs_and_assets() -> void:
	var seen_level_ids: Dictionary = {}
	for level_id in range(1, 10):
		var config := load("res://data/levels/level_%02d.tres" % level_id) as LevelConfig
		_expect_true(config != null, "Level %d config loads" % level_id)
		if config == null:
			continue
		_expect_equal(config.level_id, level_id, "Level %d has the correct ID" % level_id)
		_expect_true(not seen_level_ids.has(config.level_id), "Level %d ID is unique" % level_id)
		seen_level_ids[config.level_id] = true
		_expect_true(config.duration > 0.0, "Level %d duration is positive" % level_id)
		_expect_equal(config.duration, 60.0, "Level %d keeps the 60-second duration" % level_id)
		_expect_true(config.max_active_characters >= 1 and config.max_active_characters <= 2, "Level %d has valid max active" % level_id)
		var weights := [config.normal_weight, config.fast_weight, config.golden_weight, config.bomb_weight, config.clock_weight, config.glutton_weight, config.drunk_weight]
		var total_weight := 0.0
		for weight in weights:
			_expect_true(weight >= 0.0, "Level %d has no negative character weight" % level_id)
			total_weight += weight
		_expect_true(total_weight > 0.0, "Level %d has a spawnable character mix" % level_id)
		_expect_true(config.normal_weight > 0.0, "Level %d keeps Normal enabled" % level_id)
	_expect_equal(seen_level_ids.size(), 9, "Exactly nine unique LevelConfig resources exist")

	for asset_name in ["normal", "fast", "golden", "bomb", "clock", "glutton", "drunk"]:
		var texture := load("res://assets/generated/%s_clown.png" % asset_name) as Texture2D
		_expect_true(texture != null, "%s clown asset loads" % asset_name.capitalize())
	_expect_true(load("res://assets/generated/closed_box.png") is Texture2D, "Closed-box asset loads")
	_expect_true(load("res://assets/generated/startup_splash.png") is Texture2D, "Russian startup splash loads")
	_expect_true(load("res://assets/generated/startup_splash_en.png") is Texture2D, "English startup splash loads")


func _test_spawn_director_deterministic_seed() -> void:
	var packed_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	_expect_true(packed_scene != null, "Gameplay scene loads for deterministic spawn test")
	if packed_scene == null:
		return
	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	gameplay.spawn_director.stop()
	gameplay.debug_set_level(9)
	gameplay.spawn_director.stop()
	var config := load("res://data/levels/level_09.tres") as LevelConfig
	var first_sequence := _capture_spawn_sequence(gameplay, config, 7331, 18)
	var second_sequence := _capture_spawn_sequence(gameplay, config, 7331, 18)
	_expect_equal(first_sequence, second_sequence, "Same SpawnDirector seed reproduces character and slot sequence")
	_expect_true(first_sequence.size() == 18, "Deterministic spawn test captures every requested spawn")
	for level_id in range(1, 10):
		var level_config := load("res://data/levels/level_%02d.tres" % level_id) as LevelConfig
		gameplay.board_controller.clear_all()
		gameplay.spawn_director.deterministic_seed = 7331 + level_id
		gameplay.spawn_director.configure(gameplay.board_controller, level_config)
		gameplay.spawn_director.prepare_level()
		_expect_equal(gameplay.spawn_director._guaranteed_queue.size(), 4, "Level %d schedules only active character types" % level_id)
		_expect_true(gameplay.spawn_director._guaranteed_deadlines.front() > 0.0, "Level %d does not force a guaranteed type at round start" % level_id)
		for spawn_index in range(4):
			_expect_true(gameplay.spawn_director._spawn_one(), "Level %d opens with a weighted spawn" % level_id)
			gameplay.board_controller.clear_all()
		_expect_equal(gameplay.spawn_director._guaranteed_queue.size(), 4, "Level %d keeps guarantees out of the opening spawns" % level_id)
		var guaranteed_sequence := _capture_spawn_sequence(gameplay, level_config, 7331 + level_id, 28, true)
		var seen_types: Dictionary = {}
		for spawned in guaranteed_sequence:
			seen_types[StringName(spawned.get_slice(":", 1))] = true
		for required_type in [&"normal", &"bomb", &"clock", &"glutton"]:
			_expect_true(seen_types.has(required_type), "Level %d guarantees %s" % [level_id, required_type])
		for disabled_type in [&"fast", &"golden", &"drunk"]:
			_expect_true(not seen_types.has(disabled_type), "Level %d does not spawn disabled %s" % [level_id, disabled_type])
	gameplay.queue_free()
	await process_frame


func _capture_spawn_sequence(gameplay: Control, config: LevelConfig, seed: int, count: int, advance_round: bool = false) -> Array[String]:
	var sequence: Array[String] = []
	gameplay.board_controller.clear_all()
	gameplay.spawn_director.deterministic_seed = seed
	gameplay.spawn_director.configure(gameplay.board_controller, config)
	gameplay.spawn_director.prepare_level()
	for spawn_index in range(count):
		if advance_round:
			var progress := float(spawn_index + 1) / float(count)
			gameplay.spawn_director.set_remaining_time(config.duration * (1.0 - progress))
		if not gameplay.spawn_director._spawn_one():
			break
		for slot_index in range(9):
			var slot: Control = gameplay.board_controller.get_slot(slot_index)
			if not slot.is_idle():
				sequence.append("%d:%s" % [slot_index, String(slot.get_character_type())])
				break
		gameplay.board_controller.clear_all()
	return sequence


func _test_spawn_rate_accelerates_over_round() -> void:
	var director_script := load("res://scripts/gameplay/spawn_director.gd") as GDScript
	var director := director_script.new() as Node
	var config := LevelConfig.new()
	config.duration = 60.0
	config.spawn_interval_min = 1.0
	config.spawn_interval_max = 1.0
	config.end_spawn_interval_multiplier = 0.65
	director.configure(null, config)
	director.set_remaining_time(60.0)
	var opening_interval: float = director._next_spawn_interval()
	director.set_remaining_time(0.0)
	var final_interval: float = director._next_spawn_interval()
	_expect_equal(opening_interval, 1.0, "Spawn interval starts at the configured value")
	_expect_equal(final_interval, 0.65, "Spawn interval reaches the configured end-round multiplier")
	_expect_true(final_interval < opening_interval, "Spawn frequency increases by the end of the round")


func _test_all_character_rules() -> void:
	var game_controller_script := load("res://scripts/gameplay/game_controller.gd") as GDScript
	var game_controller := game_controller_script.new() as Node
	root.add_child(game_controller)
	game_controller.start_level(60.0, 0, false, 2, 1, 30.0)
	var static_feedback: Array[String] = []
	game_controller.feedback_requested.connect(func(text: String) -> void: static_feedback.append(text))

	game_controller.resolve_character_hit(&"normal")
	game_controller.resolve_character_hit(&"fast")
	game_controller.resolve_character_hit(&"golden")
	_expect_equal(game_controller.score, 30, "Normal, Fast and Golden each award exactly +10")
	_expect_equal(game_controller.combo_count, 3, "All scoring characters increase combo")
	_expect_equal(game_controller.golden_hits, 1, "Golden hit advances the Golden objective")
	_expect_true(game_controller.objectives_met(), "Score, combo and Golden objectives are evaluated together")
	_expect_true("+10" not in static_feedback, "Scoring hits do not request a static +10 HUD message")

	game_controller.resolve_character_hit(&"bomb")
	_expect_equal(game_controller.lives, 2, "Bomb hit removes one life")
	_expect_equal(game_controller.combo_count, 0, "Bomb hit resets combo")

	game_controller.resolve_character_hit(&"normal")
	game_controller.resolve_character_hit(&"clock")
	game_controller.resolve_character_hit(&"clock")
	game_controller.resolve_character_hit(&"clock")
	game_controller.resolve_character_hit(&"clock")
	_expect_equal(game_controller.remaining_time, 90.0, "Clock bonuses stop at the 30-second level cap")
	_expect_equal(game_controller.combo_count, 1, "Clock preserves the current combo")

	game_controller.resolve_character_hit(&"glutton")
	_expect_equal(game_controller.lives, 3, "Glutton restores one lost life up to three")
	_expect_equal(game_controller.combo_count, 1, "Glutton hit preserves the current combo")
	game_controller.resolve_character_hit(&"glutton")
	_expect_equal(game_controller.lives, 3, "Glutton cannot create a fourth life")

	game_controller.resolve_character_hit(&"drunk")
	_expect_equal(game_controller.confused_strikes_remaining, 1, "Drunk arms exactly one redirected gameplay tap")
	var actual_slot: int = game_controller.redirect_gameplay_slot(4, 9)
	_expect_true(actual_slot >= 0 and actual_slot < 9, "Confused strike stays on the 3x3 board")
	_expect_equal(game_controller.confused_strikes_remaining, 0, "One gameplay tap consumes the Drunk effect")
	_expect_equal(game_controller.redirect_gameplay_slot(4, 9), 4, "Tap routing returns to the requested slot after confusion")

	game_controller.resolve_character_hit(&"normal")
	game_controller.resolve_character_escape(&"normal")
	_expect_equal(game_controller.combo_count, 0, "Escaped scoring character resets combo")
	var lives_before_ignored_bomb: int = game_controller.lives
	game_controller.resolve_character_escape(&"bomb")
	_expect_equal(game_controller.lives, lives_before_ignored_bomb, "Ignored Bomb has no penalty")
	game_controller.resolve_character_escape(&"glutton")
	_expect_equal(game_controller.lives, lives_before_ignored_bomb, "Escaped Glutton keeps all lives")
	game_controller.resolve_character_escape(&"clock")
	_expect_equal(game_controller.lives, lives_before_ignored_bomb, "Escaped Clock keeps all lives")
	game_controller.resolve_empty_hit(true)
	_expect_equal(game_controller.lives, lives_before_ignored_bomb, "Empty strike missing an active bonus keeps all lives")
	game_controller.queue_free()


func _test_save_data_defaults() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	_expect_true(save_manager_script != null, "SaveManager script loads")
	if save_manager_script == null:
		return

	var manager := save_manager_script.new() as Node
	root.add_child(manager)
	manager.set_save_path_for_tests("user://clown_smash_save_test.json")
	manager.delete_save_for_tests()

	var first_data: Dictionary = manager.load_data()
	_expect_equal(first_data["save_version"], 1, "Missing save defaults to schema version 1")
	_expect_equal(first_data["highest_unlocked_level"], 1, "Missing save defaults to Level 1")
	_expect_equal(first_data["completed_levels"], [], "Missing save has no completed levels")
	_expect_true(first_data["best_scores"] == {}, "Missing save has empty best_scores map")
	_expect_true(first_data["best_combos"] == {}, "Missing save has empty best_combos map")
	_expect_true(first_data["music_enabled"], "Missing save keeps music enabled")
	_expect_true(first_data["sound_enabled"], "Missing save keeps sound enabled")
	_expect_true(first_data["haptics_enabled"], "Missing save keeps haptics enabled")

	var second_data: Dictionary = manager.load_data()
	first_data["completed_levels"].append(1)
	first_data["best_scores"]["x"] = 5
	_expect_equal(second_data["completed_levels"], [], "Load data defaults remain independent (array)")
	_expect_equal(second_data["best_scores"], {}, "Load data defaults remain independent (dictionary)")
	manager.delete_save_for_tests()
	manager.queue_free()


func _test_save_data_record_completed_level() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	_expect_true(save_manager_script != null, "SaveManager script loads for completion recording checks")
	if save_manager_script == null:
		return

	var manager := save_manager_script.new() as Node
	root.add_child(manager)
	var test_save_path: String = "user://clown_smash_save_test_progress.json"
	manager.set_save_path_for_tests(test_save_path)
	manager.delete_save_for_tests()

	var level_one_data: Dictionary = manager.record_completed_level(1, 320, 6)
	_expect_equal(level_one_data["highest_unlocked_level"], 2, "Completing level 1 unlocks level 2")
	_expect_true(level_one_data["completed_levels"].has(1), "Completing a valid level tracks completion once")
	_expect_equal(level_one_data["best_scores"]["1"], 320, "Highest score is stored for level key")
	_expect_equal(level_one_data["best_combos"]["1"], 6, "Highest combo is stored for level key")

	var reloaded_data: Dictionary = manager.load_data()
	_expect_equal(reloaded_data["highest_unlocked_level"], 2, "Completion write round-trips through save/load")
	_expect_equal(reloaded_data["best_scores"]["1"], 320, "Saved best score round-trips")
	_expect_equal(reloaded_data["best_combos"]["1"], 6, "Saved best combo round-trips")

	level_one_data = manager.record_completed_level(1, 180, 4)
	_expect_equal(level_one_data["best_scores"]["1"], 320, "Lower score for same level does not replace best")
	_expect_equal(level_one_data["best_combos"]["1"], 6, "Lower combo for same level does not replace best")

	level_one_data = manager.record_completed_level(1, 450, 12)
	_expect_equal(level_one_data["best_scores"]["1"], 450, "Higher score replaces best score for same level")
	_expect_equal(level_one_data["best_combos"]["1"], 12, "Higher combo replaces best combo for same level")

	level_one_data = manager.record_completed_level(9, 50, 5)
	_expect_equal(level_one_data["highest_unlocked_level"], 9, "Completing level 9 keeps highest unlocked at cap 9")

	var unchanged_data: Dictionary = manager.record_completed_level(10, 100, 4)
	_expect_equal(unchanged_data["highest_unlocked_level"], 9, "Invalid level does not alter highest unlock")
	_expect_equal(unchanged_data["completed_levels"], level_one_data["completed_levels"], "Invalid level does not alter completed levels")

	unchanged_data = manager.record_completed_level(2, -10, 4)
	_expect_equal(unchanged_data["highest_unlocked_level"], 9, "Negative score does not alter highest unlock")

	unchanged_data = manager.record_completed_level(2, 120, -4)
	_expect_equal(unchanged_data["best_scores"], level_one_data["best_scores"], "Negative combo does not alter best scores")
	_expect_equal(unchanged_data["best_combos"], level_one_data["best_combos"], "Negative combo does not alter best combo values")

	manager.delete_save_for_tests()
	manager.queue_free()


func _test_save_settings_round_trip() -> void:
	var manager := (load("res://scripts/save/save_manager.gd") as GDScript).new() as Node
	root.add_child(manager)
	var test_path := "user://clown_smash_settings_test.json"
	manager.set_save_path_for_tests(test_path)
	manager.delete_save_for_tests()
	_expect_equal(manager.update_settings(false, true, false), OK, "Settings save succeeds")
	var loaded: Dictionary = manager.load_data()
	_expect_true(not loaded["music_enabled"], "Music setting persists")
	_expect_true(loaded["sound_enabled"], "Sound setting persists")
	_expect_true(not loaded["haptics_enabled"], "Haptics setting persists")
	manager.delete_save_for_tests()
	manager.queue_free()


func _test_save_data_invalid_fallback() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	_expect_true(save_manager_script != null, "SaveManager script loads for invalid input checks")
	if save_manager_script == null:
		return

	var manager := save_manager_script.new() as Node
	root.add_child(manager)
	var test_save_path: String = "user://clown_smash_save_test_invalid.json"
	manager.set_save_path_for_tests(test_save_path)

	manager.delete_save_for_tests()
	_write_test_save_payload(test_save_path, "{ not valid json ")
	var malformed_data: Dictionary = manager.load_data()
	_expect_equal(malformed_data["highest_unlocked_level"], 1, "Malformed JSON falls back to defaults")

	manager.delete_save_for_tests()
	_write_test_save_payload(test_save_path, '{"save_version":"one","highest_unlocked_level":"bad","completed_levels":"not_array","best_scores":[],"best_combos":[],"music_enabled":"yes","sound_enabled":1,"haptics_enabled":1}')
	var structural_data: Dictionary = manager.load_data()
	_expect_equal(structural_data["highest_unlocked_level"], 1, "Invalid save schema falls back to defaults")

	manager.delete_save_for_tests()
	manager.queue_free()


func _test_save_data_semantic_validation() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	_expect_true(save_manager_script != null, "SaveManager script loads for semantic validation checks")
	if save_manager_script == null:
		return

	var manager := save_manager_script.new() as Node
	root.add_child(manager)
	var test_save_path: String = "user://clown_smash_save_test_semantic.json"
	manager.set_save_path_for_tests(test_save_path)

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":2,"highest_unlocked_level":3,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var unsupported_version: Dictionary = manager.load_data()
	_expect_equal(unsupported_version["save_version"], 1, "Unsupported save_version falls back to default")
	_expect_equal(unsupported_version["highest_unlocked_level"], 1, "Unsupported save_version falls back to level 1")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":11,"completed_levels":[],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var invalid_level: Dictionary = manager.load_data()
	_expect_equal(invalid_level["highest_unlocked_level"], 1, "Highest unlocked outside 1..9 falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[1,1],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var duplicate_levels: Dictionary = manager.load_data()
	_expect_equal(duplicate_levels["highest_unlocked_level"], 1, "Duplicate completed_levels fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[10],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var out_of_range_level_list: Dictionary = manager.load_data()
	_expect_equal(out_of_range_level_list["highest_unlocked_level"], 1, "Completed_levels outside 1..9 falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1.5,"highest_unlocked_level":3,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_version: Dictionary = manager.load_data()
	_expect_equal(fractional_version["highest_unlocked_level"], 1, "Fractional save_version falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[9],"best_scores":{"1":-5},"best_combos":{"1":4},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var negative_score: Dictionary = manager.load_data()
	_expect_equal(negative_score["highest_unlocked_level"], 1, "Negative best_scores entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[9],"best_scores":{"1":1.5},"best_combos":{"1":4},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_best_score: Dictionary = manager.load_data()
	_expect_equal(fractional_best_score["highest_unlocked_level"], 1, "Fractional best_scores entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[9],"best_scores":{"1":5},"best_combos":{"1":-1},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var negative_combo: Dictionary = manager.load_data()
	_expect_equal(negative_combo["highest_unlocked_level"], 1, "Negative best_combos entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":2.2},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_best_combo: Dictionary = manager.load_data()
	_expect_equal(fractional_best_combo["highest_unlocked_level"], 1, "Fractional best_combos entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3.2,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":2},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_unlock: Dictionary = manager.load_data()
	_expect_equal(fractional_unlock["highest_unlocked_level"], 1, "Fractional highest_unlocked_level falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":6,"completed_levels":[1,3,5],"best_scores":{"1":250,"3":90},"best_combos":{"1":4,"5":7},"music_enabled":false,"sound_enabled":false,"haptics_enabled":false}'
	)
	var valid_data: Dictionary = manager.load_data()
	_expect_equal(valid_data["save_version"], 1, "Semantically valid save_version is preserved")
	_expect_equal(valid_data["highest_unlocked_level"], 6, "Semantically valid unlock level is preserved")
	_expect_equal(valid_data["completed_levels"], [1, 3, 5], "Semantically valid completed levels are preserved")
	_expect_equal(valid_data["best_scores"], {"1": 250, "3": 90}, "Semantically valid best scores are preserved")
	_expect_equal(valid_data["best_combos"], {"1": 4, "5": 7}, "Semantically valid best combos are preserved")
	_expect_true(not valid_data["music_enabled"], "Semantically valid audio flags are preserved")
	_expect_true(not valid_data["sound_enabled"], "Semantically valid sound flags are preserved")
	_expect_true(not valid_data["haptics_enabled"], "Semantically valid haptics flags are preserved")

	manager.delete_save_for_tests()
	manager.queue_free()


func _test_save_data_write_failure_and_rollback() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	_expect_true(save_manager_script != null, "SaveManager script loads for write failure checks")
	if save_manager_script == null:
		return

	var manager := save_manager_script.new() as Node
	root.add_child(manager)
	var read_only_save_path: String = "user://"
	manager.set_save_path_for_tests(read_only_save_path)

	var error_code: Error = manager.save_data(manager._default_data())
	_expect_equal(error_code, FAILED, "Save to unopenable path returns FAILED")
	_expect_equal(manager.get_last_save_error(), FAILED, "SaveManager captures last save error")

	var rollback_data: Dictionary = manager.record_completed_level(1, 120, 6)
	_expect_equal(rollback_data["highest_unlocked_level"], 1, "record_completed_level does not report unsaved completion on write failure")
	_expect_equal(rollback_data["completed_levels"], [], "Completion is not persisted in-memory on save failure")
	_expect_true(not rollback_data["best_scores"].has("1"), "Best score is not applied on failed save")

	manager.queue_free()

	manager = save_manager_script.new() as Node
	root.add_child(manager)
	var invalid_key_save_path: String = "user://clown_smash_save_test_invalid_keys.json"
	manager.set_save_path_for_tests(invalid_key_save_path)
	manager.delete_save_for_tests()
	_write_test_save_payload(
		invalid_key_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[1],"best_scores":{"1":250,"oops":90},"best_combos":{"1":4},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var invalid_keys: Dictionary = manager.load_data()
	_expect_equal(invalid_keys["highest_unlocked_level"], 1, "Non-level best_scores keys fall back to defaults")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		invalid_key_save_path,
		'{"save_version":1,"highest_unlocked_level":1,"completed_levels":[5],"best_scores":{"5":250},"best_combos":{"5":4},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var inconsistent_unlock: Dictionary = manager.load_data()
	_expect_equal(inconsistent_unlock["highest_unlocked_level"], 1, "Inconsistent highest_unlocked_level fallback to default")

	manager.delete_save_for_tests()
	manager.queue_free()


func _test_save_data_write_failure_with_open_file() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	_expect_true(save_manager_script != null, "SaveManager script loads for injected failure checks")
	if save_manager_script == null:
		return

	var manager := save_manager_script.new() as Node
	root.add_child(manager)
	var test_save_path: String = "user://clown_smash_save_test_injected_error.json"
	manager.set_save_path_for_tests(test_save_path)
	manager.delete_save_for_tests()

	var baseline_data: Dictionary = manager.record_completed_level(1, 120, 6)
	_expect_equal(baseline_data["highest_unlocked_level"], 2, "Baseline write creates a persisted successful completion")
	_expect_true(baseline_data["completed_levels"].has(1), "Baseline completed level is persisted")
	_expect_equal(baseline_data["best_scores"]["1"], 120, "Baseline best score persists")

	var flush_failure_file := TestSaveFileAccess.new(&"flush")
	manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object:
		return flush_failure_file
	)

	var rollback_data: Dictionary = manager.record_completed_level(2, 180, 4)
	_expect_equal(rollback_data["highest_unlocked_level"], 2, "Write-failure rollback keeps previously persisted highest level")
	_expect_true(not rollback_data["completed_levels"].has(2), "Failed write does not add newly completed level")
	_expect_equal(manager.get_last_save_error(), ERR_FILE_CANT_WRITE, "Injected flush failure sets last save error to real engine error")
	_expect_true(flush_failure_file._closed, "Failed flush path closes the output handle")

	var store_failure_file := TestSaveFileAccess.new(&"store")
	manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object:
		return store_failure_file
	)

	var save_failed: Error = manager.save_data(manager._default_data())
	_expect_equal(save_failed, ERR_FILE_CANT_WRITE, "Injected store_string failure path returns write error")
	_expect_equal(manager.get_last_save_error(), ERR_FILE_CANT_WRITE, "Injected store failure updates last save error")
	_expect_true(store_failure_file._closed, "Failed store_string path closes the output handle")

	manager.delete_save_for_tests()
	manager.queue_free()


func _write_test_save_payload(save_path: String, payload: String) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	_expect_true(file != null, "Test save file can be opened for invalid-input setup")
	if file == null:
		return
	file.store_string(payload)
	file.close()


func _test_session_rules() -> void:
	var game_controller_script := load("res://scripts/gameplay/game_controller.gd") as GDScript
	var game_controller := game_controller_script.new() as Node
	root.add_child(game_controller)
	game_controller.countdown_step_duration = 0.01
	game_controller.start_level(90.0, 250, true)
	_expect_equal(game_controller.state, game_controller_script.GameState.COUNTDOWN, "Level starts in COUNTDOWN")
	for countdown_step in range(4):
		game_controller._process(0.011)
	_expect_equal(game_controller.state, game_controller_script.GameState.RUNNING, "Countdown reaches RUNNING")
	_expect_equal(game_controller.lives, 3, "Level starts with three apple lives")

	var time_before_pause: float = game_controller.remaining_time
	game_controller.pause_level()
	_expect_true(paused, "Pause stops the SceneTree")
	await create_timer(0.06, true).timeout
	_expect_true(is_equal_approx(game_controller.remaining_time, time_before_pause), "Timer does not decrease while paused")
	game_controller.resume_level()
	_expect_true(not paused, "Resume unpauses the SceneTree")

	game_controller.lose_life()
	_expect_equal(game_controller.lives, 2, "Life loss removes one apple")
	game_controller.restore_life()
	game_controller.restore_life()
	_expect_equal(game_controller.lives, 3, "Life restore is capped at three")
	game_controller.lose_life()
	game_controller.lose_life()
	game_controller.lose_life()
	_expect_equal(game_controller.state, game_controller_script.GameState.FINISHED_LOSS, "Zero lives causes immediate loss")

	game_controller.start_level(0.05, 0, false)
	game_controller._process(0.06)
	_expect_equal(game_controller.state, game_controller_script.GameState.FINISHED_WIN, "Timer expiry with objective met causes win")
	game_controller.queue_free()


func _test_core_interaction_scene() -> void:
	var packed_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	_expect_true(packed_scene != null, "Gameplay scene resource loads")
	if packed_scene == null:
		return

	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	var core_test_save_path := "user://clown_smash_core_interaction_test.json"
	gameplay.save_manager.set_save_path_for_tests(core_test_save_path)
	gameplay.save_manager.delete_save_for_tests()
	gameplay.game_controller.begin_running()
	gameplay.spawn_director.stop()
	_expect_equal(gameplay.board_controller.get_child_count(), 9, "Gameplay creates exactly nine BoxSlots")

	_expect_true(gameplay.debug_spawn_normal(4, 3.4), "Normal spawns into an idle slot")
	await create_timer(0.85).timeout
	_expect_true(gameplay.board_controller.get_slot(4).is_hittable(), "Normal becomes hittable after pop")
	_expect_true(gameplay.board_controller.get_slot(4).debug_get_lid_open() > 0.99, "Box lid reaches its open state before the character is hittable")
	var active_slot: Control = gameplay.board_controller.get_slot(4)
	_expect_true(
		absf(active_slot.debug_get_open_box_baseline() - active_slot.debug_get_closed_box_baseline()) < 2.0,
		"Open and closed box art share one fixed baseline"
	)
	var clown_touch: Vector2 = active_slot.get_local_impact_position()
	var clown_touch_on_board: Vector2 = active_slot.position + clown_touch * active_slot.scale.x
	_expect_true(active_slot.contains_hittable_clown_head_at(clown_touch), "Visible clown head owns its hit region")
	_expect_equal(gameplay.board_controller.get_slot_index_for_tap(clown_touch_on_board), 4, "Touching the clown head selects its slot")
	var face_touch_on_board: Vector2 = active_slot.position + active_slot.get_local_impact_position() + Vector2(0.0, 32.0)
	_expect_equal(gameplay.board_controller.get_slot_index_for_tap(face_touch_on_board), 4, "Touching the visible clown face selects its slot before the box")
	var box_touch_on_board: Vector2 = active_slot.position + Vector2(145.0, 260.0) * active_slot.scale.x
	_expect_equal(gameplay.board_controller.get_slot_index_for_tap(box_touch_on_board), 4, "Touching the rendered box selects its slot")
	var outside_touch_on_board: Vector2 = active_slot.position + Vector2(-32.0, -105.0) * active_slot.scale.x
	_expect_equal(gameplay.board_controller.get_slot_index_for_tap(outside_touch_on_board), -1, "Transparent space outside box and clown head does not strike")
	var spring_length_before_hit: float = gameplay.board_controller.get_slot(4).debug_get_spring_length()
	_expect_true(gameplay.debug_tap_slot(4), "Gameplay tap starts hammer strike")
	await create_timer(0.29).timeout
	var spring_length_during_hit: float = gameplay.board_controller.get_slot(4).debug_get_spring_length()
	_expect_true(spring_length_during_hit < spring_length_before_hit, "Hammer impact compresses the spring")
	await create_timer(0.09).timeout
	_expect_equal(gameplay.game_controller.score, 10, "Hammer impact resolves +10 scoring hit")
	_expect_equal(gameplay.game_controller.combo_count, 1, "Hammer impact increments combo")

	_expect_true(gameplay.debug_tap_slot(0), "Empty-slot tap starts hammer strike")
	await create_timer(0.38).timeout
	_expect_equal(gameplay.game_controller.score, 10, "Empty-slot impact does not change score")
	_expect_equal(gameplay.game_controller.combo_count, 0, "Empty-slot impact resets combo")
	_expect_equal(gameplay.game_controller.lives, 2, "Empty-slot impact removes one life")
	await create_timer(0.40).timeout
	_expect_true(gameplay.board_controller.get_slot(4).is_idle(), "Hit Normal hides and returns its slot to IDLE")
	_expect_true(gameplay.debug_spawn_normal(4, 3.4), "Cleared slot can repeat the spawn cycle")
	gameplay.game_controller.pause_level()
	_expect_true(gameplay.session_overlay.is_showing_pause(), "Pause popup is shown")
	gameplay.game_controller.resume_level()
	_expect_true(not gameplay.session_overlay.is_showing_pause(), "Pause popup closes on resume")
	gameplay.game_controller.finish_level(true)
	await create_timer(0.55).timeout
	_expect_true(gameplay.session_overlay.is_showing_result(), "Results popup is shown when level finishes")
	gameplay.save_manager.delete_save_for_tests()
	gameplay.queue_free()
	await process_frame


func _test_gameplay_completion_save_integration() -> void:
	var packed_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	_expect_true(packed_scene != null, "Gameplay scene loads for completion-save integration")
	if packed_scene == null:
		return

	var test_save_path: String = "user://clown_smash_gameplay_completion_integration.json"
	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	var save_manager := gameplay.get_node_or_null("SaveManager") as Node
	_expect_true(save_manager != null, "Gameplay owns a SaveManager for completion persistence")
	if save_manager == null:
		gameplay.queue_free()
		await process_frame
		return
	save_manager.set_save_path_for_tests(test_save_path)
	save_manager.delete_save_for_tests()
	gameplay.game_controller.score = 340
	gameplay.game_controller.max_combo = 7
	gameplay.game_controller.finish_level(true)

	var saved_win: Dictionary = save_manager.load_data()
	_expect_equal(saved_win["highest_unlocked_level"], 2, "Winning Level 1 unlocks Level 2 through Gameplay")
	_expect_true(saved_win["completed_levels"].has(1), "Winning Level 1 persists completion through Gameplay")
	_expect_equal(saved_win["best_scores"]["1"], 340, "Winning Level 1 persists Gameplay score")
	_expect_equal(saved_win["best_combos"]["1"], 7, "Winning Level 1 persists Gameplay max combo")
	save_manager.delete_save_for_tests()
	gameplay.queue_free()
	await process_frame

	gameplay = packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	save_manager = gameplay.get_node_or_null("SaveManager") as Node
	_expect_true(save_manager != null, "Gameplay owns a SaveManager for loss persistence guard")
	if save_manager == null:
		gameplay.queue_free()
		await process_frame
		return
	save_manager.set_save_path_for_tests(test_save_path)
	save_manager.delete_save_for_tests()
	gameplay.game_controller.score = 100
	gameplay.game_controller.max_combo = 3
	gameplay.game_controller.finish_level(false)
	_expect_true(not FileAccess.file_exists(test_save_path), "Losing a level does not persist Gameplay completion")
	save_manager.delete_save_for_tests()
	gameplay.queue_free()
	await process_frame

	gameplay = packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	save_manager = gameplay.get_node_or_null("SaveManager") as Node
	_expect_true(save_manager != null, "Gameplay owns a SaveManager for save-failure feedback")
	if save_manager == null:
		gameplay.queue_free()
		await process_frame
		return
	var failed_file := TestSaveFileAccess.new(&"store")
	save_manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object:
		return failed_file
	)
	gameplay.game_controller.score = 300
	gameplay.game_controller.max_combo = 5
	gameplay.game_controller.finish_level(true)
	await create_timer(0.55).timeout
	_expect_true(gameplay.session_overlay.is_showing_save_error(), "Save failure is visible on the Results overlay")
	gameplay.queue_free()
	await process_frame


func _test_special_character_scene_interactions() -> void:
	var packed_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	if packed_scene == null:
		_expect_true(false, "Gameplay scene loads for special-character integration")
		return
	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	gameplay.game_controller.begin_running()
	gameplay.spawn_director.stop()

	_expect_true(gameplay.debug_spawn_character(0, &"golden", 3.4), "Golden asset spawns through BoxSlot")
	await create_timer(0.85).timeout
	_expect_true(gameplay.debug_tap_slot(0), "Golden can be struck by the hammer")
	await create_timer(0.85).timeout
	_expect_equal(gameplay.game_controller.score, 10, "Golden scene interaction awards +10")
	_expect_equal(gameplay.game_controller.golden_hits, 1, "Golden scene interaction advances its objective")

	_expect_true(gameplay.debug_spawn_character(1, &"bomb", 3.4), "Bomb asset spawns through BoxSlot")
	await create_timer(0.85).timeout
	_expect_true(gameplay.debug_tap_slot(1), "Bomb can be struck by the hammer")
	await create_timer(0.85).timeout
	_expect_equal(gameplay.game_controller.lives, 2, "Bomb scene interaction removes one apple")
	_expect_true(gameplay.audio_manager.get_bomb_sound_path().ends_with("bomb_normalized.ogg"), "Bomb scene interaction keeps the normalized bomb sound")

	var time_before_clock: float = gameplay.game_controller.remaining_time
	_expect_true(gameplay.debug_spawn_character(2, &"clock", 3.4), "Clock asset spawns through BoxSlot")
	await create_timer(0.85).timeout
	_expect_true(gameplay.debug_tap_slot(2), "Clock can be struck by the hammer")
	await create_timer(0.85).timeout
	_expect_true(gameplay.game_controller.remaining_time > time_before_clock + 8.0, "Clock scene interaction adds about ten seconds")

	_expect_true(gameplay.debug_spawn_character(3, &"glutton", 3.4), "Glutton asset spawns through BoxSlot")
	await create_timer(0.85).timeout
	_expect_true(gameplay.debug_tap_slot(3), "Glutton can be struck by the hammer")
	await create_timer(0.85).timeout
	_expect_equal(gameplay.game_controller.lives, 3, "Glutton scene interaction restores the missing apple")

	_expect_true(gameplay.debug_spawn_character(4, &"drunk", 3.4), "Drunk asset spawns through BoxSlot")
	await create_timer(0.85).timeout
	_expect_true(gameplay.debug_tap_slot(4), "Drunk can be struck by the hammer")
	await create_timer(0.85).timeout
	_expect_equal(gameplay.game_controller.confused_strikes_remaining, 1, "Drunk scene interaction arms one confused strike")

	gameplay.game_controller.confused_strikes_remaining = 0
	var lives_before_bonus_miss: int = gameplay.game_controller.lives
	_expect_true(gameplay.debug_spawn_character(7, &"clock", 3.4), "Clock can remain active during a miss")
	await create_timer(0.85).timeout
	_expect_true(gameplay.debug_tap_slot(8), "Empty slot can be struck while a bonus is active")
	await create_timer(0.85).timeout
	_expect_equal(gameplay.game_controller.lives, lives_before_bonus_miss, "Missing an active bonus in Gameplay keeps all apples")
	var label_count_before_suppressed_escape: int = gameplay._impact_fx_layer._floating_labels.size()
	gameplay.board_controller.get_slot(7).force_clear()
	gameplay._on_character_escaped(7, &"clock")
	_expect_true(gameplay._suppressed_bonus_escapes.is_empty(), "Bonus escape suppression is consumed after the missed bonus leaves")
	_expect_equal(gameplay._impact_fx_layer._floating_labels.size(), label_count_before_suppressed_escape, "Missed bonus produces no duplicate escape label")

	var lives_before_escape: int = gameplay.game_controller.lives
	_expect_true(gameplay.debug_spawn_character(5, &"glutton", 0.05), "Glutton can enter its escape path")
	await create_timer(0.95).timeout
	_expect_equal(gameplay.game_controller.lives, lives_before_escape, "Escaped Glutton scene interaction keeps all apples")
	var clown_miss_events_before: int = gameplay.audio_manager.get_event_count(&"clown_miss")
	_expect_true(gameplay.debug_spawn_normal(6, 0.05), "Normal can enter its miss path")
	await create_timer(0.95).timeout
	_expect_equal(gameplay.audio_manager.get_event_count(&"clown_miss"), clown_miss_events_before + 1, "Escaped scoring clown plays a miss sound")

	gameplay.debug_set_level(8)
	gameplay.game_controller.begin_running()
	gameplay.spawn_director.stop()
	gameplay.spawn_director.set_confusion_remaining(1)
	var allowed_types: Array[StringName] = gameplay.spawn_director._allowed_character_types()
	_expect_true(&"drunk" not in allowed_types, "SpawnDirector keeps Drunk disabled")
	_expect_true(&"fast" not in allowed_types and &"golden" not in allowed_types, "SpawnDirector keeps Fast and Golden disabled")
	_expect_true(gameplay.debug_spawn_character(0, &"bomb", 3.4), "Bomb occupies a slot for fairness validation")
	allowed_types = gameplay.spawn_director._allowed_character_types()
	_expect_true(&"bomb" not in allowed_types, "SpawnDirector allows at most one Bomb")
	_expect_true(&"glutton" not in allowed_types, "Levels 1-8 do not pair Bomb and Glutton")
	_expect_true(&"drunk" not in allowed_types, "Levels 1-8 do not pair simultaneous hazards")
	gameplay.queue_free()
	await process_frame


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS: ", message)
		return

	_failures += 1
	push_error("FAIL: %s (expected %s, got %s)" % [message, expected, actual])


func _expect_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return

	_failures += 1
	push_error("FAIL: " + message)
