"""Deprecated compatibility shim for compose-ui-delivery image tests."""

from pathlib import Path
import runpy


TARGET = (
    Path(__file__).resolve().parents[1]
    / "skills"
    / "compose-ui-delivery"
    / "scripts"
    / "test_compare_images.py"
)
runpy.run_path(str(TARGET), run_name="__main__")
