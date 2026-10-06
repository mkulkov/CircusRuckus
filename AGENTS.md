# AGENTS.md — Clown Smash

## 1. Role

You are developing **Clown Smash**, a small portrait mobile arcade game in **Godot 4.x** using **GDScript**.

Primary goals, in order:

1. Correct gameplay behavior.
2. Fast and responsive touch input.
3. Clear character readability.
4. Satisfying hammer impact feedback.
5. Stable project structure and tests.
6. Visual polish.
7. Minimal implementation cost and complexity.

The authoritative product/gameplay specification is `SPEC.md`.
The authoritative tuned animation reference is `ANIMATION_SPEC.md`; read it before implementing or modifying clown, spring, box-lid, or hammer animation.
Project status and next work are tracked in `PROGRESS.md`.

Do not invent or expand product scope when `SPEC.md` already defines the behavior.

---

## 2. Source of truth

Priority order:

1. Explicit current user instruction.
2. `SPEC.md`.
3. This `AGENTS.md`.
4. Existing tested behavior.
5. `PROGRESS.md`.
6. Reasonable implementation judgement.

If a requested implementation conflicts with a critical gameplay rule in `SPEC.md`, do not silently change the rule.

---

## 3. MVP scope lock

The MVP has:

- one world: circus tent;
- nine levels;
- 3×3 boxes;
- one-finger tap control;
- 60-second base level duration;
- three apple lives;
- seven gameplay clown types: Normal, Fast, Golden, Bomb, Drunk, Clock, Glutton.

The MVP does **not** contain:

- coins or currency;
- shop;
- ads or IAP;
- accounts/backend/cloud sync;
- online leaderboard;
- daily quests/battle pass/energy;
- paid lives;
- multiple worlds;
- multiplayer;
- collectible metagame.

Do not add these systems unless the user explicitly changes scope.

---

## 4. Critical gameplay invariants

Never change these without explicit user approval:

1. Board is exactly 3×3.
2. Primary input is a single tap / one finger.
3. Base level duration is 60 seconds.
4. Player starts with 3 lives represented by hammers in the HUD.
5. Every three consecutive misses (empty-box strikes or escaped Normal/Fast/Golden) remove one life; any clown hit resets the streak, and each penalty starts a new streak.
6. A scoring target hit gives exactly +10 score.
7. Combo does not multiply score in MVP.
8. Normal, Fast and Golden are scoring targets.
9. A correct scoring hit increases combo by 1.
10. A miss on a scoring target resets combo.
11. Empty-box tap resets combo.
12. Clock and Glutton successful hits reset combo.
13. Bomb and Drunk hits reset combo.
14. Bomb hit removes one life.
15. Ignoring Bomb has no penalty.
16. Clock hit adds 10 seconds, subject to the time-bonus cap.
17. Glutton hit restores one lost apple, up to 3 lives.
18. If Glutton escapes, it consumes one apple/life.
19. Drunk hit causes the next 3 gameplay taps to strike random boxes.
20. Drunk effect is not 3 automatic hits.
21. UI taps do not consume Drunk-effect strikes.
22. No coins exist anywhere in MVP.

---

## 5. Technical defaults

Use:

- Godot 4.x stable;
- GDScript;
- Compatibility renderer unless a justified alternative already exists;
- portrait orientation;
- base design resolution 1080×1920;
- `canvas_items` stretch;
- `expand` aspect behavior;
- reusable scenes/resources;
- typed GDScript where practical;
- signals for local communication;
- `RandomNumberGenerator` for spawn randomness;
- `.tres` Resources for level tuning.

Do not introduce C#, a third-party addon, an external framework, or a backend unless explicitly required.

---

## 6. Architecture rules

Expected major systems:

- `GameController`
- `BoardController`
- `SpawnDirector`
- `BoxSlot`
- `ClownBase`
- `HammerController`
- `HUD`
- `SaveManager`
- `AudioManager`
- `SceneRouter`

Keep responsibilities separated.
Do not create one oversized `Gameplay.gd` that owns everything.
Prefer data-driven level configuration over hardcoded per-level branches.
Do not implement physical spring simulation.
Do not add object pooling unless profiling shows a need.

---

## 7. Working method

For every non-trivial task:

1. Read relevant sections of `SPEC.md`.
2. Inspect current implementation before editing.
3. Make the smallest coherent change that completes the task.
4. Run the smallest relevant automated checks.
5. Run a headless project/smoke check when practical.
6. Fix regressions caused by the change.
7. Update `PROGRESS.md`.
8. Report files changed, behavior implemented, tests/checks run, and known issues.

Do not declare completion merely because code was written.

---

## 8. Development order

Unless the user instructs otherwise, follow the milestone order in `PROGRESS.md`.

The first playable milestone is:

`9 boxes → Normal spawn → tap → hammer → +10 → combo → hide → repeat`

Do not build polished menus or speculative infrastructure before this loop works.

---

## 9. Testing policy

After gameplay logic changes, run the smallest relevant test set first.
Before completing a milestone, run the full project test suite.

