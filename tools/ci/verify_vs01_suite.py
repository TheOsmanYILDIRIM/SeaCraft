"""Require every unit test, including the unchanged VS-01 suite, to execute exactly once."""
from pathlib import Path
import re
import sys

log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text())
vs01 = sorted(Path("tests/unit").glob("test_vs01_*.gd"))
if {p.name for p in vs01} != {"test_vs01_combat.gd", "test_vs01_mobile_input.gd"}:
    sys.exit("VS-01 test script manifest does not match")

all_paths = sorted(Path("tests/unit").glob("test_*.gd"))
expected = 0
for path in all_paths:
    tests = re.findall(r"^func (test_\w+)\(", path.read_text(), re.M)
    if not tests:
        sys.exit(f"No tests in {path}")
    expected += len(tests)
    if path in vs01:
        for test in tests:
            if not re.search(r"^\s*\*\s+" + re.escape(test) + r"\s*$", log, re.M):
                sys.exit(f"GUT did not run {path.name}:{test}")

totals = re.findall(r"^\s*Passing Tests\s+(\d+)\s*$", log, re.M)
if not totals or int(totals[-1]) != expected:
    sys.exit(f"Expected exactly {expected} passing unit tests, got {totals}")
print(f"Verified unchanged VS-01 tests and exact {expected}-test unit manifest")
