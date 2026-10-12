extends Control

signal play_requested
signal tutorial_requested
signal statistics_requested
signal settings_requested

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const SPLASH_RU := preload("res://assets/generated/startup_splash.png")
const SPLASH_EN := preload("res://assets/generated/startup_splash_en.png")
const MENU_WIDTH := 680.0
const MENU_BUTTON_SIZE := Vector2(600.0, 112.0)
const MENU_PADDING := Vector2(40.0, 42.0)
const MENU_GAP := 26.0
const MENU_CENTER_Y := 1210.0

var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_action(tr("MENU_PLAY"), "PlayButton", func() -> void: play_requested.emit())
	_create_action(tr("MENU_TUTORIAL"), "TutorialButton", func() -> void: tutorial_requested.emit())
	_create_action(tr("MENU_SETTINGS"), "SettingsButton", func() -> void: settings_requested.emit())
	_create_action(tr("MENU_STATISTICS"), "StatisticsButton", func() -> void: statistics_requested.emit())
	resized.connect(_layout)
	_layout()
	queue_redraw()


func configure(_save_data: Dictionary) -> void:
	queue_redraw()


func _create_action(text: String, node_name: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	CircusUIStyle.apply_button(button, 42)
	add_child(button)
	_buttons.append(button)


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


func _draw() -> void:
	var locale := TranslationServer.get_locale().to_lower()
	var background := SPLASH_EN if locale.begins_with("en") else SPLASH_RU
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
