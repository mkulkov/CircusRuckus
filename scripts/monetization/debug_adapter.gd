class_name DebugMonetizationAdapter
extends MonetizationAdapter

var virtual_purchase_success := false

func _init() -> void:
	platform_name = "debug"

func initialize() -> void:
	call_deferred("_finish_initialize")

func _finish_initialize() -> void:
	initialized.emit(true)

func show_interstitial() -> void:
	call_deferred("_finish_interstitial")

func _finish_interstitial() -> void:
	interstitial_finished.emit(true)

func purchase(product_id: String) -> void:
	call_deferred("_finish_purchase", product_id)

func _finish_purchase(product_id: String) -> void:
	purchase_finished.emit(virtual_purchase_success, product_id)
