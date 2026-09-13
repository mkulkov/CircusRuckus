# PROGRESS.md — Цирковой переполох

## 2026-09-13 — Yandex lifecycle, cloud saves and advertising gates

- Centralized Yandex SDK initialization in the web platform bridge; localization, Game Ready, Gameplay API, lifecycle, cloud saves and advertising now reuse one `ysdk` promise.
- Added `GameplayAPI.start()/stop()` state mapping and `game_api_pause` / `game_api_resume` handling that pauses an active round and Music/SFX without auto-resuming a user-paused round.
- Added guest/authorized cloud progress through `ysdk.getPlayer()` and `player.getData()/setData(..., true)` with a five-second local fallback. Valid local/cloud saves merge unlocked/completed levels and best results without losing progress.
- Fixed JavaScriptBridge callback decoding and callback lifetime in `WebMonetizationAdapter`; this previously prevented successful adapter initialization and therefore could suppress the sticky-banner request.
- Level 1 is now unconditionally free of game-requested interstitials, including demo builds. Yandex's separate automatic startup ad remains platform-controlled and is handled through lifecycle events.
- Sticky status and reason are reported as `[ClownSmash][Ads]`; the cabinet must enable the bottom portrait sticky placement plus **Use API to show sticky banner** before live display can be confirmed.
- Verification: Godot editor parse/import passed; full `tests/run_tests.gd` passed; `node tests/yandex_bridge_test.mjs` passed with one SDK initialization, lifecycle, Gameplay API, sticky show and cloud round-trip mocks.
- Exported `builds/clown-smash-yandex-release-2026-09-13-1737.zip`: nine runtime files at archive root, 58,241,071 bytes unpacked, 28,632,374 bytes compressed, SHA-256 `7FECD2E7CE626371BCB4107C4B0D5902313FC7E1A99F1C86E4CA3BF2C26CAD96`.

## 2026-09-13 — обновлены скриншоты страницы VK

- Подготовлена новая галерея `promotion/vk_games_2026-09-13/screenshots_v2/`: пять PNG 600×1200 в единой портретной ориентации.
- Убрана сильная JPEG-компрессия; первые позиции заменены на выразительные кадры реального игрового рендера: удар молотком, специальные клоуны и основной игровой процесс.
- Проверены декодирование, точные пиксельные размеры, соотношение 1:2 и вес менее 1 МБ для каждого файла.
- Порядок загрузки и назначение файлов описаны в `promotion/vk_games_2026-09-13/README.md`.
- Из заставки `verification/startup_splash_circus_1080x1920.png` подготовлен отдельный `screenshots_v2/03_startup_splash_600x1200.png`: 600×1200, PNG, без искажения пропорций; он отмечен как дополнительный презентационный кадр, а не геймплей.
- Автоматически заменить уже опубликованные файлы в кабинете VK не удалось: официальная страница `dev.vk.ru` заблокирована политикой браузерного доступа в текущем окружении. Готовые файлы требуют ручной загрузки в кабинет.

## 2026-09-13 — Yandex Games release after feedback fixes

- Exported the current `Web - Yandex Games` release after the gameplay-feedback deduplication and sticky-banner diagnostics changes.
- Prepared `builds/clown-smash-yandex-release-2026-09-13-1643.zip`: nine runtime files at the archive root, 58,230,460 bytes unpacked and 28,625,659 bytes compressed.
- Archive paths contain no directories, spaces or non-ASCII characters. SHA-256: `AB0384CC11AB6DBA4CF498BF4324D4F714B79B4AEBA82F814BE50A7B55359646`.

## 2026-09-13 — Gameplay feedback deduplication and Yandex banner diagnostics

- Removed the static HUD `+10` and life-loss messages; both now use only the localized rising/fading impact label at the struck box.
- A bonus miss now suppresses the later duplicate escape label for that same active Clock or Glutton.
- The Yandex web bridge now checks `getBannerAdvStatus()` before requesting a sticky banner and logs the status, show result, rejection, or platform reason in the browser console instead of silently swallowing every outcome.

## 2026-09-13 — Fresh Yandex Games release build

- Re-ran the full automated suite and smoke test, then exported the current `Web - Yandex Games` release with Godot 4.7.2 stable.
- Prepared `builds/clown-smash-yandex-release-2026-09-13-1514.zip` with nine runtime files at the archive root, including `index.html`; paths contain no spaces, Cyrillic characters, or nested directories.
- Verified the `/sdk.js` bootstrap, 58,229,230-byte unpacked payload, 28,624,977-byte ZIP, and SHA-256 `24126B8BE673377B60BC875D5175D75067F39EE80284EA59BFAA65B4DC02C41D`.
- Hosted Yandex SDK callbacks, advertising, purchases, Developer Console validation, and moderation remain external checks.

