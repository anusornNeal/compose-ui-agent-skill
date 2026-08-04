import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SKILLS = {
    "compose-ui-reference": ROOT / "skills/compose-ui-reference",
    "compose-ui-designer": ROOT / "skills/compose-ui-designer",
    "compose-ui-delivery": ROOT / "skills/compose-ui-delivery",
}


class SkillPackageTests(unittest.TestCase):
    def test_three_directly_invokable_skill_packages_exist(self):
        for name, skill_root in SKILLS.items():
            with self.subTest(skill=name):
                self.assertTrue((skill_root / "SKILL.md").is_file())
                self.assertTrue((skill_root / "agents/openai.yaml").is_file())

    def test_skill_names_and_default_prompts_match(self):
        names = set()
        for expected_name, skill_root in SKILLS.items():
            skill = (skill_root / "SKILL.md").read_text(encoding="utf-8")
            metadata = (skill_root / "agents/openai.yaml").read_text(encoding="utf-8")
            self.assertTrue(skill.startswith("---\n"))
            self.assertIn(f"name: {expected_name}", skill)
            self.assertIn("description: Use when", skill)
            self.assertIn(f"${expected_name}", metadata)
            self.assertNotIn("TODO", skill)
            self.assertNotIn("TBD", skill)
            names.add(expected_name)
        self.assertEqual(3, len(names))

    def test_reference_skill_composes_official_figma_and_delivery_skills(self):
        skill = (SKILLS["compose-ui-reference"] / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("$figma-implement-design", skill)
        self.assertIn("$compose-ui-delivery", skill)
        self.assertIn("screenshot", skill.lower())
        self.assertNotIn("get_design_context", skill)
        self.assertNotIn("get_screenshot", skill)

    def test_designer_skill_requires_approval_before_delivery(self):
        skill = (SKILLS["compose-ui-designer"] / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("Designer", skill)
        self.assertIn("Critic", skill)
        self.assertIn("explicit user approval", skill)
        self.assertIn("$compose-ui-delivery", skill)
        self.assertLess(skill.index("explicit user approval"), skill.index("$compose-ui-delivery"))

    def test_delivery_skill_exposes_all_platform_adapters(self):
        delivery = SKILLS["compose-ui-delivery"]
        skill = (delivery / "SKILL.md").read_text(encoding="utf-8")
        for platform in ("mobile", "web", "desktop"):
            self.assertIn(platform, skill.lower())
            self.assertTrue((delivery / f"references/platforms/{platform}.md").is_file())
        self.assertTrue((delivery / "scripts/discover-project.ps1").is_file())
        self.assertTrue((delivery / "templates/compose-ui-delivery.yaml").is_file())


    def test_legacy_umbrella_skill_is_not_exposed(self):
        self.assertFalse((ROOT / "SKILL.md").exists())
        self.assertFalse((ROOT / "agents/openai.yaml").exists())

    def test_readme_documents_installation_and_direct_invocation(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for skill_name in SKILLS:
            self.assertIn(f"skills/{skill_name}", readme)
            self.assertIn(f"${skill_name}", readme)
        self.assertIn("$figma-implement-design", readme)
        for platform in ("mobile", "web", "desktop"):
            self.assertIn(platform, readme.lower())


    def test_legacy_resources_are_only_compatibility_pointers(self):
        shim_paths = (
            "scripts/discover-project.ps1",
            "scripts/build-and-launch.ps1",
            "scripts/capture-screen.ps1",
            "scripts/collect-ui-evidence.ps1",
            "scripts/compare-images.py",
            "scripts/test_compare_images.py",
        )
        for relative_path in shim_paths:
            content = (ROOT / relative_path).read_text(encoding="utf-8")
            self.assertIn("skills", content)
            self.assertIn("compose-ui-delivery", content)
            self.assertLess(len(content), 1600)

        deprecated_paths = (
            "references/reference-mode.md",
            "references/designer-mode.md",
            "references/compose-patterns.md",
            "references/visual-review.md",
            "references/rubrics/visual-parity.md",
            "references/rubrics/ux-quality.md",
            "references/rubrics/anti-ai-slop.md",
            "templates/compose-ui-agent.yaml",
            "templates/screen-spec.md",
            "templates/visual-review.json",
        )
        for relative_path in deprecated_paths:
            content = (ROOT / relative_path).read_text(encoding="utf-8")
            self.assertIn("deprecated", content.lower())


if __name__ == "__main__":
    unittest.main()
