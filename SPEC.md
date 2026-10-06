# SPEC.md — Цирковой переполох MVP

## 1. Product summary

**Цирковой переполох** is a portrait mobile casual arcade game inspired by Whac-A-Mole.

The action takes place inside a circus tent. The central playfield contains **nine jack-in-the-box style boxes arranged 3×3**. Different clowns pop out on springs for a limited time. The player uses one finger to tap the board; a large toy clown hammer strikes the selected box.

The player must rapidly answer a simple question:

**Hit this clown, ignore it, or intentionally sacrifice combo for its bonus?**

The game is built around immediate feedback:

`see → recognize → decide → tap → BONK → reaction → score/bonus/penalty`

Target platforms: Android, iOS.
Primary development platform: Windows.
Engine: Godot 4.x stable.
Language: GDScript.
Orientation: portrait.
Base design size: 1080×1920.
Renderer: Compatibility.
Primary control: one-finger tap.
MVP content: 1 world, 9 levels, 7 gameplay clown types, no metagame economy.

---

## 2. MVP hypothesis

The MVP exists to test whether the core interaction is enjoyable for repeated 60-second sessions.

The essential fun must come from:

- recognizing the clown type;
- choosing hit / do not hit;
- reacting quickly;
- maintaining combo;
- receiving satisfying hammer feedback.

Do not rely on a store, progression economy, ads, collectibles, or multiple worlds to make the game engaging.

---

## 3. Explicit non-goals

Do not implement in MVP:

- coins/currency;
- shop/upgrades;
- hammer or clown purchases;
- ads/IAP;
- accounts/backend/cloud saves;
- online leaderboard;
- daily tasks/battle pass/energy;
- paid continues;
- collectibles;
- story campaign;
- multiple worlds;
- multiplayer;
- physics-driven spring simulation.

---

## 4. World

MVP contains one world: **Circus Tent**.

Visual identity:

- red/yellow/blue tent fabric;
- warm bulbs;
- wood stage;
- stars;
- flags;
- confetti;
- toy-like circus props;
- cheerful rather than scary clowns.

All nine levels use this world.
Levels differ primarily by gameplay pacing and character mix, not by new environment production.

---

## 5. Board

Exactly nine fixed BoxSlots:

```text
0 1 2
3 4 5
6 7 8
```

Rules:

- one occupant maximum per slot;
- boxes do not move or break;
- board geometry does not change between MVP levels;
- SpawnDirector may spawn only into an IDLE slot;
- hit region covers both box and character-emergence area.

---

## 6. Level duration

Base duration:

```text
60.0 seconds
```

Timer decreases only while state is `RUNNING`.
Timer pauses during countdown, pause, result and finished states.

Clock can extend time.
Per-level total Clock bonus cap:

```text
30 seconds
```

---

## 7. Lives

Player starts each level with 3 lives, displayed as hammers matching the gameplay hammer:

```text
🔨 🔨 🔨
```

Maximum 3, minimum 0.
At 0 lives, immediate loss.

### 7.1. Life-loss events

A life is lost when:

1. player accumulates three consecutive misses: empty-box strikes or escaped Normal/Fast/Golden;
2. player hits Bomb;

### 7.2. No life loss for

- first or second consecutive miss on Normal/Fast/Golden;
- ignored Bomb;
- missed Clock;
- missed Glutton;
- first or second consecutive empty-box strike, including while Clock or Glutton is active;
- direct hit on Drunk;
- combo reset.

---

## 8. Score

There is no currency.

Base scoring hit:

```text
+10
```

Scoring targets:

- Normal
- Fast
- Golden

Successful hit:

```text
score += 10
combo += 1
```

Combo does not multiply score in MVP.

---

## 9. Combo

State:

```text
combo_count: int
max_combo: int
```

Initial combo is 0.

### Combo increases on

- Normal hit;
- Fast hit;
- Golden hit.

### Combo resets on

