extends "res://tests/run_tests.gd"
func _run() -> void:
	await _test_scene_router_flow()
	print("TRAINING START ROUTE ", "PASS" if _failures == 0 else "FAIL")
	quit(0 if _failures == 0 else 1)
