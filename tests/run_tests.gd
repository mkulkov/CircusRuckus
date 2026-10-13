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
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	var isolated := ProjectSettings.globalize_path("res://builds/debug/verification/endless/full")
	DirAccess.make_dir_recursive_absolute(isolated)
	ProjectSettings.set_setting("clown_smash/testing/save_path", isolated.path_join("save.json"))
	call_deferred("_run")


func _run() -> void:
	_test_project_configuration()
	_test_localization()
	await _test_audio_manager()
	await _test_focus_audio_lifecycle()
	_test_scoring_and_combo()
	_test_consecutive_misses()
	_test_all_character_rules()
	_test_save_data_defaults()
	_test_save_data_record_run()
	_test_save_settings_round_trip()
	await _test_monetization_demo_contract()
	await _test_vk_ad_gate()
	_test_yandex_platform_contract()
	_test_save_data_invalid_fallback()
	_test_save_data_semantic_validation()
	_test_save_data_write_failure_and_rollback()
	_test_save_data_write_failure_with_open_file()
	_test_recovery_profile()
	_test_all_round_profiles_and_assets()
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


func _test_vk_ad_gate() -> void:
	var web_adapter := WebMonetizationAdapter.new()
	var callbacks := {"availability": 0, "finished": 0, "opened": 0}
	web_adapter.ad_availability_checked.connect(func(_available: bool) -> void: callbacks.availability += 1)
	web_adapter.interstitial_finished.connect(func(_success: bool) -> void: callbacks.finished += 1)
	web_adapter.interstitial_opened.connect(func() -> void: callbacks.opened += 1)
	web_adapter.cancel_ad_request()
	web_adapter._on_ad_availability(['{"available":true}'], 0)
	web_adapter._on_interstitial_finished(['{"success":true}'], 0)
	web_adapter._on_interstitial_opened([], 0)
	_expect_true(callbacks.availability == 0 and callbacks.finished == 0 and callbacks.opened == 0, "Cancelled web ad callbacks cannot affect a newer request")
	web_adapter._on_ad_availability(['{"available":false}'], 1)
	web_adapter._on_ad_availability(['{"available":true}'], 1)
	_expect_true(callbacks.availability == 1, "Web inventory completion ignores duplicate callback")
	web_adapter._on_interstitial_finished(['{"success":false}'], 2)
	web_adapter._on_interstitial_finished(['{"success":true}'], 2)
	web_adapter._on_interstitial_opened([], 2)
	_expect_true(callbacks.finished == 1 and callbacks.opened == 0, "Web timeout or cancellation ignores late ad completion and opening")
	var service := MonetizationService.new()
	var adapter := MonetizationAdapter.new()
	adapter.platform_name = "vk"
	service._adapter = adapter
	var state := {"continued": 0}
	service.show_run_start_ad(func() -> void: state.continued += 1, true)
	_expect_true(state.continued == 1 and not service._pending_interstitial.is_valid(), "Ad-free post-training run starts without an inventory check")
	service._on_ad_availability_checked(false)
	_expect_true(state.continued == 1, "Late inventory callback cannot reopen an ad-free run")
	service.show_run_start_ad(func() -> void: state.continued += 1)
	service.continue_pending_run_after_purchase()
	_expect_true(state.continued == 1, "Unconfirmed purchase cannot complete pending ad")
	service._on_ad_availability_checked(false)
	service._on_ad_availability_checked(false)
	_expect_true(state.continued == 2, "VK unavailable inventory starts run exactly once without purchase")
	service.show_run_start_ad(func() -> void: state.continued += 1)
	service._on_ad_availability_checked(true)
	service._on_ad_availability_checked(false)
	_expect_true(state.continued == 2, "Available VK ad waits for provider completion")
	service._on_interstitial_finished(false)
	service._on_interstitial_finished(false)
	_expect_true(state.continued == 3, "Failed or cancelled VK ad starts run exactly once")
	service.ads_removed = true
	service.continue_pending_run_after_purchase()
	service.continue_pending_run_after_purchase()
	_expect_true(state.continued == 3, "Entitlement callbacks cannot repeat completed navigation")
	service.show_run_start_ad(func() -> void: state.continued += 1)
	_expect_true(state.continued == 4, "Owned purchase bypasses VK ad check")
	service.ads_removed = false
	service.show_run_start_ad(func() -> void: state.continued += 1)
	service.cancel_pending_run()
	service._on_ad_availability_checked(true)
	_expect_true(state.continued == 4, "Exiting cancels pending run and ignores late response")
	adapter.platform_name = "ok"
	service.show_run_start_ad(func() -> void: state.continued += 1, true)
	service._on_ad_availability_checked(false)
	_expect_true(state.continued == 5, "OK ad-free run continues without purchasing")
	service.show_run_start_ad(func() -> void: state.continued += 1)
	service._on_ad_availability_checked(false)
	_expect_true(state.continued == 6, "OK unavailable ads allow new runs")
	service.show_run_start_ad(func() -> void: state.continued += 1)
	service._on_ad_availability_checked(true)
	service._on_interstitial_finished(false)
	service._on_interstitial_finished(false)
	_expect_true(state.continued == 7, "Failed OK interstitial continues exactly once")
	service.free()
