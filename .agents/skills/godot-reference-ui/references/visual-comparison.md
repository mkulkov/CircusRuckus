# Visual comparison

The CLI uses Pillow (`py -m pip install Pillow` if absent). It compares a reference PNG with a captured Godot screenshot, saves `diff.png`, `overlay.png`, and `metrics.json`, prints JSON, and returns 0 for PASS, 1 for FAIL, 2 for invalid input.

```powershell
py scripts/visual_compare.py reference.png actual.png --output-dir comparison --max-mae 0.08 --max-blur-mae 0.06 --max-changed 0.12
```

`--reference-crop` and `--actual-crop` take `x,y,width,height` in each source image. Use matching semantic regions, such as one button, not arbitrary crops chosen to improve the score. The actual image is normalized to the reference crop dimensions. `--fit contain` is the default and preserves aspect ratio with padding; `cover` crops excess; `stretch` may distort and should be used only for a known scaling difference. Both RGBA images are composited onto `--background` (default `#000000`) before comparison, so for transparent art choose the intended game background.

Metrics are normalized 0–1: `mae` is mean absolute RGB difference; `blur_mae` is luminance difference after Gaussian blur, a simple perceptual proxy for broad shapes and lighting; `changed_fraction` counts pixels whose largest channel error exceeds `--pixel-threshold` (default 0.10). All configured maxima must pass. These are not SSIM or a learned perceptual score. The overlay blends reference and actual at 50% to expose alignment; the diff amplifies differences for inspection. `metrics.json` records dimensions, crops, fit, thresholds, and status.

Compare like with like: same UI state, language, render size, and animation frame. A concept sketch, compressed source, or different background may legitimately yield a low numeric score even when a component is visually appropriate. Tune thresholds on a known acceptable screenshot, record them, and still inspect the images. Never use the same image twice as evidence of a real Godot render.
