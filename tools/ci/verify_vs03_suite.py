"""Require every VS-03 test script/function to appear exactly once in the real GUT log."""
from pathlib import Path
import re
import sys

log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text())
paths = sorted(Path("tests/unit").glob("test_vs03_*.gd"))
if {p.name for p in paths} != {"test_vs03_loot.gd"}:
    sys.exit("VS-03 test script manifest does not match")
count = 0
for path in paths:
    tests = re.findall(r"^func (test_\w+)\(", path.read_text(), re.M)
    if len(tests) < 18:
        sys.exit(f"VS-03 requires at least 18 tests, found {len(tests)}")
    for test in tests:
        matches = re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", log, re.M)
        if len(matches) != 1:
            sys.exit(f"Expected one GUT execution for {path.name}:{test}, got {len(matches)}")
    count += len(tests)
print(f"Verified execution of {count} VS-03 tests")
