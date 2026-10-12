extends SceneTree
## Run only in a disposable project copy: this suite changes analytics consent/storage.
const BOOT := preload("res://scenes/boot/Boot.tscn")
var failed := 0
var passed := 0
var events: Array = []
var analytics: Node

class PendingAdapter extends MonetizationAdapter:
	func show_interstitial() -> void:
		pass
	func purchase(_product: String) -> void:
		pass


func _init() -> void:
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(label)


func _run() -> void:
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("ClownAnalyticsFixture_"):
		quit(1)
		return
	await process_frame
	await process_frame
	analytics = root.get_node("OptionalAnalytics")._backend
	if analytics != null and not analytics.has_method("configure"): analytics = null
	var scenarios := ["disabled", "debug", "full", "invalid", "corrupt", "storage", "oversized_storage", "http_400", "http_403", "http_413", "http_429", "http_500", "dns", "tls", "timeout", "game_disk"] if analytics != null else ["disabled"]
	if OS.get_environment("ANALYTICS_LIVE") == "1": scenarios = ["live"]
	for scenario in scenarios:
		if analytics != null:
			var cfg := ConfigFile.new()
			cfg.load("res://config/game_analytics.cfg")
			var opts := {}
			for key in cfg.get_section_keys("analytics"): opts[key] = cfg.get_value("analytics", key)
			opts.mode = "production" if scenario == "live" else ("disabled" if scenario == "disabled" else "debug")
			opts.contract_verified = true
			opts.max_queue = 1 if scenario == "full" else 256
			opts.flush_interval = 300.0
			analytics.configure(opts)
			analytics.set_process(false)
			analytics._restore_pending = false
			if scenario == "full": analytics.track("app_start")
			if scenario == "oversized_storage": await oversized_storage()
			if scenario == "invalid": check(not analytics.configure({"mode": 3}), "malformed config fails open")
			if scenario == "corrupt": analytics._restore("broken")
			if scenario == "storage":
				DirAccess.make_dir_absolute(analytics.QUEUE_PATH + ".tmp")
				analytics._start_storage("write")
			if scenario.begins_with("http_") or scenario in ["dns", "tls", "timeout", "game_disk"]:
				opts.mode = "production"
				opts.endpoint = "https://clown-analytics.invalid/events"
				opts.contract_verified = true
				analytics.configure(opts)
				analytics.set_process(false)
				analytics.track("app_start")
				analytics._inflight = analytics._queue.duplicate(true)
				var code := int(scenario.trim_prefix("http_")) if scenario.begins_with("http_") else 0
				var transport: int = {"dns": HTTPRequest.RESULT_CANT_RESOLVE, "tls": HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, "timeout": HTTPRequest.RESULT_TIMEOUT}.get(scenario, HTTPRequest.RESULT_SUCCESS)
				analytics._on_request_completed(transport, code, PackedStringArray(), PackedByteArray())
		await _exercise_application(str(scenario))
		if analytics != null:
			if scenario == "disabled": check(analytics.pending_events().is_empty(), "disabled no events")
			if scenario == "debug":
				var names: Array = analytics.pending_events().map(func(event: Dictionary): return event.event_type)
				check(names.count("level_start") == 3 and names.count("level_complete") == 1 and names.count("level_fail") == 1, "actual attempt and result boundaries")
				check(names.count("level_restart") == 0, "retry boundaries")
				check(names.count("ad_requested") == 1 and names.count("ad_started") == 1 and names.count("ad_failed") == 1, "ad callbacks deduplicated")
				check(names.count("purchase_started") == 2 and names.count("purchase_failed") == 1 and names.count("purchase_completed") == 1, "purchase callback telemetry after fulfilment")
			if scenario == "live": await live_send()
			analytics.configure({"mode":"disabled"})
			DirAccess.remove_absolute(analytics.QUEUE_PATH + ".tmp")
		print("APPLICATION_FAIL_OPEN scenario=%s PASS" % scenario)
	print("ANALYTICS_APPLICATION passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _exercise_application(label: String) -> void:
	var app := BOOT.instantiate()
	var save := app.get_node("SaveManager")
	save.set_save_path_for_tests("user://analytics_application_test.json")
	save.delete_save_for_tests()
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.get_node_or_null("StartupSplash") != null, label + " startup")
	app.skip_startup_splash()
	await create_timer(0.3).timeout
	app.start_run()
	await process_frame
	var disk_failure := label == "game_disk"
	if disk_failure:
		save.set_open_file_for_tests(func(_path: String, _mode: int): return null)
	var gameplay: Node = app._current_screen
	var controller: Node = gameplay.game_controller
	gameplay.spawn_director.stop()
	controller.begin_running()
	check(gameplay.board_controller.spawn_normal(4, 5.0), label + " spawn")
	await create_timer(0.8).timeout
	gameplay.spawn_director.stop()
	gameplay.board_controller.slot_tapped.emit(4)
	await create_timer(0.6).timeout
	check(controller.score == 10 and controller.combo_count == 1, label + " real tap/hammer score")
	controller.remaining_time = 0.0
	controller._process(0.01)
	controller.complete_round() # duplicate callback must not emit another result
	await process_frame
	check(save.load_data().best_run_score == (0 if disk_failure else 10) and save.load_data().best_run_rounds == (0 if disk_failure else 1), label + " round checkpoint honors write result without blocking")
	gameplay._on_retry_requested()
	await process_frame
	gameplay = app._current_screen
	controller = gameplay.game_controller
	controller.begin_running()
	gameplay.spawn_director.stop()
	gameplay.board_controller.clear_all()
	for miss in 9:
		gameplay.hammer_controller._last_strike_time = -10.0
		gameplay.board_controller.slot_tapped.emit(0)
	check(controller.lives == 0 and controller.state == controller.GameState.FINISHED_LOSS, label + " empty strikes finish loss")
	gameplay._on_retry_requested()
	await process_frame
	gameplay = app._current_screen
	controller = gameplay.game_controller
	check(controller.lives == 3 and controller.score == 0, label + " restart resets gameplay")
	var service: MonetizationService = app.monetization_service
	var adapter := PendingAdapter.new()
	adapter.platform_name = "yandex"
	service._adapter = adapter
	service._on_entitlement_restored(false)
	var continued := [0]
	service.show_run_start_ad(func() -> void: continued[0] += 1)
	service._on_interstitial_opened()
	service._on_interstitial_opened()
	service._on_interstitial_finished(false)
	service._on_interstitial_finished(false)
	check(continued[0] == 1, label + " failed Yandex ad continues exactly once")
	service.purchase_remove_ads()
	service._on_purchase_finished(false, "remove_ads")
	service._on_purchase_finished(false, "remove_ads")
	service.purchase_remove_ads()
	service._on_purchase_finished(true, "remove_ads")
	check(service.ads_removed and (disk_failure or save.load_data().ads_removed) and continued[0] == 1, label + " confirmed entitlement/save/pending level continuation")
	service._on_entitlement_restored(false)
	service._on_entitlement_restored(true)
	check(service.ads_removed and (disk_failure or save.load_data().ads_removed), label + " restore fulfilment")
	app.show_main_menu(false)
	check(not paused, label + " menu/input unpaused")
	await create_timer(0.6).timeout
	save.delete_save_for_tests()
	app.queue_free()
	await process_frame


