extends Node

signal locale_ready(locale: String)

const SUPPORTED_LOCALES: PackedStringArray = ["ru", "en"]
const FALLBACK_LOCALE := "ru"
const YANDEX_TIMEOUT_MSEC := 2500

var current_locale := FALLBACK_LOCALE
var locale_source := "fallback"
var _platform_callback: JavaScriptObject
var _platform_locale := ""


func initialize() -> void:
	var detected_locale := ""
	if OS.has_feature("web"):
		detected_locale = _detect_vk_locale()
		if not detected_locale.is_empty():
			_apply_locale(detected_locale, "vk_launch_params")
			return
		if _start_platform_detection():
			var started_at := Time.get_ticks_msec()
			while _platform_locale.is_empty() and Time.get_ticks_msec() - started_at < YANDEX_TIMEOUT_MSEC:
				await get_tree().process_frame
			if not _platform_locale.is_empty():
				_apply_locale(_platform_locale, "platform_sdk")
				return

	detected_locale = OS.get_locale_language()
	_apply_locale(detected_locale, "device_locale")


func normalize_locale(locale: String) -> String:
	var normalized := locale.strip_edges().to_lower().replace("_", "-")
	var language := normalized.get_slice("-", 0)
	return language if language in SUPPORTED_LOCALES else FALLBACK_LOCALE


func _detect_vk_locale() -> String:
	var value: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('vk_language') || ''",
		true
	)
	return str(value) if value != null else ""


func _start_platform_detection() -> bool:
	var bridge: Variant = JavaScriptBridge.get_interface("ClownSmashPlatform")
	if bridge == null:
		return false
	_platform_callback = JavaScriptBridge.create_callback(_on_platform_locale)
	bridge.getLocale(_platform_callback)
	return true


func _on_platform_locale(arguments: Array) -> void:
	if not arguments.is_empty():
		_platform_locale = str(arguments[0])


func _apply_locale(locale: String, source: String) -> void:
	current_locale = normalize_locale(locale)
	locale_source = source
	TranslationServer.set_locale(current_locale)
	locale_ready.emit(current_locale)
