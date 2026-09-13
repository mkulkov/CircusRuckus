# Visual reference analysis

Reference: `assets/references/gameplay_field_reference.png` (941×1672, portrait 9:16).

The target composition has five depth planes: painted tent canopy, marquee entrance and side props, raised wooden board, interactive boxes/character/hammer, and screen-space HUD. The first 15% of the screen is HUD; the entrance occupies the central upper third; the board begins near 37% and its front edge ends near 87%.

## Priority differences from the original prototype

### P0

- Replace the flat tent with a warm, painterly depth plate.
- Make the nine open boxes read as one coherent red/blue/gold prop family.
- Align the 3×3 rows to the reference board region and retain perspective scaling.
- Increase clown readability while keeping it anchored to the middle rear box.

### P1

- Match the two-tier HUD geometry, large pause control, timer hierarchy and three apple lives.
- Strengthen board thickness, contact shadows, cavity depth and warm stage lighting.
- Preserve the animation specification and gameplay hit regions.

### P2

- Add wood grain, rivets, highlight bands and small decorative material cues.
- Keep responsive captures readable without non-uniform full-canvas stretching.

## Ownership

`MAIN_AGENT_TASKS`: reference measurement, art direction, generated-asset selection, integration, gameplay-contract preservation, visual review and final verification.

`SUBAGENT_TASKS`: none. The implementation remained tightly coupled to one presentation stack, and the active collaboration policy did not independently authorize delegation.