- empty-box gameplay tap;
- missed Normal/Fast/Golden;
- Bomb hit;
- Drunk hit;
- escaped Glutton.

### Combo is preserved when

- Bomb is correctly ignored;
- Clock is ignored;
- Drunk is ignored.

---

## 10. Character categories

### SCORING_TARGET

- Normal
- Fast
- Golden

Hit: +10 score, +1 combo.

### BONUS_OR_RISK_REWARD

- Clock
- Glutton

Hit applies its effect without resetting combo.

### HAZARD

- Bomb
- Drunk

Correct behavior is normally not to hit.
A hazard hit resets combo and applies its consequence.

---

## 11. Normal clown

Role: baseline target.

Visual: orange/red hair, red nose, small blue hat, cheerful face.

Hit:

```text
score += 10
combo += 1
```

Escape:

```text
combo = 0
```

No life loss.
Suggested visible duration: 1.0–1.5 sec depending on level.

---

## 12. Fast clown

Role: reaction-speed target.

Visual markers: goggles and/or propeller hat, movement streaks, energetic expression.

Hit:

```text
score += 10
combo += 1
```

Escape resets combo, no life loss.
Suggested visible duration on full introduction: 0.50–0.60 sec.

---

## 13. Golden clown

Role: rare scoring target and level-objective target.

Visual: gold hair/clothes, crown, star sparkles.

Hit:

```text
score += 10
combo += 1
golden_hits += 1
```

Escape resets combo, no life loss.

No coins and no special score multiplier in MVP.

---

## 14. Bomb clown

Role: avoid target.

Visual: black bomb/helmet, skull icon, burning fuse, angry face.

Correct action: do not hit.

Hit:

```text
lives -= 1
consecutive_misses = 0
combo = 0
```

Score +0.

Escape: no penalty, combo unchanged.

Feedback: cartoon flash, smoke puff, stronger short shake, apple HUD loss animation.

---

## 15. Clock clown

Role: optional time bonus at the cost of combo.

Visual: large clock prop.

Hit:

```text
remaining_time += 10.0
```

Subject to max time bonus cap.
Score +0.
Escape: no penalty, combo unchanged.

HUD feedback: `+10 SEC`, timer bounce, clock SFX.

---

## 16. Glutton clown

Role: risk/reward life character.

Visual: clearly holding/eating a large red apple, greedy expression.

Correct action: hit before escape.

### Hit while lives < 3

```text
lives += 1
```

Score +0.

Animation: hammer hit → hammer flies from clown → hammer reaches Lives HUD → empty life slot refills.

### Hit while lives == 3

Lives remain 3. Combo is preserved. No fourth life.
Show brief “full lives” feedback.

### Escape

```text
combo = 0
```

Animation concept: HUD apple flies to Glutton → Glutton eats apple → hides.
If lives becomes 0, immediate loss.

---

## 17. Drunk clown

Role: control-disruption hazard.

Visual: green bottle, flushed cheeks, sleepy eyes, bubbles, tilted hat.

Correct action: do not hit.

Hit:

```text
combo = 0
confused_strikes_remaining = 1
```

No immediate life loss, no score.

### Confusion behavior

The next gameplay tap is redirected to a random box. It is not an automatic hit.

Pseudo-code:

```text
on_board_tap(requested_slot):
    actual_slot = requested_slot

    if confused_strikes_remaining > 0:
        actual_slot = random slot 0..8
        confused_strikes_remaining -= 1

    resolve_hit(actual_slot)
```

The random box may equal the requested box.
UI/Pause/Settings taps do not consume the counter.

While confused:

- show bottle/status icon;
- show remaining 3/2/1;
- mild wobble allowed;
- hammer visibly hits actual random box.

Random hit resolves normally.
SpawnDirector must not spawn another Drunk while confusion is active.

---

## 18. Hammer

Large toy circus hammer, red/yellow, star motif.

Tap sequence:

