"""Render the dark room with the same layout as the original comparison."""
import importlib.util
import sys
from pathlib import Path

sys.dont_write_bytecode = True
BATCH = Path(__file__).resolve().parent
ROOT = BATCH.parents[2]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

if __name__ == "__main__":
    dark = load("dark_style", BATCH / "build_dark_assets.py")
    assembly = load("room_assembly", ROOT / "assets/source/task3d_rooms_2026-11-14/assemble_review_room.py")
    assembly.BATCH = BATCH
    assembly.MODELS = ROOT / "assets/models/midgard/rooms_dark"
    assembly.main(dark.dark_studio)
