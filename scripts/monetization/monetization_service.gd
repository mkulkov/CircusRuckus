class_name MonetizationService
extends Node

signal entitlement_changed(ads_removed: bool)
signal purchase_failed
signal product_info_changed
signal platform_pause_requested
signal platform_resume_requested
signal banner_status_changed(visible: bool, reason: String)

const REMOVE_ADS_PRODUCT := "remove_ads"
const AD_PLACEMENT_CYCLE_END := "cycle_end"
const AD_PLACEMENT_LOSS_RETRY := "loss_retry"
const ANALYTICS := preload("res://scripts/analytics/analytics_events.gd")

var ads_removed: bool = false
var _purchases_disabled := false
var _save_manager: Node
var _audio_manager: Node
var _adapter: MonetizationAdapter
var _demo_presenter: MonetizationDemoPresenter
var _banner_allowed := false
var _active_seconds_since_ad := 0.0
var _last_ad_attempt_msec := -60000
var _ad_request_generation := 0
var _pending_placement := ""
var _pending_interstitial: Callable
var _pending_run_ad_eligible := false
var _pending_ad_show_started := false
var _purchase_pending := false
var _game_ready_sent := false
var _adapter_initialization_started := false
var _adapter_ready := false
var _lifecycle_pause_reasons: Dictionary = {}
var _audio_pause_reasons: Dictionary = {}
var _remove_ads_price := ""
var _remove_ads_title := ""
var _remove_ads_currency_icon: Texture2D
var _currency_icon_request: HTTPRequest
var _analytics_ad_operation := ""
var _analytics_purchase_operation := ""