1. receive gameplay tap;
2. resolve requested/actual slot;
3. swing hammer;
4. impact;
5. target response;
6. hammer exits.

Suggested timings:

```text
anticipation 40–60 ms
swing        70–100 ms
impact       40–60 ms
return       60–90 ms
```

Total about 180–250 ms.
Do not block new gameplay input for the entire animation.
Suggested debounce: 70–100 ms, tune on device.

---

## 19. Empty hit

Gameplay tap on empty BoxSlot:

```text
combo = 0
score unchanged
consecutive_misses += 1
at 3 misses: lives -= 1; consecutive_misses = 0
```

Feedback: small box shake, wooden thunk, tiny dust.
Show life-loss feedback on the third consecutive miss. Any clown hit resets the miss streak. Ignored Bomb/Clock/Glutton and UI taps do not change it; pausing preserves it and starting a level clears it.

---

## 20. BoxSlot state machine

States:

```text
IDLE
OPENING
ACTIVE
HIT
HIDING
COOLDOWN
```

Flow:

```text
IDLE → OPENING → ACTIVE → HIT/HIDING → COOLDOWN → IDLE
```

Spawn allowed only in IDLE.

Recommended visual order:

```text
box back
character + spring
box front
foreground FX
```

---

## 21. Clown state machine

States:

```text
SPAWNING
VISIBLE
HIT
ESCAPING
DESPAWNED
```

A clown can be hit only once. Disable hit resolution immediately after first valid hit.

---

## 22. Spring

No physics simulation.
Use Sprite2D/TextureRect plus scale/tween/AnimationPlayer.

Example pop:

```text
scale_y 0.30 → 1.08 → 1.00
```

Hit:

```text
1.00 → 0.35
```

---

## 23. SpawnDirector

Central owner of all spawn logic.

Responsibilities:

- read `LevelConfig`;
- schedule spawn attempts;
- choose character by weights;
- choose eligible free BoxSlot;
- enforce max active;
- enforce double-spawn rules;
- enforce fairness;
- enforce character limits;
- support deterministic test seed.

Do not put independent random spawn timers in nine BoxSlots.

Use `RandomNumberGenerator` and support fixed seed for tests.

---

## 24. Spawn fairness

Mandatory baseline constraints:

1. Never spawn into non-IDLE slot.
2. Never have two occupants in one slot.
3. Max active follows LevelConfig.
4. No new Drunk while confusion active.
5. Max one Glutton active.
6. Max one Bomb active.
7. Clock count obeys per-level cap.
8. Avoid same slot more than twice consecutively.
9. Levels 1–8: avoid Bomb + Glutton exact simultaneous spawn.
10. Levels 1–8: avoid two hazards simultaneously.
11. Levels 1–8: avoid unfair Fast + Glutton exact simultaneous pop.
12. Double spawn may be staggered 80–200 ms.

Level 9 may be more aggressive but must remain readable.

---

## 25. Game state

```text
LOADING
COUNTDOWN
RUNNING
PAUSED
FINISHED_WIN
FINISHED_LOSS
```

Gameplay timer/input logic runs only in appropriate states.

---

## 26. Level start

Sequence:

```text
3
2
1
GO!
```

Total around 2–3 seconds.
During countdown, board taps are ignored, SpawnDirector is stopped, timer is stopped.
At GO, state becomes RUNNING.

---

## 27. Level finish

Immediately stop SpawnDirector, gameplay input and timer.
Hide or settle active characters.
Show Results after about 0.4–0.7 sec.

Win: timer reaches zero, objectives satisfied, at least one life.
Loss: lives reaches zero, or timer reaches zero with objective failure.

---

## 28. Objectives

Supported MVP objective types:

- target score;
- minimum max combo;
- required Golden hits.

Keep objective implementation simple and typed/data-driven.

---

## 29. Initial level balance

