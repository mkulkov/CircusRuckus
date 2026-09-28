---
name: godot-reference-ui
description: Build or revise Godot game UI and HUD from an image reference, including reusable art-backed controls, runtime screenshots, and visual comparison. Use when visual fidelity to a supplied sketch or approved design matters.
---

# Godot UI/HUD from a visual reference

Use this workflow for an actual Godot project and an accessible reference image. A concept sketch is evidence of visual intent; identify which details are precise and which are ambiguous. If the image is unavailable, request it and continue only with work that does not depend on its pixels. Do not claim visual fidelity from a text description alone.

## 1. Read the project and decompose the reference

- Inspect project rules, target platform, base viewport, stretch settings, existing theme, components, assets, fonts, and input paths. Reuse the established UI kit where it matches the reference.
- Record the reference canvas, target viewport, element bounds, spacing, safe area, text, colors, silhouette, texture, lighting, and states. Separate whole-screen comparison from element crops. Mark sketch details whose exact values cannot be inferred.
- Split the design into background, reusable controls, fixed decoration, text, icons, and live HUD values. Avoid turning a whole interactive screen into one image.

## 2. Build art-backed components

- Preserve intricate material, scratches, ornaments, bolts, unusual silhouettes, and painted light in transparent raster assets or suitable vectors. Extract from source only when resolution and rights permit; otherwise recreate the artwork from the reference and inspect it. Do not substitute a plain `StyleBoxFlat` for detailed reference art merely for convenience.
- Keep labels, counters, timers, progress, localization, and changeable icons as Godot nodes. Remove baked text from a reusable texture when feasible. If text removal damages the art, recreate the center or use a carefully designed overlay and check it at runtime.
- Choose `TextureButton` for fixed-size interactive art and its state textures; use `NinePatchRect` or `StyleBoxTexture` for stretchable art, with input handled by a real Button/Control. Set slice margins around corners, rivets, and trim; stretch only a neutral region. Check the minimum, intended, and widest sizes for distortion.
- Make reusable scenes with explicit content and signals, normal/hover/pressed/focus/disabled visuals as applicable to the platform, and a visible keyboard/gamepad focus state when those inputs exist. Keep hit targets usable and check that decorative Controls do not intercept input.
- For HUD, keep a static frame or plate separate from `ProgressBar`, `Label`, `TextureRect` icons, counters, and state updates. Verify live values and their alignment at representative extremes (empty/full, short/long numbers).

## 3. Layout and visual proof

- Use anchors, containers, size flags, minimum sizes, and appropriate project stretch settings to match the composition at the target viewport. Respect device safe areas when relevant. Test all specified aspect ratios and orientations; do not invent extra ones.
- Run the scene in Godot, navigate to the UI, capture a fresh screenshot after assets import, and compare against the reference at the same state, viewport, language, and crop. Inspect both the entire composition and important components. Iterate on geometry, art, type, color, and states until material differences are resolved. Static scene validation alone is not visual proof.
- The available Godot MCP tool `mcp__godot__godot_compare_gameplay_screenshot` can run a scene, capture after `warmupFrames`, and compare with `referencePath` inside the selected project. Its supported arguments are `referencePath`, optional `scenePath`, `outputPath`, `threshold`, and `warmupFrames`. First select the intended project with `godot_workspace_select_project` if needed. Use it only when the reference is in that project and the scene can reach the needed UI state. Inspect its returned artifact and result; its own threshold is a per-channel threshold, not the CLI metrics below.
- If MCP cannot reach a particular menu/HUD state, capture from a normal Godot run or an existing project-specific screenshot mechanism. Pass the resulting PNG to `scripts/visual_compare.py`; the script is a comparison adapter and does not invent a capture API. See [comparison guide](references/visual-comparison.md).
- A numeric PASS is supporting evidence, not approval of art quality. Review overlay/diff visually, especially for hand-drawn references, anti-aliasing, animation, and variable text. Report viewport, state, screenshot path, metrics, fixes, and any remaining visual mismatch honestly.

Example: a worn blue metal menu button with brass side pieces and cyan glow should have an art-backed base, actual `Label`, appropriate input and focus handling, and state-specific lighting. Reuse that visual language for related HUD frames and counters without baking changing values into the art.
