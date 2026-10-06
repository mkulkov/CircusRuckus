extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture_size := _get_capture_size()
	var capture_mode := _get_capture_mode()
	var capture_locale := _get_capture_locale()
	if not capture_locale.is_empty():
		TranslationServer.set_locale(capture_locale)
	root.size = capture_size
	var scene_path := "res://scenes/gameplay/Gameplay.tscn"
	if capture_mode in ["main_menu", "main_menu_remove_ads"]:
		scene_path = "res://scenes/ui/MainMenu.tscn"
	elif capture_mode == "startup_splash":
		scene_path = "res://scenes/ui/StartupSplash.tscn"
	elif capture_mode == "level_select":
		scene_path = "res://scenes/ui/LevelSelect.tscn"
	elif capture_mode == "settings":
		scene_path = "res://scenes/ui/SettingsOverlay.tscn"
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("CAPTURE FAILED: %s did not load" % scene_path)
		quit(1)
		return

	var gameplay := packed_scene.instantiate()
	if capture_mode == "main_menu":
		gameplay.configure({"highest_unlocked_level": 3, "completed_levels": [1, 2]})
	elif capture_mode == "main_menu_remove_ads":
		var monetization := MonetizationService.new()
		monetization._remove_ads_price = "49 YAN"
		root.add_child(monetization)
		gameplay.configure({"highest_unlocked_level": 3, "completed_levels": [1, 2]}, monetization)
	elif capture_mode == "level_select":
		gameplay.configure({"highest_unlocked_level": 4, "completed_levels": [1, 2, 3], "best_scores": {"1": 320, "2": 410, "3": 380}})
	root.add_child(gameplay)
	if capture_mode == "main_menu_remove_ads":
		gameplay._layout()
	if capture_mode == "settings":
		gameplay.open({"music_enabled": true, "sound_enabled": true, "haptics_enabled": true})
		await create_timer(0.25, true).timeout
	elif capture_mode == "startup_splash":
		await create_timer(0.35, true).timeout
	elif capture_mode in ["main_menu", "main_menu_remove_ads", "level_select"]:
		await create_timer(0.25, true).timeout
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
		gameplay.debug_set_level(8)
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		var special_types: Array[StringName] = [&"fast", &"golden", &"bomb", &"clock", &"glutton", &"drunk"]
		for slot_index in range(special_types.size()):
			gameplay.debug_spawn_character(slot_index, special_types[slot_index], 3.4)
		await create_timer(1.15, true).timeout
	elif capture_mode == "hud_status":
		gameplay.debug_set_level(9)
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.hud.set_score(1230)
		gameplay.hud.set_golden_progress(1)
		gameplay.hud.set_confusion(2)
		gameplay.hud.show_feedback("ПУТАНИЦА: 2 УДАРА")
		gameplay.debug_spawn_character(1, &"golden", 3.4)
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
	elif capture_mode in ["result_win", "result_remove_ads"]:
		gameplay.game_controller.begin_running()
		gameplay.spawn_director.stop()
		gameplay.game_controller.finish_level(capture_mode == "result_win")
		await create_timer(0.65, true).timeout
		if capture_mode == "result_remove_ads":
			var settings_scene := load("res://scenes/ui/SettingsOverlay.tscn") as PackedScene
			var settings := settings_scene.instantiate()
			root.add_child(settings)
			settings.open({})
			var remove_ads := settings.get_node("RemoveAdsButton") as Button
			remove_ads.visible = true
			remove_ads.text = tr("REMOVE_ADS")
			settings.queue_redraw()
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
	return "res://verification/%s_%dx%d.png" % [capture_mode, capture_size.x, capture_size.y]