Expected command shape:

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

Also perform a headless scene/resource load check when the change affects scenes/resources.

A task is not complete while there are parser errors, missing resources, broken scene paths, or known failing relevant tests.

If a test cannot run because the environment lacks Godot/export tooling, record the blocker in `PROGRESS.md` and report it explicitly.

---

## 10. Cheap subagent policy

Subagents are optional. Use them only when delegation is likely to reduce total cost or execution time without increasing integration risk.

### 10.1. Ownership

The main agent remains the owner/orchestrator.
Subagents are bounded workers, not autonomous project leads.

The main agent must:

- define a narrow task;
- provide only required context;
- specify expected output;
- review the result;
- integrate it;
- perform final verification.

Do not delegate product rules, architecture ownership, final gameplay interpretation, or broad cross-cutting refactors to cheap workers.

### 10.2. Cost-first routing

When the current Codex harness supports selecting a worker model/reasoning level, prefer:

| Task class | Preferred worker | Reasoning |
|---|---|---|
| File/repository scan, grep, asset inventory, repetitive inspection | GPT-6 Sol | low |
| Simple documentation maintenance, test enumeration, boilerplate | GPT-6 Luna | low |
| One short, local, well-defined GDScript or UI adjustment in an existing implementation | GPT-6 Luna | low |
| Small isolated GDScript change with explicit acceptance criteria | GPT-6 Sol | low |
| Unit tests for already-defined behavior | GPT-6 Sol | medium |
| Low-risk bounded refactor | GPT-6 Sol | medium |
| Difficult debugging, cross-system integration, architecture review | GPT-6 Sol | high |
| High-risk or ambiguous technical judgement | GPT-6 Sol | high |

Available model names and selectable effort may differ by Codex version/account. Treat routing as requested until runtime confirms it.
If the harness cannot actually pin a child model/effort, do not claim that it did.

Use Luna only for the focused cases in the table. Do not use it for
architecture, broad refactors, unclear diagnosis, risky changes, or work that
needs deep reasoning; use Sol at the effort the scope requires.

### 10.3. Astra policy

**GPT-6 Astra must never be selected automatically.**

Before recommending Astra:

1. stop before dispatch;
2. explain why Sol is insufficient or materially less efficient;
3. state expected benefit;
4. request explicit user permission;
5. use Astra only after approval. A direct user instruction to use Astra for
   the task also authorizes its use without a second request.

Do not use Astra for routine coding, file scans, asset renaming, standard tests, formatting, simple bug fixes, or documentation maintenance.

### 10.4. Good tasks for cheap workers

Examples:

- find every reference to `combo_count`;
- list broken resource paths;
- inventory clown textures;
- verify all nine LevelConfig resources exist;
- write table-driven tests from fixed rules;
- inspect scenes for missing anchors;
- check localization keys;
- scan logs for parser errors;
- update repetitive `.tres` values after the orchestrator defines them.

### 10.5. Bad tasks for cheap workers

Do not delegate these without direct main-agent control:

- deciding gameplay rules;
- redesigning architecture;
- changing score/life rules;
- choosing level progression;
- large gameplay refactors;
- save-format migrations;
- difficult state/race bugs;
- final release validation.

### 10.6. Parallelism

Default to **0–2 cheap subagents at once**.
Use 3+ only for truly independent tasks with low integration cost.
Do not spawn agents merely because concurrency is available.

### 10.7. Context minimization

Give subagents a bounded brief and the minimum relevant files/sections.
Prefer a small/fresh context fork when supported.
Do not hydrate a worker with long unrelated history for a one-file task.

### 10.8. Worker output contract

A worker returns:

- task performed;
- files inspected/changed;
- findings;
- tests run;
- unresolved uncertainty.

The orchestrator independently verifies code before declaring the user task complete.

---

## 11. Change discipline

Prefer small diffs.

Do not:

- reformat unrelated files;
- rename working resources without need;
- rewrite functioning systems just for style;
- alter unrelated assets;
- add speculative abstractions.

Preserve existing tested behavior unless `SPEC.md` requires a change.

---

## 12. Assets

Final user-approved assets take precedence over placeholders.
Placeholders are allowed only to unblock development.

When replacing placeholders, preserve node contracts, pivots, hit areas, and scene expectations.
Character sprites should not bake the reusable box into the character asset.

---

## 13. UI

Gameplay readability is more important than decoration.
Critical controls must remain in safe areas.
HUD decorations must not overlap playfield hit regions.
Touch targets should be forgiving: tap the logical BoxSlot area, not a tiny face-only area.

---

## 14. Save data

Save only MVP fields defined in `SPEC.md`.
The save system must fail safely on missing/corrupt files.
Do not add currency/inventory fields “for the future”.

---

## 15. Completion criteria

A feature is done only when:

- behavior matches `SPEC.md`;
- project parses;
- relevant scene/resource loads;
- tests pass or an environmental blocker is documented;
- no known regression caused by the task is left behind;
- `PROGRESS.md` is updated.

The user is the final authority for ambiguous product behavior.
