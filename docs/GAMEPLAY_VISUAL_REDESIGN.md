# Gameplay visual redesign — 2026-10-09

Approved reference: assets/references/gameplay_redesign_2026-10-09.png.

2026-10-12 HUD override: ticket artwork is restored using verification/hud_series_v2_ru_720x1280.png as the style reference. Current endless fields (round/training, total score, current/best series, phase/recovery, timer and hammers) remain. Blank frames reuse nine patches of the approved series PNG for localized labels; no campaign targets or progress bar. Latest captures: builds/debug/verification/endless/captures/hud_tickets_restored_*.png. Earlier layout notes below are historical.

Current HUD: user-selected ticket artwork from assets/ui/tickets/hud_tickets_ru_v1.png, connected without editing the PNG. Source atlas regions include all static Russian print and icons; runtime overlays supply numeric values, progress fill and life hammers. Other locales preserve translated procedural captions. Screenshots: verification/hud_tickets_*.png.

Latest user-directed HUD revision: a lighter presentation supersedes the ornate plate sketch for HUD only. Compact warm cream surfaces with brown text use a 2px gold rim and 18px corners, without rivets, bevels or heavy text shadows. Top row plates are 288x88; score/series plates 488x72; objectives use one 1000x50 strip. Native HUD content height reduced from 324 to 238 design pixels. Clock and hammer icons reduced with their insets and restore-flight coordinates preserved. The old raster HUD plate remains available as reference but is no longer loaded by the HUD. Game board art and input routing remain unchanged.

Implementation: isolated gameplay background and HUD artwork; live values and existing pause/input paths retained. Existing box/clown/spring art and animation retained. Required Series remains a count, not x multiplier. Misses and Golden goals remain visible. Tiles follow actual BoardController slots. Fixed design art extends the floor below 1920 design pixels for tall screens. HUD plate uses three horizontal slices to preserve corner proportions.

Layout correction: HUD top offset 28 design pixels on native, uniform 288x104 top plates and 488x104 score/series plates. One 1000x80 objective row with adaptive columns; long captions fit their bounds. Board rows use 0.88/0.92/0.96 depth scale and slot origins at y=600/840/1080, plus a shared 10 pixel native/web offset. 320x122 tile artwork extends outside box bases and stays above the arena front rim; visible gaps separate the tiles. Screenshots: verification/layout_v2_*.png. Physical cutout and hosted web evidence remain unverified.

Generated with built-in image_gen (no CLI). Original game assets preserved. New assets: assets/generated/gameplay_stage_v2.png, assets/generated/gameplay_tile_v2.png, assets/ui/gameplay_hud_plate_v2.png.

## Prompts

### Background
Use case: stylized-concept. Create a production background texture for portrait mobile circus game using attached approved sketch as STYLE reference. 9:16 portrait. Remove ALL HUD, text, icons, boxes, characters, springs, individual tile platforms, and foreground props. Retain rich crimson velvet side curtains, navy striped tent, blurred glowing entrance arch in upper middle, warm golden spotlight and charming painted 2.5D toy circus art. Bottom 65 percent must be a broad EMPTY honey-colored wooden circus stage surface in gentle perspective, top stage edge at 34 percent image height, bottom stage edge at 87 percent image height, curved front thickness and alternating red/navy decorative bunting below, small warm bulbs along OUTER edges only. Absolutely no bulbs inside playable stage and no objects on stage. Low contrast wood grain, no grid. Scene will have nine interactive boxes and tiles drawn over it by game engine. Top 30 percent remains dark soft backdrop for live UI. No lettering or UI whatsoever.

### HUD plate
Production game UI asset, one single wide rectangular circus sign panel on truly transparent background. Aspect 3:1. Match approved screenshot style: dark navy blue lacquer enamel inset, ornate but restrained rounded brass gold rim, four small gold rivets inset at corners, gently curved bevels, warm highlights on upper left, tiny subtle worn scratches, soft inner shadow, rich hand-painted polished toy circus 2.5D artwork. Straight front view, symmetric rounded rectangle, panel fills nearly entire canvas with small transparent margin. Center must be empty uniform deep navy suitable for live text. NO text, numbers, symbols, stars, icons or backdrop. Reusable nine-slice HUD plate with corners restricted to outer 15 percent and plain stretchable middle.

### Tile
Use case stylized-concept. Single game sprite on transparent background: low raised wooden rectangular plinth / tile under a toy jack-in-the-box. Wide 3:1 aspect, gentle top-down perspective, rounded chunky corners, honey amber varnished wood, carved gold bevel, visible darker front thickness, tiny delicate wood grain, subtle worn edges. A small pale gold five-point star inlaid near front center. Hand painted polished 2.5D circus mobile game art. No box or other objects, no text, no bulbs. Fill canvas with one isolated platform, generous clear top surface. Transparent background.


2026-10-12 follow-up: the lower phase/training strip has no ticket or panel. Its caption uses bundled Yeseva One lettering, gold fill and dark outline/shadow over the stage; optional recovery progress uses outlined green lettering. The top ticket HUD remains.

2026-10-12 latest override: phase/training descriptions are hidden entirely. The permanent 1000x86 message sign starts at design y222 directly under the score/series tickets, with the same geometry for empty, bonus, warning and confusion states. Recovery progress uses this sign between transient messages. The top round/training number ticket remains.
