extends SceneTree

func _init() -> void:
	ProjectSettings.set_setting("clown_smash/testing/skip_tutorial", true)
	var fixture_dir := ProjectSettings.globalize_path("res://builds/debug/verification/endless/captures")
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	ProjectSettings.set_setting("clown_smash/testing/save_path", fixture_dir.path_join("capture_save.json"))
	call_deferred("_run")


func _run() -> void:
	var capture_size := _get_capture_size()
	var capture_mode := _get_capture_mode()
	var capture_locale := _get_capture_locale()
	if not capture_locale.is_empty():
		TranslationServer.set_locale(capture_locale)
	root.size = capture_size
	var scene_path := "res://scenes/gameplay/Gameplay.tscn"
	if capture_mode == "main_menu":
		scene_path = "res://scenes/ui/MainMenu.tscn"
	elif capture_mode == "statistics":
		scene_path = "res://scenes/ui/Statistics.tscn"
	elif capture_mode == "startup_splash":
		scene_path = "res://scenes/ui/StartupSplash.tscn"
	elif capture_mode == "settings":
		scene_path = "res://scenes/ui/SettingsOverlay.tscn"
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("CAPTURE FAILED: %s did not load" % scene_path)
		quit(1)
		return

	var gameplay := packed_scene.instantiate()
	if capture_mode in ["main_menu", "statistics"]:
		gameplay.configure({"best_run_score": 9007199254740991, "best_run_combo": 9007199254740991, "best_run_rounds": 9007199254740991, "best_run_active_seconds": 45000.0})
	root.add_child(gameplay)
	if capture_mode == "settings":
		gameplay.open({"music_enabled": true, "sound_enabled": true, "haptics_enabled": true})
		await create_timer(0.25, true).timeout
	elif capture_mode == "startup_splash":
		await create_timer(0.35, true).timeout
	elif capture_mode in ["main_menu", "statistics"]:
		await create_timer(0.25, true).timeout
	elif capture_mode == "redesign":
		gameplay.debug_set_round(8)
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.hud.set_score(30)
		gameplay.hud.set_combo(3)
		gameplay.debug_spawn_character(4, &"clock", 3.4)
		await create_timer(1.15, true).timeout
	elif capture_mode == "gameplay":
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.debug_spawn_normal(1, 3.4)
		await create_timer(1.15, true).timeout
	elif capture_mode == "impact":
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.debug_spawn_normal(1, 3.4)
		await create_timer(0.85, true).timeout
		gameplay.debug_tap_slot(1)
		await create_timer(0.225, true).timeout
	elif capture_mode == "impact_fx":
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		var fx: Control = gameplay.get_node("ImpactFxLayer")
		fx.show_score(Vector2(540.0, 850.0), "+10")
		fx.show_score(Vector2(320.0, 1110.0), "+10 СЕК", true)
		fx.show_bomb_confetti(Vector2(760.0, 1090.0))
		await create_timer(0.20, true).timeout
	elif capture_mode == "specials":
		gameplay.debug_set_round(8)
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		var special_types: Array[StringName] = [&"fast", &"golden", &"bomb", &"clock", &"glutton", &"drunk"]
		for slot_index in range(special_types.size()):
			gameplay.debug_spawn_character(slot_index, special_types[slot_index], 3.4)
		await create_timer(1.15, true).timeout
	elif capture_mode == "feedback_warning":
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.hud.set_lives(2)
		gameplay.hud.show_feedback(tr("THREE_MISSES_LIFE"))
		await create_timer(0.20, true).timeout
	elif capture_mode in ["hud_status", "hud_large"]:
		gameplay.debug_set_round(9007199254740991 if capture_mode == "hud_large" else 1000)
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		var big_value := 9007199254740991 if capture_mode == "hud_large" else 1230
		gameplay.hud.set_score(big_value)
		gameplay.hud.set_combo(big_value)
		gameplay.hud.set_run_details(big_value, 19, true)
		gameplay.debug_spawn_character(1, &"golden", 3.4)
		gameplay.hud.set_round(9007199254740991 if capture_mode == "hud_large" else 1000, "peak", "precision")
		await create_timer(1.15, true).timeout
	elif capture_mode in ["tutorial", "tutorial_normal"]:
		gameplay.spawn_director.stop()
		if capture_mode == "tutorial_normal":
			gameplay.session_overlay.show_tutorial(tr("TUTORIAL_NORMAL_TITLE"), tr("TRAINING_MODE_INTRO") + "\n" + tr("TUTORIAL_NORMAL_BODY"), load("res://assets/generated/normal_clown.png"))
		else:
			gameplay.session_overlay.show_tutorial(tr("TUTORIAL_ENDLESS_RULES_TITLE"), tr("TUTORIAL_ENDLESS_RULES_BODY"), load("res://assets/generated/glutton_clown.png"))
		await create_timer(0.15, true).timeout
	elif capture_mode == "training_complete":
		gameplay.spawn_director.stop()
		gameplay.session_overlay.show_training_complete()
		await create_timer(0.15, true).timeout
	elif capture_mode == "round_result":
		gameplay.spawn_director.stop()
		gameplay.session_overlay.show_round_result(10, 120, 870, 8, 2)
		await create_timer(0.15, true).timeout
	elif capture_mode in ["result", "result_large", "result_save_error"]:
		gameplay.spawn_director.stop()
		var value := 9007199254740991 if capture_mode == "result_large" else 850
		gameplay.session_overlay.show_run_result(value, value, value, 45000.0, 650, capture_mode == "result_save_error")
		await create_timer(0.15, true).timeout
	elif capture_mode == "tutorial_advance":
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.session_overlay.show_tutorial_advance(true)
		gameplay.debug_spawn_normal(7, 3.4)
		await create_timer(1.15, true).timeout
	elif capture_mode == "pause":
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.game_controller.pause_level()
		await create_timer(0.15, true).timeout
	elif capture_mode == "countdown_final":
		gameplay.spawn_director.stop()
		gameplay.session_overlay.show_countdown(tr("COUNTDOWN_GO"))
		await create_timer(0.20, true).timeout
	else:
		await create_timer(0.15, true).timeout
	await process_frame
	RenderingServer.force_draw()

	var output_path := _get_output_path(capture_mode, capture_size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("CAPTURE FAILED: active display driver does not expose a viewport texture")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("CAPTURE FAILED: viewport image is unavailable")
		quit(1)
		return
	var error := image.save_png(output_path)
	if error != OK:
		push_error("CAPTURE FAILED: error %d" % error)
		quit(1)
		return

	print("CAPTURE SAVED: ", output_path)
	paused = false
	quit(0)


func _get_capture_size() -> Vector2i:
	var width := 1080
	var height := 1920
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("width="):
			width = argument.trim_prefix("width=").to_int()
		elif argument.begins_with("height="):
			height = argument.trim_prefix("height=").to_int()
	return Vector2i(width, height)


func _get_capture_mode() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("mode="):
			return argument.trim_prefix("mode=")
	return "gameplay"


func _get_capture_locale() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("locale="):
			return argument.trim_prefix("locale=")
	return ""


func _get_output_path(capture_mode: String, capture_size: Vector2i) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output="):
			return argument.trim_prefix("output=")
	return "res://builds/debug/verification/endless/captures/%s_%s_%dx%d.png" % [capture_mode, _get_capture_locale(), capture_size.x, capture_size.y]
