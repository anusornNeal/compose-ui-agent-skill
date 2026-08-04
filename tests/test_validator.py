import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts/validate-skill.ps1"


class ValidatorTests(unittest.TestCase):
    def make_fixture(self):
        directory = tempfile.TemporaryDirectory()
        fixture = pathlib.Path(directory.name) / "repo"
        shutil.copytree(
            ROOT,
            fixture,
            ignore=shutil.ignore_patterns(".git", ".superpowers", "__pycache__"),
        )
        return directory, fixture

    def run_validator(self, fixture):
        return subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(VALIDATOR),
                "-RepoRoot",
                str(fixture),
            ],
            capture_output=True,
            text=True,
        )

    def test_clean_repository_passes(self):
        result = self.run_validator(ROOT)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Repository skill validation passed", result.stdout)

    def test_validator_rejects_missing_skill_package(self):
        directory, fixture = self.make_fixture()
        try:
            shutil.rmtree(fixture / "skills/compose-ui-delivery")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Missing skill package: compose-ui-delivery", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_stale_default_prompt(self):
        directory, fixture = self.make_fixture()
        try:
            metadata_path = fixture / "skills/compose-ui-reference/agents/openai.yaml"
            metadata = metadata_path.read_text(encoding="utf-8")
            metadata_path.write_text(metadata.replace("$compose-ui-reference", "$compose-ui-agent-skill"), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("default_prompt must mention $compose-ui-reference", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_broken_or_escaping_markdown_links(self):
        directory, fixture = self.make_fixture()
        try:
            skill_path = fixture / "skills/compose-ui-designer/SKILL.md"
            original = skill_path.read_text(encoding="utf-8")
            for link, expected in (
                ("[missing](references/missing.md)", "Missing markdown link target"),
                ("[escape](../../README.md)", "Markdown link escapes skill root"),
            ):
                skill_path.write_text(original + "\n" + link + "\n", encoding="utf-8")
                result = self.run_validator(fixture)
                self.assertNotEqual(0, result.returncode)
                self.assertIn(expected, result.stderr)
                skill_path.write_text(original, encoding="utf-8")
        finally:
            directory.cleanup()

    def test_validator_rejects_invalid_platform_config(self):
        directory, fixture = self.make_fixture()
        try:
            config_path = fixture / "skills/compose-ui-delivery/templates/compose-ui-delivery.yaml"
            config = config_path.read_text(encoding="utf-8")
            config_path.write_text(config.replace('kind: "mobile"', 'kind: "television"'), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("platform.kind must be mobile, web, or desktop", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_production_placeholders(self):
        directory, fixture = self.make_fixture()
        try:
            reference_path = fixture / "skills/compose-ui-reference/references/reference-normalization.md"
            reference_path.write_text(reference_path.read_text(encoding="utf-8") + "\nTODO later\n", encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Placeholder found in production resource", result.stderr)
        finally:
            directory.cleanup()


    def test_validator_rejects_invalid_platform_combination(self):
        directory, fixture = self.make_fixture()
        try:
            config_path = fixture / "skills/compose-ui-delivery/templates/compose-ui-delivery.yaml"
            config = config_path.read_text(encoding="utf-8")
            config = config.replace('kind: "mobile"', 'kind: "web"')
            config_path.write_text(config, encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Unsupported platform combination: web/android", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_malformed_metadata_quotes(self):
        directory, fixture = self.make_fixture()
        try:
            metadata_path = fixture / "skills/compose-ui-reference/agents/openai.yaml"
            metadata = metadata_path.read_text(encoding="utf-8")
            metadata_path.write_text(
                metadata.replace(
                    'display_name: "Compose UI Reference"',
                    'display_name: "Compose UI Reference\\"',
                    1,
                ),
                encoding="utf-8",
            )
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Invalid metadata YAML", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_invalid_visual_review_nested_values(self):
        directory, fixture = self.make_fixture()
        try:
            import json

            review_path = fixture / "skills/compose-ui-delivery/templates/visual-review.json"
            original = json.loads(review_path.read_text(encoding="utf-8"))
            mutations = (
                (lambda review: review.update(iteration=True), "iteration must be an integer"),
                (lambda review: review.update(fixed=[{}]), "fixed entries must be strings"),
                (lambda review: review["scores"].update(visual_parity=[]), "scores.visual_parity must be an integer"),
                (lambda review: review.update(functional_checks=[{"name": [], "result": {}}]), "functional checks require"),
            )
            for mutate, expected in mutations:
                review = json.loads(json.dumps(original))
                mutate(review)
                review_path.write_text(json.dumps(review), encoding="utf-8")
                result = self.run_validator(fixture)
                self.assertNotEqual(0, result.returncode)
                self.assertIn(expected, result.stderr)
        finally:
            directory.cleanup()


if __name__ == "__main__":
    unittest.main()