func _test_monetization_demo_contract() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	var save_manager := save_manager_script.new() as Node
	var test_path := "res://builds/debug/verification/endless/full/clown_smash_monetization_demo_test.json"
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
	service._on_entitlement_restored(false)
	_expect_true(not service.is_ads_removed(), "Authoritative restore revokes a refunded or different-account entitlement")
	_expect_true(not bool(save_manager.load_data()["ads_removed"]), "Revoked entitlement is persisted")
	service._on_entitlement_restored(true)
	_expect_true(service.is_ads_removed(), "Authoritative restore grants a confirmed account entitlement")
	service._on_product_info_updated("remove_ads", "Отключить рекламу", "49 ₽", "")
	_expect_equal(service.get_remove_ads_price(), "49 ₽", "Remove Ads offer keeps the SDK-provided portal price")
	_expect_equal(service.get_remove_ads_title(), "Отключить рекламу", "Remove Ads offer keeps the SDK-provided product title")
	var offer_menu_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var offer_menu := offer_menu_scene.instantiate()
	root.add_child(offer_menu)
	service.ads_removed = false
	offer_menu.configure({})
	_expect_true(offer_menu.get_node_or_null("RemoveAdsButton") == null, "Main Menu keeps Remove Ads inside Settings")
	var settings := (load("res://scenes/ui/SettingsOverlay.tscn") as PackedScene).instantiate()
	root.add_child(settings)
	settings.configure_monetization(service)
	var offer_button := settings.get_node("RemoveAdsButton") as Button
	_expect_true(offer_button.visible, "Remove Ads offer appears in Settings after SDK catalog metadata loads")
	_expect_equal(offer_button.text, "Отключить рекламу\n49 ₽", "Settings offer combines SDK product title and formatted price")
	_expect_true(offer_button.icon == null, "Settings offer does not display a currency icon")
	var offer_overlay: Control = (load("res://scripts/ui/session_overlay.gd") as GDScript).new()
	root.add_child(offer_overlay)
	_expect_true(offer_overlay.get_node_or_null("RemoveAdsButton") == null, "Pause and results keep Remove Ads inside Settings")
	service._on_purchase_finished(true, "remove_ads")
	_expect_true(not offer_button.visible, "Successful purchase immediately hides the Settings offer")
	offer_overlay.queue_free()
	settings.queue_free()
	offer_menu.queue_free()

	var restarted_service := MonetizationService.new()
	restarted_service.configure(save_manager)
	_expect_true(restarted_service.is_ads_removed(), "Restart restores ads_removed from the saved entitlement")
	var level_opened := [false]
	restarted_service.show_run_start_ad(func() -> void: level_opened[0] = true)
	_expect_true(bool(level_opened[0]), "Restored ads_removed bypasses run-start ad")
	var first_level_opened := [false]
	restarted_service.ads_removed = false
	restarted_service.show_run_start_ad(func() -> void: first_level_opened[0] = true, true)
	_expect_true(bool(first_level_opened[0]), "Post-training ad-free entry never requests interstitial")
	_expect_true(not restarted_service._pending_interstitial.is_valid(), "Ad-free entry leaves no pending interstitial request")

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
	service.free()
	restarted_service.free()
	save_manager.free()


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
	_expect_true(shell.contains("payments.getCatalog()"), "Yandex product catalog supplies portal price and currency")
	_expect_true(shell.contains("getPriceCurrencyImage('small')"), "Yandex currency icon comes from the SDK")
	var export_presets := ConfigFile.new()
	_expect_equal(export_presets.load("res://export_presets.cfg"), OK, "Export presets load")
	var web_preset_count := 0
	for preset_section in export_presets.get_sections():
		if export_presets.get_value(preset_section, "platform", "") != "Web":
			continue
		web_preset_count += 1
		var preset_name := str(export_presets.get_value(preset_section, "name", preset_section))
		var include_filter := str(export_presets.get_value(preset_section, "include_filter", ""))
		_expect_true(
			include_filter.split(",").has("config/game_analytics.cfg"),
			"%s exports the non-resource production analytics config" % preset_name
		)
	_expect_equal(web_preset_count, 5, "Every configured Web export includes the analytics config")
	var yandex_features := str(export_presets.get_value("preset.1", "custom_features", ""))
	_expect_true(yandex_features.split(",").has("yandex_games"), "Yandex production export enables its platform adapter")
	_expect_true(not yandex_features.split(",").has("no_purchases"), "Yandex production export enables the declared remove_ads purchase")

	var web_adapter := WebMonetizationAdapter.new()
	var callback_data: Dictionary = web_adapter._decode_callback_dictionary(['{"platform":"yandex","visible":true}'])
	_expect_equal(callback_data.get("platform"), "yandex", "JavaScriptBridge callback arrays decode platform data")
	_expect_true(bool(callback_data.get("visible", false)), "JavaScriptBridge callback arrays decode banner status")

	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	var manager := save_manager_script.new() as Node
	var local_data: Dictionary = manager.DEFAULT_DATA.duplicate(true)
	local_data["best_run_score"] = 300
	local_data["learned_lessons"] = ["normal"]
	var cloud_data: Dictionary = manager.DEFAULT_DATA.duplicate(true)
	cloud_data["best_run_score"] = 250
	cloud_data["best_run_combo"] = 10
	cloud_data["learned_lessons"] = ["bomb"]
	cloud_data["music_enabled"] = false
	var merged: Dictionary = manager._merge_save_data(local_data, cloud_data)
	_expect_equal(merged["best_run_score"], 300, "Cloud merge preserves score maximum")
	_expect_equal(merged["best_run_combo"], 10, "Cloud merge preserves independent series maximum")
	_expect_true(merged.learned_lessons.has("normal") and merged.learned_lessons.has("bomb"), "Cloud merges lesson mastery")
	_expect_true(not bool(merged["music_enabled"]), "Cloud settings retain their policy")
	manager.free()


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
	_expect_equal(TranslationServer.translate("COUNTDOWN_GO"), "GO!", "English countdown translation is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_1"), "CIRCUS", "English game title first line is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_2"), "RUCKUS", "English game title second line is available")
	TranslationServer.set_locale("ru")
	_expect_equal(TranslationServer.translate("MENU_PLAY"), "ИГРАТЬ", "Russian menu translation is available")
	_expect_equal(TranslationServer.translate("COUNTDOWN_GO"), "НАЧАЛИ!", "Russian countdown translation is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_1"), "ЦИРКОВОЙ", "Russian game title first line is available")
	_expect_equal(TranslationServer.translate("GAME_TITLE_LINE_2"), "ПЕРЕПОЛОХ", "Russian game title second line is available")
	TranslationServer.set_locale(previous_locale)
	manager.queue_free()

	var settings_scene := load("res://scenes/ui/SettingsOverlay.tscn") as PackedScene
	var settings := settings_scene.instantiate()
	root.add_child(settings)
	TranslationServer.set_locale("en")
	_expect_equal(settings._music.text, "MUSIC", "Existing Settings UI refreshes to English")
	TranslationServer.set_locale("ru")
	_expect_equal(settings._music.text, "МУЗЫКА", "Existing Settings UI refreshes to Russian")
	TranslationServer.set_locale(previous_locale)
	settings.queue_free()


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
	manager.play_music_for_run()
	var first_music_track: String = manager.get_current_music_track_path()
	_expect_true(first_music_track.ends_with(".ogg"), "Run music uses an imported OGG track")
	manager.play_music_for_run()
	_expect_true(first_music_track != manager.get_current_music_track_path(), "Consecutive runs do not repeat the same music track")
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


