extends Node

const SAMPLE_RATE := 22050
const MUSIC_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/fon1_normalized.ogg"),
	preload("res://assets/audio/music/fon2_normalized.ogg")
]
const CLOWN_MISS_SFX: Array[AudioStream] = [
	preload("res://assets/audio/sfx/clown_miss_1.ogg"),
	preload("res://assets/audio/sfx/clown_miss_2.ogg")
]
const BOMB_SFX: AudioStream = preload("res://assets/audio/sfx/bomb_normalized.ogg")

var music_enabled := true
var sound_enabled := true
var haptics_enabled := true
var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _event_counts: Dictionary = {}
var _music_rng := RandomNumberGenerator.new()
var _sfx_rng := RandomNumberGenerator.new()
var _current_music_track_index := -1
var _current_clown_miss_stream: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	_music_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	for index in range(6):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % index
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		_sfx_players.append(player)
	_build_sfx()
	_music_rng.randomize()
	_sfx_rng.randomize()


func _exit_tree() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	for player in _sfx_players:
		player.stop()
		player.stream = null
	_sfx_players.clear()
	_streams.clear()


func apply_settings(data: Dictionary) -> void:
	music_enabled = bool(data.get("music_enabled", true))
	sound_enabled = bool(data.get("sound_enabled", true))
	haptics_enabled = bool(data.get("haptics_enabled", true))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), not music_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), not sound_enabled)
	if music_enabled:
		play_music()
	elif _music_player != null:
		_music_player.stop()


func play_music() -> void:
	if _audio_output_available() and music_enabled and _music_player != null and _music_player.stream != null and not _music_player.playing:
		_music_player.play()


func play_music_for_level(_level_id: int) -> void:
	if MUSIC_TRACKS.is_empty() or _music_player == null:
		return
	var next_track_index := _music_rng.randi_range(0, MUSIC_TRACKS.size() - 1)
	if MUSIC_TRACKS.size() > 1 and next_track_index == _current_music_track_index:
		next_track_index = (next_track_index + 1) % MUSIC_TRACKS.size()
	_current_music_track_index = next_track_index
	_music_player.stop()
	_music_player.stream = MUSIC_TRACKS[_current_music_track_index]
	play_music()


func get_music_track_count() -> int:
	return MUSIC_TRACKS.size()


func get_current_music_track_path() -> String:
	if _current_music_track_index < 0:
		return ""
	return MUSIC_TRACKS[_current_music_track_index].resource_path


func get_clown_miss_sound_count() -> int:
	return CLOWN_MISS_SFX.size()


func get_current_clown_miss_sound_path() -> String:
	if _current_clown_miss_stream == null:
		return ""
	return _current_clown_miss_stream.resource_path


func get_bomb_sound_path() -> String:
	return BOMB_SFX.resource_path


func set_music_random_seed_for_tests(seed: int) -> void:
	_music_rng.seed = seed


func play_event(event_name: StringName) -> void:
	_event_counts[event_name] = int(_event_counts.get(event_name, 0)) + 1
	var stream := _get_event_stream(event_name)
	if _audio_output_available() and sound_enabled and stream != null:
		var player := _available_sfx_player()
		player.stream = stream
		player.play()
	if haptics_enabled and OS.has_feature("mobile"):
		if event_name == &"correct_hit":
			Input.vibrate_handheld(20, 0.28)
		elif event_name in [&"empty_hit", &"clown_miss"]:
			Input.vibrate_handheld(65, 0.65)
		elif event_name in [&"bomb", &"life_lost"]:
			Input.vibrate_handheld(55, 0.58)


func _audio_output_available() -> bool:
	return DisplayServer.get_name() != "headless"


func get_event_count(event_name: StringName) -> int:
	return int(_event_counts.get(event_name, 0))


func _available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players[0]


func _get_event_stream(event_name: StringName) -> AudioStream:
	if event_name == &"bomb":
		return BOMB_SFX
	if event_name == &"clown_miss":
		if CLOWN_MISS_SFX.is_empty():
			return null
		_current_clown_miss_stream = CLOWN_MISS_SFX[_sfx_rng.randi_range(0, CLOWN_MISS_SFX.size() - 1)]
		return _current_clown_miss_stream
	return _streams.get(event_name) as AudioStream


func _on_music_finished() -> void:
	play_music()


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _build_sfx() -> void:
	var tones := {
		&"box_pop": [520.0, 0.09], &"hammer_bonk": [145.0, 0.12], &"correct_hit": [760.0, 0.10],
		&"empty_hit": [190.0, 0.08], &"life_lost": [120.0, 0.20],
		&"clock": [980.0, 0.18], &"apple_restore": [660.0, 0.20], &"glutton_escape": [105.0, 0.22],
		&"drunk": [310.0, 0.20], &"combo": [880.0, 0.11], &"countdown": [440.0, 0.08],
		&"victory": [1040.0, 0.30], &"defeat": [98.0, 0.34], &"ui_button": [620.0, 0.06]
	}
	for event_name in tones:
		var definition: Array = tones[event_name]
		_streams[event_name] = _make_tone(float(definition[0]), float(definition[1]))


func _make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, roundi(SAMPLE_RATE * duration))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var envelope := 1.0 - float(index) / sample_count
		var sample := sin(TAU * frequency * float(index) / SAMPLE_RATE) * envelope * 0.32
		bytes.encode_s16(index * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	return stream
