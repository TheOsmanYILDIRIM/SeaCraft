"""Require the real VS-04 suite and its integration/checkpoint/soak markers."""
from pathlib import Path
import re
import sys

log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text())
paths = sorted(Path("tests/unit").glob("test_vs04_*.gd"))
if {p.name for p in paths} != {"test_vs04_vertical_slice.gd"}:
    sys.exit("VS-04 test script manifest does not match")
count = 0
for path in paths:
    tests = re.findall(r"^func (test_\w+)\(", path.read_text(), re.M)
    if len(tests) != 25:
        sys.exit(f"VS-04 requires exactly 25 tests, found {len(tests)}")
    for test in tests:
        matches = re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", log, re.M)
        if len(matches) != 1:
            sys.exit(f"Expected one GUT execution for {path.name}:{test}, got {len(matches)}")
    count += len(tests)

for marker in ("VS04_SCENARIO_COMPLETE", "VS04_CHECKPOINT_REPLAY_OK", "VS04_SOAK_OK"):
    if marker not in log:
        sys.exit(f"Missing VS-04 execution marker: {marker}")

print(f"Verified execution of {count} VS-04 tests with integration/checkpoint/soak markers")