func _test_focus_audio_lifecycle() -> void:
	var audio_script := load("res://scripts/audio/audio_manager.gd") as Script
	var manager: Node = audio_script.new()
	root.add_child(manager)
	await process_frame
	manager.apply_settings({"music_enabled": true, "sound_enabled": false, "haptics_enabled": true})
	var service := MonetizationService.new()
	service._audio_manager = manager
	root.add_child(service)
	await process_frame
	var pause_events := [0]
	var resume_events := [0]
	service.platform_pause_requested.connect(func() -> void: pause_events[0] += 1)
	service.platform_resume_requested.connect(func() -> void: resume_events[0] += 1)
	service._on_platform_pause_requested()
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	service._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_expect_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Losing application focus mutes music")
	_expect_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Losing application focus mutes sound effects")
	_expect_true(pause_events[0] == 1, "Platform, focus loss, and application pause share one lifecycle transition")
	service._on_platform_resume_requested()
	_expect_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) and resume_events[0] == 0, "Platform resume cannot release an active native focus pause")
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	service._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_expect_true(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Music resumes when enabled in settings")
	_expect_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Sound effects stay muted when disabled in settings")
	_expect_true(resume_events[0] == 1, "Focus return and application resume share one lifecycle transition")
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	manager.apply_settings({"music_enabled": false, "sound_enabled": true, "haptics_enabled": true})
	service.refresh_audio_pause_state()
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Focus return respects a music setting changed while unfocused")
	_expect_true(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Focus return restores effects enabled while unfocused")
	manager.apply_settings({"music_enabled": true, "sound_enabled": false, "haptics_enabled": true})
	service.refresh_audio_pause_state()
	service._set_audio_pause_reason(&"interstitial", true)
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Returning from focus does not release another audio pause reason")
	service._set_audio_pause_reason(&"interstitial", false)
	_expect_true(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Clearing temporary mute restores current settings")
	service.queue_free()
	manager.apply_settings({"music_enabled": true, "sound_enabled": true, "haptics_enabled": true})
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
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	menu.configure({"best_run_score": 9007199254740991, "best_run_combo": 200, "best_run_rounds": 1000, "best_run_active_seconds": 45000.0})
	for action in ["PlayButton", "TutorialButton", "SettingsButton", "StatisticsButton"]:
		_expect_true(menu.get_node_or_null(action) != null, "Main menu exposes " + action)
	_expect_true(menu.get_node_or_null("AboutButton") == null and menu.get_node_or_null("AboutPanel") == null, "About screen and button are removed")
	_expect_true(menu.get_node_or_null("LevelsButton") == null, "Campaign selection is removed")
	var requests := {"play": 0, "tutorial": 0}
	menu.play_requested.connect(func() -> void: requests.play += 1)
	menu.tutorial_requested.connect(func() -> void: requests.tutorial += 1)
	menu.get_node("PlayButton").pressed.emit()
	menu.get_node("TutorialButton").pressed.emit()
	_expect_equal(requests, {"play": 1, "tutorial": 1}, "Menu actions emit without campaign IDs")
	menu.queue_free()
	await process_frame


func _test_scene_router_flow() -> void:
	var boot := (load("res://scenes/boot/Boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	boot.save_manager.delete_save_for_tests()
	boot.skip_startup_splash()
	await create_timer(0.30).timeout
	_expect_equal(boot._current_screen.name, "MainMenu", "Router opens main menu")
	boot.save_manager.record_run(120, 8, 4, 125.0)
	boot._current_screen.get_node("StatisticsButton").pressed.emit()
	await process_frame
	_expect_equal(boot._current_screen.name, "Statistics", "Statistics button opens separate screen")
	var records_label: Label = boot._current_screen.find_child("Records", true, false)
	_expect_equal(records_label.text, tr("MENU_RECORDS") % [120, 8, 4, "2:05"], "Statistics displays all four saved records")
	boot._current_screen.find_child("BackButton", true, false).pressed.emit()
	await process_frame
	_expect_equal(boot._current_screen.name, "MainMenu", "Statistics Back returns to menu")
	for id in boot.save_manager.LESSON_IDS:
		boot.save_manager.learn_lesson(id)
	boot.start_run()
	await process_frame
	_expect_equal(boot._current_screen.name, "Gameplay", "Router starts mastered endless run")
	var completed_game = boot._current_screen
	completed_game.game_controller.score = 123
	completed_game._on_training_completed()
	_expect_true(completed_game.session_overlay.is_showing_training_complete(), "Router-owned training completion shows notification")
	completed_game.session_overlay._continue_button.pressed.emit()
	await process_frame
	_expect_true(boot._current_screen != completed_game, "Start game uses main-menu router to create a new screen")
	_expect_true(boot._current_screen.round_director.round_index == 1 and boot._current_screen.game_controller.score == 0 and not paused, "Router start clears training score and pause")
	boot._current_screen.game_controller.begin_running()
	boot._current_screen.game_controller.pause_level()
	boot.show_main_menu()
	await process_frame
	_expect_true(not paused, "Returning to menu clears SceneTree pause")
	_expect_equal(boot._current_screen.name, "MainMenu", "Router returns to main menu")
	boot.save_manager.delete_save_for_tests()
	boot.queue_free()
	await process_frame


func _test_scoring_and_combo() -> void:
	var game_controller_script := load("res://scripts/gameplay/game_controller.gd") as GDScript
	var game_controller := game_controller_script.new() as Node
	root.add_child(game_controller)
	game_controller.start_run(RoundProfile.new(), false)

	game_controller.resolve_scoring_hit()
	_expect_equal(game_controller.score, 10, "Normal hit adds exactly 10 score")
	_expect_equal(game_controller.combo_count, 1, "Normal hit increases combo")
	game_controller.resolve_scoring_hit()
	_expect_equal(game_controller.score, 20, "Second Normal hit adds exactly 10 score")
	_expect_equal(game_controller.combo_count, 2, "Second Normal hit increases combo")
	game_controller.resolve_empty_hit()
	_expect_equal(game_controller.score, 20, "Empty hit preserves score")
	_expect_equal(game_controller.combo_count, 0, "Empty hit resets combo")
	_expect_equal(game_controller.lives, 3, "Empty hit preserves lives")
	game_controller.resolve_scoring_hit()
	game_controller.resolve_scoring_miss()
	_expect_equal(game_controller.combo_count, 0, "Missed Normal resets combo")
	game_controller.queue_free()


func _test_recovery_profile() -> void:
	var profile := load("res://data/round_profiles/recovery.tres") as RoundProfile
	_expect_true(profile != null, "Recovery profile loads")
	_expect_equal(profile.duration, 25.0, "Round duration remains 25 seconds")
	_expect_equal(profile.max_decision_targets, 1, "Recovery allows one decision")
	_expect_equal(profile.double_spawn_chance, 0.0, "Recovery has no double spawns")


func _test_all_round_profiles_and_assets() -> void:
	for phase in ["recovery", "build", "variation", "pressure", "peak"]:
		var profile := load("res://data/round_profiles/%s.tres" % phase) as RoundProfile
		_expect_true(profile != null, phase + " profile loads")
		_expect_equal(profile.validation_errors(), PackedStringArray(), phase + " respects all numerical bounds")

	for asset_name in ["normal", "fast", "golden", "bomb", "clock", "glutton", "drunk"]:
		var texture := load("res://assets/generated/%s_clown.png" % asset_name) as Texture2D
		_expect_true(texture != null, "%s clown asset loads" % asset_name.capitalize())
	_expect_true(load("res://assets/generated/closed_box.png") is Texture2D, "Closed-box asset loads")
	_expect_true(load("res://assets/generated/startup_splash.png") is Texture2D, "Russian startup splash loads")
	_expect_true(load("res://assets/generated/startup_splash_en.png") is Texture2D, "English startup splash loads")
	_expect_true(load("res://assets/ui/countdown_go_ru.png") is Texture2D, "Russian countdown wordmark loads")
	_expect_true(load("res://assets/ui/countdown_go_en.png") is Texture2D, "English countdown wordmark loads")


func _test_spawn_director_deterministic_seed() -> void:
	var packed_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	_expect_true(packed_scene != null, "Gameplay scene loads for deterministic spawn test")
	if packed_scene == null:
		return
	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	gameplay.spawn_director.stop()
	gameplay.debug_set_round(9)
	gameplay.spawn_director.stop()
	var config := load("res://data/round_profiles/peak.tres") as RoundProfile
	var first_sequence := _capture_spawn_sequence(gameplay, config, 7331, 18)
	var second_sequence := _capture_spawn_sequence(gameplay, config, 7331, 18)
	_expect_equal(first_sequence, second_sequence, "Same SpawnDirector seed reproduces character and slot sequence")
	_expect_true(first_sequence.size() == 18, "Deterministic spawn test captures every requested spawn")
	for level_id in range(5):
		var phase: String = ["recovery", "build", "variation", "pressure", "peak"][level_id]
		var level_config := load("res://data/round_profiles/%s.tres" % phase) as RoundProfile
		gameplay.board_controller.clear_all()
		gameplay.spawn_director.deterministic_seed = 7331 + level_id
		gameplay.spawn_director.configure(gameplay.board_controller, level_config)
		gameplay.spawn_director.prepare_round()
		var required: Array[StringName] = []
		for kind in gameplay.spawn_director.ENABLED_CHARACTER_TYPES:
			if gameplay.spawn_director._weight_for(kind) > 0.0:
				required.append(kind)
		var sequence := _capture_spawn_sequence(gameplay, level_config, 7331 + level_id, 36, true)
		var seen: Dictionary = {}
		for spawned in sequence:
			var kind := StringName(spawned.get_slice(":", 1))
			seen[kind] = true
			_expect_true(kind in required, "Only profile-enabled types spawn")
		for kind in required:
			_expect_true(seen.has(kind), "Phase %d guarantees %s" % [level_id, kind])
		_expect_true(not seen.has(&"drunk"), "Drunk awaits human clarity validation")
	gameplay.queue_free()
	await process_frame


func _capture_spawn_sequence(gameplay: Control, config: RoundProfile, seed: int, count: int, advance_round: bool = false) -> Array[String]:
	var sequence: Array[String] = []
	gameplay.board_controller.clear_all()
	gameplay.spawn_director.deterministic_seed = seed
	gameplay.spawn_director.configure(gameplay.board_controller, config)
	gameplay.spawn_director.prepare_round()
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
	var config := RoundProfile.new()
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
	director.free()


func _test_all_character_rules() -> void:
	var game_controller_script := load("res://scripts/gameplay/game_controller.gd") as GDScript
	var game_controller := game_controller_script.new() as Node
	root.add_child(game_controller)
	game_controller.start_run(RoundProfile.new(), false)
	var static_feedback: Array[String] = []
	game_controller.feedback_requested.connect(func(text: String) -> void: static_feedback.append(text))

	game_controller.resolve_character_hit(&"normal")
	_expect_equal(game_controller.score, 10, "Normal awards +10")
	game_controller.resolve_character_hit(&"fast")
	_expect_equal(game_controller.score, 30, "Fast adds +20")
	game_controller.resolve_character_hit(&"golden")
	_expect_equal(game_controller.score, 80, "Normal +10, Fast +20 and Golden +50")
	_expect_equal(game_controller.combo_count, 3, "All scoring characters increase combo")
	_expect_equal(game_controller.golden_hits, 1, "Golden hit retains hit statistic")
	_expect_true("+10" not in static_feedback, "Scoring hits do not request a static +10 HUD message")

	game_controller.resolve_character_hit(&"bomb")
	_expect_equal(game_controller.lives, 2, "Bomb hit removes one life")
	_expect_equal(game_controller.combo_count, 0, "Bomb hit resets combo")

	game_controller.resolve_character_hit(&"normal")
	game_controller.resolve_character_hit(&"clock")
	game_controller.resolve_character_hit(&"clock")
	game_controller.resolve_character_hit(&"clock")
	game_controller.resolve_character_hit(&"clock")
	_expect_equal(game_controller.remaining_time, 25.0, "Clock leaves round duration unchanged")
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
	_expect_equal(game_controller.lives, lives_before_ignored_bomb - 1, "Escaped Glutton removes one life")
	game_controller.resolve_character_escape(&"clock")
	_expect_equal(game_controller.lives, lives_before_ignored_bomb - 1, "Escaped Clock keeps remaining lives")
	game_controller.resolve_empty_hit()
	_expect_equal(game_controller.lives, lives_before_ignored_bomb - 1, "First empty strike preserves remaining lives")
	game_controller.queue_free()


func _test_save_data_defaults() -> void:
	var manager = load("res://scripts/save/save_manager.gd").new()
	manager.set_save_path_for_tests("res://builds/debug/verification/endless/full/defaults.json")
	manager.delete_save_for_tests()
	var first: Dictionary = manager.load_data()
	_expect_equal(first.save_version, 2, "Missing save defaults to v2")
	_expect_equal(first.best_run_score, 0, "Missing save has no endless records")
	_expect_equal(first.learned_lessons, [], "Missing save requires all lessons")
	_expect_true(first.music_enabled and first.sound_enabled and first.haptics_enabled, "Default settings remain enabled")
	var second: Dictionary = manager.load_data()
	first.learned_lessons.append("normal")
	first.legacy_campaign.best_scores.x = 5
	_expect_equal(second.learned_lessons, [], "Default lesson array remains independent")
	_expect_equal(second.legacy_campaign.best_scores, {}, "Default legacy dictionary remains independent")
	manager.free()


func _test_save_data_record_run() -> void:
	var manager = load("res://scripts/save/save_manager.gd").new()
	manager.set_save_path_for_tests("res://builds/debug/verification/endless/full/records.json")
	manager.delete_save_for_tests()
	_expect_true(manager.record_run(320, 6, 10, 500.0), "Run records write successfully")
	_expect_true(manager.record_run(180, 12, 1000, 300.0), "Independent records merge successfully")
	var result: Dictionary = manager.load_data()
	_expect_equal(result.best_run_score, 320, "Lower run score does not replace best")
	_expect_equal(result.best_run_combo, 12, "Series record updates independently")
	_expect_equal(result.best_run_rounds, 1000, "Round records are not capped at nine")
	_expect_equal(result.best_run_active_seconds, 500.0, "Active time retains independent maximum")
	_expect_true(not manager.record_run(-1, 20, 5, 30), "Negative run score is rejected")
	_expect_equal(manager.load_data(), result, "Invalid record leaves persisted data unchanged")
	manager.delete_save_for_tests()
	manager.free()


func _test_save_settings_round_trip() -> void:
	var manager := (load("res://scripts/save/save_manager.gd") as GDScript).new() as Node
	root.add_child(manager)
	var test_path := "res://builds/debug/verification/endless/full/clown_smash_settings_test.json"
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
	var test_save_path: String = "res://builds/debug/verification/endless/full/clown_smash_save_test_invalid.json"
	manager.set_save_path_for_tests(test_save_path)

	manager.delete_save_for_tests()
	_write_test_save_payload(test_save_path, "{ not valid json ")
	var malformed_data: Dictionary = manager.load_data()
	_expect_equal(malformed_data["legacy_campaign"]["highest_unlocked_level"], 1, "Malformed JSON falls back to defaults")

	manager.delete_save_for_tests()
	_write_test_save_payload(test_save_path, '{"save_version":"one","highest_unlocked_level":"bad","completed_levels":"not_array","best_scores":[],"best_combos":[],"music_enabled":"yes","sound_enabled":1,"haptics_enabled":1}')
	var structural_data: Dictionary = manager.load_data()
	_expect_equal(structural_data["legacy_campaign"]["highest_unlocked_level"], 1, "Invalid save schema falls back to defaults")

	manager.delete_save_for_tests()
	manager.queue_free()


# These v1 fixtures verify only legacy migration validation, never active campaign runtime.
func _test_save_data_semantic_validation() -> void:
	var save_manager_script := load("res://scripts/save/save_manager.gd") as GDScript
	_expect_true(save_manager_script != null, "SaveManager script loads for semantic validation checks")
	if save_manager_script == null:
		return

	var manager := save_manager_script.new() as Node
	root.add_child(manager)
	var test_save_path: String = "res://builds/debug/verification/endless/full/clown_smash_save_test_semantic.json"
	manager.set_save_path_for_tests(test_save_path)

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":99,"highest_unlocked_level":3,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var unsupported_version: Dictionary = manager.load_data()
	_expect_equal(unsupported_version["save_version"], 2, "Unsupported save_version falls back to default")
	_expect_equal(unsupported_version["legacy_campaign"]["highest_unlocked_level"], 1, "Unsupported save_version falls back to level 1")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":11,"completed_levels":[],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var invalid_level: Dictionary = manager.load_data()
	_expect_equal(invalid_level["legacy_campaign"]["highest_unlocked_level"], 1, "Highest unlocked outside 1..9 falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[1,1],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var duplicate_levels: Dictionary = manager.load_data()
	_expect_equal(duplicate_levels["legacy_campaign"]["highest_unlocked_level"], 1, "Duplicate completed_levels fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[10],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var out_of_range_level_list: Dictionary = manager.load_data()
	_expect_equal(out_of_range_level_list["legacy_campaign"]["highest_unlocked_level"], 1, "Completed_levels outside 1..9 falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1.5,"highest_unlocked_level":3,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":6},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_version: Dictionary = manager.load_data()
	_expect_equal(fractional_version["legacy_campaign"]["highest_unlocked_level"], 1, "Fractional save_version falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[9],"best_scores":{"1":-5},"best_combos":{"1":4},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var negative_score: Dictionary = manager.load_data()
	_expect_equal(negative_score["legacy_campaign"]["highest_unlocked_level"], 1, "Negative best_scores entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[9],"best_scores":{"1":1.5},"best_combos":{"1":4},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_best_score: Dictionary = manager.load_data()
	_expect_equal(fractional_best_score["legacy_campaign"]["highest_unlocked_level"], 1, "Fractional best_scores entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[9],"best_scores":{"1":5},"best_combos":{"1":-1},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var negative_combo: Dictionary = manager.load_data()
	_expect_equal(negative_combo["legacy_campaign"]["highest_unlocked_level"], 1, "Negative best_combos entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":2.2},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_best_combo: Dictionary = manager.load_data()
	_expect_equal(fractional_best_combo["legacy_campaign"]["highest_unlocked_level"], 1, "Fractional best_combos entries fall back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":3.2,"completed_levels":[1],"best_scores":{"1":10},"best_combos":{"1":2},"music_enabled":true,"sound_enabled":true,"haptics_enabled":true}'
	)
	var fractional_unlock: Dictionary = manager.load_data()
	_expect_equal(fractional_unlock["legacy_campaign"]["highest_unlocked_level"], 1, "Fractional highest_unlocked_level falls back to default")

	manager.delete_save_for_tests()
	_write_test_save_payload(
		test_save_path,
		'{"save_version":1,"highest_unlocked_level":6,"completed_levels":[1,3,5],"best_scores":{"1":250,"3":90},"best_combos":{"1":4,"5":7},"music_enabled":false,"sound_enabled":false,"haptics_enabled":false}'
	)
	var valid_data: Dictionary = manager.load_data()
	_expect_equal(valid_data["save_version"], 2, "Semantically valid save_version is preserved")
	_expect_equal(valid_data["legacy_campaign"]["highest_unlocked_level"], 6, "Semantically valid unlock level is preserved")
	_expect_equal(valid_data["legacy_campaign"]["completed_levels"], [1, 3, 5], "Semantically valid completed levels are preserved")
	_expect_equal(valid_data["legacy_campaign"]["best_scores"], {"1": 250, "3": 90}, "Semantically valid best scores are preserved")
	_expect_equal(valid_data["legacy_campaign"]["best_combos"], {"1": 4, "5": 7}, "Semantically valid best combos are preserved")
	_expect_true(not valid_data["music_enabled"], "Semantically valid audio flags are preserved")
	_expect_true(not valid_data["sound_enabled"], "Semantically valid sound flags are preserved")
	_expect_true(not valid_data["haptics_enabled"], "Semantically valid haptics flags are preserved")

	manager.delete_save_for_tests()
	manager.queue_free()


func _test_save_data_write_failure_and_rollback() -> void:
	var manager = load("res://scripts/save/save_manager.gd").new()
	manager.set_save_path_for_tests("res://builds/debug/verification/endless/full/rollback.json")
	manager.delete_save_for_tests()
	manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object: return null)
	_expect_true(not manager.record_run(100, 5, 10, 500), "Open failure rejects record write")
	_expect_equal(manager.load_data().best_run_score, 0, "Failed write does not apply new record")
	manager.free()


func _test_save_data_write_failure_with_open_file() -> void:
	var manager = load("res://scripts/save/save_manager.gd").new()
	manager.set_save_path_for_tests("res://builds/debug/verification/endless/full/write_failure.json")
	manager.delete_save_for_tests()
	_expect_true(manager.record_run(120, 5, 2, 100), "Baseline record persists")
	for operation in [&"flush", &"store"]:
		var failed_file := TestSaveFileAccess.new(operation)
		manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object: return failed_file)
		_expect_true(not manager.record_run(200, 8, 3, 200), "Injected %s error rejects write" % operation)
		_expect_equal(manager.load_data().best_run_score, 120, "Write failure retains previous persisted record")
		_expect_equal(manager.get_last_save_error(), ERR_FILE_CANT_WRITE, "Write failure reports engine error")
		_expect_true(failed_file._closed, "Failed output handle closes")
	manager.delete_save_for_tests()
	manager.free()


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
	game_controller.start_run(RoundProfile.new(), true)
	_expect_equal(game_controller.state, game_controller_script.GameState.COUNTDOWN, "Run starts in COUNTDOWN")
	for countdown_step in range(4):
		game_controller._process(0.011)
	_expect_equal(game_controller.state, game_controller_script.GameState.RUNNING, "Countdown reaches RUNNING")
	_expect_equal(game_controller.lives, 3, "Run starts with three hammer lives")

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

	game_controller.start_run(RoundProfile.new(), false)
	game_controller.remaining_time = 0.05
	game_controller._process(0.06)
	_expect_equal(game_controller.state, game_controller_script.GameState.ROUND_TRANSITION, "Timer expiry enters round-results transition")
	game_controller.queue_free()


func _test_core_interaction_scene() -> void:
	var packed_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	_expect_true(packed_scene != null, "Gameplay scene resource loads")
	if packed_scene == null:
		return

	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	var core_test_save_path := "res://builds/debug/verification/endless/full/clown_smash_core_interaction_test.json"
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
	var box_touch_on_board: Vector2 = active_slot.position + Vector2(130.0, 260.0) * active_slot.scale.x
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
	_expect_equal(gameplay.game_controller.lives, 3, "Empty-slot impact preserves lives")
	await create_timer(0.40).timeout
	_expect_true(gameplay.board_controller.get_slot(4).is_idle(), "Hit Normal hides and returns its slot to IDLE")
	_expect_true(gameplay.debug_spawn_normal(4, 3.4), "Cleared slot can repeat the spawn cycle")
	await create_timer(0.9).timeout
	gameplay.game_controller.pause_level()
	_expect_true(gameplay.session_overlay.is_showing_pause(), "Pause popup is shown")
	var paused_slot = gameplay.board_controller.get_slot(4)
	var paused_state: int = paused_slot.state
	var paused_position: Vector2 = paused_slot.clown.position
	var paused_time: float = gameplay.game_controller.remaining_time
	await create_timer(3.6, true).timeout
	_expect_equal(paused_slot.state, paused_state, "Clown visibility timer stops throughout pause")
	_expect_true(paused_slot.clown.position.is_equal_approx(paused_position), "Clown animation stops during pause")
	_expect_true(is_equal_approx(gameplay.game_controller.remaining_time, paused_time), "Gameplay timer stops during pause")
	_expect_true(not gameplay.audio_manager._music_player.can_process(), "Music player stops processing during pause")
	for player in gameplay.audio_manager._sfx_players:
		_expect_true(not player.can_process(), "SFX player stops processing during pause")
	gameplay.game_controller.resume_level()
	_expect_true(not gameplay.session_overlay.is_showing_pause(), "Pause popup closes on resume")
	gameplay.game_controller.is_practice = false
	gameplay.game_controller.lives = 0
	gameplay.game_controller.finish_run("lives")
	await create_timer(0.55).timeout
	_expect_true(gameplay.session_overlay.is_showing_result(), "Results popup is shown when run finishes")
	gameplay.save_manager.delete_save_for_tests()
	gameplay.queue_free()
	await process_frame


func _test_gameplay_completion_save_integration() -> void:
	var scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	for reason in ["menu", "lives"]:
		var gameplay := scene.instantiate()
		root.add_child(gameplay)
		await process_frame
		gameplay.save_manager.delete_save_for_tests()
		gameplay.game_controller.score = 340
		gameplay.game_controller.max_combo = 7
		gameplay.game_controller.completed_rounds = 10
		gameplay.game_controller.active_elapsed = 450.0
		gameplay.game_controller.finish_run(reason)
		var saved: Dictionary = gameplay.save_manager.load_data()
		_expect_equal(saved.best_run_score, 340, "Run termination persists score: " + reason)
		_expect_equal(saved.best_run_combo, 7, "Run termination persists best series")
		_expect_equal(saved.best_run_rounds, 10, "Only completed rounds persist")
		gameplay.save_manager.delete_save_for_tests()
		gameplay.queue_free()
		await process_frame
	var gameplay := scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	var failed_file := TestSaveFileAccess.new(&"store")
	gameplay.save_manager.set_open_file_for_tests(func(_path: String, _mode: int) -> Object: return failed_file)
	gameplay.game_controller.score = 300
	gameplay.game_controller.lives = 0
	gameplay.game_controller.finish_run("lives")
	await create_timer(0.55).timeout
	_expect_true(gameplay.session_overlay.is_showing_save_error(), "Save failure remains visible on results")
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
	_expect_equal(gameplay.game_controller.score, 50, "Golden scene interaction awards +50")
	_expect_equal(gameplay.game_controller.golden_hits, 1, "Golden scene interaction retains hit statistic")

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
	_expect_true(gameplay.spawn_director.slowdown_remaining > 4.0 and gameplay.game_controller.remaining_time <= time_before_clock, "Clock scene interaction slows spawning without adding time")

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
	_expect_equal(gameplay.game_controller.lives, lives_before_escape - 1, "Escaped Glutton scene interaction removes one life")
	var clown_miss_events_before: int = gameplay.audio_manager.get_event_count(&"clown_miss")
	_expect_true(gameplay.debug_spawn_normal(6, 0.05), "Normal can enter its miss path")
	await create_timer(0.95).timeout
	_expect_equal(gameplay.audio_manager.get_event_count(&"clown_miss"), clown_miss_events_before + 1, "Escaped scoring clown plays a miss sound")

	gameplay.debug_set_round(8)
	gameplay.game_controller.begin_running()
	gameplay.spawn_director.stop()
	gameplay.spawn_director.set_confusion_remaining(1)
	var allowed_types: Array[StringName] = gameplay.spawn_director._allowed_character_types()
	_expect_true(&"drunk" not in allowed_types, "SpawnDirector keeps Drunk disabled")
	_expect_true(&"fast" in allowed_types and &"golden" in allowed_types, "Endless profiles enable Fast and Golden")
	_expect_true(gameplay.debug_spawn_character(0, &"bomb", 3.4), "Bomb occupies a slot for fairness validation")
	allowed_types = gameplay.spawn_director._allowed_character_types()
	_expect_true(&"bomb" not in allowed_types, "SpawnDirector allows at most one Bomb")
	_expect_true(&"glutton" not in allowed_types, "Fairness does not pair Bomb and Glutton")
	_expect_true(&"drunk" not in allowed_types, "Fairness does not pair simultaneous hazards")
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


func _test_consecutive_misses() -> void:
	var controller = load("res://scripts/gameplay/game_controller.gd").new()
	root.add_child(controller)
	controller.start_run(RoundProfile.new(), false)
	controller.resolve_empty_hit()
	controller.resolve_character_escape(&"normal")
	_expect_equal(controller.lives, 3, "First two mixed misses preserve lives")
	controller.resolve_character_escape(&"golden")
	_expect_equal(controller.lives, 2, "Third mixed miss removes exactly one life")
	_expect_equal(controller.consecutive_misses, 0, "Life penalty clears miss streak")
	controller.resolve_empty_hit()
	controller.resolve_empty_hit()
	controller.resolve_scoring_hit()
	_expect_equal(controller.consecutive_misses, 0, "Scoring hit clears miss streak")
	controller.resolve_empty_hit()
	controller.resolve_character_hit(&"clock")
	_expect_equal(controller.consecutive_misses, 0, "Bonus hit clears miss streak")
	controller.resolve_empty_hit()
	controller.resolve_character_escape(&"bomb")
	controller.resolve_character_escape(&"clock")
	_expect_equal(controller.consecutive_misses, 1, "Ignored non-scoring clowns do not alter streak")
	controller.pause_level()
	controller.resolve_empty_hit()
	_expect_equal(controller.consecutive_misses, 1, "Paused misses do not count")
	controller.resume_level()
	controller.start_run(RoundProfile.new(), false)
	_expect_equal(controller.consecutive_misses, 0, "Restart clears miss streak")
	for index in range(9):
		controller.resolve_empty_hit()
	_expect_equal(controller.lives, 0, "Nine consecutive misses exhaust three lives")
	_expect_equal(controller.state, controller.GameState.FINISHED_LOSS, "Third life penalty ends run in loss")
	controller.queue_free()
