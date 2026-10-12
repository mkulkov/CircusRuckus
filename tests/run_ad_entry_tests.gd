extends "res://tests/run_tests.gd"


func _run() -> void:
	await _test_vk_ad_gate()
	if _failures == 0:
		print("AD ENTRY TEST RESULT: PASS")
		quit(0)
	else:
		push_error("AD ENTRY TEST RESULT: FAIL (%d failure(s))" % _failures)
		quit(1)
