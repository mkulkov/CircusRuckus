extends Control

const FLOAT_DURATION := 0.82
const CONFETTI_DURATION := 0.82
const BOMB_FLASH_DURATION := 0.20
const SCORE_COLOR := Color("fff3a1")
const BONUS_COLOR := Color("a9f4ff")
const CONFETTI_COLORS := [Color("ff5b63"), Color("ffd35c"), Color("64d9ff"), Color("8ce36b"), Color("d792ff")]

var _floating_labels: Array[Dictionary] = []
var _confetti: Array[Dictionary] = []
var _bomb_flashes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()


func show_score(global_position: Vector2, text: String = "+10", is_bonus: bool = false) -> void:
	_floating_labels.append({
		"position": _local_from_global(global_position),
		"text": text,
		"elapsed": 0.0,
		"color": BONUS_COLOR if is_bonus else SCORE_COLOR,
	})
	queue_redraw()


func show_bomb_confetti(global_position: Vector2) -> void:
	var origin: Vector2 = _local_from_global(global_position)
	_bomb_flashes.append({"position": origin, "elapsed": 0.0})
	for index in range(32):
		var angle := TAU * float(index) / 32.0 + _rng.randf_range(-0.13, 0.13)
		_confetti.append({
			"position": origin + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-11.0, 11.0)),
			"velocity": Vector2(cos(angle), sin(angle) - 0.34) * _rng.randf_range(285.0, 470.0),
			"rotation": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-10.0, 10.0),
			"color": CONFETTI_COLORS[index % CONFETTI_COLORS.size()],
			"elapsed": 0.0,
		})
	queue_redraw()


func _process(delta: float) -> void:
	var changed := false
	for label in _floating_labels:
		label["elapsed"] = float(label["elapsed"]) + delta
		changed = true
	for particle in _confetti:
		particle["elapsed"] = float(particle["elapsed"]) + delta
		particle["position"] = Vector2(particle["position"]) + Vector2(particle["velocity"]) * delta
		particle["velocity"] = Vector2(particle["velocity"]) + Vector2(0.0, 720.0) * delta
		particle["rotation"] = float(particle["rotation"]) + float(particle["spin"]) * delta
		changed = true
	for flash in _bomb_flashes:
		flash["elapsed"] = float(flash["elapsed"]) + delta
		changed = true
	_floating_labels = _floating_labels.filter(func(label: Dictionary) -> bool: return float(label["elapsed"]) < FLOAT_DURATION)
	_confetti = _confetti.filter(func(particle: Dictionary) -> bool: return float(particle["elapsed"]) < CONFETTI_DURATION)
	_bomb_flashes = _bomb_flashes.filter(func(flash: Dictionary) -> bool: return float(flash["elapsed"]) < BOMB_FLASH_DURATION)
	if changed:
		queue_redraw()


func _local_from_global(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for flash in _bomb_flashes:
		var progress := clampf(float(flash["elapsed"]) / BOMB_FLASH_DURATION, 0.0, 1.0)
		var center := Vector2(flash["position"])
		draw_circle(center, lerpf(82.0, 20.0, progress), Color(1.0, 0.47, 0.08, (1.0 - progress) * 0.34))
		draw_circle(center, lerpf(42.0, 9.0, progress), Color(1.0, 0.91, 0.36, (1.0 - progress) * 0.82))
		draw_circle(center, lerpf(18.0, 3.0, progress), Color(1.0, 1.0, 0.91, (1.0 - progress) * 0.95))
	for label in _floating_labels:
		var progress := clampf(float(label["elapsed"]) / FLOAT_DURATION, 0.0, 1.0)
		var alpha := 1.0 - progress * progress
		var position := Vector2(label["position"]) + Vector2(0.0, -150.0 * progress)
		var text: String = label["text"]
		var font_size := 58
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var baseline := position + Vector2(-text_width * 0.5, 0.0)
		draw_string(font, baseline + Vector2(3.0, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.13, 0.05, 0.12, alpha * 0.78))
		for offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(CircusUIStyle.INK, alpha))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(label["color"], alpha))
	for particle in _confetti:
		var progress := clampf(float(particle["elapsed"]) / CONFETTI_DURATION, 0.0, 1.0)
		var alpha := 1.0 - progress
		var center := Vector2(particle["position"])
		var rotation := float(particle["rotation"])
		var size := Vector2(17.0, 8.0)
		var points := PackedVector2Array([
			center + Vector2(-size.x, -size.y).rotated(rotation),
			center + Vector2(size.x, -size.y).rotated(rotation),
			center + Vector2(size.x, size.y).rotated(rotation),
			center + Vector2(-size.x, size.y).rotated(rotation),
		])
		var color := Color(particle["color"], alpha)
		draw_colored_polygon(points, Color(1.0, 0.90, 0.42, alpha * 0.36))
		draw_colored_polygon(points, color)
