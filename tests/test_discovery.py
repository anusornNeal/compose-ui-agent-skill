import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/discover-project.ps1"


class DiscoveryTests(unittest.TestCase):
    def run_discovery(self, project_root):
        return subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(SCRIPT),
                "-ProjectRoot",
                str(project_root),
            ],
            capture_output=True,
            text=True,
        )

    def test_discovery_reports_android_project_signals(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            (project_root / "settings.gradle.kts").write_text(
                'include(":app")\n', encoding="utf-8"
            )
            manifest = project_root / "app/src/main/AndroidManifest.xml"
            manifest.parent.mkdir(parents=True)
            manifest.write_text(
                '<manifest package="com.example.app"><application /></manifest>',
                encoding="utf-8",
            )
            result = self.run_discovery(project_root)
            self.assertEqual(0, result.returncode, result.stderr)
            payload = json.loads(result.stdout)
            self.assertTrue(payload["signals"]["gradle_wrapper"])
            self.assertIn(":app", payload["modules"])
            self.assertIn("app/src/main/AndroidManifest.xml", payload["manifests"])

    def test_discovery_supports_groovy_settings_modules(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "settings.gradle").write_text(
                "include ':app', ':feature'\n", encoding="utf-8"
            )
            result = self.run_discovery(project_root)
            self.assertEqual(0, result.returncode, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual([":app", ":feature"], payload["modules"])
            self.assertTrue(payload["signals"]["app_module"])

    def test_evidence_collection_writes_metadata_after_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            scripts = root / "scripts"
            scripts.mkdir()
            (scripts / "collect-ui-evidence.ps1").write_text(
                (ROOT / "scripts/collect-ui-evidence.ps1").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            (scripts / "capture-screen.ps1").write_text(
                "param([string]$Serial, [string]$OutputPath, [switch]$Force)\n"
                "Set-Content -LiteralPath $OutputPath -Value 'captured'\n"
                "Write-Output $OutputPath\n",
                encoding="utf-8",
            )
            evidence = root / "evidence"
            result = subprocess.run(
                [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(scripts / "collect-ui-evidence.ps1"),
                    "-Serial",
                    "test-device",
                    "-OutputDirectory",
                    str(evidence),
                    "-State",
                    "default",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            metadata = json.loads((evidence / "default.json").read_text(encoding="utf-8-sig"))
            self.assertEqual("default", metadata["state"])
            self.assertTrue((evidence / "default.png").is_file())

    def test_dry_run_does_not_execute_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            config = project_root / "compose-ui-agent.yaml"
            (project_root / "settings.gradle.kts").write_text(
                'include(":app")\n', encoding="utf-8"
            )
            (project_root / "app/src/debug").mkdir(parents=True)
            manifest = project_root / "app/src/main/AndroidManifest.xml"
            manifest.parent.mkdir(parents=True)
            manifest.write_text(
                '<manifest package="com.example"><application><activity android:name=".MainActivity" /></application></manifest>',
                encoding="utf-8",
            )
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            config.write_text(
                "project:\n  root: .\n  module: app\n  variant: debug\nlaunch:\n  mode: activity\n  target: com.example/.MainActivity\n",
                encoding="utf-8",
            )
            script = ROOT / "scripts/build-and-launch.ps1"
            result = subprocess.run(
                [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                    "-ProjectRoot",
                    str(project_root),
                    "-ConfigPath",
                    str(config),
                    "-DryRun",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("DRY-RUN", result.stdout)

    def test_dry_run_supports_groovy_settings_and_adb_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "settings.gradle").write_text(
                "include ':app', ':feature'\n", encoding="utf-8"
            )
            (project_root / "app/src/main").mkdir(parents=True)
            (project_root / "app/src/main/AndroidManifest.xml").write_text(
                '<manifest><application><activity android:name=".MainActivity" /></application></manifest>',
                encoding="utf-8",
            )
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            config = project_root / "compose-ui-agent.yaml"
            config.write_text(
                "project:\n  root: .\n  module: app\n  variant: debug\n"
                "device_profiles:\n  primary:\n    serial: emulator-5554\n"
                "launch:\n  mode: activity\n  target: com.example/.MainActivity\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(ROOT / "scripts/build-and-launch.ps1"),
                    "-ProjectRoot",
                    str(project_root),
                    "-ConfigPath",
                    str(config),
                    "-DryRun",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("LAUNCH: adb -s emulator-5554 shell am start -n", result.stdout)
            self.assertNotIn("LAUNCH: adb adb", result.stdout)

    def test_build_parser_rejects_duplicate_unknown_and_unterminated_config(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "settings.gradle").write_text("include ':app'\n", encoding="utf-8")
            (project_root / "app/src/main/AndroidManifest.xml").parent.mkdir(parents=True)
            (project_root / "app/src/main/AndroidManifest.xml").write_text(
                '<manifest><application><activity android:name=".MainActivity" /></application></manifest>',
                encoding="utf-8",
            )
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            config = project_root / "compose-ui-agent.yaml"
            script = ROOT / "scripts/build-and-launch.ps1"
            base = "project:\n  root: .\n  module: app\n  variant: debug\nlaunch:\n  mode: activity\n  target: com.example/.MainActivity\n"
            for content, expected_error in (
                (base + "project:\n  module: other\n", "Duplicate config key"),
                (base + "unsupported: true\n", "Unsupported config key"),
                (base.replace("mode: activity", "mode: deeplink") + '  deeplink: "example://home\n', "Unterminated quoted config scalar"),
            ):
                config.write_text(content, encoding="utf-8")
                result = subprocess.run(
                    [
                        "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                        "-ProjectRoot", str(project_root), "-ConfigPath", str(config), "-DryRun",
                    ],
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(0, result.returncode)
                self.assertIn(expected_error, result.stderr)

            schema_base = base + (
                "device_profiles:\n  primary:\n    density: 2.625\n"
                "capture:\n  record_logcat: true\n"
                "acceptance:\n  visual_parity_min: 4\n  ux_quality_min: 4\n  max_iterations: 5\n"
            )
            for content, expected_error in (
                (schema_base.replace("density: 2.625", 'density: "dense"'), "positive number: device_profiles.primary.density"),
                (schema_base.replace("record_logcat: true", 'record_logcat: "yes"'), "must be boolean: capture.record_logcat"),
                (schema_base.replace("visual_parity_min: 4", "visual_parity_min: 6"), "integer between 1 and 5: acceptance.visual_parity_min"),
                (schema_base.replace("max_iterations: 5", "max_iterations: 9"), "integer between 1 and 5: acceptance.max_iterations"),
            ):
                config.write_text(content, encoding="utf-8")
                result = subprocess.run(
                    [
                        "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
                        "-ProjectRoot", str(project_root), "-ConfigPath", str(config), "-DryRun",
                    ],
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(0, result.returncode)
                self.assertIn(expected_error, result.stderr)


if __name__ == "__main__":
    unittest.main()
