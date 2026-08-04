import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

from PIL import Image


ROOT = pathlib.Path(__file__).resolve().parent
SCRIPT = ROOT / "compare-images.py"


class CompareImagesScriptTests(unittest.TestCase):
    def run_compare(self, reference, actual, *, include_diff=False, include_blend=False):
        with tempfile.TemporaryDirectory() as directory:
            workspace = pathlib.Path(directory)
            reference_path = workspace / "reference.png"
            actual_path = workspace / "actual.png"
            output_path = workspace / "artifacts/result.json"
            diff_path = workspace / "artifacts/diff.png"
            blend_path = workspace / "artifacts/blend.png"
            reference.save(reference_path)
            actual.save(actual_path)
            command = [
                sys.executable,
                str(SCRIPT),
                "--reference",
                str(reference_path),
                "--actual",
                str(actual_path),
                "--output-json",
                str(output_path),
            ]
            if include_diff:
                command.extend(["--diff", str(diff_path)])
            if include_blend:
                command.extend(["--blend", str(blend_path)])
            result = subprocess.run(command, capture_output=True, text=True)
            payload = json.loads(output_path.read_text(encoding="utf-8")) if output_path.exists() else None
            return result, payload, diff_path.exists(), blend_path.exists()

    def test_identical_images_have_perfect_pixel_similarity(self):
        image = Image.new("RGB", (4, 4), "red")
        result, payload, _, _ = self.run_compare(image, image.copy())
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(1.0, payload["pixel_similarity"])
        self.assertEqual(0.0, payload["changed_pixel_ratio"])

    def test_changed_and_alpha_images_report_differences(self):
        reference = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
        actual = Image.new("RGBA", (4, 4), (0, 0, 0, 255))
        result, payload, _, _ = self.run_compare(reference, actual)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertLess(payload["pixel_similarity"], 1.0)
        self.assertGreater(payload["changed_pixel_ratio"], 0.0)

    def test_diff_and_blend_artifacts_are_created(self):
        reference = Image.new("RGB", (4, 4), "red")
        actual = Image.new("RGB", (4, 4), "blue")
        result, _, diff_exists, blend_exists = self.run_compare(
            reference, actual, include_diff=True, include_blend=True
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertTrue(diff_exists)
        self.assertTrue(blend_exists)


if __name__ == "__main__":
    unittest.main(verbosity=2)
