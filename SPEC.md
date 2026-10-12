# SPEC.md — Цирковой переполох MVP

## 1. Product summary

**Цирковой переполох** is a portrait mobile casual arcade game inspired by Whac-A-Mole.

The action takes place inside a circus tent. The central playfield contains **nine jack-in-the-box style boxes arranged 3×3**. Different clowns pop out on springs for a limited time. The player uses one finger to tap the board; a large toy clown hammer strikes the selected box.

The player must rapidly answer a simple question:

**Hit this clown, ignore it, or collect a bonus while preserving the series?**

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
Content: one world, persistent training, endless five-phase cycles, six enabled types; Drunk disabled.

---

## 2. MVP hypothesis

The MVP exists to test whether the core interaction is enjoyable for repeated 25-second sessions.

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
- new monetization or backend systems beyond the existing platform integrations;
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

All rounds use this world and vary pacing and character mix.

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

## 6. Round duration

25 seconds of active play per round; Clock halves new clown spawn speed for 5 active seconds, with three Clock spawns per round. Repeat hits refresh five seconds without stacking; pauses freeze the effect and new rounds clear it. Existing clown movement and availability are unaffected. Round elapsed is monotonic and acceleration clamps at 25 seconds. Run time excludes practice, countdown, pauses, ads and transitions.

---

## 7. Lives

Player starts each run with 3 lives, displayed as hammers matching the gameplay hammer:

```text
🔨 🔨 🔨
```

Maximum 3, minimum 0.
At 0 lives, immediate loss.

### 7.1. Life-loss events

A life is lost when:

1. player accumulates three consecutive misses: empty-box strikes or escaped Normal/Fast/Golden;
2. player hits Bomb;
3. Glutton escapes (one life; ordinary miss counter resets).

### 7.2. No life loss for

- first or second consecutive miss on Normal/Fast/Golden;
- ignored Bomb;
- missed Clock;
- first or second consecutive empty-box strike, including while Clock or Glutton is active;
- direct hit on Drunk;
- combo reset.

---

## 8. Score

There is no currency.

Scoring: Normal +10, Fast +20, Golden +50.

Scoring targets:

- Normal
- Fast
- Golden

Successful hit:

```text
score += points_for_character
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
- Drunk is ignored;
- Clock or Glutton is hit.

---

## 10. Character categories

### SCORING_TARGET

- Normal
- Fast
- Golden

Hit: Normal +10, Fast +20, Golden +50; +1 combo.

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

Counts as one consecutive miss.
Suggested visible duration: 1.0–1.5 sec depending on level.

---

## 12. Fast clown

Role: reaction-speed target.

Visual markers: goggles and/or propeller hat, movement streaks, energetic expression.

Hit:

```text
score += 20
combo += 1
```

Escape resets combo and counts as one consecutive miss.
Fast availability: .550–.700 seconds according to phase.

---

## 13. Golden clown

Role: rare scoring target.

Visual: gold hair/clothes, crown, star sparkles.

Hit:

```text
score += 50
combo += 1
golden_hits += 1
```

Escape resets combo and counts as one consecutive miss.

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

Feedback: cartoon flash, smoke puff, stronger short shake, hammer HUD loss animation.

---

## 15. Clock clown

Role: optional spawn slowdown preserving combo.

Visual: large clock prop.

Hit:

```text
spawn_speed *= 0.5 for 5 active seconds
```

Repeat hits refresh the five-second effect; no duration or multiplier stacking. Round time is unchanged.
Score +0.
Escape: no penalty, combo unchanged.

HUD feedback: `SPAWNS ×0.5 · 5 SEC`, clock SFX.

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
lives -= 1
consecutive_misses = 0
```

Animation concept: HUD hammer flies to Glutton → Glutton eats apple → hides.
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
- show remaining 1;
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
3. reserve the current lifecycle and apply the result exactly once;
4. swing hammer (visual only);
5. impact and target reaction;
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
Show life-loss feedback on the third consecutive miss. Any clown hit resets the miss streak. Ignored Bomb/Clock and UI taps do not change it; Glutton escape resets it and removes one life; pausing preserves it and starting a level clears it.

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

