extends Node

const MAIN_MENU_SCENE := preload("res://scenes/ui/MainMenu.tscn")
const LEVEL_SELECT_SCENE := preload("res://scenes/ui/LevelSelect.tscn")
const GAMEPLAY_SCENE := preload("res://scenes/gameplay/Gameplay.tscn")
const STARTUP_SPLASH_SCENE := preload("res://scenes/ui/StartupSplash.tscn")
const ADS_UNAVAILABLE_DIALOG := preload("res://scripts/ui/ads_unavailable_dialog.gd")

@onready var save_manager: Node = $SaveManager
@onready var settings_overlay: Control = $SettingsOverlay
@onready var audio_manager: Node = $AudioManager
@onready var localization_manager: Node = $LocalizationManager
@onready var monetization_service: MonetizationService = $MonetizationService

var _current_screen: Node
var _ads_dialog: CanvasLayer


func _ready() -> void:
	save_manager.configure_web_profile()
	monetization_service.configure(save_manager, audio_manager)
	settings_overlay.configure_monetization(monetization_service)
	monetization_service.platform_pause_requested.connect(_on_platform_pause_requested)
	monetization_service.platform_resume_requested.connect(_on_platform_resume_requested)
	monetization_service.ads_unavailable.connect(_show_ads_unavailable)
	monetization_service.purchase_failed.connect(_on_ad_gate_purchase_failed)
	monetization_service.product_info_changed.connect(_refresh_ad_gate)
	await localization_manager.initialize()
	await save_manager.initialize_cloud()
	settings_overlay.settings_changed.connect(_on_settings_changed)
	monetization_service.entitlement_changed.connect(_on_ads_entitlement_changed)
	monetization_service.refresh_saved_state()
	audio_manager.apply_settings(save_manager.load_data())
	monetization_service.refresh_audio_pause_state()
	_show_startup_splash()


func skip_startup_splash() -> void:
	if _current_screen != null and _current_screen.has_method("finish"):
		_current_screen.finish()


func _show_startup_splash() -> void:
	var splash := STARTUP_SPLASH_SCENE.instantiate()
	_replace_screen(splash)
	splash.completed.connect(func() -> void: show_main_menu(false), CONNECT_ONE_SHOT)


func show_main_menu(play_sound: bool = true) -> void:
	monetization_service.cancel_pending_level()
	_close_ad_gate()
	get_tree().paused = false
	monetization_service.set_gameplay_active(false)
	if play_sound:
		audio_manager.play_event(&"ui_button")
	_replace_screen(MAIN_MENU_SCENE.instantiate())
	_current_screen.configure(save_manager.load_data())
	_current_screen.play_requested.connect(start_level)
	_current_screen.levels_requested.connect(show_level_select)
	_current_screen.settings_requested.connect(_show_settings)
	monetization_service.notify_game_ready()


func show_level_select() -> void:
	get_tree().paused = false
	monetization_service.set_gameplay_active(false)
	audio_manager.play_event(&"ui_button")
	var screen := LEVEL_SELECT_SCENE.instantiate()
	screen.configure(save_manager.load_data())
	_replace_screen(screen)
	screen.level_selected.connect(start_level)
	screen.back_requested.connect(show_main_menu)


func start_level(level_id: int) -> void:
	get_tree().paused = false
	monetization_service.set_gameplay_active(false)
	var data: Dictionary = save_manager.load_data()
	if level_id < 1 or level_id > int(data["highest_unlocked_level"]):
		return
	audio_manager.play_event(&"ui_button")
	monetization_service.show_level_start_ad(level_id, func() -> void: _open_level(level_id))


func _open_level(level_id: int) -> void:
	var gameplay := GAMEPLAY_SCENE.instantiate()
	gameplay.configure(level_id, save_manager, audio_manager, monetization_service)
	_replace_screen(gameplay)
	gameplay.menu_requested.connect(show_main_menu)
	gameplay.next_level_requested.connect(start_level)
	gameplay.settings_requested.connect(_show_settings)


func _on_ads_entitlement_changed(_ads_removed: bool) -> void:
	if _ads_removed and is_instance_valid(_ads_dialog):
		_close_ad_gate()
		monetization_service.continue_pending_level_after_purchase()

func _show_ads_unavailable() -> void:
	if is_instance_valid(_ads_dialog):
		return
	get_tree().paused = true
	_ads_dialog = ADS_UNAVAILABLE_DIALOG.new()
	add_child(_ads_dialog)
	_ads_dialog.exit_requested.connect(func() -> void: show_main_menu())
	_ads_dialog.purchase_requested.connect(func() -> void:
		_ads_dialog.set_pending()
		monetization_service.purchase_remove_ads()
	)
	_refresh_ad_gate()

func _refresh_ad_gate() -> void:
	if is_instance_valid(_ads_dialog):
		_ads_dialog.set_purchase_available(monetization_service.are_purchases_enabled() and monetization_service.is_remove_ads_offer_available(), monetization_service.get_remove_ads_price())

func _on_ad_gate_purchase_failed() -> void:
	if is_instance_valid(_ads_dialog):
		_ads_dialog.show_purchase_failure()
		_refresh_ad_gate()

func _close_ad_gate() -> void:
	if is_instance_valid(_ads_dialog):
		_ads_dialog.queue_free()
	_ads_dialog = null
	get_tree().paused = false


func _replace_screen(screen: Node) -> void:
	if _current_screen != null:
		_current_screen.queue_free()
	_current_screen = screen
	add_child(screen)
	move_child(screen, 0)


func _show_settings() -> void:
	audio_manager.play_event(&"ui_button")
	settings_overlay.open(save_manager.load_data())


func _on_settings_changed(music_enabled: bool, sound_enabled: bool, haptics_enabled: bool) -> void:
	save_manager.update_settings(music_enabled, sound_enabled, haptics_enabled)
	audio_manager.apply_settings(save_manager.load_data())
	monetization_service.refresh_audio_pause_state()
	audio_manager.play_event(&"ui_button")


func _on_platform_pause_requested() -> void:
	if _current_screen != null and _current_screen.has_method("handle_platform_pause"):
		_current_screen.handle_platform_pause()


func _on_platform_resume_requested() -> void:
	if _current_screen != null and _current_screen.has_method("handle_platform_resume"):
		_current_screen.handle_platform_resume()
