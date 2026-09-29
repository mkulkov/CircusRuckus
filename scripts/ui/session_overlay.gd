extends Control

signal resume_requested
signal retry_requested
signal menu_requested
signal next_requested
signal settings_requested

var _monetization: MonetizationService

enum OverlayMode {
	NONE,
	COUNTDOWN,
	PAUSE,
	RESULT,
}

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const PANEL_X := 205.0
const PANEL_TOP := 535.0
const PANEL_WIDTH := 670.0
const ACTION_SIZE := Vector2(460.0, 90.0)
const ACTION_GAP := 25.0
const PANEL_BOTTOM_PADDING := 40.0
const COUNTDOWN_GO_EN := preload("res://assets/ui/countdown_go_en.png")
const COUNTDOWN_GO_RU := preload("res://assets/ui/countdown_go_ru.png")
const CONFETTI_COLORS: Array[Color] = [
	Color("ff315d"), Color("ffcf2f"), Color("23d9ff"), Color("39ef89"),
	Color("b65cff"), Color("ff7a22"), Color("fff4b0"), Color("ff4fd8"),
]

var _mode: OverlayMode = OverlayMode.NONE
var _countdown_text: String = ""
var _result_won: bool = false
var _result_score: int = 0
var _result_combo: int = 0
var _result_target: int = 0
var _result_save_error: bool = false
var _resume_button: Button
var _retry_button: Button
var _menu_button: Button
var _next_button: Button
var _settings_button: Button
var _remove_ads_button: Button
var _countdown_is_final := false
var _countdown_burst_time := 0.0
var _confetti: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_button = _create_button(tr("RESUME"))
	_resume_button.name = "ResumeButton"
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	add_child(_resume_button)
	_retry_button = _create_button(tr("PLAY_AGAIN"))
	_retry_button.name = "RetryButton"
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	add_child(_retry_button)
	_menu_button = _create_button(tr("MENU"))
	_menu_button.name = "MenuButton"
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	add_child(_menu_button)
	_next_button = _create_button(tr("NEXT"))
	_next_button.name = "NextButton"
	_next_button.pressed.connect(func() -> void: next_requested.emit())
	add_child(_next_button)
	_settings_button = _create_button(tr("MENU_SETTINGS"))
	_settings_button.name = "OverlaySettingsButton"
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	add_child(_settings_button)
	_remove_ads_button = _create_button(tr("REMOVE_ADS"))
	_remove_ads_button.name = "RemoveAdsButton"
	_remove_ads_button.pressed.connect(func() -> void:
		if _monetization != null:
			_monetization.purchase_remove_ads()
	)
	add_child(_remove_ads_button)
	resized.connect(_layout_buttons)
	_layout_buttons()
	hide_overlay()


func configure_monetization(monetization_service: MonetizationService) -> void:
	_monetization = monetization_service
	if _monetization == null:
		refresh_monetization()
		return
	if not _monetization.entitlement_changed.is_connected(refresh_monetization):
		_monetization.entitlement_changed.connect(refresh_monetization)
	if not _monetization.product_info_changed.is_connected(refresh_monetization):
		_monetization.product_info_changed.connect(refresh_monetization)
	refresh_monetization()


func refresh_monetization() -> void:
	if _remove_ads_button != null:
		_remove_ads_button.visible = _monetization != null and _monetization.is_remove_ads_offer_available() and not _monetization.is_ads_removed()
		if _monetization != null:
			var price := _monetization.get_remove_ads_price()
			var title := _monetization.get_remove_ads_title()
			_remove_ads_button.text = tr("REMOVE_ADS") if title.is_empty() or price.is_empty() else "%s\n%s" % [title, price]
			_remove_ads_button.icon = null
		_layout_buttons()
		queue_redraw()


func show_countdown(text: String) -> void:
	_countdown_text = text
	_countdown_is_final = not text.is_empty() and text not in ["3", "2", "1"]
	if _countdown_is_final:
		_start_countdown_burst()
	_mode = OverlayMode.COUNTDOWN if not text.is_empty() else OverlayMode.NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if _mode != OverlayMode.NONE else Control.MOUSE_FILTER_IGNORE
	_resume_button.visible = false
	_retry_button.visible = false
	_menu_button.visible = false
	_next_button.visible = false
	_settings_button.visible = false
	_remove_ads_button.visible = false
	_layout_buttons()
	queue_redraw()


func show_pause() -> void:
	_mode = OverlayMode.PAUSE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_button.visible = true
	_retry_button.visible = true
	_retry_button.text = tr("RESTART")
	_menu_button.visible = true
	_next_button.visible = false
	_settings_button.visible = true
	refresh_monetization()
	queue_redraw()