## 2026-09-13 — Yandex production export banner startup fix

- Fixed the production web export compile failure caused by the monetization demo presenter preloading a demo-only video that the Yandex preset intentionally excludes.
- The demo video is now loaded lazily only when the opt-in demo presenter runs, so the production `MonetizationService` can initialize, restore entitlements, request the sticky banner and later send `LoadingAPI.ready()`.
- Live draft diagnosis before the fix showed the missing-resource parse error and no game-side banner request; a corrected archive must be uploaded to the Yandex Games draft before hosted behavior can be rechecked.

## 2026-09-13 — Browser gameplay layout

- Raised the browser HUD to the top of the portrait canvas and moved the 3×3 playfield up by the same 112 design pixels.
- Kept the existing native/mobile HUD and playfield offsets unchanged.
- Rebuilt the `Web - Yandex Games` release package after automated and rendered browser verification.

## 2026-09-13 — Yandex Games monetized release candidate

- Added the required one-shot `LoadingAPI.ready()` call when the player-facing Main Menu becomes available.
- Fullscreen Yandex advertising now mutes the Music/SFX buses from the SDK `onOpen` callback and restores their prior mute state on close/error; duplicate terminal callbacks are ignored.
- Rebuilt the `Web - Yandex Games` release archive with production SDK advertising and the durable `remove_ads` purchase/restore flow.
- Store-console contracts, the `remove_ads` catalog item, real ad inventory, live purchase callbacks and moderation still require the owner's Yandex account and cannot be proven by local tests.

## 2026-09-13 — Cross-platform monetization demo QA

- Added the opt-in `monetization_demo` export feature with a bottom-slot test banner, a labelled four-second Theora video interstitial before level start, and a successful virtual `remove_ads` purchase.
- The demo uses the production `MonetizationService` and `SaveManager` entitlement path: purchase hides banner/button immediately, skips later interstitials, and persists `ads_removed` across restart.
- Added separate Android/RuStore, Yandex Games Web and VK Mini Apps Web demo export presets under `builds/monetization-demo/`; no real SDK purchase or ad inventory is simulated in production adapters.
- Added automated coverage for virtual purchase, disk persistence, restart restore, ad bypass, bottom banner placement/hide, and video resource loading.
- Verification: full `tests/run_tests.gd` and `tests/smoke_test.gd` passed; all three demo exports completed. Physical Infinix X663 inspection confirmed the bottom banner and video interstitial. A restart check exposed and fixed the demo presenter's default-visible banner state; final recheck is recorded in `verification/monetization_demo_after_restart_android.png`.
- Still unverified: hosted Yandex/VK containers and their real SDK callbacks; RuStore Pay SDK/sandbox and a selected Android ad network; store-console catalog/placement setup, real payment restoration across accounts/devices, and moderation.

## 2026-09-12 — Countdown purchase visibility

- Kept `REMOVE_ADS` hidden during the pre-level countdown; it is shown only on eligible pause or result panels.

## 2026-09-12 — Phone menu and result panel fit

- Removed the enclosing frame from Main Menu while keeping a non-overlapping adaptive action layout.
- Made SessionOverlay panels grow for every visible action, so `REMOVE_ADS` remains inside pause and result panels.
- Changed StartupSplash from aspect-covered scaling to screen-fill scaling, preventing the localized title art from being horizontally cropped on 1080×2400 phones.

## 2026-09-12 — Startup and Main Menu mobile layout

- Reduced the embedded Russian and English startup-title art to add reliable horizontal safe margins on phone screens.
- Main Menu now uses the localized startup art as its background and no longer draws a duplicate text title.
- Added an adaptive menu panel: its height follows the visible actions, including the optional `REMOVE_ADS` button, and actions use consistent non-overlapping vertical gaps.

## 2026-09-12 — Boot splash hammer angle refinement

- Replaced `assets/generated/boot_splash_clown_chase.png` with the approved preview: the hammer head keeps its side-view perspective with a reduced diagonal tilt, while the handle remains perpendicular to the head axis.
- Preserved the hidden striking/top surfaces and the rest of the splash composition.

## 2026-09-12 — Boot splash hammer replacement

- Replaced the hammer in `assets/generated/boot_splash_clown_chase.png` with the authored gameplay hammer from `assets/generated/toy_hammer.png` as the visual reference.
- Corrected the hammer construction in the splash: centered perpendicular handle, hidden striking/top surfaces, and a slight turn around the handle's vertical axis.
- Preserved the circus background, clowns, composition and engine-level splash path.

