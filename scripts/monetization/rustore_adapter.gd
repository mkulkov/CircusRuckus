class_name RuStoreMonetizationAdapter
extends MonetizationAdapter

func _init() -> void:
	platform_name = "rustore"

func initialize() -> void:
	# The current RuStore Pay SDK must be added as a native Android plugin.
	# Do not report success until that plugin is configured by the project owner.
	initialized.emit(false)
