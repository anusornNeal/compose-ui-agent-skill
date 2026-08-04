import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image
    from PIL import ImageChops
except ImportError as error:
    print(
        "Pillow is required to run compare-images.py. Install it with: python -m pip install Pillow",
        file=sys.stderr,
    )
    raise SystemExit(1) from error


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", required=True)
    parser.add_argument("--actual", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--diff")
    parser.add_argument("--blend")
    return parser.parse_args()


def ensure_parent(path_string):
    Path(path_string).parent.mkdir(parents=True, exist_ok=True)


def load_image(path_string):
    with Image.open(path_string) as image:
        return image.convert("RGBA")


def compute_metrics(reference_image, actual_image):
    width, height = reference_image.size
    total_pixels = width * height
    total_channels = total_pixels * 3

    white_background = Image.new("RGBA", reference_image.size, (255, 255, 255, 255))
    reference_rgb = Image.alpha_composite(white_background, reference_image).convert("RGB")
    actual_rgb = Image.alpha_composite(white_background, actual_image).convert("RGB")
    appearance_difference = ImageChops.difference(reference_rgb, actual_rgb)
    alpha_difference = ImageChops.difference(
        reference_image.getchannel("A"), actual_image.getchannel("A")
    ).convert("RGB")
    absolute_difference = ImageChops.lighter(appearance_difference, alpha_difference)
    diff_values = absolute_difference.tobytes()

    absolute_total = sum(diff_values)
    changed_pixels = sum(
        1
        for offset in range(0, len(diff_values), 3)
        if diff_values[offset] or diff_values[offset + 1] or diff_values[offset + 2]
    )

    mean_absolute_error = absolute_total / total_channels
    normalized_error = mean_absolute_error / 255.0
    changed_pixel_ratio = changed_pixels / total_pixels
    pixel_similarity = max(0.0, 1.0 - normalized_error)

    return absolute_difference, {
        "width": width,
        "height": height,
        "mean_absolute_error": round(mean_absolute_error, 6),
        "changed_pixel_ratio": round(changed_pixel_ratio, 6),
        "pixel_similarity": round(pixel_similarity, 6),
    }


def main():
    args = parse_args()

    reference_image = load_image(args.reference)
    actual_image = load_image(args.actual)

    if reference_image.size != actual_image.size:
        ensure_parent(args.output_json)
        with Path(args.output_json).open("w", encoding="utf-8") as output_file:
            json.dump(
                {"error": "Reference and actual images must have the same dimensions."},
                output_file,
                indent=2,
                sort_keys=True,
            )
            output_file.write("\n")
        print("Reference and actual images must have the same dimensions.", file=sys.stderr)
        return 1

    absolute_difference, payload = compute_metrics(reference_image, actual_image)

    ensure_parent(args.output_json)
    with Path(args.output_json).open("w", encoding="utf-8") as output_file:
        json.dump(payload, output_file, indent=2, sort_keys=True)
        output_file.write("\n")

    if args.diff:
        ensure_parent(args.diff)
        absolute_difference.save(args.diff)

    if args.blend:
        ensure_parent(args.blend)
        white_background = Image.new("RGBA", reference_image.size, (255, 255, 255, 255))
        reference_rgb = Image.alpha_composite(white_background, reference_image).convert("RGB")
        actual_rgb = Image.alpha_composite(white_background, actual_image).convert("RGB")
        Image.blend(reference_rgb, actual_rgb, 0.5).save(args.blend)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