## 2026-09-12 — Results popup bottom padding

- Increased the Results popup height so the lower Menu button has a 40-pixel inner bottom gap instead of touching the panel edge.

## 2026-09-12 — Web viewport fit

- Added a reusable portrait web shell for Yandex Games and VK Mini Apps exports.
- The 9:16 canvas now scales against both browser width and real viewport height, stays centered, and no longer overflows a wide external browser window.

## 2026-09-12 — Branded boot splash

- Replaced the default Godot boot image with a text-free circus chase composition: one clown with the toy hammer runs after another clown.
- Corrected the chasing clown's hammer construction and grip: centered perpendicular handle, closed hand around the shaft, and end knob below the fist.
- Kept this engine-level splash language-neutral; the localized Russian/English title splash still follows after startup.

## 2026-09-12 — Game rename

- Renamed the player-facing game title to `Цирковой переполох` in project metadata, export metadata, Main Menu and About text.
- Reworked the startup splash title while preserving the approved circus composition, clown and hammer artwork.
- Added visible Compatibility-renderer captures for the renamed startup splash and Main Menu at 1080×1920.
- Added the English `Circus Ruckus` splash and localized Main Menu/About titles; English startup now selects its own title art automatically.

## 2026-09-12 — Yandex Games release build

- Exported the `Web - Yandex Games` release build to `builds/yandex` with Godot 4.7.2 stable.
- Prepared `builds/clown-smash-yandex.zip` for Developer Console upload: one root `index.html`, no spaces or Cyrillic characters in paths, 48.62 MiB unpacked.
- Verified the Yandex Games SDK bootstrap uses the required relative `/sdk.js` path for archive hosting.
- Launched the official Yandex Games SDK dev proxy in mock mode and verified its HTTPS response; the visible browser run uses a separate local HTTP server because the embedded browser rejects the proxy's self-signed certificate. Developer Console moderation and production SDK behavior remain pending.

## 2026-09-12 — Android test build without purchases and updated Yandex materials

- Added the Android-only `no_purchases` export feature: the purchase action is hidden and `MonetizationService` declines purchase requests in this test build.
- Exported `builds/clown-smash-test-no-purchases.apk` and installed it on the physical Infinix X663.
- Captured and visually reviewed the test-build menu (no purchase action) and active gameplay; recorded a 28-second real-device gameplay video.
- Prepared the separate package `promotion/yandex_games_test_no_purchases_2026-09-12/` with icons, covers, mobile screenshots, the new phone recording, device evidence and an upload checklist tied to current Yandex Games requirements.

## 2026-09-12 — Yandex Games cover

- Added `promotion/yandex_games_test_no_purchases_2026-09-12/covers/cover_800x472_clownsmash.png`: a text-free 800x470 cover with the Normal, Bomb and Clock clowns, circus setting and the authored red/gold side-handle hammer silhouette.
- Visually reviewed the final PNG at its exact upload resolution; it has no UI, border or rounded corners.

## 2026-09-12 — Russian/English localization

- Added English translations for the current player-facing UI and gameplay feedback.
- Added startup language detection for Yandex Games (`environment.i18n.lang`), VK Mini Apps (`vk_language`), and Android/RuStore device locale.
- Unsupported languages fall back to Russian; locale selection finishes before the first game screen is created.
- Live platform verification in the Yandex/VK developer environments and a RuStore-installed Android build remains pending.

## Current status

Milestones 0–8 are complete and verified with Godot 4.7.2 stable.

Milestone 9 is complete for automated Android validation on desktop, the `Medium_Phone` emulator, and the physical Infinix X663 phone. The physical-device run confirmed stable 60 FPS and successful haptic API delivery; a person holding the phone must still make the subjective tactile-quality judgement.

---

## Done