func show_result(won: bool, score: int, max_combo: int, target_score: int, save_error: bool = false, can_advance: bool = false) -> void:
	_mode = OverlayMode.RESULT
	_result_won = won
	_result_score = score
	_result_combo = max_combo
	_result_target = target_score
	_result_save_error = save_error
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_button.visible = false
	_retry_button.visible = true
	_retry_button.text = tr("PLAY_AGAIN") if won else tr("RETRY")
	_menu_button.visible = true
	_next_button.visible = won and can_advance and not save_error
	_settings_button.visible = false
	refresh_monetization()
	queue_redraw()


func hide_overlay() -> void:
	_mode = OverlayMode.NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_button.visible = false
	_retry_button.visible = false
	_menu_button.visible = false
	_next_button.visible = false
	_settings_button.visible = false
	_remove_ads_button.visible = false
	queue_redraw()


func is_showing_pause() -> bool:
	return _mode == OverlayMode.PAUSE


func is_showing_result() -> bool:
	return _mode == OverlayMode.RESULT


func is_showing_countdown() -> bool:
	return _mode == OverlayMode.COUNTDOWN


func is_showing_save_error() -> bool:
	return _mode == OverlayMode.RESULT and _result_save_error


func _draw() -> void:
	if _mode == OverlayMode.NONE and _confetti.is_empty():
		return
	var scale_factor := size.x / DESIGN_SIZE.x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)

	if _mode == OverlayMode.COUNTDOWN:
		_draw_countdown()
	elif _mode == OverlayMode.PAUSE:
		_draw_pause()
	elif _mode == OverlayMode.RESULT:
		_draw_result()
	_draw_confetti()


func _draw_countdown() -> void:
	if not _countdown_is_final:
		_draw_text(_countdown_text, Rect2(410.0, 670.0, 260.0, 170.0), 118, Color.WHITE)
		return
	var texture := COUNTDOWN_GO_RU if TranslationServer.get_locale().begins_with("ru") else COUNTDOWN_GO_EN
	var reveal := clampf(_countdown_burst_time / 0.16, 0.0, 1.0)
	var fade := 1.0 - clampf((_countdown_burst_time - 0.38) / 0.24, 0.0, 1.0)
	var pop_scale := lerpf(0.45, 1.08, sin(reveal * PI * 0.5))
	var target_size := Vector2(650.0, 230.0) if texture == COUNTDOWN_GO_RU else Vector2(470.0, 260.0)
	target_size *= pop_scale
	var target_rect := Rect2(Vector2(540.0, 760.0) - target_size * 0.5, target_size)
	draw_texture_rect(texture, target_rect, false, Color(1.0, 1.0, 1.0, fade))


func _process(delta: float) -> void:
	if not _countdown_is_final and _confetti.is_empty():
		return
	_countdown_burst_time += delta
	for piece in _confetti:
		piece.position += piece.velocity * delta
		piece.velocity.y += 980.0 * delta
		piece.rotation += piece.spin * delta
		piece.life -= delta
	for index in range(_confetti.size() - 1, -1, -1):
		if float(_confetti[index].life) <= 0.0:
			_confetti.remove_at(index)
	queue_redraw()