func configure(save_manager: Node, audio_manager: Node = null) -> void:
	_save_manager = save_manager
	_audio_manager = audio_manager
	refresh_saved_state()
	if is_inside_tree():
		_start_adapter()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_purchases_disabled = OS.has_feature("no_purchases")
	_prepare_adapter()
	if _save_manager != null:
		_start_adapter()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_set_lifecycle_pause_reason(&"application", true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_set_lifecycle_pause_reason(&"application", false)

func _prepare_adapter() -> void:
	if _adapter != null:
		return
	_adapter = _select_adapter()
	if OS.has_feature("monetization_demo"):
		_demo_presenter = MonetizationDemoPresenter.new()
		add_child(_demo_presenter)
	_adapter.initialized.connect(_on_adapter_initialized)
	_adapter.interstitial_opened.connect(_on_interstitial_opened)
	_adapter.interstitial_finished.connect(_on_interstitial_finished)
	_adapter.ad_availability_checked.connect(_on_ad_availability_checked)
	_adapter.purchase_finished.connect(_on_purchase_finished)
	_adapter.entitlement_restored.connect(_on_entitlement_restored)
	_adapter.product_info_updated.connect(_on_product_info_updated)
	_adapter.platform_pause_requested.connect(_on_platform_pause_requested)
	_adapter.platform_resume_requested.connect(_on_platform_resume_requested)
	_adapter.banner_status_changed.connect(_on_banner_status_changed)

func _start_adapter() -> void:
	_prepare_adapter()
	if _adapter_initialization_started:
		return
	_adapter_initialization_started = true
	_adapter.initialize()

func refresh_saved_state() -> void:
	# VK rights belong to the authenticated account and payment mode, not browser storage.
	if _save_manager != null and not (OS.has_feature("vk_mini_apps") and not OS.has_feature("monetization_demo")):
		ads_removed = bool(_save_manager.load_data().get("ads_removed", false))
	if _adapter_ready:
		_set_banner_visible(_banner_allowed and not ads_removed)

func _select_adapter() -> MonetizationAdapter:
	if OS.has_feature("monetization_demo"):
		var demo_adapter := DebugMonetizationAdapter.new()
		demo_adapter.virtual_purchase_success = true
		return demo_adapter
	if OS.has_feature("yandex_games") or OS.has_feature("vk_mini_apps"):
		return WebMonetizationAdapter.new()
	if OS.has_feature("android"):
		return RuStoreMonetizationAdapter.new()
	return DebugMonetizationAdapter.new()

func _on_adapter_initialized(success: bool) -> void:
	if not success:
		return
	_adapter_ready = true
	if not _purchases_disabled:
		_adapter.load_catalog()
		_adapter.restore_entitlements()
	if not ads_removed:
		_set_banner_visible(_banner_allowed)

func is_ads_removed() -> bool:
	return ads_removed

func notify_game_ready() -> void:
	if _game_ready_sent or _adapter == null:
		return
	_game_ready_sent = true
	_adapter.notify_game_ready()

func set_gameplay_active(active: bool) -> void:
	if _adapter != null:
		_adapter.set_gameplay_active(active)

func is_platform_lifecycle_active() -> bool:
	return not _lifecycle_pause_reasons.is_empty()


func are_purchases_enabled() -> bool:
	return not _purchases_disabled


func is_remove_ads_offer_available() -> bool:
	if _purchases_disabled:
		return false
	return not _remove_ads_title.is_empty() and not _remove_ads_price.is_empty()


func get_remove_ads_price() -> String:
	return _remove_ads_price

func get_remove_ads_title() -> String:
	return _remove_ads_title


func get_remove_ads_currency_icon() -> Texture2D:
	return _remove_ads_currency_icon

func show_banner(visible: bool = true) -> void:
	_banner_allowed = visible
	if _adapter != null:
		_set_banner_visible(visible and not ads_removed)

func record_active_play(elapsed: float) -> void:
	if is_finite(elapsed) and elapsed > 0.0:
		_active_seconds_since_ad = minf(_active_seconds_since_ad + elapsed, 604800.0)

func show_transition_ad(placement: String, on_finished: Callable, completed_rounds: int = 0, run_seconds: float = 0.0) -> void:
	if _pending_interstitial.is_valid():
		return
	var interval := maxf(float(ProjectSettings.get_setting("monetization/policy/active_interval_seconds", 120.0)), 120.0)
	var cycle_length := maxi(int(ProjectSettings.get_setting("monetization/policy/cycle_rounds", 5)), 1)
	var valid_placement := (placement == AD_PLACEMENT_CYCLE_END and completed_rounds > 0 and completed_rounds % cycle_length == 0) or (placement == AD_PLACEMENT_LOSS_RETRY and run_seconds >= interval)
	var retry_msec := int(maxf(float(ProjectSettings.get_setting("monetization/policy/retry_backoff_seconds", 60.0)), 30.0) * 1000.0)
	if not valid_placement or ads_removed or not _adapter_ready or _active_seconds_since_ad < interval or Time.get_ticks_msec() - _last_ad_attempt_msec < retry_msec:
		on_finished.call()
		return
	_last_ad_attempt_msec = Time.get_ticks_msec()
	_pending_placement = placement
	show_run_start_ad(on_finished)

func _watch_ad_request(generation: int) -> void:
	await get_tree().create_timer(maxf(float(ProjectSettings.get_setting("monetization/policy/request_timeout_seconds", 30.0)), 1.0), true, false, true).timeout
	if generation != _ad_request_generation or not _pending_interstitial.is_valid():
		return
	# An opened provider owns its close callback; never resume under a visible ad.
	if _audio_pause_reasons.has(&"interstitial"):
		return
	_adapter.cancel_ad_request()
	_set_audio_pause_reason(&"interstitial", false)
	_complete_pending_run()

func show_run_start_ad(on_finished: Callable, ad_free: bool = false) -> void:
	if ads_removed or _adapter == null or ad_free:
		on_finished.call()
		return
	if _pending_interstitial.is_valid():
		return
	_pending_interstitial = on_finished
	_ad_request_generation += 1
	if is_inside_tree():
		_watch_ad_request(_ad_request_generation)
	_pending_run_ad_eligible = true
	if _adapter.platform_name in ["vk", "ok"]:
		_adapter.check_ad_availability()
		return
	_show_pending_interstitial()

func _on_ad_availability_checked(available: bool) -> void:
	if not _pending_interstitial.is_valid() or _pending_ad_show_started:
		return
	if ads_removed or not available or not _pending_run_ad_eligible:
		_complete_pending_run()
	else:
		_show_pending_interstitial()

func _show_pending_interstitial() -> void:
	if _pending_ad_show_started:
		return
	_pending_ad_show_started = true
	_analytics_ad_operation = ANALYTICS.new_operation()
	ANALYTICS.record("ad_requested", {"placement": "default", "ad_type": "interstitial"}, _analytics_ad_operation)
	if _demo_presenter != null:
		_demo_presenter.show_interstitial(_adapter.show_interstitial)
	else:
		_adapter.show_interstitial()

func purchase_remove_ads() -> void:
	if _purchases_disabled or ads_removed or _purchase_pending or _adapter == null:
		return
	_purchase_pending = true
	_analytics_purchase_operation = ANALYTICS.new_operation()
	ANALYTICS.record("purchase_started", {"product_id": REMOVE_ADS_PRODUCT}, _analytics_purchase_operation)
	_adapter.purchase(REMOVE_ADS_PRODUCT)

func _on_interstitial_finished(success: bool) -> void:
	if not _pending_interstitial.is_valid() or not _pending_ad_show_started:
		return
	if success:
		_active_seconds_since_ad = 0.0
	var operation := _analytics_ad_operation
	_analytics_ad_operation = ""
	_set_audio_pause_reason(&"interstitial", false)
	_complete_pending_run()
	_record_ad_failure(success, operation)


func _record_ad_failure(success: bool, operation: String) -> void:
	if not success and not operation.is_empty():
		ANALYTICS.record("ad_failed", {"placement": "default", "reason": "error"}, operation)

func cancel_pending_run() -> void:
	_ad_request_generation += 1
	_set_audio_pause_reason(&"interstitial", false)
	if _adapter != null:
		_adapter.cancel_ad_request()
	_pending_interstitial = Callable()
	_pending_run_ad_eligible = false
	_pending_ad_show_started = false
	_analytics_ad_operation = ""

func continue_pending_run_after_purchase() -> void:
	if ads_removed and not _audio_pause_reasons.has(&"interstitial"):
		if _adapter != null:
			_adapter.cancel_ad_request()
		_complete_pending_run()

func _complete_pending_run() -> void:
	_ad_request_generation += 1
	_pending_placement = ""
	var callback := _pending_interstitial
	_pending_interstitial = Callable()
	_pending_run_ad_eligible = false
	_pending_ad_show_started = false
	if callback.is_valid():
		callback.call()

func _on_interstitial_opened() -> void:
	if not _pending_interstitial.is_valid() or not _pending_ad_show_started:
		return
	_set_audio_pause_reason(&"interstitial", true)
	# Only Yandex forwards SDK onOpen. Android/VK announce before showing.
	if _adapter != null and _adapter.platform_name == "yandex" and not _analytics_ad_operation.is_empty():
		ANALYTICS.record("ad_started", {"placement": "default", "ad_type": "interstitial"}, _analytics_ad_operation)

func _set_audio_pause_reason(reason: StringName, active: bool) -> void:
	if active:
		_audio_pause_reasons[reason] = true
	else:
		_audio_pause_reasons.erase(reason)
	refresh_audio_pause_state()

func refresh_audio_pause_state() -> void:
	var should_mute := not _audio_pause_reasons.is_empty()
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	var music_enabled := true
	var sound_enabled := true
	if _audio_manager != null:
		music_enabled = bool(_audio_manager.get("music_enabled"))
		sound_enabled = bool(_audio_manager.get("sound_enabled"))
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, should_mute or not music_enabled)
	if sfx_bus >= 0:
		AudioServer.set_bus_mute(sfx_bus, should_mute or not sound_enabled)