- [x] MVP concept defined.
- [x] One world selected: Circus Tent.
- [x] 3×3 box playfield fixed.
- [x] Seven gameplay clown types defined.
- [x] Score rules fixed.
- [x] Combo rules fixed.
- [x] Apple-life rules fixed.
- [x] Drunk random-hit mechanic defined.
- [x] Nine-level progression defined.
- [x] MVP scope locked: no coins/store/ads/backend.
- [x] Codex orchestration/subagent policy defined.
- [x] `SPEC.md` prepared.
- [x] `AGENTS.md` prepared.
- [x] `PROGRESS.md` prepared.
- [x] Milestone 0 bootstrap completed.
- [x] Godot 4.7.2 stable detected.
- [x] Portrait 1080×1920 project configured with `canvas_items`, `expand`, and Compatibility renderer.
- [x] Project directory structure created.
- [x] Basic headless test runner and smoke test added.
- [x] Milestone 1 core interaction prototype completed.
- [x] Milestone 2 complete Level 1 session completed.
- [x] Gameplay visual-depth pass completed: raised perspective stage, converging 3×3 layout, row depth scaling, extruded boxes, recessed openings, cast shadows, dimensional Normal clown and hammer.
- [x] Reference-matching presentation pass completed: original painted circus background, shared painted open-box asset, Normal clown and hammer assets, measured HUD/board alignment, automated overlay/difference workflow, impact capture and responsive visual QA.
- [x] Hammer art corrected: vertical top-to-bottom striking head with a centered perpendicular side handle; impact contact re-aligned without changing animation timing.
- [x] Animation anchoring correction: spring is clipped to the box opening and tracks the clown base; the clown is clipped while descending; hammer contact is aligned from above to the clown's top centre.
- [x] Seven-character gameplay set completed: Normal, Fast, Golden, Bomb, Clock, Glutton and Drunk.
- [x] Authored special-character asset pack and closed-box asset integrated with transparent-source QC.
- [x] Box lid now transitions between authored closed/open states; hammer impact compresses the spring and follows the compressed target.
- [x] Box artwork is baseline-aligned across lid states; active clowns own the gameplay touch target and hammer contact.
- [x] Gameplay taps now require an opaque box pixel or visible clown-head region; hammer makes an amplified arc around the far edge of its handle.
- [x] Regression checks protect the fixed box baseline and direct clown-face tap selection from later hammer changes.
- [x] HUD feedback added for Golden objective progress, Clock time, Glutton lives, Bomb penalty and Drunk confusion strikes.
- [x] Level 1-9 tuning resources, weighted character selection, double-spawn staggering and baseline fairness constraints implemented.
- [x] Round duration reduced to 60 seconds; spawn intervals now accelerate smoothly through each round; HUD life icons use the gameplay hammer.
- [x] Current tuning pass: Fast, Golden and Drunk are excluded from automatic spawns; Clock/Glutton hits preserve combo; Glutton escape no longer removes a life; local score/bonus floaters and a bright Bomb-confetti impact with a short flash are added.
- [x] Startup splash added: the approved portrait circus key art fades in on launch, can be skipped with one tap, and then opens the Main Menu.

---

## In progress

- Milestone 9 — functional physical-device QA complete; subjective haptic-feel sign-off remains.

---

## Next

### Milestone 0 — Bootstrap

- [x] Create Godot project.
- [x] Confirm installed Godot stable version.
- [x] Configure portrait mode.
- [x] Configure base 1080×1920 layout.
- [x] Configure `canvas_items` stretch and `expand` aspect.
- [x] Select Compatibility renderer.
- [x] Create repository/project directory structure.
- [x] Add `AGENTS.md`, `SPEC.md`, `PROGRESS.md`.
- [x] Add `.gitignore`.
- [x] Add basic test runner.
- [x] Add headless smoke test.
- [x] Verify empty project opens/runs without parser/runtime errors.

Acceptance:
- Godot project runs.
- Headless smoke check exits successfully.
- Test runner exits successfully.

---

### Milestone 1 — Core interaction prototype

- [x] Create `Gameplay.tscn`.
- [x] Create `BoxSlot.tscn`.
- [x] Place 9 BoxSlots in a fixed 3×3 board.
- [x] Implement `BoardController`.
- [x] Implement Normal clown.
- [x] Implement `SpawnDirector` with only Normal.
- [x] Implement tap-to-slot detection.
- [x] Implement Hammer animation/controller.
- [x] Correct hit gives +10.
- [x] Correct hit increases combo.
- [x] Empty tap resets combo but not life.
- [x] Missed Normal resets combo.
- [x] Add basic tests.

Acceptance:
`spawn → tap → hammer → +10 → combo → hide → repeat`

---

### Milestone 2 — Complete level session

- [x] Add 60-second timer.
- [x] Add three apple lives.
- [x] Add countdown `3 2 1 GO`.
- [x] Add pause/resume.
- [x] Add score HUD.
- [x] Add combo HUD.
- [x] Add lives HUD.
- [x] Add win state.
- [x] Add loss state.
- [x] Add Results popup.
- [x] Implement Level 1 config.
- [x] Test complete Level 1 loop.

---

### Milestone 3 — Special characters

Implement and verify one at a time.

- [x] Golden.
- [x] Bomb.
- [x] Fast.
- [x] Clock.
- [x] Glutton.
- [x] Drunk.

