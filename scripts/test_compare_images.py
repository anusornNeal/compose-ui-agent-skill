import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

from PIL import Image


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "compare-images.py"


class CompareImagesScriptTests(unittest.TestCase):
    def run_compare(
        self,
        reference,
        actual,
        *,
        include_diff=False,
        include_blend=False,
    ):
        with tempfile.TemporaryDirectory() as directory:
            workspace = pathlib.Path(directory)
            reference_path = workspace / "reference.png"
            actual_path = workspace / "actual.png"
            output_path = workspace / "artifacts" / "result.json"
            diff_path = workspace / "artifacts" / "diff.png"
            blend_path = workspace / "artifacts" / "blend.png"

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

            payload = None
            if output_path.exists():
                payload = json.loads(output_path.read_text(encoding="utf-8"))

            artifact_summary = {
                "result": result,
                "payload": payload,
                "output_exists": output_path.is_file(),
                "diff_exists": diff_path.is_file(),
                "blend_exists": blend_path.is_file(),
            }
            if diff_path.is_file():
                with Image.open(diff_path) as diff_image:
                    artifact_summary["diff_size"] = diff_image.size
                    artifact_summary["diff_pixel"] = diff_image.getpixel((0, 0))
                    artifact_summary["diff_alpha_extrema"] = diff_image.convert("RGBA").getchannel("A").getextrema()
            if blend_path.is_file():
                with Image.open(blend_path) as blend_image:
                    artifact_summary["blend_size"] = blend_image.size
                    artifact_summary["blend_pixel"] = blend_image.getpixel((0, 0))

            return artifact_summary

    def test_identical_images_have_perfect_scores(self):
        image = Image.new("RGB", (4, 4), "red")

        run = self.run_compare(image, image.copy())

        self.assertEqual(0, run["result"].returncode, run["result"].stderr)
        self.assertIsNotNone(run["payload"])
        self.assertEqual(4, run["payload"]["width"])
        self.assertEqual(4, run["payload"]["height"])
        self.assertEqual(0.0, run["payload"]["mean_absolute_error"])
        self.assertEqual(0.0, run["payload"]["changed_pixel_ratio"])
        self.assertEqual(1.0, run["payload"]["structural_similarity_estimate"])

    def test_changed_images_report_difference_metrics(self):
        reference = Image.new("RGB", (4, 4), "red")
        actual = reference.copy()
        actual.putpixel((1, 2), (0, 0, 255))

        run = self.run_compare(reference, actual)

        self.assertEqual(0, run["result"].returncode, run["result"].stderr)
        self.assertIsNotNone(run["payload"])
        self.assertGreater(run["payload"]["mean_absolute_error"], 0.0)
        self.assertGreater(run["payload"]["changed_pixel_ratio"], 0.0)
        self.assertLess(run["payload"]["structural_similarity_estimate"], 1.0)

    def test_dimension_mismatch_fails_with_actionable_error(self):
        reference = Image.new("RGB", (4, 4), "red")
        actual = Image.new("RGB", (5, 4), "red")

        run = self.run_compare(reference, actual)

        self.assertNotEqual(0, run["result"].returncode)
        self.assertEqual(
            {"error": "Reference and actual images must have the same dimensions."},
            run["payload"],
        )
        self.assertIn("same dimensions", run["result"].stderr)

    def test_diff_and_blend_artifacts_are_created(self):
        reference = Image.new("RGB", (4, 4), "red")
        actual = Image.new("RGB", (4, 4), "blue")

        run = self.run_compare(reference, actual, include_diff=True, include_blend=True)

        self.assertEqual(0, run["result"].returncode, run["result"].stderr)
        self.assertTrue(run["output_exists"])
        self.assertTrue(run["diff_exists"])
        self.assertTrue(run["blend_exists"])
        self.assertEqual((4, 4), run["diff_size"])
        self.assertEqual((4, 4), run["blend_size"])
        self.assertNotEqual((0, 0, 0), run["diff_pixel"][:3])
        self.assertEqual((255, 255), run["diff_alpha_extrema"])
        self.assertNotEqual(reference.getpixel((0, 0)), run["blend_pixel"][:3])
        self.assertNotEqual(actual.getpixel((0, 0)), run["blend_pixel"][:3])

    def test_alpha_difference_is_measured(self):
        reference = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
        actual = Image.new("RGBA", (4, 4), (0, 0, 0, 255))

        run = self.run_compare(reference, actual)

        self.assertEqual(0, run["result"].returncode, run["result"].stderr)
        self.assertGreater(run["payload"]["mean_absolute_error"], 0.0)
        self.assertGreater(run["payload"]["changed_pixel_ratio"], 0.0)
        self.assertLess(run["payload"]["structural_similarity_estimate"], 1.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