All values are tunable defaults in resources, not hardcoded gameplay branches. Every level schedules its active character types at random moments from 10% through 75% of the round; weights control all other spawns. During the current tuning pass, Fast, Golden and Drunk are disabled from automatic spawning.

### Level 1 — Introduction

- Normal weight 100; each other type weight 1
- max active 1
- visible 0.75 sec
- spawn interval 0.25–0.31 sec
- objective score >= 150

### Level 2 — Rhythm

- Normal weight 100; each other type weight 1
- max active 1
- visible 0.625 sec
- spawn 0.20–0.27 sec
- objective score >= 250

### Level 3 — Speed

- Normal weight 100; each other type weight 1
- max active 1
- visible 0.475 sec
- spawn 0.16–0.22 sec
- objective score >= 300

### Level 4 — Two targets

- Normal weight 100; each other type weight 1
- max active 2
- double-spawn chance 35%
- visible 0.50 sec
- spawn 0.17–0.23 sec
- objective score >= 400

### Level 5 — Golden

- Normal 88; Golden 12; each other type 1
- max active 2
- Golden visible 0.35 sec
- objective: score >= 350

### Level 6 — Bomb + combo discipline

- Normal 78; Bomb 22; each other type 1
- max active 2
- objectives: score >= 350; max_combo >= 5
- first hint: `БОМБА! НЕ БЕЙ!`

### Level 7 — Fast

- Normal 65; Fast 25; Bomb 10; each other type 1
- max active 2
- Fast visible 0.275 sec
- Normal visible 0.45 sec
- objective score >= 400

### Level 8 — Specials

- Normal 55; Fast 12; Golden 1; Bomb 8; Clock 8; Glutton 10; Drunk 7
- max active 2
- objective score >= 350
- guarantee at least one appearance of every clown type

### Level 9 — Final mix

- Normal 43
- Fast 18
- Golden 8
- Bomb 10
- Clock 5
- Glutton 9
- Drunk 7
- max active 2
- double-spawn chance 50%
- objectives: score >= 500; max_combo >= 8

---

## 30. LevelConfig Resource

Suggested fields:

```text
level_id: int
display_name: String
duration: float

target_score: int
required_max_combo: int
required_golden_hits: int

spawn_interval_min: float
spawn_interval_max: float
max_active_characters: int
double_spawn_chance: float

normal_weight: float
fast_weight: float
golden_weight: float
bomb_weight: float
clock_weight: float
glutton_weight: float
drunk_weight: float

normal_visible_time: float
fast_visible_time: float
golden_visible_time: float
bomb_visible_time: float
clock_visible_time: float
glutton_visible_time: float
drunk_visible_time: float

max_clock_spawns: int
max_time_bonus: float
```

Resources:

```text
res://data/levels/level_01.tres
...
res://data/levels/level_09.tres
```

---

## 31. CharacterDefinition Resource

Suggested fields:

```text
id
display_name
category
scene
icon
base_score
spawn_sound
hit_sound
escape_sound
```

Avoid duplicating category state across many contradictory booleans.

---

## 32. Recommended project tree

```text
res://
├── project.godot
├── AGENTS.md
├── SPEC.md
├── PROGRESS.md
├── README.md
├── autoload/
│   ├── game_state.gd
│   ├── save_manager.gd
│   ├── audio_manager.gd
│   └── scene_router.gd
├── assets/
│   ├── backgrounds/
│   ├── characters/
│   │   ├── normal/
│   │   ├── fast/
│   │   ├── golden/
│   │   ├── bomb/
│   │   ├── clock/
│   │   ├── glutton/
│   │   └── drunk/
│   ├── boxes/
│   ├── hammer/
│   ├── ui/
│   ├── fx/
│   ├── fonts/
│   └── audio/
├── data/
│   ├── characters/
│   └── levels/
├── scenes/
│   ├── boot/
│   ├── menu/
│   ├── levels/
│   ├── gameplay/
│   ├── characters/
│   ├── components/
│   └── ui/
├── scripts/
│   ├── gameplay/
│   ├── ui/
│   ├── data/
│   └── utilities/
├── tests/
│   ├── run_tests.gd
│   ├── test_scoring.gd
│   ├── test_combo.gd
│   ├── test_lives.gd
│   ├── test_drunk.gd
│   ├── test_spawn_director.gd
│   └── test_level_configs.gd
└── builds/
```

