extends Node
const ANALYTICS = preload("res://scripts/analytics/analytics_events.gd")

const MAIN_MENU_SCENE := preload("res://scenes/ui/MainMenu.tscn")
const STATISTICS_SCENE := preload("res://scenes/ui/Statistics.tscn")
const GAMEPLAY_SCENE := preload("res://scenes/gameplay/Gameplay.tscn")
const STARTUP_SPLASH_SCENE := preload("res://scenes/ui/StartupSplash.tscn")
const LOADING_IMAGE := preload("res://assets/generated/boot_splash_clown_chase.png")

@onready var save_manager: Node = $SaveManager
@onready var settings_overlay: Control = $SettingsOverlay
@onready var audio_manager: Node = $AudioManager
@onready var localization_manager: Node = $LocalizationManager
@onready var monetization_service: MonetizationService = $MonetizationService

var _current_screen: Node
var _loading_layer: CanvasLayer


var _analytics_launched := Time.get_ticks_msec()

func _ready() -> void:
	_show_loading_image()
	ANALYTICS.record("app_start", {}, ANALYTICS.new_operation())
	ANALYTICS.record("session_start", {"reason": "launch"}, ANALYTICS.new_operation())
	save_manager.configure_web_profile()
	monetization_service.configure(save_manager, audio_manager)
	settings_overlay.configure_monetization(monetization_service)
	monetization_service.platform_pause_requested.connect(_on_platform_pause_requested)
	monetization_service.platform_resume_requested.connect(_on_platform_resume_requested)
	await localization_manager.initialize()
	await save_manager.initialize_cloud()
	settings_overlay.settings_changed.connect(_on_settings_changed)
	monetization_service.refresh_saved_state()
	audio_manager.apply_settings(save_manager.load_data())
	monetization_service.refresh_audio_pause_state()
	_hide_loading_image()
	_show_startup_splash()


func _show_loading_image() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.name = "LoadingImage"
	_loading_layer.layer = 1
	var image := TextureRect.new()
	image.name = "Art"
	image.texture = LOADING_IMAGE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_layer.add_child(image)
	add_child(_loading_layer)


func _hide_loading_image() -> void:
	if is_instance_valid(_loading_layer):
		_loading_layer.queue_free()
		_loading_layer = null


func skip_startup_splash() -> void:
	if _current_screen != null and _current_screen.has_method("finish"):
		_current_screen.finish()


func _show_startup_splash() -> void:
	var splash := STARTUP_SPLASH_SCENE.instantiate()
	_replace_screen(splash)
	splash.completed.connect(func() -> void: show_main_menu(false), CONNECT_ONE_SHOT)


func show_main_menu(play_sound: bool = true) -> void:
	monetization_service.cancel_pending_run()
	get_tree().paused = false
	monetization_service.set_gameplay_active(false)
	monetization_service.show_banner(false)
	if play_sound:
		audio_manager.play_event(&"ui_button")
	_replace_screen(MAIN_MENU_SCENE.instantiate())
	_current_screen.configure(save_manager.load_data())
	_current_screen.play_requested.connect(start_run)
	_current_screen.tutorial_requested.connect(start_training)
	_current_screen.settings_requested.connect(_show_settings)
	_current_screen.statistics_requested.connect(show_statistics)
	monetization_service.notify_game_ready()


func show_statistics() -> void:
	audio_manager.play_event(&"ui_button")
	_replace_screen(STATISTICS_SCENE.instantiate())
	_current_screen.configure(save_manager.load_data())
	_current_screen.back_requested.connect(show_main_menu)


func start_training() -> void:
	monetization_service.cancel_pending_run()
	monetization_service.show_banner(false)
	_open_run("training_repeat")


func start_run() -> void:
	monetization_service.cancel_pending_run()
	get_tree().paused = false
	monetization_service.set_gameplay_active(false)
	monetization_service.show_banner(false)
	audio_manager.play_event(&"ui_button")
	if not save_manager.tutorials_complete() and not ProjectSettings.get_setting("clown_smash/testing/skip_tutorial", false):
		_open_run("training")
		return
	_open_run("endless")


func _open_run(run_mode: String) -> void:
	var gameplay := GAMEPLAY_SCENE.instantiate()
	gameplay.configure(run_mode, save_manager, audio_manager, monetization_service)
	_replace_screen(gameplay)
	gameplay.menu_requested.connect(show_main_menu)
	gameplay.retry_requested.connect(func() -> void:
		if _current_screen != gameplay:
			return
		if gameplay.game_controller.finish_reason == "lives":
			monetization_service.show_transition_ad(MonetizationService.AD_PLACEMENT_LOSS_RETRY, _start_after_loss_ad.bind(gameplay), 0, gameplay.game_controller.active_elapsed)
		else:
			start_run()
	)
	gameplay.new_game_requested.connect(start_run)
	gameplay.settings_requested.connect(_show_settings)


func _start_after_loss_ad(gameplay: Node) -> void:
	while monetization_service.is_platform_lifecycle_active():
		await get_tree().process_frame
		if _current_screen != gameplay:
			return
	if _current_screen == gameplay:
		start_run()


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

func _exit_tree() -> void:
	ANALYTICS.record("session_end", {"reason": "exit", "duration_sec": clampf((Time.get_ticks_msec() - _analytics_launched) / 1000.0, 0.0, 604800.0)}, ANALYTICS.new_operation())
