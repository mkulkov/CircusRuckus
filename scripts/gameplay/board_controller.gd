extends Control

signal slot_tapped(slot_index: int)
signal character_hit(slot_index: int, character_type: StringName)
signal character_escaped(slot_index: int, character_type: StringName)
signal character_spawned(character_type: StringName)

const BOX_SLOT_SCENE := preload("res://scenes/gameplay/BoxSlot.tscn")
const SLOT_SIZE := Vector2(290.0, 290.0)
const MOBILE_BOARD_VERTICAL_OFFSET := 10.0
const WEB_BOARD_VERTICAL_OFFSET := -102.0
const SLOT_POSITIONS := [
	Vector2(94.0, 660.0), Vector2(391.0, 660.0), Vector2(688.0, 660.0),
	Vector2(64.0, 936.0), Vector2(395.0, 936.0), Vector2(726.0, 936.0),
	Vector2(8.0, 1212.0), Vector2(380.5, 1212.0), Vector2(753.0, 1212.0),
]
const ROW_DEPTH_SCALES := [0.98, 1.0, 1.10]

var _slots: Array[Control] = []
var _last_input_time: int = -1000
var _last_input_position := Vector2(-1000.0, -1000.0)
var _layout_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_slots()
	resized.connect(_layout_slots)
	_layout_slots()


func get_free_slot_indices() -> Array[int]:
	var result: Array[int] = []
	for slot_index in range(_slots.size()):
		if _slots[slot_index].is_idle():
			result.append(slot_index)
	return result


func get_occupied_slot_count() -> int:
	var result := 0
	for slot in _slots:
		if not slot.is_idle():
			result += 1
	return result


func spawn_normal(slot_index: int, visible_time: float = 1.5) -> bool:
	return spawn_character(slot_index, &"normal", visible_time)


func spawn_character(slot_index: int, character_type: StringName, visible_time: float = 1.5) -> bool:
	var slot := get_slot(slot_index)
	var spawned: bool = slot != null and slot.spawn_character(character_type, visible_time)
	if spawned:
		character_spawned.emit(character_type)
	return spawned


func hit_slot(slot_index: int) -> bool:
	var slot := get_slot(slot_index)
	return slot != null and slot.hit_character()


func play_empty_hit(slot_index: int) -> void:
	var slot := get_slot(slot_index)
	if slot != null:
		slot.play_empty_hit()


func get_slot(slot_index: int) -> Control:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index]


func clear_all() -> void:
	for slot in _slots:
		slot.force_clear()


func get_slot_impact_position(slot_index: int) -> Vector2:
	var slot := get_slot(slot_index)
	if slot == null:
		return Vector2.ZERO
	return slot.position + slot.get_local_impact_position() * slot.scale.x


func get_active_character_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for slot in _slots:
		if not slot.is_idle():
			result.append(slot.get_character_type())
	return result


func _gui_input(event: InputEvent) -> void:
	var tap_position := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		tap_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap_position = event.position
	else:
		return

	var now := Time.get_ticks_msec()
	if now - _last_input_time < 24 and tap_position.distance_to(_last_input_position) < 8.0:
		accept_event()
		return
	_last_input_time = now
	_last_input_position = tap_position

	var slot_index := get_slot_index_for_tap(tap_position)
	if slot_index < 0:
		return
	slot_tapped.emit(slot_index)
	accept_event()


func _create_slots() -> void:
	for slot_index in range(9):
		var slot := BOX_SLOT_SCENE.instantiate() as Control
		slot.name = "Slot%02d" % slot_index
		slot.slot_index = slot_index
		slot.position = SLOT_POSITIONS[slot_index]
		slot.size = SLOT_SIZE
		slot.tap_requested.connect(_on_slot_tapped)
		slot.character_hit.connect(_on_character_hit)
		slot.character_escaped.connect(_on_character_escaped)
		add_child(slot)
		_slots.append(slot)


func _layout_slots() -> void:
	_layout_scale = size.x / 1080.0
	var vertical_offset := _get_vertical_offset()
	for slot_index in range(_slots.size()):
		var row := floori(slot_index / 3.0)
		var depth_scale: float = ROW_DEPTH_SCALES[row]
		_slots[slot_index].scale = Vector2.ONE * _layout_scale * depth_scale
		_slots[slot_index].position = (SLOT_POSITIONS[slot_index] + Vector2(0.0, vertical_offset)) * _layout_scale


func _get_vertical_offset() -> float:
	return WEB_BOARD_VERTICAL_OFFSET if OS.has_feature("web") else MOBILE_BOARD_VERTICAL_OFFSET


func get_slot_index_for_tap(tap_position: Vector2) -> int:
	# Only a visible head or an opaque, rendered part of a box is a valid target.
	var character_slot_index := _find_hittable_clown_head_for_tap(tap_position)
	if character_slot_index >= 0:
		return character_slot_index
	return _find_box_for_tap(tap_position)


func _find_hittable_clown_head_for_tap(tap_position: Vector2) -> int:
	var best_index := -1
	var best_distance := INF
	for slot_index in range(_slots.size()):
		var slot := _slots[slot_index]
		if not slot.is_hittable():
			continue
		var local_position := (tap_position - slot.position) / slot.scale.x
		if not slot.contains_hittable_clown_head_at(local_position):
			continue
		var distance := local_position.distance_squared_to(slot.get_local_impact_position())
		if distance < best_distance:
			best_distance = distance
			best_index = slot_index
	return best_index


func _find_box_for_tap(tap_position: Vector2) -> int:
	var best_index := -1
	var best_distance := INF
	for slot_index in range(_slots.size()):
		var slot := _slots[slot_index]
		var slot_scale: float = slot.scale.x
		var local_position := (tap_position - slot.position) / slot_scale
		if not slot.contains_box_at(local_position):
			continue
		var normalized_delta := (local_position - Vector2(145.0, 205.0)) / Vector2(175.0, 215.0)
		var distance := normalized_delta.length_squared()
		if distance < best_distance:
			best_distance = distance
			best_index = slot_index
	return best_index


func _on_slot_tapped(slot_index: int) -> void:
	slot_tapped.emit(slot_index)


func _on_character_hit(slot_index: int, character_type: StringName) -> void:
	character_hit.emit(slot_index, character_type)


func _on_character_escaped(slot_index: int, character_type: StringName) -> void:
	character_escaped.emit(slot_index, character_type)