Ignore `builds/` in version control.

---

## 33. Main scenes

Required:

```text
Boot.tscn
MainMenu.tscn
LevelSelect.tscn
Gameplay.tscn
ResultsPopup.tscn
PausePopup.tscn
SettingsPopup.tscn
BoxSlot.tscn
ClownBase.tscn
Hammer.tscn
FloatingText.tscn
AppleFlyFX.tscn
```

---

## 34. Gameplay scene concept

```text
Gameplay
├── Background
├── CircusDecor
├── GameArea
│   ├── Playfield
│   │   ├── Slot00 ... Slot22
│   ├── CharacterFX
│   ├── HammerLayer
│   └── FloatingTextLayer
├── HUD
│   ├── PauseButton
│   ├── LevelLabel
│   ├── TimerPanel
│   ├── ScorePanel
│   ├── ComboPanel
│   └── LivesPanel
├── CountdownLayer
├── TutorialLayer
├── PauseLayer
└── ResultLayer
```

---

## 35. Controllers

### GameController

Owns authoritative runtime gameplay state.
Responsibilities:

```text
start_level
pause_level
resume_level
finish_level
handle_board_tap
resolve_character_hit
add_score
increment_combo
reset_combo
lose_life
restore_life
add_time
```

### BoardController

```text
get_free_slots
get_slot
get_occupant
spawn_character
hit_slot
clear_all
```

### SpawnDirector

Owns spawn scheduling/selection.

### HammerController

Owns visual hammer behavior and resolved impact location.

HUD observes via signals rather than owning rules.

---

## 36. Signals

Examples:

```text
BoxSlot.tap_requested(slot_index)
SpawnDirector.character_spawned(character)
SpawnDirector.character_escaped(character)
GameController.score_changed(value)
GameController.combo_changed(value)
GameController.lives_changed(value)
GameController.time_changed(value)
GameController.confusion_changed(remaining)
GameController.game_finished(result)
```

Avoid an unnecessary universal EventBus.

---

## 37. Touch input

Primary: `InputEventScreenTouch`.

Requirements:

- mouse-to-touch emulation for editor development;
- whole BoxSlot logical region is tappable;
- UI consumes its own taps;
- multi-touch gameplay not required;
- use one consistent policy for simultaneous touches.

---

## 38. Responsive UI

Base: 1080×1920.
Use `canvas_items` and `expand`.
Use anchors/containers.

Test at minimum:

```text
720×1280
1080×1920
1080×2340
1440×3200
```

Also validate tall phone safe areas/cutouts.

---

## 39. HUD

Priority:

1. playfield;
2. characters;
3. timer;
4. lives;
5. score;
6. combo.

Required: Pause, Level, Timer, Score, Combo, three hammers.

Lives loss: hammer shake/bounce → fade/shrink.
Life restore: hammer flies from Glutton → HUD slot pops in.
Combo 0 may be hidden. x3+ should bounce.
Timer displays MM:SS and may pulse below 10 sec.
Clock shows `+10 SEC`.

---

## 40. Main menu

Required:

```text
ЦИРКОВОЙ ПЕРЕПОЛОХ
ИГРАТЬ
УРОВНИ
НАСТРОЙКИ
ОБ ИГРЕ
```

Visual: circus tent, marquee lights, mascot clown, toy/game-show feel.

`ИГРАТЬ` starts earliest unlocked incomplete level. If all complete, Level 9 is acceptable.

---

## 41. Level select

Grid:

```text
1 2 3
4 5 6
7 8 9
```