func live_send() -> void:
	var captured: Array = analytics._queue.duplicate(true)
	check(not captured.is_empty(), "actual producer events captured")
	var file := FileAccess.open(OS.get_environment("ANALYTICS_EVIDENCE"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"game_id": analytics.game_id, "events": analytics.pending_events()}, "  "))
	file.close()
	analytics.flush()
	for frame in 2000:
		await create_timer(0.01).timeout
		if analytics.pending_events().is_empty(): break
	check(analytics.pending_events().is_empty(), "real HTTPS batch acknowledged")
	if not analytics.pending_events().is_empty(): return
	await create_timer(2.0).timeout
	analytics._queue = captured.duplicate(true)
	analytics._next_attempt = analytics._clock
	analytics.flush()
	for frame in 2000:
		await create_timer(0.01).timeout
		if analytics.pending_events().is_empty(): break
	check(analytics.pending_events().is_empty(), "exact event IDs retry acknowledged")
	print("LIVE_TRANSPORT events=%d failed=%d" % [captured.size(), failed])

func oversized_storage() -> void:
	for step in 100:
		analytics._poll_storage()
		if analytics._task == -1: break
		await create_timer(0.005).timeout
	var file := FileAccess.open(analytics.QUEUE_PATH, FileAccess.WRITE)
	file.store_string("x".repeat(262145))
	file.close()
	analytics._start_storage("read")
	for step in 100:
		analytics._poll_storage()
		if analytics._task == -1: break
		await create_timer(0.005).timeout
	check(analytics._task == -1 and analytics.pending_events().is_empty(), "oversized spool is bounded and ignored asynchronously")
	DirAccess.remove_absolute(analytics.QUEUE_PATH)

