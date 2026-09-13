class_name MonetizationAdapter
extends RefCounted

signal initialized(success: bool)
signal interstitial_opened
signal interstitial_finished(success: bool)
signal purchase_finished(success: bool, product_id: String)
signal platform_pause_requested
signal platform_resume_requested
signal banner_status_changed(visible: bool, reason: String)

var platform_name: String = "unsupported"

func initialize() -> void:
	initialized.emit(true)

func restore_entitlements() -> void:
	pass

func notify_game_ready() -> void:
	pass

func set_gameplay_active(_active: bool) -> void:
	pass

func show_banner(_visible: bool) -> void:
	pass

func show_interstitial() -> void:
	interstitial_finished.emit(false)

func purchase(_product_id: String) -> void:
	purchase_finished.emit(false, "")
