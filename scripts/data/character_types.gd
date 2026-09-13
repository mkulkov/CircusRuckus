class_name CharacterTypes
extends RefCounted

const NORMAL: StringName = &"normal"
const FAST: StringName = &"fast"
const GOLDEN: StringName = &"golden"
const BOMB: StringName = &"bomb"
const CLOCK: StringName = &"clock"
const GLUTTON: StringName = &"glutton"
const DRUNK: StringName = &"drunk"

const ALL: Array[StringName] = [NORMAL, FAST, GOLDEN, BOMB, CLOCK, GLUTTON, DRUNK]
const SCORING: Array[StringName] = [NORMAL, FAST, GOLDEN]
const HAZARDS: Array[StringName] = [BOMB, DRUNK]


static func is_scoring(character_type: StringName) -> bool:
	return character_type in SCORING


static func is_hazard(character_type: StringName) -> bool:
	return character_type in HAZARDS
