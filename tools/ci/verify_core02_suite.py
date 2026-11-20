"""Prove CORE-02 tests executed in the actual full GUT run."""
from pathlib import Path
import re
import sys

log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text())
suite = Path("tests/unit/test_core02_combat_world.gd")
tests = re.findall(r"^func (test_core02_\w+)\(", suite.read_text(), re.M)
if len(tests) != 8 or suite.name not in log:
    sys.exit("CORE-02 suite absent or incomplete")
for test in tests:
    if len(re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", log, re.M)) != 1:
        sys.exit(f"CORE-02 test did not execute exactly once: {test}")
for marker in (
    "CORE02_TARGET_TAG_MATRIX_OK",
    "CORE02_HARPOON_DAMAGE_OK",
    "CORE02_DUPLICATE_SPAWN_CLAIM_OK",
    "CORE02_WORLD_PERSISTENCE_OK",
):
    if marker not in log:
        sys.exit(f"Missing {marker}")
summary = re.findall(r"^\s*Tests\s+(\d+)\s*$", log, re.M)
if not summary or int(summary[-1]) < 234:
    sys.exit(f"Existing 226 tests plus CORE-02 did not execute: {summary}")
print(f"Verified execution of {len(tests)} CORE-02 tests; {summary[-1]} total tests")
