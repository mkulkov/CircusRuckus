class_name CircusUIStyle
extends RefCounted

const CREAM := Color("fff1b8")
const GOLD := Color("ffc84f")
const GOLD_LIGHT := Color("ffe49a")
const INK := Color("3b1420")
const RED := Color("a93232")
const RED_HOVER := Color("c74735")
const RED_PRESSED := Color("7e252b")
const BLUE := Color("244b89")
const WOOD := Color("60351f")


static func apply_button(button: Button, font_size: int, compact: bool = false) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD_LIGHT)
	button.add_theme_color_override("font_disabled_color", Color("9f8c7f"))
	button.add_theme_color_override("font_outline_color", INK)
	button.add_theme_constant_override("outline_size", maxi(2, roundi(float(font_size) * 0.075)))
	button.add_theme_constant_override("h_separation", 12)
	button.add_theme_stylebox_override("normal", button_style(RED, compact))
	button.add_theme_stylebox_override("hover", button_style(RED_HOVER, compact, 12))
	button.add_theme_stylebox_override("pressed", button_style(RED_PRESSED, compact, 4))
	button.add_theme_stylebox_override("disabled", button_style(Color("594448"), compact, 4))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func apply_toggle(toggle: CheckButton, font_size: int) -> void:
	toggle.add_theme_font_size_override("font_size", font_size)
	toggle.add_theme_color_override("font_color", CREAM)
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)
	toggle.add_theme_color_override("font_pressed_color", GOLD_LIGHT)
	toggle.add_theme_color_override("font_outline_color", INK)
	toggle.add_theme_constant_override("outline_size", maxi(2, roundi(float(font_size) * 0.07)))
	toggle.add_theme_constant_override("h_separation", 22)
	toggle.add_theme_stylebox_override("normal", inset_style(WOOD))
	toggle.add_theme_stylebox_override("hover", inset_style(Color("754329")))
	toggle.add_theme_stylebox_override("pressed", inset_style(Color("4e2a1d")))


static func button_style(fill: Color, compact: bool = false, shadow: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = GOLD
	style.set_border_width_all(7 if not compact else 5)
	style.set_corner_radius_all(28 if not compact else 20)
	style.shadow_color = Color(0.12, 0.025, 0.035, 0.68)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0.0, 5.0)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 12.0
	return style


static func panel_style(fill: Color = WOOD, border_width: int = 9, radius: int = 28) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = GOLD
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.08, 0.02, 0.04, 0.65)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0.0, 7.0)
	return style


static func inset_style(fill: Color) -> StyleBoxFlat:
	var style := panel_style(fill, 4, 18)
	style.shadow_size = 5
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	return style


static func draw_text(canvas: CanvasItem, text: String, rect: Rect2, font_size: int, color: Color = CREAM, outline: int = 3) -> void:
	var font := ThemeDB.fallback_font
	var baseline := rect.position + Vector2(0.0, rect.size.y * 0.78)
	canvas.draw_string(font, baseline + Vector2(3.0, 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color(0.12, 0.02, 0.05, 0.72))
	for offset in [Vector2(-outline, 0), Vector2(outline, 0), Vector2(0, -outline), Vector2(0, outline)]:
		canvas.draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, INK)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)
