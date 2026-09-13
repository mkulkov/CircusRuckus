# Visual reference matching report

Reference: `assets/references/gameplay_field_reference.png`

Final screenshot: `artifacts/visual_tests/final.png`

Comparison artifacts: `overlay.png`, `difference.png`, `side_by_side.png`.

## Iteration 1

The original procedural scene was captured and inspected at 1080×1920 before integration. Largest differences:

1. Flat tent background lacked painterly depth and props.
2. Board occupied too much vertical space and read as a plain plane.
3. Boxes were flat, small in the rear row and materially unlike the reference.
4. Clown was too small and visually simple.
5. HUD proportions were close, but surfaces and typography lacked depth.

Changes: integrated an original generated circus plate, reusable painted box, clown and hammer; realigned the board and 3×3 rows; strengthened HUD surface details.

## Iteration 2

Screenshot: `artifacts/visual_tests/iteration_02.png`

Largest remaining differences:

1. Generated box lids are taller and more upright than the reference.
2. The board remains more geometric and less painterly than the reference board.
3. The system fallback font is less rounded/decorative than the reference lettering.
4. Side props differ because the background is an original recreation.
5. Apples remain procedural and less glossy than the painted reference.

Corrections: moved box art down inside each slot, increased rear-row scale, enlarged and re-anchored the clown, tightened level/timer panels, added board grain, text shadows and highlight bands.

## Final verification

- Visible renderer: OpenGL 3.3 Compatibility on NVIDIA GeForce RTX 3050 Laptop GPU.
- Target capture: 1080×1920.
- Responsive captures: 720×1280 and 1080×2340.
- Hammer state: `artifacts/visual_tests/impact.png`.
- Normalized full-frame mean absolute pixel difference: `0.145944` (diagnostic only).
- Visual comparison iterations: 2.

## Reference compliance check

- [x] overall portrait composition
- [x] pause position
- [x] level panel
- [x] timer
- [x] lives
- [x] score panel
- [x] combo panel
- [x] circus entrance position
- [x] board position
- [x] board size
- [x] board perspective
- [x] 3×3 arrangement
- [x] back-row scale
- [x] middle-row scale
- [x] front-row scale
- [x] box width/height
- [x] open-box depth
- [x] clown scale
- [x] clown anchor
- [x] red/blue/gold palette
- [x] wood appearance
- [x] contact shadows
- [x] scene depth
- [x] warm lighting
- [x] background visual hierarchy

Result: PASS at the requested convergence level. There are no P0 composition discrepancies. Remaining differences are the P1/P2 asset-shape, board-painting, font and apple-detail items listed above.

## Functional evidence

- Full `tests/run_tests.gd`: PASS.
- `tests/smoke_test.gd`: PASS.
- Headless main-scene run: exit 0.
- Captured states: fully visible clown and hammer approach/impact.
- Rise, hit, hide, disappearance and repeated interaction phases exercised by the automated core interaction test.
