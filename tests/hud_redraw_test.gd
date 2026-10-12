extends SceneTree
## Run with a real renderer; optional --baseline measures the preserved pre-refactor HUD.

var redraws := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("HUD redraw measurement requires a rendered window")
		quit(1)
		return
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var path := "res://scripts/ui/gameplay_hud.gd"
	if baseline:
		path = "res://builds/debug/verification/refactor_2026-10-11/before/scripts/ui/gameplay_hud.gd"
	if not ResourceLoader.exists(path):
		push_error("Requested HUD source is unavailable: " + path)
		quit(1)
		return
	TranslationServer.set_locale("ru")
	root.size = Vector2i(720, 1280)
	var hud: Control = load(path).new()
	root.add_child(hud)
	hud.set_process(false)
	hud.draw.connect(func() -> void: redraws += 1)
	hud.set_round(1, "recovery")
	hud.show_feedback("HUD")
	await RenderingServer.frame_post_draw
	redraws = 0
	for frame in range(180):
		hud.set_time(25.0 - float(frame + 1) / 60.0)
		hud._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw
	print("HUD_REDRAWS baseline=", baseline, " frames=180 redraws=", redraws)
	var output := "res://builds/debug/verification/refactor_2026-10-11/hud_%s.png" % ("before" if baseline else "after")
	var error := root.get_texture().get_image().save_png(output)
	var passed := error == OK and (baseline or redraws <= 5)
	print("HUD REDRAW ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
