class_name WebMonetizationAdapter
extends MonetizationAdapter

var _bridge: Variant
var _platform: String = ""
var _initialize_callback: JavaScriptObject
var _restore_callback: JavaScriptObject
var _catalog_callback: JavaScriptObject
var _banner_callback: JavaScriptObject
var _interstitial_opened_callback: JavaScriptObject
var _interstitial_finished_callback: JavaScriptObject
var _purchase_callback: JavaScriptObject
var _availability_callback: JavaScriptObject
var _platform_pause_callback: JavaScriptObject
var _platform_resume_callback: JavaScriptObject


func initialize() -> void:
	if not OS.has_feature("web"):
		initialized.emit(false)
		return
	_bridge = JavaScriptBridge.get_interface("ClownSmashPlatform")
	if _bridge == null:
		initialized.emit(false)
		return
	_bridge.configureVkPayments(str(ProjectSettings.get_setting("monetization/vk/payments_base_url", "")))
	_initialize_callback = JavaScriptBridge.create_callback(_on_initialized)
	_bridge.initialize(_initialize_callback)


func _on_initialized(arguments: Array) -> void:
	var data := _decode_callback_dictionary(arguments)
	_platform = str(data.get("platform", ""))
	platform_name = _platform if not _platform.is_empty() else "web"
	if not _platform.is_empty():
		_platform_pause_callback = JavaScriptBridge.create_callback(_on_platform_pause)
		_platform_resume_callback = JavaScriptBridge.create_callback(_on_platform_resume)
		_bridge.subscribeLifecycle(_platform_pause_callback, _platform_resume_callback)
	initialized.emit(not _platform.is_empty())


func restore_entitlements() -> void:
	if _bridge == null:
		return
	_restore_callback = JavaScriptBridge.create_callback(_on_restored)
	if _platform in ["vk", "ok"]:
		_bridge.subscribeVkEntitlements(_restore_callback)
	_bridge.restorePurchases(_restore_callback)


func load_catalog() -> void:
	if _bridge == null:
		return
	_catalog_callback = JavaScriptBridge.create_callback(_on_catalog_loaded)
	_bridge.loadProductCatalog(_catalog_callback)


func _on_catalog_loaded(arguments: Array) -> void:
	var data := _decode_callback_dictionary(arguments)
	var product_id := str(data.get("product_id", ""))
	if product_id.is_empty():
		return
	product_info_updated.emit(
		product_id,
		str(data.get("title", "")),
		str(data.get("price", "")),
		str(data.get("currency_icon_url", ""))
	)


func notify_game_ready() -> void:
	if _bridge != null:
		_bridge.notifyGameReady()


func set_gameplay_active(active: bool) -> void:
	if _bridge != null:
		_bridge.setGameplayActive(active)


func _on_restored(arguments: Array) -> void:
	var data := _decode_callback_dictionary(arguments)
	if _platform in ["vk", "ok"]:
		if bool(data.get("verified", false)):
			entitlement_restored.emit(bool(data.get("remove_ads", false)))
		return
	if bool(data.get("remove_ads", false)):
		purchase_finished.emit(true, "remove_ads")


func show_banner(visible: bool) -> void:
	if _bridge == null:
		return
	_banner_callback = JavaScriptBridge.create_callback(_on_banner_status)
	_bridge.setBannerVisible(visible, _banner_callback)


func show_interstitial() -> void:
	if _bridge == null:
		interstitial_finished.emit(false)
		return
	_interstitial_opened_callback = JavaScriptBridge.create_callback(_on_interstitial_opened)
	_interstitial_finished_callback = JavaScriptBridge.create_callback(_on_interstitial_finished)
	_bridge.showInterstitial(_interstitial_opened_callback, _interstitial_finished_callback)

func check_ad_availability() -> void:
	if _bridge == null:
		ad_availability_checked.emit(false)
		return
	_availability_callback = JavaScriptBridge.create_callback(_on_ad_availability)
	_bridge.checkAdAvailability(_availability_callback)

func _on_ad_availability(arguments: Array) -> void:
	ad_availability_checked.emit(bool(_decode_callback_dictionary(arguments).get("available", false)))


func _on_interstitial_opened(_arguments: Array) -> void:
	interstitial_opened.emit()


func _on_interstitial_finished(arguments: Array) -> void:
	var data := _decode_callback_dictionary(arguments)
	interstitial_finished.emit(bool(data.get("success", false)))


func purchase(product_id: String) -> void:
	if _bridge == null:
		purchase_finished.emit(false, product_id)
		return
	_purchase_callback = JavaScriptBridge.create_callback(_on_purchase_finished)
	_bridge.purchase(product_id, _purchase_callback)


func _on_purchase_finished(arguments: Array) -> void:
	var data := _decode_callback_dictionary(arguments)
	purchase_finished.emit(bool(data.get("success", false)), str(data.get("product_id", "")))


func _on_platform_pause(_arguments: Array) -> void:
	platform_pause_requested.emit()


func _on_platform_resume(_arguments: Array) -> void:
	platform_resume_requested.emit()


func _on_banner_status(arguments: Array) -> void:
	var data := _decode_callback_dictionary(arguments)
	banner_status_changed.emit(bool(data.get("visible", false)), str(data.get("reason", "")))


func _decode_callback_dictionary(arguments: Array) -> Dictionary:
	if arguments.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(str(arguments[0]))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
