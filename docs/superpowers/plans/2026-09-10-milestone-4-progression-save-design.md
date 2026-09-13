# Milestone 4 Progression and Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist MVP progress locally, unlock the next level after a win, and prove deterministic spawn behavior.

**Architecture:** `SaveManager` owns a small versioned JSON file at `user://clown_smash_save.json` and always exposes validated defaults if the file is absent or invalid. `Gameplay` records the completed session through that manager, without adding menu/navigation responsibilities. `SpawnDirector` exposes its generated sequence through ordinary spawning and receives fixed-seed regression coverage.

**Tech Stack:** Godot 4.7, GDScript, built-in `FileAccess` and `JSON`, existing `tests/run_tests.gd` runner.

---

### Task 1: Safe MVP save data

**Files:**

- Create: `scripts/save/save_manager.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing save-default test**

```gdscript
var manager := load("res://scripts/save/save_manager.gd").new()
manager.set_save_path_for_tests("user://clown_smash_save_test.json")
manager.delete_save_for_tests()
var data := manager.load_data()
_expect_equal(data["highest_unlocked_level"], 1, "Missing save defaults to Level 1")
_expect_equal(data["completed_levels"], [], "Missing save has no completed levels")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd`

Expected: FAIL because `save_manager.gd` does not exist.

- [ ] **Step 3: Implement minimal safe JSON manager**

```gdscript
const DEFAULT_DATA := {
	"save_version": 1,
	"highest_unlocked_level": 1,
	"completed_levels": [],
	"best_scores": {},
	"best_combos": {},
	"music_enabled": true,
	"sound_enabled": true,
	"haptics_enabled": true,
}

func load_data() -> Dictionary:
	if not FileAccess.file_exists(_save_path):
		return DEFAULT_DATA.duplicate(true)
	# Parse and validate, returning defaults on any failure.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd`

Expected: PASS for save defaults and existing suite.

### Task 2: Save progress and recover corrupt data

**Files:**

- Modify: `scripts/save/save_manager.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write failing round-trip and corruption tests**

```gdscript
manager.record_completed_level(1, 320, 6)
_expect_equal(manager.load_data()["highest_unlocked_level"], 2, "Winning Level 1 unlocks Level 2")
manager.write_raw_for_tests("{not json")
_expect_equal(manager.load_data()["highest_unlocked_level"], 1, "Corrupt save falls back to defaults")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd`

Expected: FAIL because completion recording and test raw-write helper are absent.

- [ ] **Step 3: Implement record and validation behavior**

```gdscript
func record_completed_level(level_id: int, score: int, combo: int) -> Dictionary:
	var data := load_data()
	data["highest_unlocked_level"] = mini(9, maxi(int(data["highest_unlocked_level"]), level_id + 1))
	# Add completion once and retain only higher per-level records.
	save_data(data)
	return data
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd`

Expected: PASS for round-trip, invalid JSON, and existing suite.

### Task 3: Connect a won game to persisted progression

**Files:**

- Modify: `scenes/gameplay/Gameplay.tscn`
- Modify: `scripts/gameplay/gameplay.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Write the failing gameplay integration test**

```gdscript
gameplay.game_controller.score = 420
gameplay.game_controller.max_combo = 7
gameplay.game_controller.finish_level(true)
_expect_equal(gameplay.save_manager.get_highest_unlocked_level(), 2, "Won gameplay session persists next unlock")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd`

Expected: FAIL because Gameplay has no `SaveManager` node or save hook.

- [ ] **Step 3: Add one scene-owned SaveManager and win hook**

```gdscript
@onready var save_manager: Node = $SaveManager

func _on_game_finished(won: bool) -> void:
	if won:
		save_manager.record_completed_level(level_number, game_controller.score, game_controller.max_combo)
	board_controller.clear_all()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd`

Expected: PASS for persisted win and existing interaction tests.

### Task 4: Verify fixed-seed spawning and update project status

**Files:**

- Modify: `tests/run_tests.gd`
- Modify: `PROGRESS.md`

- [ ] **Step 1: Write a failing deterministic-seed test**

```gdscript
var sequence_a := await _capture_spawn_sequence(7331)
var sequence_b := await _capture_spawn_sequence(7331)
_expect_equal(sequence_a, sequence_b, "Same SpawnDirector seed reproduces sequence")
```

- [ ] **Step 2: Run test to verify it fails or exposes non-determinism**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd`

Expected: FAIL until any randomization outside the configured seed is eliminated from the test path.

- [ ] **Step 3: Make the minimal SpawnDirector adjustment, only if the test exposes one**

```gdscript
func configure(board: Control, config: LevelConfig = null) -> void:
	_board = board
	_config = config
	_rng.seed = deterministic_seed if deterministic_seed != 0 else Time.get_unix_time_from_system()
```

- [ ] **Step 4: Run full verification and update status**

Run: `godot_console --headless --path . --script res://tests/run_tests.gd; godot_console --headless --path . --script res://tests/smoke_test.gd`

Expected: both commands exit 0. Mark Milestone 4 progress/save and deterministic coverage complete, leaving menu/navigation for Milestone 5.
