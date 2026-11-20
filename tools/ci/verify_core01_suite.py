"""Prove CORE-01 tests executed in the actual full GUT run."""
from pathlib import Path
import sys
import re

log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text())
suite = Path("tests/unit/test_core01_combat.gd")
tests = re.findall(r"^func (test_core01_\w+)\(", suite.read_text(), re.M)
if len(tests) != 6 or suite.name not in log:
    sys.exit("CORE-01 suite absent or incomplete")
for test in tests:
    if len(re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", log, re.M)) != 1:
        sys.exit(f"CORE-01 test did not execute exactly once: {test}")
for marker in ("CORE01_FORMULA_MATRIX_EXECUTED", "CORE01_ATOMICITY_EXECUTED"):
    if marker not in log:
        sys.exit(f"Missing {marker}")
summary = re.findall(r"^\s*Tests\s+(\d+)\s*$", log, re.M)
if not summary or int(summary[-1]) < 220 + len(tests):
    sys.exit(f"Existing 220 tests plus CORE-01 did not execute: {summary}")
print(f"Verified execution of {len(tests)} CORE-01 tests; {summary[-1]} total tests")
