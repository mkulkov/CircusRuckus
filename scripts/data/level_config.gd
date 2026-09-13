class_name LevelConfig
extends Resource

@export var level_id: int = 1
@export var display_name: String = "Введение"
@export var duration: float = 60.0
@export var target_score: int = 150
@export var required_max_combo: int = 0
@export var required_golden_hits: int = 0
@export var spawn_interval_min: float = 1.25
@export var spawn_interval_max: float = 1.55
@export_range(0.25, 1.0, 0.01) var end_spawn_interval_multiplier: float = 0.65
@export var max_active_characters: int = 1
@export_range(0.0, 1.0) var double_spawn_chance: float = 0.0

@export var normal_weight: float = 100.0
@export var fast_weight: float = 0.0
@export var golden_weight: float = 0.0
@export var bomb_weight: float = 0.0
@export var clock_weight: float = 0.0
@export var glutton_weight: float = 0.0
@export var drunk_weight: float = 0.0

@export var normal_visible_time: float = 0.75
@export var fast_visible_time: float = 0.275
@export var golden_visible_time: float = 0.35
@export var bomb_visible_time: float = 0.5
@export var clock_visible_time: float = 0.5
@export var glutton_visible_time: float = 0.5
@export var drunk_visible_time: float = 0.5

@export var max_clock_spawns: int = 3
@export var max_time_bonus: float = 30.0