States: LOCKED, UNLOCKED, COMPLETED.
No 3-star system in MVP.
Completed may show check mark and best score.
Initially only Level 1 unlocked. Winning N unlocks N+1.

---

## 42. Results

Win:

```text
УРОВЕНЬ ПРОЙДЕН!
Очки: 620
Лучшее комбо: x11
```

Buttons: ДАЛЬШЕ, ЕЩЁ РАЗ, МЕНЮ.

Loss:

```text
НЕ ПОЛУЧИЛОСЬ!
Очки: ...
Цель: ...
```

Buttons: ПОВТОРИТЬ, МЕНЮ.

---

## 43. Pause

Pause stops gameplay timer, spawn scheduling, gameplay input and relevant animations/tweens.

Popup:

```text
ПРОДОЛЖИТЬ
НАЧАТЬ ЗАНОВО
НАСТРОЙКИ
В МЕНЮ
```

Pause tap never counts as gameplay hit or Drunk strike.

---

## 44. Settings

MVP:

- Music ON/OFF
- Sound ON/OFF
- Haptics ON/OFF

Russian-only first build is acceptable.
Keep strings centralized for later localization.

---

## 45. Save system

Local only.

Store:

```text
highest_unlocked_level
completed_levels
best_scores
best_combos
music_enabled
sound_enabled
haptics_enabled
```

Defaults:

```text
highest_unlocked_level = 1
completed_levels = []
best_scores = {}
best_combos = {}
music_enabled = true
sound_enabled = true
haptics_enabled = true
```

Missing/corrupt save must not crash.
Do not add nonexistent currencies/inventory.

---

## 46. Audio

One looping circus music track is sufficient.

Required SFX hooks:

- box pop;
- hammer BONK;
- correct hit;
- empty wood hit;
- Bomb;
- life lost;
- Clock bonus;
- apple restore;
- Glutton escape/eat;
- Drunk effect;
- combo;
- countdown;
- victory;
- defeat;
- UI button.

Use separate Music/SFX buses/categories.

---

## 47. Haptics

If available:

- correct hit: light;
- Bomb: medium;
- life loss: medium.

Haptics must obey Settings and are not required for gameplay correctness.

---

## 48. Visual style

Target: bright, cartoony, toy-like, soft 2.5D volume, high contrast, readable silhouettes, cheerful circus.

Avoid horror clowns, photorealism, blood/gore, realistic weapons.

---

## 49. Asset conventions

Background preferred master: 2160×3840; minimum 1080×1920.
Clown transparent source: 512×512 or larger.
Do not bake reusable box into each clown asset.

Box split preferred:

```text
box_back
box_front
box_lid
spring
```

Hammer: transparent 768×768 or 1024×1024, pivot near handle end.

Reusable UI pieces:

```text
button_primary
button_secondary
panel_wood
panel_blue
panel_red
combo_badge
apple
pause
clock
lock
check
```

Prefer NinePatchRect for scalable panels/buttons.

---

## 50. Core animations

Pop timing guideline:

```text
lid anticipation 0.05
pop              0.16
overshoot        0.06
settle           0.05
```

Idle: small sway/blink/spring oscillation.

Correct hit:

```text
hammer impact
→ squash Y / stretch X
→ star particles
→ +10
→ spring compress
→ clown hides
```

Reaction target: 0.25–0.35 sec.

Floating +10: rise 60–100 px, fade 1→0, scale 0.7→1.1→1.0, 0.5–0.7 sec.

---

## 51. Camera shake

Correct: 2–3 px for ~80 ms.
Bomb: 5–8 px for ~150 ms.
Keep subtle.

---

## 52. Tutorial

No long tutorial scene. Use first-time contextual hints.