func _on_platform_pause_requested() -> void:
	_set_lifecycle_pause_reason(&"platform", true)

func _on_platform_resume_requested() -> void:
	_set_lifecycle_pause_reason(&"platform", false)

func _set_lifecycle_pause_reason(reason: StringName, active: bool) -> void:
	var was_paused := not _lifecycle_pause_reasons.is_empty()
	if active == _lifecycle_pause_reasons.has(reason):
		return
	if active:
		_lifecycle_pause_reasons[reason] = true
	else:
		_lifecycle_pause_reasons.erase(reason)
	_set_audio_pause_reason(reason, active)
	var is_paused := not _lifecycle_pause_reasons.is_empty()
	if was_paused == is_paused:
		return
	if is_paused:
		platform_pause_requested.emit()
	else:
		platform_resume_requested.emit()

func _on_banner_status_changed(visible: bool, reason: String) -> void:
	print("[ClownSmash][Ads] Sticky banner visible=%s reason=%s" % [visible, reason])
	banner_status_changed.emit(visible, reason)

func _on_purchase_finished(success: bool, product_id: String) -> void:
	var operation := _analytics_purchase_operation
	_analytics_purchase_operation = ""
	_purchase_pending = false
	if success and product_id == REMOVE_ADS_PRODUCT:
		ads_removed = true
		if _save_manager != null:
			_save_manager.set_ads_removed(true)
		_set_banner_visible(false)
		entitlement_changed.emit(true)
		continue_pending_run_after_purchase()
		if not operation.is_empty():
			ANALYTICS.record("purchase_completed", {"product_id": REMOVE_ADS_PRODUCT}, operation)
		return
	purchase_failed.emit()
	if not operation.is_empty():
		ANALYTICS.record("purchase_failed", {"product_id": REMOVE_ADS_PRODUCT, "reason": "error"}, operation)


