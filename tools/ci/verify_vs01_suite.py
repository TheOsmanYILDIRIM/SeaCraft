"""Require every VS-01 test to appear in the real GUT execution log."""
from pathlib import Path
import re
import sys

log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text())
paths = sorted(Path("tests/unit").glob("test_vs01_*.gd"))
if {p.name for p in paths} != {"test_vs01_combat.gd", "test_vs01_mobile_input.gd"}:
    sys.exit("VS-01 test script manifest does not match")
count = 0
for path in paths:
    tests = re.findall(r"^func (test_\w+)\(", path.read_text(), re.M)
    if not tests:
        sys.exit(f"No tests in {path}")
    for test in tests:
        if not re.search(r"^\s*\*\s+" + re.escape(test) + r"\s*$", log, re.M):
            sys.exit(f"GUT did not run {path.name}:{test}")
    count += len(tests)
totals = re.findall(r"^\s*Passing Tests\s+(\d+)\s*$", log, re.M)
if not totals or int(totals[-1]) != 99 + count:
    sys.exit(f"Expected {99 + count} passing tests, got {totals}")
print(f"Verified execution: 99 baseline + {count} VS-01 tests")
