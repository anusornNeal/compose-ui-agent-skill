import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class SkillPackageTests(unittest.TestCase):
    def test_required_skill_files_exist(self):
        required = [
            "SKILL.md",
            "agents/openai.yaml",
            "references/reference-mode.md",
            "references/designer-mode.md",
            "references/visual-review.md",
            "references/compose-patterns.md",
            "templates/compose-ui-agent.yaml",
            "templates/screen-spec.md",
            "templates/visual-review.json",
        ]
        missing = [path for path in required if not (ROOT / path).is_file()]
        self.assertEqual([], missing)

    def test_skill_metadata_is_actionable(self):
        skill = (ROOT / "SKILL.md").read_text(encoding="utf-8")
        metadata = (ROOT / "agents/openai.yaml").read_text(encoding="utf-8")
        self.assertTrue(skill.startswith("---\n"))
        self.assertIn("name: compose-ui-agent-skill", skill)
        self.assertIn("description: Use when", skill)
        self.assertIn("Reference Mode", skill)
        self.assertIn("Designer Mode", skill)
        self.assertNotIn("TODO", skill)
        self.assertIn("interface:", metadata)
        self.assertIn('display_name: "Compose UI Agent"', metadata)
        self.assertIn("$compose-ui-agent-skill", metadata)
        self.assertNotIn("agent:\n", metadata)

if __name__ == "__main__":
    unittest.main()
