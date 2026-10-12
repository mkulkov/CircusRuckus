> Historical model before the 30-second round and explicit Continue update. These survival numbers do not verify the current balance.

# Endless balance model, 2026-10-10

This report describes the current endless profiles and the automated human-decision approximation. The authoritative rules are in [SPEC.md](../SPEC.md). The old campaign reports remain historical evidence and are not directly comparable to continuous survival.

The full run used the real GameController, SpawnDirector and RoundDirector for six styles, seeds 1 through 100, and a 1,800-second active-game horizon per run. No Boot, SaveManager, purchase, SDK, analytics, or ordinary user profile was instantiated. There were 600 trajectories plus repeatability pairs at seed 42 for each style. Event stepping runs the real controller timers and director spawn decisions; transitions take zero active time.

| Model | P10 active seconds | P50 active seconds | P90 active seconds | Survived horizon, censored |
|---|---:|---:|---:|---:|
| cautious | 1800.00 | 1800.00 | 1800.00 | 93/100 |
| confident | 1800.00 | 1800.00 | 1800.00 | 96/100 |
| ideal | 1800.00 | 1800.00 | 1800.00 | 100/100 |
| idle | 22.73 | 29.87 | 33.78 | 0/100 |
| novice | 115.62 | 577.98 | 1800.00 | 20/100 |
| spam | 0.80 | 0.80 | 1.10 | 0/100 |

A result at 1,800 seconds is a censored lower bound, not a defeat or proof of unlimited survival. Novice median 577.98 seconds exceeds the 180-second working target; confident median is at least 1,800 seconds and exceeds 480 seconds. Ideal has zero defeats. Idle has zero life restorations; random spam does not survive. All six styles were deterministic on repeat and had zero recorded violations for occupancy, decision caps, forbidden pairs, Drunk exclusion, Clock caps, effective profile bounds, phase order and pending delayed-spawn queue growth. No profile values or acceptance thresholds were changed to obtain these results.

| Model | Clock spawns/min | Glutton spawns/min | Boundary-cancelled targets | Recovery restores | Glutton restores | Max error streak |
|---|---:|---:|---:|---:|---:|---:|
| cautious | 2.18 | 2.27 | 2959.0 | 3.0 | 710.0 | 6 |
| confident | 2.23 | 2.61 | 1692.0 | 16.0 | 571.0 | 4 |
| ideal | 2.25 | 2.69 | 1093.0 | 0.0 | 0.0 | 0 |
| idle | 1.86 | 1.99 | 0 | 0.0 | 0.0 | 9 |
| novice | 2.29 | 2.48 | 1109.0 | 3.0 | 897.0 | 6 |
| spam | 2.03 | 4.73 | 0 | 0.0 | 4.0 | 9 |

| Phase, ideal model | Mean live decisions | Mean occupied boxes | Spawns/active second |
|---|---:|---:|---:|
| recovery | 0.322 | 1.229 | 0.850 |
| build | 0.370 | 1.369 | 0.938 |
| variation | 0.449 | 1.592 | 1.078 |
| pressure | 0.497 | 1.782 | 1.210 |
| peak | 0.549 | 1.938 | 1.310 |

The recovery phase has fewer decisions than peak (0.322 versus 0.549) and larger configured scoring windows. The maximum observed occupancy is 5, decision count 2, and delayed second-spawn queue 1. Each transition clears unfinished decision targets; these are counted only as cancelled, with no escape/hit credit. Raw trajectories include phase-weighted life distributions, lost lives, restore sources, Clock/Glutton hit/escape frequencies, completed rounds and cancelled callbacks.

The visual lifecycle is approximate: full spring pop 0.68 seconds, head readable/hittable about 0.18 seconds after the 0.08-second lid opening and quart rise, escape occupancy 0.62+0.20 seconds, hit occupancy 0.22+0.18+0.62×0.8+0.20=1.096 seconds. Availability countdown begins when hittable, not after the full pop. One-finger input is serialized with a minimum 0.08-second debounce. Human recognition delay is sampled from 0.65–1.55 times the style reaction; skip, hazard misclassification and accidental empty-tap probabilities are explicit in the JSON. Targets are selected by earliest expiry.

These are model results, not phone/container evidence or promised player durations. The models do not include human fatigue, attention lapses in long correlated bursts, visual recognition errors beyond the declared rates, touch positioning, GPU/frame stalls, or exact tween geometry. Many confident/cautious trajectories reach the horizon, which warrants human playtesting rather than a claim that those players cannot lose. Actual scene soak and visual/tutorial checks are separate acceptance evidence.

Validation:

- `godot-check.ps1 -Mode script -Script res://tests/balance_simulation.gd`: PASS, exit 0, zero diagnostics. Log: `builds/debug/verification/godot-script-20261010-113001-166-51eafc.log`.
- `Godot_console.exe --headless --path . --script res://tests/balance_simulation.gd -- --aggregate-only`: PASS; recomputed derived summaries from the same 600 retained trajectories, without changing sampling, model parameters or results.
- All structural and minimum-duration checks in the JSON report are true.

Machine-readable evidence: [endless_balance_simulation.json](endless_balance_simulation.json).
