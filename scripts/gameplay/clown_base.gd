extends Control

const TEXTURES := {
	&"normal": preload("res://assets/generated/normal_clown.png"),
	&"fast": preload("res://assets/generated/fast_clown.png"),
	&"golden": preload("res://assets/generated/golden_clown.png"),
	&"bomb": preload("res://assets/generated/bomb_clown.png"),
	&"clock": preload("res://assets/generated/clock_clown.png"),
	&"glutton": preload("res://assets/generated/glutton_clown.png"),
	&"drunk": preload("res://assets/generated/drunk_clown.png"),
}

var character_type: StringName = &"normal"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(180.0, 190.0)
	size = custom_minimum_size
	pivot_offset = Vector2(90.0, 172.0)
	queue_redraw()


func set_character_type(value: StringName) -> void:
	character_type = value if TEXTURES.has(value) else &"normal"
	queue_redraw()


func _draw() -> void:
	var texture: Texture2D = TEXTURES[character_type]
	draw_texture_rect(texture, Rect2(-35.0, -50.0, 250.0, 250.0), false, Color.WHITE)
