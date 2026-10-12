extends Node
## Kept outside the removable addon; no compile-time backend dependency.
const BACKEND_PATH := "res://addons/game_analytics/game_analytics.gd"
var _backend: Node
var _pending := 0

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	if not ResourceLoader.exists(BACKEND_PATH):
		return
	var script: Variant = load(BACKEND_PATH)
	if not script is GDScript or not script.can_instantiate() or script.get_instance_base_type() != "Node":
		return
	var instance: Variant = script.new()
	if not instance is Node:
		return
	_backend = instance
	_backend.name = "AnalyticsBackend"
	add_child(_backend)

func track(event_type: Variant, event_data: Variant = {}, action_id: Variant = "") -> void:
	if _pending >= 64 or not is_instance_valid(_backend) or not event_data is Dictionary or event_data.size() > 3:
		return
	# Reject large/nested inputs before copying into the deferred mailbox.
	if not event_type is String or event_type.length() > 32 or not action_id is String or action_id.length() > 32:
		return
	for key in event_data:
		if not key is String or key.length() > 32:
			return
		var value: Variant = event_data[key]
		if typeof(value) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT]:
			return
		if value is String and value.length() > 64:
			return
	_pending += 1
	call_deferred("_dispatch", event_type, event_data.duplicate(true), action_id)

func _dispatch(event_type: Variant, event_data: Variant, action_id: Variant) -> void:
	_pending = maxi(0, _pending - 1)
	if is_instance_valid(_backend) and _backend.has_method("track"):
		_backend.call("track", event_type, event_data, action_id)
