extends "res://tests/run_tests.gd"

class PolicyAdapter extends MonetizationAdapter:
	var requests := 0
	var checks := 0
	var banners: Array[bool] = []
	var available := true
	var cancellations := 0
	func _init() -> void:
		platform_name = "vk"
	func check_ad_availability() -> void:
		checks += 1
		ad_availability_checked.emit(available)
	func show_interstitial() -> void:
		requests += 1
	func show_banner(visible: bool) -> void:
		banners.append(visible)
	func cancel_ad_request() -> void:
		cancellations += 1

func _run() -> void:
	var adapter := PolicyAdapter.new()
	var service := MonetizationService.new()
	service._adapter = adapter
	adapter.initialized.connect(service._on_adapter_initialized)
	adapter.ad_availability_checked.connect(service._on_ad_availability_checked)
	adapter.interstitial_opened.connect(service._on_interstitial_opened)
	adapter.interstitial_finished.connect(service._on_interstitial_finished)
	root.add_child(service)
	service._adapter_ready = true
	var done := [0]
	var next := func() -> void: done[0] += 1
	service.show_transition_ad("cycle_end", next, 5)
	_expect_true(done[0] == 1 and adapter.requests == 0, "No advertisement before 120 active seconds")
	service.record_active_play(119.0)
	service.show_transition_ad("cycle_end", next, 5)
	_expect_true(done[0] == 2 and adapter.requests == 0, "119 seconds is below threshold")
	service.record_active_play(1.0)
	service.show_transition_ad("cycle_end", next, 4)
	service.show_transition_ad("loss_retry", next, 0, 119.0)
	_expect_true(done[0] == 4 and adapter.requests == 0, "Ordinary rounds and short losses never request ads")
	service.show_transition_ad("cycle_end", next, 5)
	service.show_transition_ad("cycle_end", next, 5)
	_expect_true(adapter.requests == 1 and done[0] == 4, "One request for repeated Continue")
	adapter.interstitial_finished.emit(true)
	adapter.interstitial_finished.emit(true)
	_expect_true(done[0] == 5 and service._active_seconds_since_ad == 0.0, "Confirmed show resets interval and continues once")
	service.show_transition_ad("loss_retry", next, 0, 125.0)
	_expect_true(done[0] == 6 and adapter.requests == 1, "Cycle and defeat share the interval")
	service.record_active_play(120.0)
	service._last_ad_attempt_msec = -60000
	adapter.available = false
	service.show_transition_ad("cycle_end", next, 10)
	_expect_true(done[0] == 7 and service._active_seconds_since_ad == 120.0, "Unavailable inventory continues without consuming active interval")
	adapter.available = true
	service.show_transition_ad("loss_retry", next, 0, 125.0)
	_expect_true(done[0] == 8 and adapter.requests == 1, "Unavailable inventory uses shared retry backoff")
	service._last_ad_attempt_msec = -60000
	service.show_transition_ad("loss_retry", next, 0, 125.0)
	adapter.interstitial_finished.emit(false)
	_expect_true(done[0] == 9 and service._active_seconds_since_ad == 120.0, "Provider error continues without fake show")
	service._last_ad_attempt_msec = -60000
	service.show_transition_ad("cycle_end", next, 15)
	service.cancel_pending_run()
	adapter.interstitial_finished.emit(true)
	_expect_true(done[0] == 9 and service._active_seconds_since_ad == 120.0, "Cancelled request ignores late success")
	service.ads_removed = true
	service.show_banner(true)
	service.show_transition_ad("cycle_end", next, 15)
	_expect_true(done[0] == 10 and not adapter.banners.back(), "Entitlement suppresses banners and transitions")
	service.show_banner(false)
	service._on_entitlement_restored(false)
	_expect_true(not adapter.banners.back(), "Restoring unowned entitlement cannot show banner in menu")
	service.show_banner(true)
	_expect_true(adapter.banners.back(), "Gameplay can request banner")
	service._on_entitlement_restored(true)
	_expect_true(not adapter.banners.back(), "Restore immediately hides gameplay banner")
	service.ads_removed = false
	service._last_ad_attempt_msec = -60000
	ProjectSettings.set_setting("monetization/policy/request_timeout_seconds", 1.0)
	service.show_transition_ad("cycle_end", next, 20)
	await create_timer(1.1).timeout
	_expect_true(done[0] == 11 and not service._pending_interstitial.is_valid(), "Missing pre-open callback fails open after timeout")
	ProjectSettings.set_setting("monetization/policy/request_timeout_seconds", 30.0)
	service.queue_free()
	await process_frame
	await _test_real_gameplay_policy()
	await _test_real_router_policy()
	await _test_vk_ad_gate()
	if _failures == 0:
		print("MONETIZATION POLICY RESULT: PASS")
		quit(0)
	else:
		quit(1)