For each:
- [x] gameplay behavior;
- [x] spawn/despawn;
- [x] feedback;
- [x] tests;
- [x] no regression.

---

### Milestone 4 — Nine levels

- [x] Implement `LevelConfig` Resource.
- [x] Create `level_01.tres` … `level_09.tres`.
- [x] Implement objective checks.
- [x] Implement unlock progression.
- [x] Validate SpawnDirector fairness constraints.
- [x] Add deterministic-seed tests.

---

### Milestone 5 — Menu and navigation

- [x] Main Menu.
- [x] Level Select.
- [x] Pause popup.
- [x] Settings popup.
- [x] Results screen.
- [x] Scene routing.
- [x] Save progression.
- [x] Save settings.
- [x] Best score.
- [x] Best combo.

Acceptance flow:
`launch → menu → levels → gameplay → results → next/retry/menu`

---

### Milestone 6 — Final art integration

- [x] Circus background.
- [x] Reusable box layers.
- [x] Normal asset.
- [x] Fast asset.
- [x] Golden asset.
- [x] Bomb asset.
- [x] Clock asset.
- [x] Glutton asset.
- [x] Drunk asset.
- [x] Hammer asset.
- [x] Apple/UI assets.
- [x] Check pivots.
- [x] Check CanvasItem ordering.
- [x] Check 9:16 composition.
- [x] Remove obsolete placeholders from runtime scenes and Android export.

---

### Milestone 7 — Juice and polish

- [x] Pop spring animation.
- [x] Clown idle movement.
- [x] Correct-hit squash.
- [x] `+10` floating text.
- [x] Combo bounce.
- [x] Bomb impact flash.
- [x] Clock `+10 sec` HUD feedback.
- [x] Glutton apple-flight animation.
- [x] Drunk wobble and remaining-strikes indicator.
- [x] Light camera shake.
- [x] End-of-level transition delay.
- [x] Contextual first-time tutorial hints.

---

### Milestone 8 — Audio and haptics

- [x] Music loop.
- [x] Two normalized background tracks selected randomly per level without immediate repeats.
- [x] Two normalized, non-silent-fade miss sounds selected randomly when a scoring clown escapes.
- [x] Normalized authored Bomb-hit sound replaces the procedural Bomb SFX.
- [x] Box pop.
- [x] Hammer BONK.
- [x] Correct hit.
- [x] Empty hit.
- [x] Bomb.
- [x] Life lost.
- [x] Apple restored.
- [x] Clock.
- [x] Drunk.
- [x] Combo.
- [x] Countdown.
- [x] Victory.
- [x] Defeat.
- [x] UI button.
- [x] Music toggle.
- [x] SFX toggle.
- [x] Haptics toggle.

---

### Milestone 9 — Mobile QA

- [x] Android touch input verified by ADB tap on emulator.
- [x] Mouse emulation in editor.
- [x] 720×1280.
- [x] 1080×1920.
- [x] 1080×2340.
- [x] Tall phone safe area verified at 1080×2400 emulator resolution.
- [x] Pause/resume from OS verified through Android Home/resume.
- [x] No touch leakage through HUD.
- [x] 60 FPS target verified on physical Infinix X663 (Android 12) after warm-up.
- [x] Emulator memory baseline captured (about 160 MB PSS on Main Menu).
- [x] Android debug export, signature verification, install and launch.
- [x] Physical-device Android `VIBRATE` permission and haptic API invocation verified.

---

## Known issues

- A person holding the Infinix X663 must still judge the subjective strength and feel of the 20 ms correct-hit and 55 ms bomb/life-loss haptics; ADB can verify permission and error-free API delivery, but not tactile sensation.

---

## Tests

Bootstrap, audio hooks, scoring, combo, session state, lives, saves, navigation, all nine LevelConfigs, BoxSlot count and core interaction integration tests exist.

All seven character rules, nine level resources, asset loading, Clock cap, Golden objectives, Bomb/Glutton life rules, Drunk routing, lid opening, spring compression and special-character scene wiring are covered.

Last verified on Godot 4.7.2 stable:

- `godot_console --headless --path . --script res://tests/run_tests.gd` — PASS.
- `godot_console --headless --path . --script res://tests/smoke_test.gd` — PASS.
- `godot_console --headless --path . --quit-after 300` — exit code 0.
- Core interaction integration test — PASS (`spawn → tap → hammer → +10 → combo → hide → repeat`).
- Session tests — PASS (countdown, pause/resume timer freeze, three-life cap, zero-life loss, timer win and Results popup).
- Visible Compatibility-renderer captures — PASS at 720×1280, 1080×1920, 1080×2340 and 1440×3200.
- Reference-matching regression run — PASS: full tests, smoke test and headless main-scene load.
- Android debug export — PASS; APK signed with v2/v3 schemes and installed on the `Medium_Phone` emulator.
- Android runtime — PASS after 12+ seconds, touch interaction produced score 10/combo 1, Home/resume opened Pause, no GDScript/runtime error in logcat.
- Physical Infinix X663 (Android 12) — PASS: fresh APK installed and launched, menu and 1080×2400 gameplay captures reviewed, ADB gameplay interaction scored +10, `android.permission.VIBRATE` was present and granted, the successful hit no longer produced a VIBRATE exception, and post-warm-up frame pacing reported about 60.4 FPS.

## Visual verification

- Reference checked: YES — `assets/references/gameplay_field_reference.png` was opened before implementation and reopened after the runtime capture.
- Screenshot compared: YES — `verification/gameplay_1080x1920.png` was compared side by side with the reference.
- Responsive captures reviewed at 720×1280, 1080×1920 and 1080×2340 for this pass; controls remain readable and the board has no overlaps.
- Countdown, Pause and win-result captures reviewed at 1080×1920.
- The earlier procedural clown, box, hammer and tent rendering was replaced for this presentation pass; gameplay contracts, node paths and the fixed 3×3 rules remain unchanged.
- Reference-matching final: `artifacts/visual_tests/final.png`; overlay/difference and compliance report are in `artifacts/visual_tests/`.
- Two rendered comparison iterations completed. No P0 composition discrepancy remains. P1/P2 deviations: generated lids are taller than the reference, the board and apples are less painterly, and the fallback font is less decorative.
- Visible impact state captured at `artifacts/visual_tests/impact.png`; 720×1280 and 1080×2340 captures were inspected after the tall-screen background fix.
- Seven-character showcase reviewed at `verification/mvp_specials_1080x1920.png`; authored closed boxes, open boxes, springs and all six new special assets have coherent alignment and depth order.
- Gameplay-status HUD reviewed at `verification/mvp_hud_status_1080x1920.png` and `verification/mvp_hud_status_720x1280.png`; Golden and Drunk indicators remain readable without covering the playfield.
- Updated HUD/board capture reviewed at `verification/round60_hud_hammers_1080x1920.png`; the 60-second timer, hammer life icons, one-timer-height HUD offset and 10-pixel box-field offset are visible without overlaps.
- Physical Infinix X663 launch check completed for the 60-second/HUD update: refreshed debug APK installed, menu and active gameplay captured at `verification/physical_round60_hammers_infinix_x663_1080x2400.png` and `verification/physical_gameplay_round60_hammers_infinix_x663_1080x2400.png`; no fatal or GDScript error was found in the recent logcat window.
- Final hammer/spring contact reviewed at `verification/mvp_impact_1080x1920.png`; the hammer follows the compressed target and the spring shortens on impact.
- Main Menu reviewed at `verification/main_menu_720x1280.png`, `verification/main_menu_1080x1920.png` and `verification/main_menu_1080x2340.png`.
- Level Select and Results reviewed at `verification/level_select_1080x1920.png` and `verification/result_win_1080x1920.png`.
- Android 1080×2400 menu, gameplay, hit feedback and lifecycle pause reviewed in `verification/android_*.png`.

Planned:

- physical-device haptics;
- sustained frame pacing on a representative mid-range Android phone.

### 2026-09-12 — Monetization integration

- Added `MonetizationService` with platform adapters for Yandex Games/VK web exports, a RuStore Pay SDK integration boundary for Android, and a deterministic debug adapter.
- Added bottom sticky-banner requests and interstitial requests before levels 2–9 only.
- Added the styled `REMOVE_ADS` purchase button to Main Menu and session overlays; durable `ads_removed` entitlement hides ads and buttons after restore or confirmed purchase.
- Added `docs/monetization.md` with current official documentation links and the remaining console/SDK setup steps.
- Verification: Godot editor parse/load check passed; `tests/run_tests.gd` passed with exit code 0. Live ad inventory, payment, restore across accounts/devices, VK moderation, and RuStore Android SDK behavior remain unverified.

### 2026-09-12 — Yandex Games visual materials

- Added a standalone upload-ready static-media package in `promotion/yandex_games_2026-09-12/`: 512×512 icon, maskable icon, 800×470 catalog cover, 1560×520 storefront cover, and two real portrait gameplay screenshots in valid 9:16 JPEG 1440×2560 format.
- Reviewed generated icon/cover composition and confirmed the screenshots are based on existing rendered gameplay states. Required horizontal gameplay video remains intentionally uncreated: it must be recorded from an actual gameplay session rather than synthesized from static frames.

