import json
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SKILL_ROOT = ROOT / "skills/compose-ui-delivery"
DISCOVERY = SKILL_ROOT / "scripts/discover-project.ps1"
BUILD_AND_LAUNCH = SKILL_ROOT / "scripts/build-and-launch.ps1"


class DiscoveryTests(unittest.TestCase):
    def run_ps(self, script, *args):
        return subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script),
                *map(str, args),
            ],
            capture_output=True,
            text=True,
        )

    def run_discovery(self, project_root):
        return self.run_ps(DISCOVERY, "-ProjectRoot", project_root)

    def test_discovery_preserves_android_signals(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            (project_root / "settings.gradle.kts").write_text('include(":app")\n', encoding="utf-8")
            manifest = project_root / "app/src/main/AndroidManifest.xml"
            manifest.parent.mkdir(parents=True)
            manifest.write_text('<manifest package="com.example.app"><application /></manifest>', encoding="utf-8")
            (project_root / "app/src/main/kotlin").mkdir(parents=True)
            result = self.run_discovery(project_root)
            self.assertEqual(0, result.returncode, result.stderr)
            payload = json.loads(result.stdout)
            self.assertTrue(payload["signals"]["gradle_wrapper"])
            self.assertIn(":app", payload["modules"])
            self.assertIn("app/src/main/AndroidManifest.xml", payload["manifests"])
            self.assertIn("mobile", payload["platforms"])

    def test_discovery_reports_compose_multiplatform_source_sets(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            (project_root / "settings.gradle.kts").write_text('include(":composeApp")\n', encoding="utf-8")
            build = project_root / "composeApp/build.gradle.kts"
            build.parent.mkdir(parents=True)
            build.write_text('plugins { id("org.jetbrains.compose") }\nkotlin { wasmJs { browser() } }\n', encoding="utf-8")
            for source_set in ("commonMain", "androidMain", "iosMain", "desktopMain", "wasmJsMain", "jsMain"):
                (project_root / f"composeApp/src/{source_set}/kotlin").mkdir(parents=True)
            result = self.run_discovery(project_root)
            self.assertEqual(0, result.returncode, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(
                ["androidMain", "commonMain", "desktopMain", "iosMain", "jsMain", "wasmJsMain"],
                payload["source_sets"],
            )
            self.assertEqual(["desktop", "mobile", "web"], payload["platforms"])
            self.assertTrue(payload["compose_signals"]["jetbrains_compose_plugin"])

    def test_android_dry_run_keeps_gradle_install_and_adb_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "settings.gradle.kts").write_text('include(":app")\n', encoding="utf-8")
            (project_root / "app/src/main").mkdir(parents=True)
            (project_root / "app/src/main/AndroidManifest.xml").write_text(
                '<manifest><application><activity android:name=".MainActivity" /></application></manifest>',
                encoding="utf-8",
            )
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            config = project_root / "compose-ui-delivery.yaml"
            config.write_text(
                "platform:\n  kind: mobile\n  target: android\n"
                "project:\n  root: .\n  module: app\n  variant: debug\n"
                "device_profiles:\n  primary:\n    serial: emulator-5554\n"
                "launch:\n  mode: activity\n  target: com.example/.MainActivity\n",
                encoding="utf-8",
            )
            result = self.run_ps(
                BUILD_AND_LAUNCH,
                "-ProjectRoot", project_root,
                "-ConfigPath", config,
                "-DryRun",
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("ASSEMBLE:", result.stdout)
            self.assertIn("INSTALL:", result.stdout)
            self.assertIn("LAUNCH: adb -s emulator-5554", result.stdout)
            self.assertIn("DRY-RUN", result.stdout)

    def test_web_and_desktop_dry_runs_emit_safe_gradle_tasks(self):
        cases = (
            ("web", "browser", ":composeApp:wasmJsBrowserDevelopmentRun", "http://localhost:8080"),
            ("desktop", "jvm", ":desktopApp:run", "Compose App"),
        )
        for kind, target, task, launch_value in cases:
            with self.subTest(platform=kind), tempfile.TemporaryDirectory() as directory:
                project_root = pathlib.Path(directory)
                module = "composeApp" if kind == "web" else "desktopApp"
                (project_root / "settings.gradle.kts").write_text(f'include(":{module}")\n', encoding="utf-8")
                (project_root / module).mkdir()
                (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
                config = project_root / "compose-ui-delivery.yaml"
                extra = f"  url: {launch_value}\n" if kind == "web" else f"  window_title: {launch_value}\n"
                config.write_text(
                    f"platform:\n  kind: {kind}\n  target: {target}\n"
                    f"project:\n  root: .\n  module: {module}\n"
                    f"launch:\n  task: {task}\n{extra}",
                    encoding="utf-8",
                )
                result = self.run_ps(
                    BUILD_AND_LAUNCH,
                    "-ProjectRoot", project_root,
                    "-ConfigPath", config,
                    "-DryRun",
                )
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn(f"RUN: {project_root / 'gradlew.bat'} {task}", result.stdout)
                self.assertIn("DRY-RUN", result.stdout)

    def test_generic_gradle_task_rejects_shell_operators(self):
        with tempfile.TemporaryDirectory() as directory:
            project_root = pathlib.Path(directory)
            (project_root / "settings.gradle.kts").write_text('include(":desktopApp")\n', encoding="utf-8")
            (project_root / "desktopApp").mkdir()
            (project_root / "gradlew.bat").write_text("@echo off\n", encoding="utf-8")
            config = project_root / "compose-ui-delivery.yaml"
            config.write_text(
                "platform:\n  kind: desktop\n  target: jvm\n"
                "project:\n  root: .\n  module: desktopApp\n"
                "launch:\n  task: :desktopApp:run;Remove-Item\n  window_title: Compose App\n",
                encoding="utf-8",
            )
            result = self.run_ps(
                BUILD_AND_LAUNCH,
                "-ProjectRoot", project_root,
                "-ConfigPath", config,
                "-DryRun",
            )
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Unsupported Gradle task", result.stderr)


if __name__ == "__main__":
    unittest.main()
