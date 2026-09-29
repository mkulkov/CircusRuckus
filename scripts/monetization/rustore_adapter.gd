class_name RuStoreMonetizationAdapter
extends MonetizationAdapter

const REMOVE_ADS_PRODUCT := "remove_ads"
const ADS_SINGLETON := "GodotAndroidYandexAds"
const DEMO_BANNER_ID := "demo-banner-yandex"
const DEMO_INTERSTITIAL_ID := "demo-interstitial-yandex"

var _pay_client: RuStoreGodotPayClient
var _ads: Object
var _banner_requested := false
var _interstitial_requested := false

func _init() -> void:
	platform_name = "rustore"

func initialize() -> void:
	if not Engine.has_singleton("RuStoreGodotPay"):
		initialized.emit(false)
		return
	_pay_client = RuStoreGodotPayClient.get_instance()
	_pay_client.on_get_products_success.connect(_on_get_products_success)
	_pay_client.on_get_products_failure.connect(_on_get_products_failure)
	_pay_client.on_purchase_success.connect(_on_purchase_success)
	_pay_client.on_purchase_failure.connect(_on_purchase_failure)
	_pay_client.on_get_purchases_success.connect(_on_get_purchases_success)
	_pay_client.on_get_purchases_failure.connect(_on_get_purchases_failure)
	if Engine.has_singleton(ADS_SINGLETON):
		_ads = Engine.get_singleton(ADS_SINGLETON)
		_ads._on_banner_loaded.connect(_on_banner_loaded)
		_ads._on_banner_failed_to_load.connect(_on_banner_failed)
		_ads._on_interstitial_loaded.connect(_on_interstitial_loaded)
		_ads._on_interstitial_failed_to_load.connect(_on_interstitial_failed)
		_ads._on_interstitial_ad_dismissed.connect(_on_interstitial_closed)
		_ads.init(str(ProjectSettings.get_setting("monetization/rustore/yandex_appmetrica_api_key", "")))
	initialized.emit(true)

func restore_entitlements() -> void:
	if _pay_client != null:
		_pay_client.get_purchases()

func load_catalog() -> void:
	if _pay_client == null:
		return
	var product_ids: Array[RuStorePayProductId] = [RuStorePayProductId.new(REMOVE_ADS_PRODUCT)]
	_pay_client.get_products(product_ids)

func show_banner(visible: bool) -> void:
	if _ads == null:
		banner_status_changed.emit(false, "ads_sdk_unavailable")
		return
	if not visible:
		_ads.hideBanner()
		banner_status_changed.emit(false, "hidden")
		return
	var banner_id := _get_banner_id()
	if banner_id.is_empty():
		banner_status_changed.emit(false, "banner_id_missing")
		return
	_banner_requested = true
	_ads.loadBanner(banner_id, false, 0, 0)

func show_interstitial() -> void:
	if _ads == null:
		interstitial_finished.emit(false)
		return
	var interstitial_id := _get_interstitial_id()
	if interstitial_id.is_empty():
		interstitial_finished.emit(false)
		return
	_interstitial_requested = true
	_ads.loadInterstitial(interstitial_id)

func _get_banner_id() -> String:
	if OS.has_feature("yandex_ads_demo"):
		return DEMO_BANNER_ID
	return str(ProjectSettings.get_setting("monetization/rustore/yandex_banner_id", ""))

func _get_interstitial_id() -> String:
	if OS.has_feature("yandex_ads_demo"):
		return DEMO_INTERSTITIAL_ID
	return str(ProjectSettings.get_setting("monetization/rustore/yandex_interstitial_id", ""))

func purchase(product_id: String) -> void:
	if _pay_client == null or product_id != REMOVE_ADS_PRODUCT:
		purchase_finished.emit(false, product_id)
		return
	var parameters := RuStorePayProductPurchaseParams.new(RuStorePayProductId.new(product_id))
	_pay_client.purchase(parameters, ERuStorePayPreferredPurchaseType.Item.ONE_STEP)

func _on_banner_loaded() -> void:
	if not _banner_requested:
		return
	_banner_requested = false
	_ads.showBanner()
	banner_status_changed.emit(true, "loaded")

func _on_banner_failed(error_code: int) -> void:
	_banner_requested = false
	banner_status_changed.emit(false, "load_failed_%d" % error_code)

func _on_interstitial_loaded() -> void:
	if not _interstitial_requested:
		return
	_interstitial_requested = false
	interstitial_opened.emit()
	_ads.showInterstitial()

func _on_interstitial_failed(_error_code: int) -> void:
	_interstitial_requested = false
	interstitial_finished.emit(false)

func _on_interstitial_closed() -> void:
	interstitial_finished.emit(true)

func _on_purchase_success(result: RuStorePayProductPurchaseResult) -> void:
	var product_id := ""
	if result != null and result.productId != null:
		product_id = result.productId.value
	purchase_finished.emit(product_id == REMOVE_ADS_PRODUCT, product_id)

func _on_purchase_failure(product_id: RuStorePayProductId, _error: RuStoreError) -> void:
	purchase_finished.emit(false, product_id.value if product_id != null else "")

func _on_get_products_success(products: Array[RuStorePayProduct]) -> void:
	for product in products:
		if product == null or product.productId == null or product.productId.value != REMOVE_ADS_PRODUCT:
			continue
		if product.type != ERuStorePayProductType.Item.NON_CONSUMABLE_PRODUCT:
			push_warning("[ClownSmash][Pay] remove_ads must be configured as a non-consumable product")
			return
		var title: String = str(product.title.value) if product.title != null else ""
		var price: String = str(product.amountLabel.value) if product.amountLabel != null else ""
		product_info_updated.emit(REMOVE_ADS_PRODUCT, title, price, "")
		return

func _on_get_products_failure(_error: RuStoreError) -> void:
	push_warning("[ClownSmash][Pay] RuStore product catalog request failed")

func _on_get_purchases_success(purchases: Array[RuStorePayPurchase]) -> void:
	for purchase_item in purchases:
		var purchase := purchase_item as RuStorePayProductPurchase
		if purchase != null and purchase.productId != null \
				and purchase.productId.value == REMOVE_ADS_PRODUCT \
				and purchase.productType == ERuStorePayProductType.Item.NON_CONSUMABLE_PRODUCT \
				and purchase.status == ERuStorePayProductPurchaseStatus.Item.CONFIRMED:
			purchase_finished.emit(true, REMOVE_ADS_PRODUCT)
			return

func _on_get_purchases_failure(_error: RuStoreError) -> void:
	pass
