"""Prove CORE-03 tests and required scenario markers executed in the full GUT run."""
from pathlib import Path
import re
import sys

log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text())
suite = Path("tests/unit/test_core03_sector_map.gd")
tests = re.findall(r"^func (test_core03_\w+)\(", suite.read_text(), re.M)
if len(tests) != 10 or suite.name not in log:
    sys.exit(f"CORE-03 suite absent or incomplete: {len(tests)}")
for test in tests:
    if len(re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", log, re.M)) != 1:
        sys.exit(f"CORE-03 test did not execute exactly once: {test}")
for marker in (
    "CORE03_TRANSITION_RULES_OK",
    "CORE03_STALE_RUNTIME_OK",
    "CORE03_MULTI_SECTOR_PERSISTENCE_OK",
    "CORE03_SAFE_ZONE_MATRIX_OK",
    "CORE03_HAZARD_ROUTE_OK",
    "CORE03_MAP_TRANSFORM_OK",
):
    if marker not in log:
        sys.exit(f"Missing {marker}")
summary = re.findall(r"^\s*Tests\s+(\d+)\s*$", log, re.M)
if not summary or int(summary[-1]) < 244:
    sys.exit(f"Existing 234 tests plus CORE-03 did not execute: {summary}")
print(f"Verified execution of {len(tests)} CORE-03 tests; {summary[-1]} total tests")
