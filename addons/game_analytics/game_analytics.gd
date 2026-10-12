extends Node
## Optional backend: no user/device/installation/account/session identity.
const VERSION := "2.0.0"
const CONFIG_PATH := "res://config/game_analytics.cfg"
const QUEUE_PATH := "user://minimal_analytics_v2.json"
const ENDPOINT_TEMPLATE := "https://game-analitics.mkulkov.ru/v1/ingest/{game_id}/{platform}/{app_version}"
const ENVELOPE := ["game_id", "platform", "app_version", "os", "event_type", "event_id", "event_data"]
const SCHEMA := {
	"app_start": {}, "session_start": {"reason": "reason"},
	"session_end": {"reason": "reason", "duration_sec": "duration"},
	"tutorial_completed": {"tutorial_id": "index"},
	"level_start": {"level_id": "index", "difficulty": "difficulty"},
	"level_complete": {"level_id": "index", "duration_sec": "duration"},
	"level_fail": {"level_id": "index", "reason": "reason"},
	"level_restart": {"level_id": "index"}, "difficulty_changed": {"difficulty": "difficulty"},
	"hint_requested": {"level_id": "index", "hint_id": "hint"},
	"hint_used": {"level_id": "index", "hint_id": "hint"},
	"ad_requested": {"placement": "placement", "ad_type": "ad_type"},
	"ad_started": {"placement": "placement", "ad_type": "ad_type"},
	"ad_completed": {"placement": "placement", "ad_type": "ad_type"},
	"ad_failed": {"placement": "placement", "reason": "reason"},
	"purchase_started": {"product_id": "product"},
	"purchase_completed": {"product_id": "product"},
	"purchase_failed": {"product_id": "product", "reason": "reason"},
}
const ENUMS := {
	"reason": ["launch", "foreground", "background", "exit", "completed", "failed", "cancelled", "unavailable", "timeout", "error", "out_of_moves"],
	"difficulty": ["easy", "normal", "hard", "expert"],
	"hint": ["default", "reveal", "suggest", "undo"],
	"placement": ["default", "level_end", "hint", "restart", "menu"],
	"ad_type": ["rewarded", "interstitial"],
}
var mode := "disabled"
var endpoint := ""
var game_id := ""
var platform := ""
var app_version := ""
var max_queue := 256
var batch_size := 32
var flush_interval := 5.0
var retention_days := 7
var product_ids: Array = []
var _queue: Array = []
var _seen: Dictionary = {}
var _http: HTTPRequest
var _inflight: Array = []
var _clock := 0.0
var _next_attempt := 5.0
var _failures := 0
var _dirty := false
var _storage_clock := 0.0
var _task := -1
var _task_result: Array = []
var _task_kind := ""
var _generation := 0
var _task_generation := 0
var _wipe_pending := false
var _restore_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	_http.body_size_limit = 65536
	_http.max_redirects = 0
	_http.use_threads = not OS.has_feature("web")
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK and cfg.has_section("analytics"):
		var options := {}
		for key in cfg.get_section_keys("analytics"):
			options[key] = cfg.get_value("analytics", key)
		configure(options)

func configure(options: Variant) -> bool:
	# An invalid configuration must disable a previously active backend.
	_disable()
	if not options is Dictionary:
		return false
	var requested: Variant = options.get("mode", "disabled")
	if not requested is String or requested not in ["disabled", "debug", "production"]:
		return false
	if requested == "disabled":
		return true
	if not _hex_id(options.get("game_id")) or not _token(options.get("app_version")):
		return false
	if options.get("platform") not in ["windows", "linux", "macos", "android", "ios", "web", "rustore", "vk", "yandex", "ok"]:
		return false
	var target: Variant = options.get("endpoint", ENDPOINT_TEMPLATE)
	if target is String:
		target = target.format({"game_id": options.game_id, "platform": options.platform, "app_version": options.app_version})
	if requested == "production" and (not _https_url(target) or typeof(options.get("contract_verified")) != TYPE_BOOL or options.contract_verified != true):
		return false
	for key in ["max_queue", "batch_size", "retention_days"]:
		if options.has(key) and typeof(options[key]) != TYPE_INT:
			return false
	if options.has("flush_interval") and (typeof(options.flush_interval) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(options.flush_interval))):
		return false
	var products: Variant = options.get("product_ids", [])
	if not products is Array or products.size() > 64:
		return false
	for item in products:
		if not _token(item):
			return false
	game_id = options.game_id
	platform = options.platform
	app_version = options.app_version
	endpoint = target if target is String else ""
	product_ids = products.duplicate()
	max_queue = clampi(options.get("max_queue", 256), 1, 256)
	batch_size = clampi(options.get("batch_size", 32), 1, mini(32, max_queue))
	retention_days = clampi(options.get("retention_days", 7), 1, 7)
	flush_interval = clampf(options.get("flush_interval", 5.0), 1.0, 300.0)
	mode = requested
	_restore_pending = mode == "production" and not OS.has_feature("web")
	_wipe_pending = mode != "production" and not OS.has_feature("web")
	_next_attempt = _clock + flush_interval
	return true

