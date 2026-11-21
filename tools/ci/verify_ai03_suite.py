#!/usr/bin/env python3
import re
import sys
from pathlib import Path

SCRIPT = "res://tests/unit/test_ai03_fleet_world.gd"
EXPECTED_TESTS = [
    "test_ai03_formation_slots_deterministic_insertion_independent_and_hysteretic",
    "test_ai03_convoy_ambush_break_preserves_local_tactical_ai_then_regroups",
    "test_ai03_leader_loss_selects_deterministic_successor_and_preserves_fleet_job",
    "test_ai03_dock_queue_fifo_stable_tie_break_capacity_and_cleanup",
    "test_ai03_faction_relation_transition_drives_perception_without_hardcoded_factions",
    "test_ai03_safe_zone_target_cuts_pursuit_clears_memory_and_returns_to_regroup",
    "test_ai03_world_jobs_cargo_trade_salvage_patrol_and_economy_hook_are_typed",
    "test_ai03_support_intent_dispatch_is_existing_member_bounded_and_loop_guarded",
    "test_ai03_fleet_persistence_roundtrip_ambush_and_restore_succession",
    "test_ai03_24_ship_fixture_respects_formation_path_and_queue_budgets",
]
MARKERS = [
    "AI03_FORMATION_SLOTS_OK", "AI03_CONVOY_AMBUSH_OK", "AI03_LEADER_SUCCESSION_OK",
    "AI03_DOCK_QUEUE_OK", "AI03_FACTION_RELATION_OK", "AI03_SAFE_ZONE_PURSUIT_OK",
    "AI03_WORLD_JOBS_OK", "AI03_SUPPORT_RESPONSE_OK", "AI03_PERSISTENCE_OK",
    "AI03_FLEET_BUDGET_OK",
]
FATAL = ["SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Ignoring script"]

def fail(message: str) -> None:
    print(f"AI-03 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_ai03_suite.py <gut.log>")
    path = Path(sys.argv[1])
    if not path.is_file():
        fail(f"missing log: {path}")
    text = re.sub(r"\x1b\[[0-9;]*m", "", path.read_text(encoding="utf-8", errors="replace"))
    if SCRIPT not in text:
        fail("AI-03 test script did not load")
    for token in FATAL:
        if token in text:
            fail(f"fatal GUT token present: {token}")
    if re.search(r"Failing Tests\s+[1-9][0-9]*", text):
        fail("GUT reports failing tests")
    if re.search(r"(?:[Oo]rphans?\s+[1-9][0-9]*|[1-9][0-9]*\s+[Oo]rphans?)", text):
        fail("GUT reports orphan nodes")
    for test in EXPECTED_TESTS:
        count = len(re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", text, re.M))
        if count != 1:
            fail(f"expected one execution for {test}, got {count}")
    for marker in MARKERS:
        if text.count(marker) != 1:
            fail(f"expected one execution marker {marker}, got {text.count(marker)}")
    metric = re.search(
        r"AI03_FLEET_BUDGET_OK\s+fleet_count=(\d+)\s+ship_count=(\d+)\s+"
        r"formation_updates=(\d+)\s+max_formation_updates_per_tick=(\d+)\s+"
        r"path_requests=(\d+)\s+max_path_jobs_per_tick=(\d+)\s+dock_queue_max=(\d+)\s+"
        r"succession_count=(\d+)\s+break_reform_count=(\d+)\s+support_dispatch_count=(\d+)\s+"
        r"bt_failures=(\d+)\s+bt_timeouts=(\d+)", text)
    if not metric:
        fail("24-ship fleet budget diagnostic missing or malformed")
    fleets, ships, updates, max_updates, paths, max_paths, dock_max, successions, break_reform, support, bt_failures, bt_timeouts = map(int, metric.groups())
    if fleets != 6 or ships != 24:
        fail(f"unexpected fixture size: fleets={fleets} ships={ships}")
    if updates <= 0 or paths <= 0:
        fail("formation/path work did not execute")
    if max_updates > 8 or max_paths > 4:
        fail(f"budget exceeded: formation={max_updates} path={max_paths}")
    if dock_max > 32 or successions < 1 or break_reform < 2 or support < 1:
        fail("required bounded scenario metrics did not execute")
    if bt_failures != 0 or bt_timeouts != 0:
        fail(f"BT failures/timeouts present: {bt_failures}/{bt_timeouts}")
    print(f"AI03_VERIFIER_OK tests={len(EXPECTED_TESTS)} fleets={fleets} ships={ships} max_formation={max_updates} max_path={max_paths}")

if __name__ == "__main__":
    main()
