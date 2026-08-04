import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts" / "validate-skill.ps1"


class ValidatorTests(unittest.TestCase):
    def make_fixture(self):
        directory = tempfile.TemporaryDirectory()
        fixture = pathlib.Path(directory.name) / "skill"
        shutil.copytree(
            ROOT,
            fixture,
            ignore=shutil.ignore_patterns(".git", ".superpowers", "tests", "__pycache__"),
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
                "-SkillRoot",
                str(fixture),
            ],
            capture_output=True,
            text=True,
        )

    def test_validator_rejects_missing_core_scripts(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = pathlib.Path(directory) / "skill"
            shutil.copytree(ROOT, fixture, ignore=shutil.ignore_patterns(".git", ".superpowers", "tests", "__pycache__"))
            shutil.rmtree(fixture / "scripts")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Missing required file:", result.stderr)
            self.assertIn("scripts/discover-project.ps1", result.stderr)

    def test_validator_rejects_duplicate_frontmatter_keys(self):
        directory, fixture = self.make_fixture()
        try:
            skill_path = fixture / "SKILL.md"
            skill = skill_path.read_text(encoding="utf-8")
            skill_path.write_text(skill.replace("description:", "name: duplicate\ndescription:", 1), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("duplicate", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_unsupported_metadata_keys(self):
        directory, fixture = self.make_fixture()
        try:
            metadata_path = fixture / "agents/openai.yaml"
            metadata_path.write_text(metadata_path.read_text(encoding="utf-8") + "unsupported: true\n", encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("unsupported", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_unterminated_yaml_strings(self):
        directory, fixture = self.make_fixture()
        try:
            metadata_path = fixture / "agents/openai.yaml"
            metadata = metadata_path.read_text(encoding="utf-8")
            metadata_path.write_text(metadata.replace('display_name: "Compose UI Agent"', 'display_name: "Compose UI Agent', 1), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Unterminated", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_escaped_terminal_yaml_quote(self):
        directory, fixture = self.make_fixture()
        try:
            metadata_path = fixture / "agents/openai.yaml"
            metadata = metadata_path.read_text(encoding="utf-8")
            malformed = 'display_name: "Compose UI Agent' + "\\" + '"'
            metadata_path.write_text(metadata.replace('display_name: "Compose UI Agent"', malformed, 1), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Unterminated", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_invalid_visual_review_collection_type(self):
        directory, fixture = self.make_fixture()
        try:
            template_path = fixture / "templates/visual-review.json"
            template = json.loads(template_path.read_text(encoding="utf-8"))
            template["fixed"] = "not-an-array"
            template_path.write_text(json.dumps(template), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("fixed must be", result.stderr)
            self.assertIn("array", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_invalid_visual_review_nested_types(self):
        directory, fixture = self.make_fixture()
        try:
            template_path = fixture / "templates/visual-review.json"
            mutations = (
                ("iteration", True, "iteration must be numeric"),
                ("fixed", [{}], "fixed entries must be strings"),
                ("scores", {"visual_parity": [], "ux_quality": 5, "anti_ai_slop": "x"}, "scores.visual_parity must be numeric"),
                ("functional_checks", [{"name": [], "result": {}}], "functional_checks entries need name and result"),
            )
            original = json.loads(template_path.read_text(encoding="utf-8"))
            for property_name, value, expected_error in mutations:
                template = json.loads(json.dumps(original))
                template[property_name] = value
                template_path.write_text(json.dumps(template), encoding="utf-8")
                result = self.run_validator(fixture)
                self.assertNotEqual(0, result.returncode)
                pattern = re.escape(expected_error).replace(r"\ ", r"\s+")
                self.assertRegex(result.stderr, pattern)
        finally:
            directory.cleanup()

    def test_validator_rejects_invalid_visual_review_values(self):
        directory, fixture = self.make_fixture()
        try:
            template_path = fixture / "templates/visual-review.json"
            original = json.loads(template_path.read_text(encoding="utf-8"))
            mutations = (
                ("score", lambda template: template["scores"].update(visual_parity=6), "scores.visual_parity must be between 1 and 5"),
                ("iteration", lambda template: template.update(iteration=0), "iteration must be between 1 and 5"),
                ("functional result", lambda template: template["functional_checks"][0].update(result="unknown"), "functional_checks entries need name and result"),
            )
            for _, mutate, expected_error in mutations:
                template = json.loads(json.dumps(original))
                mutate(template)
                template_path.write_text(json.dumps(template), encoding="utf-8")
                result = self.run_validator(fixture)
                self.assertNotEqual(0, result.returncode)
                pattern = re.escape(expected_error).replace(r"\ ", r"\s+")
                self.assertRegex(result.stderr, pattern)
        finally:
            directory.cleanup()

    def test_validator_rejects_unsupported_yaml_escape_and_launch_mode(self):
        directory, fixture = self.make_fixture()
        try:
            metadata_path = fixture / "agents/openai.yaml"
            metadata = metadata_path.read_text(encoding="utf-8")
            metadata_path.write_text(metadata.replace('display_name: "Compose UI Agent"', 'display_name: "Compose \\q Agent"', 1), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Unsupported escape", result.stderr)

            metadata_path.write_text(metadata, encoding="utf-8")
            config_path = fixture / "templates/compose-ui-agent.yaml"
            config = config_path.read_text(encoding="utf-8")
            config_path.write_text(config.replace('mode: "activity"', 'mode: "mystery"', 1), encoding="utf-8")
            result = self.run_validator(fixture)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("launch.mode must be activity or deeplink", result.stderr)
        finally:
            directory.cleanup()

    def test_validator_rejects_invalid_scalar_types_and_indentation(self):
        directory, fixture = self.make_fixture()
        try:
            mutations = (
                ("metadata indentation", fixture / "agents/openai.yaml", lambda content: content.replace('  display_name:', '   display_name:', 1), "invalid indentation"),
                ("density", fixture / "templates/compose-ui-agent.yaml", lambda content: content.replace('density: 2.625', 'density: "dense"', 1), "density must be a positive number"),
                ("boolean", fixture / "templates/compose-ui-agent.yaml", lambda content: content.replace('record_logcat: true', 'record_logcat: "yes"', 1), "key must be boolean"),
            )
            originals = {path: path.read_text(encoding="utf-8") for _, path, _, _ in mutations}
            for _, path, mutate, expected_error in mutations:
                for original_path, original_content in originals.items():
                    original_path.write_text(original_content, encoding="utf-8")
                path.write_text(mutate(originals[path]), encoding="utf-8")
                result = self.run_validator(fixture)
                self.assertNotEqual(0, result.returncode)
                pattern = re.escape(expected_error).replace(r"\ ", r"\s+")
                self.assertRegex(result.stderr, pattern)

            template_path = fixture / "templates/visual-review.json"
            original_template = json.loads(template_path.read_text(encoding="utf-8"))
            template_cases = (
                (lambda template: template.update(screen=1), "screen must be a non-empty string"),
                (lambda template: template["scores"].update(anti_ai_slop="maybe"), "anti_ai_slop must be pass, fail, or blocked"),
            )
            for mutate, expected_error in template_cases:
                template = json.loads(json.dumps(original_template))
                mutate(template)
                template_path.write_text(json.dumps(template), encoding="utf-8")
                result = self.run_validator(fixture)
                self.assertNotEqual(0, result.returncode)
                pattern = re.escape(expected_error).replace(r"\ ", r"\s+")
                self.assertRegex(result.stderr, pattern)
        finally:
            directory.cleanup()

    def test_validator_rejects_invalid_metadata_scalar_types(self):
        directory, fixture = self.make_fixture()
        try:
            metadata_path = fixture / "agents/openai.yaml"
            original = metadata_path.read_text(encoding="utf-8")
            for replacement in ('display_name: true', 'display_name: ""'):
                metadata_path.write_text(original.replace('display_name: "Compose UI Agent"', replacement, 1), encoding="utf-8")
                result = self.run_validator(fixture)
                self.assertNotEqual(0, result.returncode)
                self.assertRegex(result.stderr, r"interface\.display_name\s+must be a non-empty string")
        finally:
            directory.cleanup()


if __name__ == "__main__":
    unittest.main()