func _test_real_gameplay_policy() -> void:
	var save: Node = load("res://scripts/save/save_manager.gd").new()
	save.set_save_path_for_tests("res://builds/debug/verification/monetization-policy/scene-save.json")
	save.delete_save_for_tests()
	var adapter := PolicyAdapter.new()
	var service := MonetizationService.new()
	service._adapter = adapter
	adapter.initialized.connect(service._on_adapter_initialized)
	adapter.ad_availability_checked.connect(service._on_ad_availability_checked)
	adapter.interstitial_opened.connect(service._on_interstitial_opened)
	adapter.interstitial_finished.connect(service._on_interstitial_finished)
	root.add_child(service)
	service.configure(save)
	var game: Control = load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.configure("endless", save, null, service)
	root.add_child(game)
	await process_frame
	game.game_controller.set_process(false)
	_expect_true(not adapter.banners.back(), "Countdown has no banner")
	game.game_controller.begin_running()
	_expect_true(adapter.banners.back(), "Running ordinary game shows banner")
	game.game_controller.pause_level()
	_expect_true(not adapter.banners.back(), "Pause hides banner")
	var active_before := service._active_seconds_since_ad
	game.game_controller._process(20.0)
	_expect_true(service._active_seconds_since_ad == active_before, "Pause adds no ad time")
	game.game_controller.resume_level()
	for number in range(1, 6):
		game.spawn_director.stop()
		game.board_controller.clear_all()
		game.game_controller._process(25.0)
		await process_frame
		_expect_true(not adapter.banners.back(), "Round result hides banner")
		var time_before := service._active_seconds_since_ad
		game.game_controller._process(100.0)
		_expect_true(service._active_seconds_since_ad == time_before, "Results add no ad time")
		game.session_overlay.round_continue_requested.emit()
		if number < 5:
			_expect_true(adapter.requests == 0, "No interstitial after ordinary round")
	_expect_true(adapter.requests == 1 and game.game_controller.completed_rounds == 5, "Five real 25-second rounds request one cycle ad")
	game.session_overlay.round_continue_requested.emit()
	_expect_true(adapter.requests == 1, "Results double tap cannot request another ad")
	game.handle_platform_pause()
	adapter.interstitial_finished.emit(true)
	_expect_true(game.round_director.round_index == 5, "Ad close waits for platform resume")
	game.handle_platform_resume()
	await process_frame
	_expect_true(game.round_director.round_index == 6 and adapter.banners.back(), "Provider completion starts round six and restores gameplay banner")
	game.game_controller.is_practice = true
	game.game_controller.start_run(RoundProfile.new(), false, true)
	var before := service._active_seconds_since_ad
	game.game_controller._process(5.0)
	_expect_true(service._active_seconds_since_ad == before and not adapter.banners.back(), "Training has neither banners nor monetization playtime")
	game.queue_free()
	service.queue_free()
	save.delete_save_for_tests()
	save.free()
	await process_frame

func _test_real_router_policy() -> void:
	ProjectSettings.set_setting("clown_smash/testing/save_path", ProjectSettings.globalize_path("res://builds/debug/verification/monetization-policy/router-save.json"))
	var boot: Node = load("res://scenes/boot/Boot.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	boot.save_manager.delete_save_for_tests()
	boot.skip_startup_splash()
	await create_timer(0.30).timeout
	var adapter := PolicyAdapter.new()
	var service: MonetizationService = boot.monetization_service
	service._adapter = adapter
	service._adapter_ready = true
	adapter.ad_availability_checked.connect(service._on_ad_availability_checked)
	adapter.interstitial_finished.connect(service._on_interstitial_finished)
	service.record_active_play(120.0)
	boot.start_run()
	await process_frame
	_expect_true(adapter.requests == 0, "Menu New Game never requests interstitial even when interval is due")
	var short_game: Node = boot._current_screen
	short_game.game_controller.active_elapsed = 119.0
	short_game.game_controller.lives = 0
	short_game.game_controller.finish_run("lives")
	short_game._on_retry_requested()
	await process_frame
	_expect_true(adapter.requests == 0 and boot._current_screen != short_game, "Short defeat restarts without interstitial")
	var long_game: Node = boot._current_screen
	long_game.game_controller.active_elapsed = 120.0
	long_game.game_controller.lives = 0
	long_game.game_controller.finish_run("lives")
	long_game._on_retry_requested()
	long_game._on_retry_requested()
	_expect_true(adapter.requests == 1 and boot._current_screen == long_game, "Long defeat waits for one shared-policy interstitial")
	adapter.interstitial_finished.emit(false)
	await process_frame
	_expect_true(boot._current_screen != long_game and boot._current_screen.game_controller.score == 0, "Failed retry ad opens a clean ordinary run")
	boot.show_main_menu(false)
	_expect_true(not adapter.banners.back(), "Menu hides gameplay banner")
	boot.start_training()
	await process_frame
	_expect_true(not adapter.banners.back() and adapter.requests == 1, "Training entry is free of banners and interstitials")
	boot.save_manager.delete_save_for_tests()
	boot.queue_free()
	await process_frame