### 2026-09-12 — Yandex Games horizontal gameplay video

- Installed the freshly exported debug APK over the existing Android installation on a physical Infinix X663 (Android 12), launched it, and recorded a live 27.67-second gameplay session with real device taps.
- Added `promotion/yandex_games_2026-09-12/videos/gameplay_horizontal_1920x1080.mp4`: H.264 MP4, 1920×1080 (16:9), 27.5 seconds, 2.09 MB. It uses the unaltered portrait game capture over a blurred background derived from the same capture; no static screenshots were used as the gameplay video.
- Added `video/circus_ruckus_vertical_teaser_1080x1920.mp4`: a 9.67-second, 1080×1920 H.264/AAC teaser. It combines the branded title card, 5.67 seconds of real recorded mobile gameplay, a final call-to-action card, and the authored in-game music; a frame-by-frame contact-sheet review confirmed all three sections appear in the final render.
- Added `video/circus_tent_chase_vertical_1080x1920.mp4`: a 10.3-second, 1080×1920 H.264/AAC stylized cinematic based on the requested tent-entry and ringmaster-chase scenario. Four generated key frames are preserved under `video/ai_frames/`; the final sequence uses animated camera pushes, short crossfades, the authored in-game music and the localized startup title. Full decode and contact-sheet visual review passed.
- Added `video/circus_tent_chase_circus_text_1080x1920.mp4`, preserving the text-free cinematic as a separate source. Five timed Russian advertising captions use the game's cream, gold and dark-ink palette with layered marquee-style outlines and shadows. Full MP4 decode passed, and a 1-second contact-sheet review confirmed caption timing, readability and subject clearance across all scenes.

### 2026-09-12 — Portrait phone screenshot correction

- Reframed the seven JPG screenshots in `artifacts/phone_screenshots_2026-09-12/` from landscape 16:9 presentation frames to 9:16 portrait images. The game screen remains centered and intact; the superseded landscape sources are retained in `source_landscape_jpg/` for recovery.

### 2026-09-13 — VK Games publication texts

- Added `docs/vk_games_publication.md` with Russian and English store-card copy, gameplay instructions, category/tag recommendations and a conservative age-rating note for the VK Mini Apps web export.
- The exact live field limits and upload requirements on the linked VK cabinet page were not independently retrievable; they must be checked against the counters and hints shown in the authenticated cabinet before submission.

### 2026-09-13 — VK Games visual materials

- Added a standalone VK upload package in `promotion/vk_games_2026-09-13/`: 576×576 universal icon, 278×278 catalog/snippet icon, 150×150 small icon, 32×32 favicon, 1120×630 large snippet and five real-game 600×1200 portrait screenshots.
- Reused approved Clown Smash artwork and runtime/device captures; no synthetic image was presented as gameplay. All deliverables were visually reviewed and machine-checked for exact dimensions, format, file size and successful decode.
- The linked `dev.vk.ru` page could not be retrieved by the automated browser. Recheck the field hints in the authenticated VK cabinet before moderation in case the platform requirements changed after 13 September 2026.

### 2026-09-13 — Yandex Games English localization media

- Added `promotion/yandex_games_en_2026-09-13/` with two English gameplay videos and four English gameplay screenshots, covering both Mobile portrait and Desktop landscape upload fields.
- The upload videos are H.264/AAC MP4 at 1080×1920 and 1920×1080, 26.6 seconds each. Both show continuous rendered gameplay with English HUD text; the horizontal version preserves the undistorted portrait playfield over a blurred background derived from the same gameplay.
- Added two 1440×2560 mobile JPEGs and two 2560×1440 desktop JPEGs. Visual review confirmed English labels, readable HUD, real gameplay, and no external UI or Russian text in the upload-ready files.
- Rechecked the current official Yandex Games draft and moderation requirements on 13 September 2026. Final codec, duration, dimensions, aspect ratio, size, and decode validation passed.

### 2026-09-13 — Yandex Games bilingual desktop screenshots

- Replaced the cropped images in `promotion/yandex_games_desktop_bilingual_2026-09-13/` with full-frame portrait runtime captures fitted into 16:9 presentation images: four Russian and four English files, including localized startup splashes.
- All eight files are RGB JPEG at 2560×1440 (16:9). The portrait foreground is uniformly scaled and centered without cropping or non-uniform stretching; the side background is a blurred, darkened derivative of the same source capture.
- Visual review confirmed that each source screen, including the Russian and English localized splash titles, is complete and readable. The no-crop layout leaves the sharp foreground at 31.6% of the frame, so it is not claimed to independently satisfy Yandex Games' 70%-real-gameplay area requirement for Desktop uploads.

