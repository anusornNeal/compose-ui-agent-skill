import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

from PIL import Image


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/compare-images.py"


class CompareImagesTests(unittest.TestCase):
    def run_compare(self, reference, actual):
        with tempfile.TemporaryDirectory() as directory:
            directory_path = pathlib.Path(directory)
            reference_path = directory_path / "reference.png"
            actual_path = directory_path / "actual.png"
            output_path = directory_path / "result.json"
            reference.save(reference_path)
            actual.save(actual_path)
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--reference",
                    str(reference_path),
                    "--actual",
                    str(actual_path),
                    "--output-json",
                    str(output_path),
                ],
                capture_output=True,
                text=True,
            )
            payload = json.loads(output_path.read_text(encoding="utf-8"))
            return result, payload

    def test_identical_images_have_perfect_scores(self):
        image = Image.new("RGB", (4, 4), "white")
        result, payload = self.run_compare(image, image.copy())
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(0.0, payload["mean_absolute_error"])
        self.assertEqual(0.0, payload["changed_pixel_ratio"])
        self.assertEqual(1.0, payload["structural_similarity_estimate"])

    def test_changed_images_report_a_difference(self):
        reference = Image.new("RGB", (4, 4), "white")
        actual = reference.copy()
        actual.putpixel((0, 0), (0, 0, 0))
        result, payload = self.run_compare(reference, actual)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertGreater(payload["mean_absolute_error"], 0.0)
        self.assertGreater(payload["changed_pixel_ratio"], 0.0)
        self.assertLess(payload["structural_similarity_estimate"], 1.0)

    def test_dimension_mismatch_is_rejected(self):
        reference = Image.new("RGB", (4, 4), "white")
        actual = Image.new("RGB", (5, 4), "white")
        result, _ = self.run_compare(reference, actual)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("same dimensions", result.stderr)

    def test_alpha_difference_is_not_ignored(self):
        reference = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
        actual = Image.new("RGBA", (4, 4), (0, 0, 0, 255))
        result, payload = self.run_compare(reference, actual)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertGreater(payload["mean_absolute_error"], 0.0)
        self.assertGreater(payload["changed_pixel_ratio"], 0.0)
        self.assertLess(payload["structural_similarity_estimate"], 1.0)


if __name__ == "__main__":
    unittest.main()