Level 1: `Тапни по клоуну!`
Level 5: `ЗОЛОТОЙ КЛОУН! Успей ударить!`
Level 6: `БОМБА! НЕ БЕЙ!`
Level 7: `БЫСТРЫЙ!`
Level 8 Clock: `Часы дают +10 секунд, но сбрасывают комбо.`
Level 8 Glutton: `Ударь Обжору! Он вернёт яблоко. Если упустишь — съест жизнь.`
Level 8 Drunk: `Не бей Пьяницу! Иначе следующий удар станет случайным.`

Do not repeatedly interrupt after first teaching.

---

## 53. Code style

- snake_case for functions/variables;
- PascalCase for classes/resources;
- UPPER_SNAKE_CASE for constants;
- typed GDScript where practical;
- focused functions;
- no giant monolithic scripts.

---

## 54. Randomness and tests

SpawnDirector owns a dedicated RNG.
Production uses randomized seed; tests use fixed seed.
Spawn sequences must be reproducible under test seed.

---

## 55. Performance

Target 60 FPS on a typical mid-range Android device.
Avoid unnecessary realtime lighting, heavy shaders, high-count particles, physics and premature pooling.

---

## 56. Automated tests

A headless test runner is required.

### Scoring

- Normal hit: 0 → 10
- Fast hit: 0 → 10
- Golden hit: 0 → 10 and golden_hits +1

### Combo

- Normal → 1
- Normal → 2
- Fast → 3
- Golden → 4
- Clock at combo 7 → 0
- empty tap at combo 4 → 0; life decreases only on the third consecutive miss
- escaped scoring target at combo >0 → 0

### Bomb

- lives 3 + hit Bomb → lives 2, combo 0
- ignored Bomb → lives and combo unchanged

### Clock

- time 42 + Clock hit → 52, combo 0
- after total +30 bonus, additional Clock gives no more time

### Glutton

- lives 2 + hit → 3
- lives 3 + hit → 3
- lives 3 + escape → 2
- lives 1 + escape → 0 and loss

### Drunk

- hit → remaining 1
- one gameplay tap decrements 1→0
- second tap uses requested slot normally
- UI/Pause taps do not decrement

### LevelConfig validation

Validate:

- exactly 9 configs;
- unique IDs;
- duration > 0;
- weights >= 0;
- sum weights > 0;
- valid max active;
- L1 only Normal;
- L5 Golden;
- L6 Bomb;
- L7 Fast;
- L8 Clock/Glutton/Drunk;
- L9 all seven.

### Smoke

Headless smoke should load project, MainMenu if present, Gameplay, Level 1 config, perform a deterministic interaction, and exit 0.
Parser/resource errors fail the check.

---

## 57. Suggested CLI checks

```bash
godot --version
godot --headless --path . --script res://tests/run_tests.gd
```

When Android preset/toolchain is configured:

```bash
godot --headless --path . --export-debug "Android" builds/clown-smash-debug.apk
```

Do not report successful build unless exit code is successful and artifact exists.

---

## 58. Debug tools

Debug-only panel is allowed/recommended:

- set lives;
- set score;
- set time;
- spawn each clown;
- finish level;
- unlock all;
- force Drunk effect.

Must be hidden/disabled in release.

---

## 59. Implementation milestones

### Phase 0 — Bootstrap

Create project, folders, portrait settings, test runner, smoke test, docs.
Acceptance: empty project runs without parser/runtime error.

### Phase 1 — Core interaction

3×3 board, BoxSlot, Normal, SpawnDirector, tap resolution, hammer, +10, combo.
Acceptance: `Normal spawn → tap → hammer → +10 → combo → hide`.

### Phase 2 — Session

60-sec timer, 3 hammer life icons, countdown, pause, results, win/loss.
Acceptance: Level 1 complete loop works.

### Phase 3 — Characters

Implement one at a time: Golden, Bomb, Fast, Clock, Glutton, Drunk. Add tests before moving on.

### Phase 4 — Levels

LevelConfig, nine resources, objectives, progression.

### Phase 5 — Menu/UI

MainMenu, LevelSelect, Settings, Pause, Results, SaveManager.

