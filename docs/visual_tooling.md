# Visual verification tooling

Capture a stable fully-visible clown state:

```powershell
& 'C:\dev\Godot\Godot_console.exe' --path . --script res://tests/capture_gameplay.gd -- mode=gameplay width=1080 height=1920 output=res://artifacts/visual_tests/final.png
```

Capture the hammer approach/impact state by replacing `mode=gameplay` with `mode=impact`.

Create the scaled reference, 50% overlay, enhanced difference and side-by-side image:

```powershell
python tools/visual_compare.py assets/references/gameplay_field_reference.png artifacts/visual_tests/final.png artifacts/visual_tests
```

The numerical normalized mean absolute difference is diagnostic only. Review `side_by_side.png` visually; a full-frame pixel score is intentionally sensitive to original painterly asset detail and does not equal perceptual similarity.
