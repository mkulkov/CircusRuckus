extends Control

signal settings_changed(music_enabled: bool, sound_enabled: bool, haptics_enabled: bool)
signal closed

const DESIGN_SIZE := Vector2(1080.0, 1920.0)

var _music: CheckButton
var _sound: CheckButton
var _haptics: CheckButton
var _close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_music = _create_toggle(tr("MUSIC"))
	_sound = _create_toggle(tr("SOUNDS"))
	_haptics = _create_toggle(tr("HAPTICS"))
	_close_button = Button.new()
	_close_button.text = tr("DONE")
	_close_button.focus_mode = Control.FOCUS_NONE
	CircusUIStyle.apply_button(_close_button, 34)
	_close_button.pressed.connect(_close)
	add_child(_close_button)
	resized.connect(_layout)
	_layout()
	_refresh_translations()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_translations()


func _refresh_translations() -> void:
	if _music == null or _sound == null or _haptics == null or _close_button == null:
		return
	_music.text = tr("MUSIC")
	_sound.text = tr("SOUNDS")
	_haptics.text = tr("HAPTICS")
	_close_button.text = tr("DONE")
	queue_redraw()


func configure(data: Dictionary) -> void:
	_music.button_pressed = bool(data.get("music_enabled", true))
	_sound.button_pressed = bool(data.get("sound_enabled", true))
	_haptics.button_pressed = bool(data.get("haptics_enabled", true))


func open(data: Dictionary) -> void:
	_refresh_translations()
	configure(data)
	show()


func _create_toggle(text: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.focus_mode = Control.FOCUS_NONE
	CircusUIStyle.apply_toggle(toggle, 36)
	add_child(toggle)
	return toggle


func _close() -> void:
	settings_changed.emit(_music.button_pressed, _sound.button_pressed, _haptics.button_pressed)
	hide()
	closed.emit()


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.02, 0.08, 0.82))
	var scale_factor := size.x / DESIGN_SIZE.x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	var panel := CircusUIStyle.panel_style()
	draw_style_box(panel, Rect2(220, 520, 640, 820))
	CircusUIStyle.draw_text(self, tr("MENU_SETTINGS"), Rect2(270, 565, 540, 90), 56, CircusUIStyle.GOLD_LIGHT, 4)


func _layout() -> void:
	if _close_button == null:
		return
	var scale_factor := size.x / DESIGN_SIZE.x
	var toggles: Array[CheckButton] = [_music, _sound, _haptics]
	for index in range(toggles.size()):
		toggles[index].position = Vector2(310.0, 700.0 + index * 140.0) * scale_factor
		toggles[index].size = Vector2(460.0, 100.0) * scale_factor
		toggles[index].add_theme_font_size_override("font_size", maxi(22, roundi(36.0 * scale_factor)))
	_close_button.position = Vector2(340.0, 1160.0) * scale_factor
	_close_button.size = Vector2(400.0, 100.0) * scale_factor
	_close_button.add_theme_font_size_override("font_size", maxi(22, roundi(34.0 * scale_factor)))
