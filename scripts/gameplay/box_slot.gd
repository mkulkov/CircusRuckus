extends Control

const BOX_TEXTURE := preload("res://assets/generated/open_box.png")
const CLOSED_BOX_TEXTURE := preload("res://assets/generated/closed_box.png")

signal tap_requested(slot_index: int)
signal character_hit(slot_index: int, character_type: StringName)
signal character_escaped(slot_index: int, character_type: StringName)

enum SlotState {
	IDLE,
	OPENING,
	ACTIVE,
	HIT,
	HIDING,
	COOLDOWN,
}

const CLOSED_POSITION := Vector2(55.0, 227.0)
const SPRING_ANCHOR := Vector2(145.0, 188.0)
const SPRING_CONNECTION_LOCAL := Vector2(90.0, 196.0)
# Centre of the visible head/hat: the hammer's striking edge lands here,
# rather than on the front rim of the box.
const HAMMER_TARGET_LOCAL := Vector2(90.0, 82.0)
const CLOWN_HEAD_TAP_RECT := Rect2(-28.0, -50.0, 236.0, 198.0)
const CLOSED_BOX_RECT := Rect2(-7.0, 32.0, 304.0, 318.0)
# The source images have different transparent bounds. These offsets align
# their rendered bottom edges, so the box body never translates with the lid.
const OPEN_BOX_RECT := Rect2(-7.0, 66.0, 304.0, 318.0)

@export var slot_index: int = 0
@export var pop_height: float = 325.0
@export var pop_duration: float = 0.68
@export var overshoot: float = 46.0
@export var idle_wobble_duration: float = 1.25
@export var hide_duration: float = 0.62
@export var impact_squash: float = 0.38
@export var impact_duration: float = 0.18

@onready var clown: Control = $CharacterLayer/Clown
@onready var character_layer: Control = $CharacterLayer
@onready var box_front: Control = $BoxFront

var state: SlotState = SlotState.IDLE
var _animation: Tween
var _idle_animation: Tween
var _empty_animation: Tween
var _lifecycle_id: int = 0
var _lid_open: float = 0.0
var _character_type: StringName = &"normal"
var _impact_flash: float = 0.0
var _open_box_image: Image
var _closed_box_image: Image


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(290.0, 290.0)
	size = custom_minimum_size
	_set_clown_position(CLOSED_POSITION)
	clown.visible = false
	_open_box_image = BOX_TEXTURE.get_image()
	_closed_box_image = CLOSED_BOX_TEXTURE.get_image()
	queue_redraw()


func _process(_delta: float) -> void:
	# The spring is drawn by this slot, while the clown moves in its child layer.
	# Redraw while exposed so its endpoint follows every tweened pose.
	if clown.visible:
		queue_redraw()


func is_idle() -> bool:
	return state == SlotState.IDLE


func is_hittable() -> bool:
	return state == SlotState.ACTIVE


func get_local_impact_position() -> Vector2:
	if is_hittable():
		# Strike the visible head, not the handle/pivot of the hammer or the box rim.
		return _get_clown_local_point(HAMMER_TARGET_LOCAL)
	return Vector2(145.0, 145.0)


func contains_hittable_clown_head_at(local_position: Vector2) -> bool:
	if not is_hittable() or not clown.visible:
		return false
	# The character is clipped, scaled and idly rotated in CharacterLayer. Convert
	# the board-local touch back into its untransformed local art coordinates.
	var unrotated_point := (
		local_position - character_layer.position - clown.position - clown.pivot_offset
	).rotated(-clown.rotation)
	var clown_local_point := clown.pivot_offset + unrotated_point / clown.scale
	return CLOWN_HEAD_TAP_RECT.has_point(clown_local_point)


func contains_box_at(local_position: Vector2) -> bool:
	# Respect the transparent outline of both authored box states so empty board
	# space next to a box never starts a hammer strike.
	return _texture_contains_point(_closed_box_image, CLOSED_BOX_RECT, local_position) or _texture_contains_point(_open_box_image, OPEN_BOX_RECT, local_position)


