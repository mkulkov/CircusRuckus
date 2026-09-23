extends SceneTree

const CAPTURE_SECONDS := 25.0
const CHARACTER_SEQUENCE: Array[StringName] = [
	&"normal", &"fast", &"golden", &"clock", &"glutton", &"normal",
	&"bomb", &"golden", &"clock", &"normal", &"glutton", &"fast",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("en")
	root.size = Vector2i(1080, 1920)
	var packed_scene := load("res://scenes/gameplay/Gameplay.tscn") as PackedScene
	if packed_scene == null:
		push_error("VIDEO CAPTURE FAILED: gameplay scene did not load")
		quit(1)
		return

	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	gameplay.debug_set_level(8)
	gameplay.game_controller.begin_running()
	gameplay.spawn_director.stop()
	await create_timer(1.0, true).timeout

	var elapsed := 1.0
	var sequence_index := 0
	while elapsed < CAPTURE_SECONDS - 1.0:
		var slot_index := (sequence_index * 5 + 1) % 9
		var character_type := CHARACTER_SEQUENCE[sequence_index % CHARACTER_SEQUENCE.size()]
		gameplay.debug_spawn_character(slot_index, character_type, 1.35)
		await create_timer(0.62, true).timeout
		gameplay.debug_tap_slot(slot_index)
		await create_timer(0.88, true).timeout
		elapsed += 1.5
		sequence_index += 1

	await create_timer(1.0, true).timeout
	quit(0)
