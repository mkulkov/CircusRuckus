# ClownSmash: minimal analytics v2 вЂ” 2026-10-09

Canonical module2.0.0 installed at addons/game_analytics; independent app/analytics/optional_analytics.gd autoload OptionalAnalytics. Original1.0.1 managed bytes matched upstream baseline exactly; backup verified in Codex outputs/six-projects-backup-20261009. Local game/SDK behavior preserved. Default disabled; desktop QA platform windows, app_version 1.0.5, shared random game_id 4143832bdeb84abebf413804ddd39df1. Register source ID/catalogue, never use account/device/install identifiers. IP/request metadata are visible to server: no unconditional legal anonymity, no exact retention/unique users.

Seven strict fields only. Clown levels use numeric level indices; fixed difficulty normal; provider failure maps error; contextual hints map default; ad placement maps default. Action keys are fresh random RAM only; source config ID is shared across installations. No consent API/UI. Abrupt exit may lose telemetry.

| Event | Producer | Evidence/status |
|---|---|---|
| app_start | scripts/navigation/scene_router.gd:23 | Actual headless producer / HTTPS count 1 |
| session_start | scripts/navigation/scene_router.gd:24 | Actual headless producer / HTTPS count 1 |
| session_end | scripts/navigation/scene_router.gd:163 | Actual headless producer / HTTPS count 1 |
| tutorial_completed | No explicit authoritative mechanic boundary | Not applicable: no separate tutorial completion/difficulty owner |
| level_start | scripts/gameplay/gameplay.gd:121 | Actual headless producer / HTTPS count 3 |
| level_complete | scripts/gameplay/gameplay.gd:309 | Actual headless producer / HTTPS count 1 |
| level_fail | scripts/gameplay/gameplay.gd:312 | Actual headless producer / HTTPS count 1 |
| level_restart | scripts/gameplay/gameplay.gd:120 | Actual headless producer / HTTPS count 2 |
| difficulty_changed | No explicit authoritative mechanic boundary | Not applicable: no separate tutorial completion/difficulty owner |
| hint_requested | No explicit authoritative mechanic boundary | Not applicable: hints are automatic contextual UI; no request boundary |
| hint_used | scripts/gameplay/gameplay.gd:229, scripts/gameplay/gameplay.gd:338 | Actual headless producer / HTTPS count 1 |
| ad_requested | scripts/monetization/monetization_service.gd:177 | Actual headless producer / HTTPS count 1 |
| ad_started | scripts/monetization/monetization_service.gd:227 | Actual headless producer / HTTPS count 1 |
| ad_completed | monetization_service.gd:_on_interstitial_finished; rustore_adapter.gd:114; web_adapter.gd:123 | Unverified: generic shared success includes onClosed and debug finish; no fabricated completion from close/display without authoritative platform proof |
| ad_failed | scripts/monetization/monetization_service.gd:205 | Actual headless producer / HTTPS count 1 |
| purchase_started | scripts/monetization/monetization_service.gd:188 | Actual headless producer / HTTPS count 2 |
| purchase_completed | scripts/monetization/monetization_service.gd:286 | Actual headless producer / HTTPS count 1 |
| purchase_failed | scripts/monetization/monetization_service.gd:290 | Actual headless producer / HTTPS count 1 |

Actual app tests use unique disposable application names/user directories. Adugo exercises board touch/move, frames, save/resume, restart, hint, finish, mock entitlement and restore; Clown exercises tap/hammer score/combo, victory save, loss/retry, ad continuation, confirmed entitlement/restore. Missing/corrupt/runtime-error addon scenarios exercise the same game entrypoints. Corrupt/runtime addon diagnostics are intentional. Network failure callback injections are local simulation, not proof of real DNS/TLS behavior. Actual HTTPS batches and exact event-ID retries passed; event snapshots retained in Codex outputs. Full project checks and logs are listed in the migration report.

Final application assertions: 157, failed0; missing/corrupt/throwing backend app entrypoints also passed. Actual oversized262145byte native spool read is asynchronous and bounded. Full tests/run_tests.gd TEST RESULT PASS; main smoke clean.


## Endless round compatibility (2026-10-10)

Analytics remain disabled and optional. Existing whitelisted level_start/level_complete/level_fail represent ordinary rounds. level_id is the stable phase1..5, not the unbounded round number; each round has a separate operation ID. The wrapper retains at most three supported parameters. Practice emits no round events. No new server run_* event contract was invented. Authoritative state and saves precede deferred dispatch. This loses round/cycle/pattern detail intentionally; telemetry is not required for gameplay, entitlement or records.