func _start_countdown_burst() -> void:
	_countdown_burst_time = 0.0
	_confetti.clear()
	var random := RandomNumberGenerator.new()
	random.seed = 0xC1AC05
	for index in range(92):
		var angle := random.randf_range(-PI * 0.92, -PI * 0.08)
		var speed := random.randf_range(430.0, 980.0)
		_confetti.append({
			"position": Vector2(540.0 + random.randf_range(-105.0, 105.0), 760.0 + random.randf_range(-25.0, 25.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"rotation": random.randf_range(0.0, TAU),
			"spin": random.randf_range(-13.0, 13.0),
			"size": Vector2(random.randf_range(10.0, 25.0), random.randf_range(5.0, 13.0)),
			"color": CONFETTI_COLORS[index % CONFETTI_COLORS.size()],
			"life": random.randf_range(0.72, 1.18),
			"shape": index % 5,
		})


func _draw_confetti() -> void:
	for piece in _confetti:
		var alpha := clampf(float(piece.life) / 0.3, 0.0, 1.0)
		var color: Color = piece.color
		color.a = alpha
		var transform := Transform2D(float(piece.rotation), piece.position)
		draw_set_transform_matrix(transform)
		var piece_size: Vector2 = piece.size
		match int(piece.shape):
			0:
				draw_rect(Rect2(-piece_size * 0.5, piece_size), color)
				draw_line(Vector2(-piece_size.x * 0.28, 0.0), Vector2(piece_size.x * 0.28, 0.0), Color(1, 1, 1, alpha * 0.9), 2.0)
			1:
				var diamond := PackedVector2Array([Vector2(0, -piece_size.x * 0.55), Vector2(piece_size.x * 0.5, 0), Vector2(0, piece_size.x * 0.55), Vector2(-piece_size.x * 0.5, 0)])
				draw_colored_polygon(diamond, color)
				draw_circle(Vector2(-1.5, -2.0), 2.3, Color(1, 1, 1, alpha))
			2:
				draw_circle(Vector2.ZERO, piece_size.x * 0.42, color)
				draw_circle(Vector2(-piece_size.x * 0.12, -piece_size.x * 0.14), piece_size.x * 0.12, Color(1, 1, 1, alpha * 0.95))
			3:
				var ribbon := PackedVector2Array([Vector2(-piece_size.x * 0.6, -piece_size.y), Vector2(-piece_size.x * 0.12, piece_size.y), Vector2(piece_size.x * 0.6, -piece_size.y * 0.5), Vector2(piece_size.x * 0.12, piece_size.y)])
				draw_polyline(ribbon, color, 5.0, true)
			_:
				draw_line(Vector2(-piece_size.x * 0.55, 0), Vector2(piece_size.x * 0.55, 0), color, 4.0)
				draw_line(Vector2(0, -piece_size.x * 0.55), Vector2(0, piece_size.x * 0.55), Color(1, 1, 1, alpha), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.05, 0.02, 0.10, 0.68))
	_draw_modal_panel()
	_draw_text(tr("PAUSE_TITLE"), Rect2(315.0, 620.0, 450.0, 95.0), 68, Color("ffe190"))
	_draw_text(tr("PAUSE_MESSAGE"), Rect2(315.0, 720.0, 450.0, 60.0), 34, Color.WHITE)


func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.05, 0.02, 0.10, 0.70))
	_draw_modal_panel()
	var title := tr("LEVEL_COMPLETE") if _result_won else tr("LEVEL_FAILED")
	var title_color := Color("ffe190") if _result_won else Color("ff9d86")
	_draw_text(title, Rect2(245.0, 585.0, 590.0, 95.0), 54, title_color)
	_draw_text(tr("SCORE_VALUE") % _result_score, Rect2(315.0, 710.0, 450.0, 60.0), 38, Color.WHITE)
	_draw_text(tr("BEST_COMBO_VALUE") % _result_combo, Rect2(285.0, 780.0, 510.0, 60.0), 34, Color.WHITE)
	if not _result_won:
		_draw_text(tr("TARGET_VALUE") % _result_target, Rect2(315.0, 850.0, 450.0, 60.0), 32, Color("ffd080"))
	elif _result_save_error:
		_draw_text(tr("PROGRESS_NOT_SAVED"), Rect2(265.0, 850.0, 550.0, 60.0), 30, Color("ff9d86"))


func _draw_modal_panel() -> void:
	var style := CircusUIStyle.panel_style()
	draw_style_box(style, _get_modal_panel_rect())


func _get_modal_panel_rect() -> Rect2:
	var action_count := 0
	for button in [_resume_button, _retry_button, _next_button, _menu_button, _settings_button, _remove_ads_button]:
		if button != null and button.visible:
			action_count += 1
	var action_start_y := 940.0 if _mode == OverlayMode.RESULT else 800.0
	var panel_bottom := action_start_y + action_count * ACTION_SIZE.y + maxi(0, action_count - 1) * ACTION_GAP + PANEL_BOTTOM_PADDING
	return Rect2(PANEL_X, PANEL_TOP, PANEL_WIDTH, panel_bottom - PANEL_TOP)


func _draw_text(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	CircusUIStyle.draw_text(self, text, rect, font_size, color, 3)


func _create_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	CircusUIStyle.apply_button(button, 34, true)
	return button


func _layout_buttons() -> void:
	if _resume_button == null:
		return
	var scale_factor := size.x / DESIGN_SIZE.x
	var action_start_y := 940.0 if _mode == OverlayMode.RESULT else 800.0
	var visible_buttons: Array[Button] = []
	for button in [_resume_button, _retry_button, _next_button, _menu_button, _settings_button, _remove_ads_button]:
		if button.visible:
			visible_buttons.append(button)
	for index in range(visible_buttons.size()):
		var button := visible_buttons[index]
		button.position = Vector2(310.0, action_start_y + index * (ACTION_SIZE.y + ACTION_GAP)) * scale_factor
		button.size = ACTION_SIZE * scale_factor
	_settings_button.size = Vector2(460.0, 90.0) * scale_factor
	_resume_button.add_theme_font_size_override("font_size", maxi(20, roundi(34.0 * scale_factor)))
	_retry_button.add_theme_font_size_override("font_size", maxi(20, roundi(34.0 * scale_factor)))
	_next_button.add_theme_font_size_override("font_size", maxi(20, roundi(31.0 * scale_factor)))
	_menu_button.add_theme_font_size_override("font_size", maxi(20, roundi(31.0 * scale_factor)))
	_settings_button.add_theme_font_size_override("font_size", maxi(20, roundi(31.0 * scale_factor)))
	_remove_ads_button.add_theme_font_size_override("font_size", maxi(20, roundi(28.0 * scale_factor)))