- read `RoundProfile`;
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
3. Max active follows RoundProfile.
4. No new Drunk while confusion active.
5. Max one Glutton active.
6. Max one Bomb active.
7. Clock count obeys per-round cap.
8. Avoid same slot more than twice consecutively.
9. Bomb+Glutton and Fast+Glutton overlap are forbidden at every round index.
10. Hazard overlap is forbidden.
11. Delayed scoring pairs repeat all limits and generation/pause checks.

---

## 25. Game state

LOADING, COUNTDOWN, RUNNING, PAUSED, ROUND_TRANSITION, FINISHED_LOSS. Pause reasons are owned separately. Zero lives has priority over transitions.

---

## 26. Run start

start_run initializes 3 lives, zero counters and one RNG stream. Countdown occurs once. start_round resets only local timer, Clock quotas, round metrics and spawn plan.

---

## 27. Round and run finish

Timer expiry with lives enters ROUND_TRANSITION: spawning and input stop; existing animations complete without escape penalties. Round results wait for Continue before advancing. Lives, score, series, misses and active run time carry over. A run ends once at zero lives or voluntary restart/menu. Records checkpoint at boundaries and exit.

---

## 28. No mandatory objectives

No score, Golden or combo requirements, unlocks or campaign progression. Normal gives +10, Fast +20, Golden +50; combo never multiplies score.

---

## 29. Cycles and balance

