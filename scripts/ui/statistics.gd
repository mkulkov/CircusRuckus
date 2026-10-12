extends Control

signal back_requested

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const PANEL_SIZE := Vector2(900.0, 760.0)
const SPLASH_RU := preload("res://assets/generated/startup_splash.png")
const SPLASH_EN := preload("res://assets/generated/startup_splash_en.png")

var _save_data: Dictionary = {}
var _panel: Panel
var _records: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Panel.new()
	_panel.name = "RecordsPanel"
	_panel.add_theme_stylebox_override("panel", CircusUIStyle.panel_style())
	add_child(_panel)
	var margin := MarginContainer.new()
	_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 30)
	margin.add_child(content)
	var title := Label.new()
	title.text = tr("MENU_STATISTICS")
	_style_label(title, 48)
	content.add_child(title)
	_records = Label.new()
	_records.name = "Records"
	_records.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_records.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_records, 34)
	_records.add_theme_constant_override("line_spacing", 28)
	content.add_child(_records)
	var back := Button.new()
	back.name = "BackButton"
	back.text = tr("BACK")
	back.custom_minimum_size.y = 112
	back.focus_mode = Control.FOCUS_NONE
	CircusUIStyle.apply_button(back, 42)
	back.pressed.connect(func() -> void: back_requested.emit())
	content.add_child(back)
	_update_records()
	resized.connect(_layout)
	_layout()


func configure(save_data: Dictionary) -> void:
	_save_data = save_data.duplicate(true)
	if is_instance_valid(_records):
		_update_records()


func _update_records() -> void:
	var total := maxi(0, floori(float(_save_data.get("best_run_active_seconds", 0.0))))
	var duration := "%d:%02d" % [total / 60, total % 60]
	_records.text = tr("MENU_RECORDS") % [int(_save_data.get("best_run_score", 0)), int(_save_data.get("best_run_combo", 0)), int(_save_data.get("best_run_rounds", 0)), duration]
	# Fit even the largest supported record values without truncating digits.
	var font: Font = _records.get_theme_font("font")
	var widest := 1.0
	for line in _records.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x)
	_records.add_theme_font_size_override("font_size", mini(34, floori(34.0 * (PANEL_SIZE.x - 88.0) / widest)))


func _style_label(label: Label, font_size: int) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CircusUIStyle.CREAM)
	label.add_theme_color_override("font_outline_color", CircusUIStyle.INK)
	label.add_theme_constant_override("outline_size", 3)


func _layout() -> void:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_panel.size = PANEL_SIZE
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = (size - PANEL_SIZE * scale_factor) * 0.5
	queue_redraw()


func _draw() -> void:
	var background := SPLASH_EN if TranslationServer.get_locale().to_lower().begins_with("en") else SPLASH_RU
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.02, 0.03, 0.65))