func _on_entitlement_restored(owned: bool) -> void:
	ads_removed = owned
	if _save_manager != null:
		_save_manager.set_ads_removed(owned)
	_set_banner_visible(_banner_allowed and not owned)
	entitlement_changed.emit(owned)
	if owned:
		continue_pending_run_after_purchase()


func _on_product_info_updated(product_id: String, title: String, price: String, currency_icon_url: String) -> void:
	if product_id != REMOVE_ADS_PRODUCT or title.strip_edges().is_empty() or price.is_empty():
		return
	_remove_ads_title = title.strip_edges()
	_remove_ads_price = price
	product_info_changed.emit()
	if currency_icon_url.is_empty() or not is_inside_tree():
		return
	if _currency_icon_request != null:
		_currency_icon_request.queue_free()
	_currency_icon_request = HTTPRequest.new()
	add_child(_currency_icon_request)
	_currency_icon_request.request_completed.connect(_on_currency_icon_downloaded)
	var request_error := _currency_icon_request.request(currency_icon_url)
	if request_error != OK:
		_currency_icon_request.queue_free()
		_currency_icon_request = null


func _on_currency_icon_downloaded(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if _currency_icon_request != null:
		_currency_icon_request.queue_free()
		_currency_icon_request = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var image := Image.new()
	var load_error := image.load_png_from_buffer(body)
	if load_error != OK:
		load_error = image.load_webp_from_buffer(body)
	if load_error != OK:
		load_error = image.load_svg_from_buffer(body)
	if load_error != OK:
		return
	_remove_ads_currency_icon = ImageTexture.create_from_image(image)
	product_info_changed.emit()


func _set_banner_visible(visible: bool) -> void:
	_adapter.show_banner(visible)
	if _demo_presenter != null:
		_demo_presenter.set_banner_visible(visible)
