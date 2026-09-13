from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageStat


def main() -> None:
    parser = argparse.ArgumentParser(description="Create Clown Smash visual-reference diagnostics.")
    parser.add_argument("reference", type=Path)
    parser.add_argument("current", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    reference = Image.open(args.reference).convert("RGBA")
    current = Image.open(args.current).convert("RGBA")
    reference = reference.resize(current.size, Image.Resampling.LANCZOS)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    reference.save(args.output_dir / "reference_scaled.png")
    Image.blend(reference, current, 0.5).save(args.output_dir / "overlay.png")

    difference = ImageChops.difference(reference, current).convert("RGB")
    ImageEnhance.Contrast(difference).enhance(1.8).save(args.output_dir / "difference.png")

    side_by_side = Image.new("RGB", (current.width * 2, current.height), "black")
    side_by_side.paste(reference.convert("RGB"), (0, 0))
    side_by_side.paste(current.convert("RGB"), (current.width, 0))
    side_by_side.save(args.output_dir / "side_by_side.png")

    mean_channels = ImageStat.Stat(difference).mean
    normalized_difference = sum(mean_channels) / (len(mean_channels) * 255.0)
    print(f"normalized_mean_absolute_difference={normalized_difference:.6f}")


if __name__ == "__main__":
    main()
