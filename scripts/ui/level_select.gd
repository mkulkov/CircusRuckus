extends Control

signal level_selected(level_id: int)
signal back_requested

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const BACKGROUND := preload("res://assets/generated/circus_background.png")

var _save_data: Dictionary = {}
var _level_buttons: Array[Button] = []
var _back_button: Button


func configure(save_data: Dictionary) -> void:
	_save_data = save_data.duplicate(true)
	_refresh_states()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for level_id in range(1, 10):
		var button := Button.new()
		button.name = "Level%dButton" % level_id
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: level_selected.emit(level_id))
		CircusUIStyle.apply_button(button, 52, true)
		add_child(button)
		_level_buttons.append(button)
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = tr("BACK")
	_back_button.focus_mode = Control.FOCUS_NONE
	CircusUIStyle.apply_button(_back_button, 34)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	add_child(_back_button)
	resized.connect(_layout)
	_layout()
	_refresh_states()
	queue_redraw()


func get_level_button_count() -> int:
	return _level_buttons.size()


func is_level_enabled(level_id: int) -> bool:
	return level_id >= 1 and level_id <= _level_buttons.size() and not _level_buttons[level_id - 1].disabled


func is_level_completed(level_id: int) -> bool:
	return _save_data.get("completed_levels", []).has(level_id)


func _refresh_states() -> void:
	if _level_buttons.is_empty():
		return
	var highest := clampi(int(_save_data.get("highest_unlocked_level", 1)), 1, 9)
	var completed: Array = _save_data.get("completed_levels", [])
	var best_scores: Dictionary = _save_data.get("best_scores", {})
	for level_id in range(1, 10):
		var button := _level_buttons[level_id - 1]
		button.disabled = level_id > highest
		if button.disabled:
			button.text = "%d\n%s" % [level_id, tr("LOCKED")]
		elif completed.has(level_id):
			button.text = "%d  ✓\n%d" % [level_id, int(best_scores.get(str(level_id), 0))]
		else:
			button.text = str(level_id)


func _layout() -> void:
	var scale_factor := size.x / DESIGN_SIZE.x
	for index in range(_level_buttons.size()):
		var row := index / 3
		var column := index % 3
		_level_buttons[index].position = Vector2(150.0 + column * 270.0, 600.0 + row * 280.0) * scale_factor
		_level_buttons[index].size = Vector2(230.0, 210.0) * scale_factor
	_back_button.position = Vector2(340.0, 1510.0) * scale_factor
	_back_button.size = Vector2(400.0, 100.0) * scale_factor


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false, Color(0.72, 0.72, 0.72, 1.0))
	var scale_factor := size.x / DESIGN_SIZE.x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	CircusUIStyle.draw_text(self, tr("LEVEL_SELECT_TITLE"), Rect2(100, 270, 880, 105), 72, CircusUIStyle.GOLD_LIGHT, 5)