func _disable() -> void:
	_generation += 1
	mode = "disabled"
	if is_instance_valid(_http):
		_http.cancel_request()
	_inflight.clear()
	_queue.clear()
	_seen.clear()
	_dirty = false
	_failures = 0
	_restore_pending = false
	_wipe_pending = not OS.has_feature("web")

func track(event_type: Variant, event_data: Variant = {}, action_id: Variant = "") -> bool:
	if mode == "disabled" or not _valid_data(event_type, event_data):
		return false
	# Only fresh random action IDs; never raw or hashed platform/provider IDs.
	if not action_id is String or (not action_id.is_empty() and not _hex_id(action_id)):
		return false
	var key: String = event_type + ":" + action_id if not action_id.is_empty() else ""
	if not key.is_empty() and _seen.has(key):
		return false
	_prune()
	if _queue.size() >= max_queue:
		return false
	var event_id := Crypto.new().generate_random_bytes(16).hex_encode()
	if not _hex_id(event_id):
		return false
	var event := {"game_id": game_id, "platform": platform, "app_version": app_version,
		"os": _operating_system(), "event_type": event_type, "event_id": event_id,
		"event_data": event_data.duplicate(true)}
	_queue.append({"event": event, "created": int(Time.get_unix_time_from_system())})
	if not key.is_empty():
		_seen[key] = true
		while _seen.size() > 1024:
			_seen.erase(_seen.keys()[0])
	_dirty = mode == "production"
	return true

func _valid_data(event_type: Variant, data: Variant) -> bool:
	if not event_type is String or not SCHEMA.has(event_type) or not data is Dictionary:
		return false
	var fields: Dictionary = SCHEMA[event_type]
	if data.size() != fields.size():
		return false
	for key in fields:
		if not data.has(key):
			return false
		var value: Variant = data[key]
		match fields[key]:
			"index":
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(float(value)) or value < 0 or value > 1000000:
					return false
			"duration":
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < 0 or value > 604800:
					return false
			"product":
				if not value is String or value not in product_ids:
					return false
			_:
				if not value is String or value not in ENUMS[fields[key]]:
					return false
	return true

func _operating_system() -> String:
	if OS.has_feature("web"):
		return "web_unknown" # No navigator/user agent/screen/font/hardware probing.
	var names := {"Windows": "windows", "Linux": "linux", "macOS": "macos", "Android": "android", "iOS": "ios"}
	return names.get(OS.get_name(), "unknown")

func _process(delta: float) -> void:
	_clock += delta
	_storage_clock += delta
	_poll_storage()
	if _task == -1 and not OS.has_feature("web"):
		if _wipe_pending:
			_start_storage("wipe")
		elif _restore_pending:
			_start_storage("read")
		elif mode == "production" and _dirty and _storage_clock >= 2.0:
			_start_storage("write")
	if _clock >= _next_attempt:
		flush()

func flush() -> void:
	_next_attempt = _clock + flush_interval
	if mode != "production" or not is_instance_valid(_http) or not _inflight.is_empty():
		return
	_prune()
	if _queue.is_empty():
		return
	_inflight = _queue.slice(0, batch_size).duplicate(true)
	var events: Array = []
	for item in _inflight:
		events.append(item.event)
	var error := _http.request(endpoint, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"events": events}))
	if error != OK:
		_on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if _inflight.is_empty():
		return
	# Verified collector must durably acknowledge the whole batch on 2xx.
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		var delivered := {}
		for item in _inflight:
			delivered[item.event.event_id] = true
		_queue = _queue.filter(func(item: Dictionary) -> bool: return not delivered.has(item.event.event_id))
		_failures = 0
		_dirty = true
	else:
		_failures = mini(_failures + 1, 8)
		_next_attempt = _clock + minf(300.0, pow(2.0, _failures) * flush_interval)
	_inflight.clear()

