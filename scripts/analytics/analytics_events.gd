extends RefCounted
## Optional delivery is deferred so telemetry cannot interrupt gameplay handlers.

static func new_operation() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func record(event: String, params: Dictionary, operation: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var analytics := tree.root.get_node_or_null("OptionalAnalytics")
	if analytics != null and analytics.has_method("track"):
		analytics.call_deferred("track", event, params, operation)