func spawn_normal(visible_time: float = 1.5) -> bool:
	return spawn_character(&"normal", visible_time)


func spawn_character(character_type: StringName, visible_time: float = 1.5) -> bool:
	if not is_idle():
		return false

	_lifecycle_id += 1
	var lifecycle_id := _lifecycle_id
	_character_type = character_type
	clown.set_character_type(character_type)
	state = SlotState.OPENING
	clown.visible = true
	_set_clown_position(CLOSED_POSITION)
	clown.scale = Vector2(1.0, 0.30)
	_lid_open = 0.0
	queue_redraw()
	_run_spawn_cycle.call_deferred(lifecycle_id, visible_time)
	return true


func _run_spawn_cycle(lifecycle_id: int, visible_time: float) -> void:

	_animation = create_tween()
	_animation.tween_method(_set_lid_open, 0.0, 1.0, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var visible_y := CLOSED_POSITION.y - pop_height
	_animation.tween_property(clown, "position:y", _to_character_layer_y(visible_y - overshoot), pop_duration * 0.74).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_animation.parallel().tween_property(clown, "scale", Vector2(0.96, 1.08), pop_duration * 0.74).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_animation.tween_property(clown, "position:y", _to_character_layer_y(visible_y), pop_duration * 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.parallel().tween_property(clown, "scale", Vector2.ONE, pop_duration * 0.26)
	await _animation.finished

	if lifecycle_id != _lifecycle_id or state != SlotState.OPENING:
		return

	state = SlotState.ACTIVE
	_play_idle_wobble(lifecycle_id)
	await get_tree().create_timer(visible_time).timeout
	if lifecycle_id == _lifecycle_id and state == SlotState.ACTIVE:
		await _escape_character()


func hit_character() -> bool:
	if not is_hittable():
		return false

	_lifecycle_id += 1
	var lifecycle_id := _lifecycle_id
	state = SlotState.HIT
	_stop_idle_wobble()
	character_hit.emit(slot_index, _character_type)
	if lifecycle_id == _lifecycle_id and state == SlotState.HIT:
		_play_hit_animation.call_deferred(lifecycle_id)
	return true


func force_clear() -> void:
	_lifecycle_id += 1
	_stop_idle_wobble()
	if _animation != null and _animation.is_valid():
		_animation.kill()
	state = SlotState.IDLE
	clown.visible = false
	_set_clown_position(CLOSED_POSITION)
	clown.scale = Vector2.ONE
	clown.rotation = 0.0
	_lid_open = 0.0
	_impact_flash = 0.0
	box_front.set_lid_open(0.0)
	queue_redraw()


func play_empty_hit() -> void:
	if not is_idle():
		return
	if _empty_animation != null and _empty_animation.is_valid():
		_empty_animation.kill()
	rotation = 0.0
	_empty_animation = create_tween()
	_empty_animation.tween_property(self, "rotation", deg_to_rad(-2.5), 0.035)
	_empty_animation.tween_property(self, "rotation", deg_to_rad(2.5), 0.055)
	_empty_animation.tween_property(self, "rotation", 0.0, 0.045)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		tap_requested.emit(slot_index)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap_requested.emit(slot_index)
		accept_event()


func _play_idle_wobble(lifecycle_id: int) -> void:
	if lifecycle_id != _lifecycle_id:
		return
	var duration_scale := 0.62 if _character_type == &"fast" else 1.0
	var tilt_scale := 1.8 if _character_type == &"drunk" else 1.0
	_idle_animation = create_tween().set_loops()
	_idle_animation.tween_property(clown, "rotation", deg_to_rad(-2.5 * tilt_scale), idle_wobble_duration * 0.25 * duration_scale).set_trans(Tween.TRANS_SINE)
	_idle_animation.parallel().tween_property(clown, "position:x", CLOSED_POSITION.x - 5.0 * tilt_scale, idle_wobble_duration * 0.25 * duration_scale)
	_idle_animation.tween_property(clown, "rotation", deg_to_rad(2.0 * tilt_scale), idle_wobble_duration * 0.50 * duration_scale).set_trans(Tween.TRANS_SINE)
	_idle_animation.parallel().tween_property(clown, "position:x", CLOSED_POSITION.x + 5.0 * tilt_scale, idle_wobble_duration * 0.50 * duration_scale)
	_idle_animation.tween_property(clown, "rotation", 0.0, idle_wobble_duration * 0.25 * duration_scale).set_trans(Tween.TRANS_SINE)
	_idle_animation.parallel().tween_property(clown, "position:x", CLOSED_POSITION.x, idle_wobble_duration * 0.25 * duration_scale)


func _play_hit_animation(lifecycle_id: int) -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	clown.rotation = 0.0
	_impact_flash = 1.0
	var flash_tween := create_tween()
	flash_tween.tween_method(_set_impact_flash, 1.0, 0.0, impact_duration)
	var impact_start_y := clown.position.y
	_animation = create_tween()
	_animation.tween_property(clown, "scale", Vector2(1.30, impact_squash), impact_duration * 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_animation.parallel().tween_property(clown, "position:y", impact_start_y + 94.0, impact_duration * 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_animation.tween_property(clown, "scale", Vector2(0.92, 0.72), impact_duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.parallel().tween_property(clown, "position:y", impact_start_y + 54.0, impact_duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.tween_property(clown, "position:y", _to_character_layer_y(CLOSED_POSITION.y), hide_duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.parallel().tween_property(clown, "scale", Vector2(0.88, 0.30), hide_duration * 0.55)
	_animation.tween_method(_set_lid_open, 1.0, 0.0, hide_duration * 0.25)
	await _animation.finished
	if lifecycle_id == _lifecycle_id:
		await _begin_cooldown()


func _escape_character() -> void:
	_lifecycle_id += 1
	var lifecycle_id := _lifecycle_id
	state = SlotState.HIDING
	_stop_idle_wobble()
	character_escaped.emit(slot_index, _character_type)
	if lifecycle_id != _lifecycle_id or state != SlotState.HIDING:
		return
	if _animation != null and _animation.is_valid():
		_animation.kill()
	clown.rotation = 0.0
	_animation = create_tween()
	_animation.tween_property(clown, "position:y", _to_character_layer_y(CLOSED_POSITION.y), hide_duration * 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.parallel().tween_property(clown, "scale", Vector2(1.0, 0.30), hide_duration * 0.72)
	_animation.tween_method(_set_lid_open, 1.0, 0.0, hide_duration * 0.28)
	await _animation.finished
	if lifecycle_id == _lifecycle_id:
		await _begin_cooldown()


func _begin_cooldown() -> void:
	state = SlotState.COOLDOWN
	clown.visible = false
	_set_clown_position(CLOSED_POSITION)
	clown.scale = Vector2.ONE
	clown.rotation = 0.0
	queue_redraw()
	await get_tree().create_timer(0.20).timeout
	state = SlotState.IDLE


func _set_lid_open(value: float) -> void:
	_lid_open = value
	box_front.set_lid_open(value)
	queue_redraw()


func _set_impact_flash(value: float) -> void:
	_impact_flash = value
	queue_redraw()


func _stop_idle_wobble() -> void:
	if _idle_animation != null and _idle_animation.is_valid():
		_idle_animation.kill()
	_idle_animation = null


func _draw() -> void:
	_draw_oval(Vector2(145.0, 330.0), Vector2(135.0, 23.0), Color(0.10, 0.04, 0.08, 0.42))
	# The assets have different transparent bounds. Their front faces are aligned to
	# the same baseline so opening the lid never lifts the whole box.
	if _lid_open < 0.999:
		draw_texture_rect(CLOSED_BOX_TEXTURE, CLOSED_BOX_RECT, false, Color(1.0, 1.0, 1.0, 1.0 - _lid_open))
	if _lid_open > 0.001:
		draw_texture_rect(BOX_TEXTURE, OPEN_BOX_RECT, false, Color(1.0, 1.0, 1.0, _lid_open))

	if clown.visible:
		var spring_top := _get_clown_local_point(SPRING_CONNECTION_LOCAL)
		var spring_bottom := SPRING_ANCHOR
		# Once the clown has passed into the box there is no exposed spring.
		if spring_top.y >= spring_bottom.y:
			return
		var points := PackedVector2Array()
		var segment_count := 12
		for segment_index in range(segment_count + 1):
			var ratio := float(segment_index) / float(segment_count)
			var point := spring_top.lerp(spring_bottom, ratio)
			if segment_index > 0 and segment_index < segment_count:
				point.x += 20.0 if segment_index % 2 == 0 else -20.0
			points.append(point)
		var shadow_points := PackedVector2Array()
		for point in points:
			shadow_points.append(point + Vector2(7.0, 6.0))
		draw_polyline(shadow_points, Color(0.08, 0.06, 0.09, 0.55), 14.0, true)
		draw_polyline(points, Color("34313b"), 12.0, true)
		draw_polyline(points, Color("b7bdc6"), 6.0, true)
		draw_polyline(points, Color("f0f1e9"), 2.0, true)
		_draw_oval(spring_bottom, Vector2(25.0, 8.0), Color("1a101b"))
		_draw_oval(spring_bottom - Vector2(2.0, 2.0), Vector2(18.0, 4.0), Color("d0d3d4"))
	if _impact_flash > 0.001:
		var flash_color := Color(1.0, 0.23, 0.12, _impact_flash * 0.55) if _character_type == &"bomb" else Color(1.0, 0.90, 0.28, _impact_flash * 0.48)
		_draw_oval(_get_clown_local_point(Vector2(90.0, 92.0)), Vector2(116.0, 82.0) * (1.0 + (1.0 - _impact_flash) * 0.3), flash_color)


func _get_clown_local_point(point: Vector2) -> Vector2:
	var relative_point := (point - clown.pivot_offset) * clown.scale
	return character_layer.position + clown.position + clown.pivot_offset + relative_point.rotated(clown.rotation)


func _texture_contains_point(image: Image, rect: Rect2, local_position: Vector2) -> bool:
	if image == null or not rect.has_point(local_position):
		return false
	var relative_position := (local_position - rect.position) / rect.size
	var pixel_position := Vector2i(
		clampi(floori(relative_position.x * image.get_width()), 0, image.get_width() - 1),
		clampi(floori(relative_position.y * image.get_height()), 0, image.get_height() - 1)
	)
	return image.get_pixelv(pixel_position).a > 0.12


func _set_clown_position(local_position: Vector2) -> void:
	clown.position = local_position - character_layer.position


func _to_character_layer_y(local_y: float) -> float:
	return local_y - character_layer.position.y


func _draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for point_index in range(32):
		var angle := TAU * float(point_index) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func get_character_type() -> StringName:
	return _character_type


func debug_get_lid_open() -> float:
	return _lid_open


func debug_get_spring_length() -> float:
	return _get_clown_local_point(SPRING_CONNECTION_LOCAL).distance_to(SPRING_ANCHOR)


func debug_get_closed_box_baseline() -> float:
	return _get_texture_baseline(_closed_box_image, CLOSED_BOX_RECT)


func debug_get_open_box_baseline() -> float:
	return _get_texture_baseline(_open_box_image, OPEN_BOX_RECT)


func _get_texture_baseline(image: Image, rect: Rect2) -> float:
	if image == null:
		return -INF
	for y in range(image.get_height() - 1, -1, -1):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.12:
				return rect.position.y + (float(y + 1) / image.get_height()) * rect.size.y
	return -INF
