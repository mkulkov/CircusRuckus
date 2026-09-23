extends Control

signal play_requested(level_id: int)
signal levels_requested
signal settings_requested

var _monetization: MonetizationService

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const SPLASH_RU := preload("res://assets/generated/startup_splash.png")
const SPLASH_EN := preload("res://assets/generated/startup_splash_en.png")
const MENU_WIDTH := 680.0
const MENU_BUTTON_SIZE := Vector2(600.0, 112.0)
const MENU_PADDING := Vector2(40.0, 42.0)
const MENU_GAP := 26.0
const MENU_CENTER_Y := 1210.0

var _save_data: Dictionary = {}
var _buttons: Array[Button] = []
var _about_panel: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_action(tr("MENU_PLAY"), "PlayButton", func() -> void: play_requested.emit(_earliest_incomplete_level()))
	_create_action(tr("MENU_LEVELS"), "LevelsButton", func() -> void: levels_requested.emit())
	_create_action(tr("MENU_SETTINGS"), "SettingsButton", func() -> void: settings_requested.emit())
	_create_action(tr("MENU_ABOUT"), "AboutButton", _show_about)
	_create_action(tr("REMOVE_ADS"), "RemoveAdsButton", func() -> void:
		if _monetization != null:
			_monetization.purchase_remove_ads()
	)
	_create_about_panel()
	refresh_monetization()
	resized.connect(_layout)
	_layout()
	queue_redraw()


func configure(save_data: Dictionary, monetization_service: MonetizationService = null) -> void:
	_save_data = save_data.duplicate(true)
	_monetization = monetization_service
	if _monetization != null and not _monetization.entitlement_changed.is_connected(refresh_monetization):
		_monetization.entitlement_changed.connect(refresh_monetization)
	if _monetization != null and not _monetization.product_info_changed.is_connected(refresh_monetization):
		_monetization.product_info_changed.connect(refresh_monetization)
	refresh_monetization()


func refresh_monetization() -> void:
	var button := get_node_or_null("RemoveAdsButton") as Button
	if button != null:
		button.visible = _monetization != null and _monetization.is_remove_ads_offer_available() and not _monetization.is_ads_removed()
		if _monetization != null:
			var price := _monetization.get_remove_ads_price()
			button.text = tr("REMOVE_ADS") if price.is_empty() else "%s\n%s" % [tr("REMOVE_ADS"), price]
			button.icon = null
		_layout()


func _earliest_incomplete_level() -> int:
	var highest := clampi(int(_save_data.get("highest_unlocked_level", 1)), 1, 9)
	var completed: Array = _save_data.get("completed_levels", [])
	for level_id in range(1, highest + 1):
		if not completed.has(level_id):
			return level_id
	return 9 if highest >= 9 else highest


func _create_action(text: String, node_name: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	CircusUIStyle.apply_button(button, 42)
	add_child(button)
	_buttons.append(button)


func _create_about_panel() -> void:
	_about_panel = Panel.new()
	_about_panel.name = "AboutPanel"
	_about_panel.visible = false
	_about_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_about_panel)
	var label := Label.new()
	label.text = tr("ABOUT_TEXT").replace("\\n", "\n")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", CircusUIStyle.CREAM)
	label.add_theme_color_override("font_outline_color", CircusUIStyle.INK)
	label.add_theme_constant_override("outline_size", 3)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	_about_panel.add_child(label)
	var close := Button.new()
	close.text = tr("CLOSE")
	close.focus_mode = Control.FOCUS_NONE
	CircusUIStyle.apply_button(close, 30, true)
	close.position = Vector2(110, 340)
	close.size = Vector2(360, 80)
	close.pressed.connect(func() -> void: _about_panel.visible = false)
	_about_panel.add_child(close)


func _show_about() -> void:
	_about_panel.visible = true


func _layout() -> void:
	var scale_factor := size.x / DESIGN_SIZE.x
	var visible_buttons: Array[Button] = []
	for button in _buttons:
		if button.visible:
			visible_buttons.append(button)
	var menu_height := MENU_PADDING.y * 2.0 + MENU_BUTTON_SIZE.y * visible_buttons.size() + MENU_GAP * maxi(0, visible_buttons.size() - 1)
	for index in range(visible_buttons.size()):
		var button := visible_buttons[index]
		button.position = Vector2(
			(DESIGN_SIZE.x - MENU_BUTTON_SIZE.x) * 0.5,
			MENU_CENTER_Y - menu_height * 0.5 + MENU_PADDING.y + index * (MENU_BUTTON_SIZE.y + MENU_GAP)
		) * scale_factor
		button.size = MENU_BUTTON_SIZE * scale_factor
		button.add_theme_font_size_override("font_size", maxi(24, roundi(42.0 * scale_factor)))
	_about_panel.position = Vector2(250.0, 650.0) * scale_factor
	_about_panel.size = Vector2(580.0, 460.0) * scale_factor
	_about_panel.scale = Vector2.ONE
func _draw() -> void:
	var locale := TranslationServer.get_locale().to_lower()
	var background := SPLASH_EN if locale.begins_with("en") else SPLASH_RU
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)


func _panel_style() -> StyleBoxFlat:
	return CircusUIStyle.panel_style()