### Phase 6 — Art

Replace placeholders with approved assets.

### Phase 7 — Polish

Spring motion, squash, particles, floating score, hammer flight, combo animation, subtle shake.

### Phase 8 — Audio

Music, SFX, haptics, settings.

### Phase 9 — Mobile QA

Touch, safe areas, aspect ratios, FPS, lifecycle, Android debug export.

---

## 60. Full MVP acceptance criteria

### Gameplay

- exactly nine BoxSlots;
- one-finger tap;
- responsive hammer;
- all seven clown types work;
- +10 scoring rules correct;
- combo rules correct;
- three consecutive empty hits or scoring-clown escapes remove one life;
- Bomb hit removes life;
- Glutton escape removes life;
- Glutton hit restores lost life;
- Clock adds 10 seconds;
- Drunk redirects exactly next gameplay tap;
- max lives 3;
- zero lives loses.

### Content

- one Circus Tent world;
- nine playable levels;
- progression unlocks;
- Level 9 mixes all mechanics.

### UI

- Main Menu;
- Level Select;
- gameplay HUD;
- Pause;
- Settings;
- Results.

### Save

- progression persists;
- settings persist;
- best score persists;
- best combo persists.

### Technical

- no parser errors;
- no known runtime errors in normal flow;
- headless tests pass;
- mouse works in editor;
- touch works on mobile;
- portrait layout;
- multiple aspect ratios usable;
- Android debug build works when toolchain configured.

### Scope

- no coins;
- no shop;
- no ads;
- no IAP;
- no backend.

---

## 61. Definition of Done

A Codex task is complete only when:

1. implementation exists;
2. behavior matches this spec;
3. relevant scenes/resources parse;
4. relevant tests are added/updated;
5. tests pass or environment blocker is documented;
6. no known regression caused by the task is unresolved;
7. `PROGRESS.md` is updated;
8. Codex reports changed files and checks performed.

---

## 62. Final design principle

The highest-priority quality target is the impact loop.

A correct hit should produce with minimal perceived latency:

1. hammer movement;
2. clown reaction;
3. BONK sound/haptic;
4. score/combo feedback.

Desired player reaction:

**“I want to hit the next one.”**

If this loop is not satisfying, menu polish and additional systems are lower priority.

---

## Animation reference specification

When designing or implementing animation for the clown, spring, box lid, or hammer, Codex must first read `ANIMATION_SPEC.md` and use it as the authoritative tuned animation reference.

Baseline parameters from the animation lab:

- Pop Height: 325 px
- Pop Duration: 0.68 s
- Overshoot: 46 px
- Idle / Wobble: 1.25 s
- Visible Time: 3.4 s
- Hide Duration: 0.62 s
- Full automatic cycle: 15 s
- Hammer Swing Duration: 0.22 s
- Hammer Rotation: 86°
- Impact Squash: 0.38
- Impact Duration: 0.18 s

Reference appearance sequence:

`closed box → lid opens → short compression → fast pop → overshoot → damped wobble → visible wait → return into box → lid closes → pause`

Reference hit sequence:

`click visible clown → hammer wind-up → impact flash → clown squash + spring compression → short rebound → clown falls into box → lid closes → pause → next cycle`

Implementation rules:

1. Reproduce the reference motion and phase ordering before adding extra polish.
2. Keep the important animation parameters easy to tune through `@export`, Resources, or an equivalently simple mechanism.
3. Spring behavior must remain deterministic animation/tweening, not physics simulation.
4. `ANIMATION_SPEC.md` defines the motion reference. Gameplay `LevelConfig` may shorten the time a clown remains hittable/visible as difficulty increases.
5. Gameplay overrides must be explicit. Do not silently rewrite the reference values just to fit level balance.
6. Final character assets must preserve the same perceived movement: spring-driven pop, overshoot, damped wobble, squash/stretch at impact, fast hammer swing, spring compression and rebound.
