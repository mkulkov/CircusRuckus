class_name MonetizationService
extends Node

signal entitlement_changed(ads_removed: bool)
signal purchase_failed
signal product_info_changed
signal platform_pause_requested
signal platform_resume_requested
signal banner_status_changed(visible: bool, reason: String)

const REMOVE_ADS_PRODUCT := "remove_ads"
const AD_PLACEMENT_LEVEL_START := "level_start"

var ads_removed: bool = false
var _purchases_disabled := false
var _save_manager: Node
var _audio_manager: Node
var _adapter: MonetizationAdapter
var _demo_presenter: MonetizationDemoPresenter
var _pending_interstitial: Callable
var _purchase_pending := false
var _audio_muted_for_ad := false
var _music_was_muted := false
var _sfx_was_muted := false
var _game_ready_sent := false
var _adapter_initialization_started := false
var _adapter_ready := false
var _platform_lifecycle_active := false
var _audio_pause_reasons: Dictionary = {}
var _remove_ads_price := ""
var _remove_ads_title := ""
var _remove_ads_currency_icon: Texture2D
var _currency_icon_request: HTTPRequest

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
	_adapter.purchase_finished.connect(_on_purchase_finished)
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
	if _save_manager != null:
		ads_removed = bool(_save_manager.load_data().get("ads_removed", false))
	if _adapter_ready:
		_set_banner_visible(not ads_removed)

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
		_set_banner_visible(true)

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
	return _platform_lifecycle_active


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
	if _adapter == null or (visible and ads_removed):
		return
	_set_banner_visible(visible)

func show_level_start_ad(level_id: int, on_finished: Callable) -> void:
	var first_level_is_ad_free := level_id <= 1
	if ads_removed or first_level_is_ad_free or _adapter == null:
		on_finished.call()
		return
	if _pending_interstitial.is_valid():
		return
	_pending_interstitial = on_finished
	if _demo_presenter != null:
		_demo_presenter.show_interstitial(_adapter.show_interstitial)
	else:
		_adapter.show_interstitial()

func purchase_remove_ads() -> void:
	if _purchases_disabled or ads_removed or _purchase_pending or _adapter == null:
		return
	_purchase_pending = true
	_adapter.purchase(REMOVE_ADS_PRODUCT)

func _on_interstitial_finished(_success: bool) -> void:
	_set_audio_pause_reason(&"interstitial", false)
	var callback := _pending_interstitial
	_pending_interstitial = Callable()
	if callback.is_valid():
		callback.call()

func _on_interstitial_opened() -> void:
	_set_audio_pause_reason(&"interstitial", true)

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
	if should_mute:
		if not _audio_muted_for_ad:
			if music_bus >= 0:
				_music_was_muted = AudioServer.is_bus_mute(music_bus)
			if sfx_bus >= 0:
				_sfx_was_muted = AudioServer.is_bus_mute(sfx_bus)
		if music_bus >= 0:
			AudioServer.set_bus_mute(music_bus, true)
		if sfx_bus >= 0:
			AudioServer.set_bus_mute(sfx_bus, true)
	elif _audio_muted_for_ad:
		if music_bus >= 0:
			AudioServer.set_bus_mute(music_bus, _music_was_muted)
		if sfx_bus >= 0:
			AudioServer.set_bus_mute(sfx_bus, _sfx_was_muted)
	_audio_muted_for_ad = should_mute

func _on_platform_pause_requested() -> void:
	if _platform_lifecycle_active:
		return
	_platform_lifecycle_active = true
	_set_audio_pause_reason(&"platform", true)
	platform_pause_requested.emit()

func _on_platform_resume_requested() -> void:
	if not _platform_lifecycle_active:
		return
	platform_resume_requested.emit()
	_platform_lifecycle_active = false
	_set_audio_pause_reason(&"platform", false)

func _on_banner_status_changed(visible: bool, reason: String) -> void:
	print("[ClownSmash][Ads] Sticky banner visible=%s reason=%s" % [visible, reason])
	banner_status_changed.emit(visible, reason)

func _on_purchase_finished(success: bool, product_id: String) -> void:
	_purchase_pending = false
	if success and product_id == REMOVE_ADS_PRODUCT:
		ads_removed = true
		if _save_manager != null:
			_save_manager.set_ads_removed(true)
		_set_banner_visible(false)
		entitlement_changed.emit(true)
		return
	purchase_failed.emit()


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
