#!/usr/bin/env python3
import re
import sys
from pathlib import Path

SCRIPT = "res://tests/unit/test_ai01_framework.gd"
EXPECTED_TESTS = [
    "test_ai01_sense_pipeline_uses_spatial_hash_cap_filters_and_stable_order",
    "test_ai01_memory_multitarget_decay_expiry_bounded_and_roundtrip",
    "test_ai01_role_utility_differs_for_trader_escort_raider_and_rejects_nonfinite",
    "test_ai01_hysteresis_prevents_close_target_thrash_switches_when_clear_and_persists",
    "test_ai01_real_beehave_bt_lifecycle_success_failure_timeout_interrupt_and_reentry",
    "test_ai01_custom_fsm_trace_and_vs02_patrol_alert_retreat_repair_resume_regression",
    "test_ai01_scheduler_budget_20_npc_no_starvation_stagger_or_double_bt_tick",
    "test_ai01_persistence_preserves_role_memory_target_hysteresis_fsm_route_bt_and_scheduler",
    "test_ai01_authority_disabled_is_read_only_and_presenter_consumes_detached_snapshot",
    "test_ai01_content_registry_and_runtime_beehave_export_contract",
]
MARKERS = [
    "AI01_SENSE_PIPELINE_OK",
    "AI01_MEMORY_DECAY_OK",
    "AI01_ROLE_UTILITY_OK",
    "AI01_HYSTERESIS_OK",
    "AI01_BT_LIFECYCLE_OK",
    "AI01_FSM_REGRESSION_OK",
    "AI01_SCHEDULER_BUDGET_OK",
    "AI01_PERSISTENCE_OK",
]
FATAL = ["SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Ignoring script"]

def fail(message: str) -> None:
    print(f"AI-01 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_ai01_suite.py <gut.log>")
    text = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace"))
    if SCRIPT not in text:
        fail("AI-01 test script did not load")
    for token in FATAL:
        if token in text:
            fail(f"fatal GUT token present: {token}")
    if re.search(r"Failing Tests\s+[1-9][0-9]*", text):
        fail("GUT reports failing tests")
    if re.search(r"Orphans\s+[1-9][0-9]*", text):
        fail("GUT reports orphan nodes")
    for test in EXPECTED_TESTS:
        matches = re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", text, re.M)
        if len(matches) != 1:
            fail(f"expected one execution for {test}, got {len(matches)}")
    for marker in MARKERS:
        if marker not in text:
            fail(f"missing execution marker: {marker}")
    metric = re.search(
        r"AI01_SCHEDULER_BUDGET_OK\s+npc_count=(\d+)\s+total_decision_ticks=(\d+)\s+"
        r"max_decisions_in_tick=(\d+)\s+total_perception_candidates=(\d+)\s+"
        r"max_inspected_candidates=(\d+)\s+bt_failures=(\d+)\s+bt_timeouts=(\d+)",
        text,
    )
    if not metric:
        fail("20-NPC scheduler diagnostic missing or malformed")
    npc_count, total_ticks, max_per_tick, _, max_inspected, _, timeouts = map(int, metric.groups())
    if npc_count != 20 or total_ticks < 20 or max_per_tick > 3 or max_per_tick <= 0:
        fail("scheduler boundedness/starvation metrics invalid")
    if max_inspected >= 120 or timeouts != 0:
        fail("scheduler/perception fixture exceeded bounds or timed out")
    print(
        f"AI-01 verifier passed: tests={len(EXPECTED_TESTS)} npc_count={npc_count} "
        f"total_decision_ticks={total_ticks} max_decisions_in_tick={max_per_tick} "
        f"max_inspected_candidates={max_inspected}"
    )

if __name__ == "__main__":
    main()