### 2026-09-13 — VK Mini Apps publication distribution

- Prepared a standalone release package in `builds/vk-mini-apps-delivery-2026-09-13/` with clean Web and cabinet-material ZIPs, a VK hosting configuration template, publication texts and SHA-256 manifest. The unpacked export workspace remains separate under `builds/vk-mini-apps-2026-09-13/` and is not the delivery artifact.
- Kept gameplay code and the `Web - Yandex Games` preset unchanged. The only project configuration change narrows the `Web - VK Mini Apps` export filter so tests, tools, promotional folders and the monetization demo video are not embedded in the production PCK.
- Rechecked the official VK Bridge package (`3.0.2`) and official `vk-miniapps-deploy` package (`1.0.2`) on 13 September 2026. Direct `dev.vk.ru` pages were blocked to the automated browser, so authenticated cabinet field limits, moderation and production hosting remain manual release gates.
- Added the supplied VK Mini App ID `54768735` to the delivery's ready-to-use `vk-hosting-config.json`; no access token or credential is stored in the package.

---

## Decisions log

### 2026-09-13

- Confirmed that missed Clock and Glutton bonus characters do not remove a life, including an empty-box strike while either bonus is active. Their hit, escape and bonus-miss messages now use the same localized circus-style floating, rising and fading effect as score bonuses at the relevant box.

### 2026-09-12

- Unified all program-rendered labels and menu controls around a circus marquee style: cream/gold type, dark outlines, dimensional red/wood panels, and consistent hover/pressed/disabled states across Main Menu, Level Select, Settings, Pause/Results, HUD and impact text.

### 2026-09-10

- Randomized the order and timing of the all-type guarantee: each of the seven types is now scheduled between 10% and 75% of every round rather than occupying the first seven spawns. Halved all level spawn intervals and visible/hittable times.
- Reduced every target score by 100, guaranteed all seven clown types once per level, and changed Drunk confusion to one redirected gameplay tap.
- Widened the score-progress field so multi-digit values such as `1230/600` remain fully visible on the 1080×2400 physical-phone viewport.
- Doubled the current clown spawn frequency across every level again by halving all configured spawn intervals.
- Increased clown spawn frequency by 25% across all nine level configurations. Empty BoxSlot strikes now cost one life; the HUD displays current/target score and has a dedicated background panel for life hammers.
- Updated the round duration to 60 seconds, moved the HUD down by one timer-panel height and shifted the box field down 10 design pixels. Spawn intervals now interpolate from their configured start values to 65% by round end.
- Completed progression, menu/navigation, settings, save integration, polish, contextual hints, audio/haptics hooks and Android export configuration.
- Fixed `AudioStreamWAV` music loop end to the final valid sample frame after emulator QA found an Android `AudioTrack` SIGSEGV at the first loop wrap.
- Added `fon1` and `fon2` as OGG/Vorbis background tracks, loudness-normalized to approximately -18 LUFS and randomly selected at every level start without an immediate repeat.
- Added `promah1` and `promah2` as normalized OGG/Vorbis scoring-clown-miss sounds; their final second fades smoothly to 35% volume instead of silence.
- Added `bomb` as the normalized OGG/Vorbis Bomb-hit sound, replacing the procedural tone while preserving the Bomb haptic and gameplay feedback.
- Added arm64-v8a and x86_64 debug architectures so the same QA APK runs natively on phones and the local emulator.
- Excluded references, verification captures and source-processing artifacts from Android export.
- Updated the Android application ID to `ru.mkulkov.circusruckus`.
- Re-exported the Android debug APK with the new application ID, installed it on the physical Infinix X663, and launched `ru.mkulkov.circusruckus/com.godot.game.GodotAppLauncher` successfully.
- Physical-device QA exposed a missing Android VIBRATE manifest permission. Added `permissions/vibrate=true` to the Android export preset, rebuilt, installed, and verified the permission grant plus an error-free hit on Infinix X663.

### 2026-09-08

- Coins removed completely from MVP.
- Empty-box hit does not remove a life.
- Every correct scoring hit gives exactly +10.
- Combo does not multiply score.
- Bonus-character hit resets combo.
- Glutton restores one lost apple when hit.
- Escaped Glutton consumes one apple.
- Drunk causes the next player tap to strike a random box.
- Cheap subagents are permitted only for bounded low-risk work.
- Astra requires explicit user permission before use.
