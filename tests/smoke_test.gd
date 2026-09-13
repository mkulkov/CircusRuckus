extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene_path: String = ProjectSettings.get_setting(
		"application/run/main_scene",
		""
	)
	if main_scene_path.is_empty():
		push_error("SMOKE RESULT: FAIL - no main scene configured")
		quit(1)
		return

	var packed_scene := load(main_scene_path) as PackedScene
	if packed_scene == null:
		push_error("SMOKE RESULT: FAIL - cannot load " + main_scene_path)
		quit(1)
		return

	var scene_instance := packed_scene.instantiate()
	root.add_child(scene_instance)
	for frame_index in range(3):
		await process_frame

	if not is_instance_valid(scene_instance):
		push_error("SMOKE RESULT: FAIL - main scene exited unexpectedly")
		quit(1)
		return
	if scene_instance.get_node_or_null("StartupSplash") == null:
		push_error("SMOKE RESULT: FAIL - StartupSplash was not routed on launch")
		quit(1)
		return
	scene_instance.skip_startup_splash()
	await create_timer(0.30).timeout
	if scene_instance.get_node_or_null("MainMenu") == null:
		push_error("SMOKE RESULT: FAIL - MainMenu was not routed after StartupSplash")
		quit(1)
		return

	var menu_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var gameplay_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	var level_one := load("res://data/levels/level_01.tres") as LevelConfig
	if menu_scene == null or gameplay_scene == null or level_one == null:
		push_error("SMOKE RESULT: FAIL - menu, gameplay or Level 1 resource did not load")
		quit(1)
		return
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	if menu.get_node_or_null("PlayButton") == null:
		push_error("SMOKE RESULT: FAIL - MainMenu controls did not instantiate")
		quit(1)
		return
	menu.queue_free()
	await process_frame

	var gameplay := gameplay_scene.instantiate()
	root.add_child(gameplay)
	await process_frame
	gameplay.save_manager.set_save_path_for_tests("user://clown_smash_smoke_test.json")
	gameplay.save_manager.delete_save_for_tests()
	gameplay.spawn_director.deterministic_seed = 1701
	gameplay.spawn_director.stop()
	gameplay.game_controller.begin_running()
	if not gameplay.debug_spawn_normal(4, 3.4):
		push_error("SMOKE RESULT: FAIL - deterministic Normal spawn failed")
		quit(1)
		return
	await create_timer(0.85).timeout
	if not gameplay.debug_tap_slot(4):
		push_error("SMOKE RESULT: FAIL - deterministic tap failed")
		quit(1)
		return
	await create_timer(0.85).timeout
	if gameplay.game_controller.score != 10 or gameplay.game_controller.combo_count != 1:
		push_error("SMOKE RESULT: FAIL - interaction did not produce +10 and combo 1")
		quit(1)
		return
	gameplay.save_manager.delete_save_for_tests()
	gameplay.queue_free()
	await process_frame

	print("SMOKE RESULT: PASS - main, StartupSplash, MainMenu, Gameplay, Level 1 and deterministic interaction")
	scene_instance.queue_free()
	await process_frame
	quit(0)