Five phases repeat: recovery, build, variation, pressure, peak. Cycle 1 and cycle 100 use identical limits. Numeric sources: data/round_profiles/*.tres. Phase/pattern/seed are reproducible through RoundDirector. Patterns steady, pairs, precision, golden_series use a shuffled permitted bag, maximum two consecutive repeats. Only pairs enables staggered scoring pairs. Assistance is 0..2, applied between rounds: each step multiplies intervals/scoring windows by 1.05 (two steps 1.10), never harder than base. EMA accuracy alpha .25 needs >=10 opportunities; loss or valid EMA <.65 increases one step; two valid lossless rounds with EMA >.90 remove one step. Recovery grants one life per cycle for 20 uninterrupted scoring hits while injured in recovery, resets on error/full lives/leaving recovery; no passive healing. See docs/ENDLESS_IMPLEMENTATION_REPORT.md for actual verification.

---

## 30. RoundProfile Resource

class_name RoundProfile; typed duration, spawn intervals/end multiplier, occupancy and decision limits, weights, availability windows, Clock caps, recovery_hits_required and allowed_patterns. Five shared resources are duplicated for effective modifiers; tutorial resources are separate. Maximum 6 occupied/2 decisions, double <=.22, final interval >=.6716, windows Normal>=1.50/Fast>=0.550/Golden>=1.60/Bomb>=1.50/Clock>=1.90/Glutton>=2.20. Drunk=0.

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
│   ├── round_profiles/
│   └── tutorial/
├── scenes/
│   ├── boot/
│   ├── menu/
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
│   └── endless_runtime_test.gd
└── builds/
```

Ignore `builds/` in version control.

---

## 33. Main scenes

The active scenes are `boot/Boot.tscn`, `ui/StartupSplash.tscn`, `ui/MainMenu.tscn`, `gameplay/Gameplay.tscn`, `gameplay/BoxSlot.tscn`, `characters/ClownBase.tscn`, `ui/SessionOverlay.tscn` and `ui/SettingsOverlay.tscn`.

SessionOverlay owns pause, tutorial, transition and run results. Hammer and impact effects retain their existing procedural implementation. Campaign selection and separate campaign result scenes are not used.

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
│   ├── RoundLabel
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
start_run
start_round
pause_level(reason)
resume_level(reason)
complete_round
finish_run
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

Required: Pause, round/training number, Timer, total Score, current/best Series, three hammers. Phase/round descriptions are not displayed. A permanently visible message sign sits directly below the tickets; its text may be empty between messages. Bonus feedback, game messages, confusion and conditional recovery progress share that sign.

Lives loss: hammer shake/bounce → fade/shrink.
Life restore: hammer flies from Glutton → HUD slot pops in.
Show current Series without a multiplier; accent only at 3/5/10. Show total score, best run series and recovery progress only while injured in recovery. No permanent miss row or mandatory objectives.
Timer displays MM:SS and may pulse below 10 sec.
Clock shows `SPAWNS ×0.5 · 5 SEC`.

---

## 40. Main menu

Play resumes missing tutorial skills or starts a new endless run; Training explicitly repeats without erasing mastery or records. Settings and purchase restore preserved. Statistics opens a separate screen with independent best score/series/rounds/active time and Back returns to the main menu. Records are absent from the main menu; About is removed. No active run resume.

---

## 41. Tutorial entry

Campaign LevelSelect is removed. Training is available from menu and rules from pause.

---

## 42. Run results

Run result shows score, maximum series, fully completed rounds, active time and independent saved best score; buttons Retry and Menu. Loss and voluntary finish save records. Failed write never claims a saved record.

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

## 45. Save system v2

save_version=2, endless_rules_version=1, tutorial_version=1; learned_lessons, best_run_score, best_run_combo, best_run_rounds, best_run_active_seconds. Settings and ads_removed preserved. Original v1 bytes backed up before migration; old campaign values remain in legacy_campaign and never become endless records or mastery. Same-directory checked temporary writes, recoverable backup, unknown versions protected. Cloud merges matching-version lesson union and record maxima; cloud data cannot confer purchases. No active run serialization.

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

## 52. Persistent tutorial

Four tutorial rounds of 25 active seconds; cards and controlled demos stop timer/spawner. IDs: normal, misses, bomb, two, series, golden, fast, clock, glutton, endless_rules. Required actions: two Normal hits, three safe empty misses and subsequent hit reset, Bomb waiting, two different targets, three consecutive scoring hits, two Golden and two Fast, Clock five-second spawn slowdown, Glutton restore at two lives plus safe escape demonstration; final rules confirmation. Next cards and demo replacements wait for the actual character retreat and box closure; accepted hits still register immediately. Tutorial copy uses short actionable instructions. Practice never writes endless records or recovery/adaptation. Missing practice repeats, mastery saves immediately, repeat does not erase global lessons. Next is offered after current required exercises; final tutorial confirmation shows a completion modal with a good-wishes message and Start game. Start game uses the same SceneRouter.start_run entry as the main menu and starts a fresh ordinary game at round 1. All practice points, combo, bonus time, misses, completed rounds and active time reset; permanent mastery and records remain.

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

RoundDirector initializes one run RNG shared with SpawnDirector and GameController.
Production uses a randomized seed recorded in debug_plan; tests may supply that seed.
Profiles and spawns must be reproducible with the same seed and event/timing schedule.
Standalone controller tests may use their own RNG; cosmetic effects use separate randomness.

---

## 55. Performance

Target 60 FPS on a typical mid-range Android device.
Avoid unnecessary realtime lighting, heavy shaders, high-count particles, physics and premature pooling.

---

## 56. Automated tests

A headless test runner is required.

### Scoring

- Normal hit: 0 → 10
- Fast hit: 0 → 20
- Golden hit: 0 → 50 and golden_hits +1

### Combo

- Normal → 1
- Normal → 2
- Fast → 3
- Golden → 4
- Clock at combo 7 → 7
- empty tap at combo 4 → 0; life decreases only on the third consecutive miss
- escaped scoring target at combo >0 → 0

### Bomb

- lives 3 + hit Bomb → lives 2, combo 0
- ignored Bomb → lives and combo unchanged

### Clock

- Clock hit leaves round time and combo unchanged; new spawn countdowns advance at half speed for five active seconds
- another Clock hit refreshes five seconds without stacking; pause freezes, new round clears

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

### RoundProfile validation

Five profiles, bounded windows/weights/intervals, seeded cycle and pattern determinism, assistance and recovery tests.

### Smoke

Headless smoke should load project, MainMenu, Gameplay, recovery profile, perform a deterministic interaction, and exit 0.
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

Transition to endless implementation 2026-10-10 supersedes the nine-level milestones. Historical evidence is preserved in PROGRESS.md. Current work: profiles/director, continuous runtime, persistent practice, safe v2/cloud, consumer conversion, removal of campaign, acceptance checks.

---

## 60. Full acceptance criteria

Continuous rounds with explicit Continue including 9->10 and 999->1000; 1000-cycle bounds and seeded determinism; pause/practice isolation; three-miss/Bomb/Glutton rules, recovery; atomic migration and cloud compatibility; actual scene input/callback/soak tests; RU/EN responsive captures; optional disabled analytics. Device, hosted SDK, real provider/payment and publication require separate evidence.

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
4. `ANIMATION_SPEC.md` defines the motion reference. Gameplay `RoundProfile` may shorten the time a clown remains hittable/visible as difficulty increases.
5. Gameplay overrides must be explicit. Do not silently rewrite the reference values just to fit level balance.
6. Final character assets must preserve the same perceived movement: spring-driven pop, overshoot, damped wobble, squash/stretch at impact, fast hammer swing, spring compression and rebound.

## Current results and platform entry policy

Endless results checkpoint independent records on boundary, loss and voluntary exit. Ad placement follows the Existing monetization placement policy (2026-10-11) below: eligible five-round Continue or long-run defeat Retry; New Game and training remain ad-free. Errors/cancellation/timeout continue once, stale callbacks are ignored. Payment and restore verification remain required. Analytics stay disabled; compatible level events use stable phase IDs1..5 and separate round operations.

## Round-end results (2026-10-10)

Every ordinary and free-practice round lasts 25 active seconds. At timeout, input and spawning stop. Existing opening, hit, retreat and lid animations finish without escape penalties. A modal shows round score, total score, best series in this round and lives remaining. Only Continue starts the next round; waiting adds no active time, ads or penalties. State and independent records carry over. Practice Continue advances mastered rounds or repeats incomplete practice. Animation callbacks and Continue are generation guarded.

## Scoring and tutorial transition update (2026-10-10)

Fast availability after the approved 50% speed reduction: recovery .700, build .675, variation .625, pressure .600, peak .550 seconds; tutorial profile .700, controlled Fast demo 2.50 seconds. Animation motion is unchanged. Ordinary end-of-round results never end the game. The defeat modal requires zero lives and the current run generation; menu/restart do not produce a delayed defeat modal. Training HUD and results label stages separately from ordinary rounds.

## Player terminology

Every player-facing RU/EN mention uses hammers / молотки: three hammers, lose or restore a hammer, hammers remaining and hammers exhausted. Internal life/lives save fields, signals and method names retain their existing contracts.


## Existing monetization placement policy (2026-10-11)

- Ordinary rounds remain 25 seconds. Interstitials may be requested on Continue after each five completed rounds, or Retry after a lost ordinary run lasting at least 120 active seconds. New Game, onboarding, practice and first ordinary start after training do not request an interstitial.
- One shared session interval requires 120 active seconds of ordinary play since the last provider-confirmed show. Countdown, animations after timeout, pause, results, training and advertisements contribute no time. A new app session starts the interval from zero. Failed requests do not count as shows and have a 60-second wall-clock retry backoff.
- One pending request/continuation; errors and unavailable inventory continue once. A missing callback before opening has a 30-second watchdog; an opened advertisement waits for the provider close callback. Platform resume precedes a new round.
- User-approved banner placement: ordinary gameplay RUNNING only. No banners in menus, results, countdown, pause or training. Async loads must not reopen a banner after leaving gameplay.
- Existing durable remove_ads suppresses both formats, preserves purchase/restore behavior and SDK catalog metadata. No rewarded continuation, paid hammers, new products, analytics activation, SDK updates or deployment are included.
