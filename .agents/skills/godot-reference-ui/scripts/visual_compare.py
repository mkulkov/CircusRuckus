#!/usr/bin/env python3
"""Compare a reference image with a captured UI screenshot. Requires Pillow."""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps, ImageStat


def unit_interval(value):
    number = float(value)
    if not 0 <= number <= 1:
        raise argparse.ArgumentTypeError("expected a value from 0 to 1")
    return number


def crop_rect(value):
    try:
        x, y, width, height = (int(part.strip()) for part in value.split(","))
    except ValueError as error:
        raise argparse.ArgumentTypeError("crop must be x,y,width,height") from error
    if min(x, y) < 0 or min(width, height) <= 0:
        raise argparse.ArgumentTypeError("crop coordinates must be nonnegative and sizes positive")
    return (x, y, width, height)


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("reference", type=Path)
    result.add_argument("actual", type=Path)
    result.add_argument("--output-dir", type=Path, required=True)
    result.add_argument("--reference-crop", type=crop_rect)
    result.add_argument("--actual-crop", type=crop_rect)
    result.add_argument("--fit", choices=("contain", "cover", "stretch"), default="contain")
    result.add_argument("--background", default="#000000", help="RGB color behind transparent pixels")
    result.add_argument("--pixel-threshold", type=unit_interval, default=0.10)
    result.add_argument("--max-mae", type=unit_interval, default=0.08)
    result.add_argument("--max-blur-mae", type=unit_interval, default=0.06)
    result.add_argument("--max-changed", type=unit_interval, default=0.12)
    result.add_argument("--blur-radius", type=float, default=2.0)
    return result


def open_and_crop(path, rect):
    with Image.open(path) as source:
        image = ImageOps.exif_transpose(source).convert("RGBA")
    original_size = image.size
    if rect:
        x, y, width, height = rect
        if x + width > image.width or y + height > image.height:
            raise ValueError(f"crop {rect} extends outside {path} ({image.width}x{image.height})")
        image = image.crop((x, y, x + width, y + height))
    return image, original_size


def normalize(image, size, fit):
    if fit == "stretch":
        return image.resize(size, Image.Resampling.LANCZOS)
    if fit == "cover":
        return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)
    return ImageOps.pad(image, size, method=Image.Resampling.LANCZOS,
                        color=(0, 0, 0, 0), centering=(0.5, 0.5))


def flatten(image, background):
    base = Image.new("RGBA", image.size, background)
    return Image.alpha_composite(base, image).convert("RGB")


def compare(args):
    if args.blur_radius < 0:
        raise ValueError("blur radius must be nonnegative")
    reference, ref_original = open_and_crop(args.reference, args.reference_crop)
    actual, actual_original = open_and_crop(args.actual, args.actual_crop)
    actual = normalize(actual, reference.size, args.fit)
    reference = flatten(reference, args.background)
    actual = flatten(actual, args.background)

    difference = ImageChops.difference(reference, actual)
    mae = sum(ImageStat.Stat(difference).mean) / (3 * 255)
    channels = difference.split()
    max_channel = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
    histogram = max_channel.histogram()
    cutoff = min(255, int(args.pixel_threshold * 255))
    changed_fraction = sum(histogram[cutoff + 1:]) / (reference.width * reference.height)

    ref_blur = reference.convert("L").filter(ImageFilter.GaussianBlur(args.blur_radius))
    actual_blur = actual.convert("L").filter(ImageFilter.GaussianBlur(args.blur_radius))
    blur_mae = ImageStat.Stat(ImageChops.difference(ref_blur, actual_blur)).mean[0] / 255

    passed = (mae <= args.max_mae and blur_mae <= args.max_blur_mae
              and changed_fraction <= args.max_changed)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    overlay_path = args.output_dir / "overlay.png"
    diff_path = args.output_dir / "diff.png"
    metrics_path = args.output_dir / "metrics.json"
    Image.blend(reference, actual, 0.5).save(overlay_path)
    ImageEnhance.Contrast(difference).enhance(3).save(diff_path)
    report = {
        "status": "PASS" if passed else "FAIL",
        "reference": str(args.reference.resolve()),
        "actual": str(args.actual.resolve()),
        "reference_original_size": ref_original,
        "actual_original_size": actual_original,
        "compared_size": reference.size,
        "reference_crop": args.reference_crop,
        "actual_crop": args.actual_crop,
        "fit": args.fit,
        "background": args.background,
        "metrics": {"mae": round(mae, 6), "blur_mae": round(blur_mae, 6),
                    "changed_fraction": round(changed_fraction, 6)},
        "thresholds": {"max_mae": args.max_mae, "max_blur_mae": args.max_blur_mae,
                       "max_changed": args.max_changed, "pixel_threshold": args.pixel_threshold,
                       "blur_radius": args.blur_radius},
        "artifacts": {"overlay": str(overlay_path.resolve()),
                      "diff": str(diff_path.resolve())},
    }
    metrics_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if passed else 1


def main():
    args = parser().parse_args()
    try:
        return compare(args)
    except (OSError, ValueError) as error:
        print(f"visual_compare: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