func pending_events() -> Array:
	var events: Array = []
	for item in _queue:
		events.append(item.event.duplicate(true))
	return events

func _prune() -> void:
	var now := int(Time.get_unix_time_from_system())
	var old_size := _queue.size()
	_queue = _queue.filter(func(item: Dictionary) -> bool: return item.created >= now - retention_days * 86400 and item.created <= now + 300)
	if _queue.size() != old_size:
		_dirty = mode == "production"

func _start_storage(kind: String) -> void:
	_task_result = []
	_task_generation = _generation
	_task_kind = kind
	var snapshot := ""
	if kind == "write":
		snapshot = JSON.stringify({"binding": _binding(), "queue": _queue})
		_dirty = false
	_task = WorkerThreadPool.add_task(_storage_worker.bind(kind, snapshot, _task_result))
	_storage_clock = 0.0
	if kind == "wipe":
		_wipe_pending = false
	if kind == "read":
		_restore_pending = false

static func _storage_worker(kind: String, snapshot: String, result: Array) -> void:
	if kind == "wipe":
		for path in [QUEUE_PATH, QUEUE_PATH + ".tmp"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		result.append(null)
		return
	if kind == "read":
		var data: Variant = null
		if FileAccess.file_exists(QUEUE_PATH):
			var file := FileAccess.open(QUEUE_PATH, FileAccess.READ)
			if file != null:
				if file.get_length() <= 262144:
					var parser := JSON.new()
					if parser.parse(file.get_as_text()) == OK:
						data = parser.data
				file.close()
		result.append(data)
		return
	var file := FileAccess.open(QUEUE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		result.append(false)
		return
	file.store_string(snapshot)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(QUEUE_PATH + ".tmp", QUEUE_PATH)
	result.append(error == OK)

func _poll_storage() -> void:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return
	# Reap only completed tasks: no blocking disk waits in gameplay/configure/exit.
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if _task_generation == _generation and not _task_result.is_empty():
		if _task_kind == "read" and mode == "production":
			_restore(_task_result[0])
		elif _task_kind == "write" and _task_result[0] == false:
			_dirty = mode == "production"
	_task_result.clear()

func _binding() -> String:
	return (endpoint + "|" + game_id + "|" + platform + "|" + app_version).sha256_text()

func _restore(data: Variant) -> void:
	if not data is Dictionary or data.get("binding") != _binding() or not data.get("queue") is Array:
		return
	var known := {}
	for item in _queue:
		known[item.event.event_id] = true
	for item in data.queue.slice(0, 256):
		if _queue.size() >= max_queue:
			break
		if not item is Dictionary or typeof(item.get("created")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(item.created)):
			continue
		var event: Variant = item.get("event")
		if not event is Dictionary or event.size() != ENVELOPE.size():
			continue
		var complete := true
		for key in ENVELOPE:
			if not event.has(key):
				complete = false
		if not complete or not _hex_id(event.event_id) or known.has(event.event_id):
			continue
		if event.game_id != game_id or event.platform != platform or event.app_version != app_version or event.os != _operating_system():
			continue
		if not _valid_data(event.event_type, event.event_data):
			continue
		_queue.append({"event": event.duplicate(true), "created": int(item.created)})
		known[event.event_id] = true
	_prune()

func _exit_tree() -> void:
	if is_instance_valid(_http):
		_http.cancel_request()
	# Best effort persistence: abrupt close may lose recent unsaved events.

static func _hex_id(value: Variant) -> bool:
	if not value is String or value.length() != 32:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func _token(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64:
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-":
			return false
	return true

static func _https_url(value: Variant) -> bool:
	if not value is String or not value.begins_with("https://") or value.length() > 512:
		return false
	var authority: String = value.trim_prefix("https://").split("/")[0]
	return not authority.is_empty() and "@" not in value and "?" not in value and "#" not in value and "{" not in value and "}" not in value and " " not in value and "\n" not in value and "\r" not in value and "\t" not in value
