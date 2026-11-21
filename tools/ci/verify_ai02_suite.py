#!/usr/bin/env python3
import re
import sys
from pathlib import Path

EXPECTED_TESTS = [
    "test_ai02_tactical_context_is_detached_primitive_safe_and_bounded",
    "test_ai02_expected_dps_uses_core_rules_without_rng_or_transaction_mutation",
    "test_ai02_scenario_matrix_too_far_bad_broadside_ready_and_blocked",
    "test_ai02_range_band_hysteresis_and_port_starboard_are_deterministic",
    "test_ai02_ammo_economy_scarcity_weakness_resistance_zero_stock_and_tie_break",
    "test_ai02_retreat_prefers_safer_escape_and_repair_waits_for_disengage",
    "test_ai02_line_of_fire_friendly_blocker_prevents_fire_without_mutation",
    "test_ai02_boarding_utility_rejects_bad_advantage_and_authority_executes_good_board",
    "test_ai02_support_is_semantic_cooldown_without_reinforcement_side_effect",
    "test_ai02_npcbrain_persists_tactical_hold_side_support_and_resumes",
    "test_ai02_scheduler_budget_20_npc_bounded_no_starvation_or_double_bt_tick",
]
MARKERS = [
    "AI02_TACTICAL_CONTEXT_OK",
    "AI02_EXPECTED_DPS_OK",
    "AI02_RANGE_BROADSIDE_OK",
    "AI02_AMMO_ECONOMY_OK",
    "AI02_RETREAT_REPAIR_OK",
    "AI02_LINE_OF_FIRE_OK",
    "AI02_BOARDING_OK",
    "AI02_SUPPORT_INTENT_OK",
    "AI02_PERSISTENCE_OK",
    "AI02_SCHEDULER_BUDGET_OK",
]
FATAL = ["SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Ignoring script"]


def fail(message: str) -> None:
    print(f"AI-02 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_ai02_suite.py <gut.log>")
    path = Path(sys.argv[1])
    if not path.is_file():
        fail(f"missing log: {path}")
    text = path.read_text(encoding="utf-8", errors="replace")
    for token in FATAL:
        if token in text:
            fail(f"fatal GUT token present: {token}")
    if re.search(r"Failing Tests\s+[1-9][0-9]*", text):
        fail("GUT reports failing tests")
    if re.search(r"(?:[Oo]rphans?\s+[1-9][0-9]*|[1-9][0-9]*\s+[Oo]rphans?)", text):
        fail("GUT reports orphan nodes")
    for test in EXPECTED_TESTS:
        matches = re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", text, re.M)
        if len(matches) != 1:
            fail(f"expected one execution for {test}, got {len(matches)}")
    for marker in MARKERS:
        if text.count(marker) != 1:
            fail(f"expected one execution marker {marker}, got {text.count(marker)}")
    metric = re.search(
        r"AI02_SCHEDULER_BUDGET_OK\s+npc_count=(\d+)\s+total_decisions=(\d+)\s+"
        r"max_decisions_per_tick=(\d+)\s+total_tactical_evaluations=(\d+)\s+"
        r"max_target_candidates=(\d+)\s+max_ammo_candidates=(\d+)\s+"
        r"max_escape_candidates=(\d+)\s+max_line_of_fire_inspected=(\d+)\s+"
        r"fire_transactions=(\d+)\s+boarding_attempts=(\d+)\s+support_intents=(\d+)\s+"
        r"bt_failures=(\d+)\s+bt_timeouts=(\d+)",
        text,
    )
    if not metric:
        fail("20-NPC tactical scheduler diagnostic missing or malformed")
    (
        npc_count,
        total_decisions,
        max_per_tick,
        tactical_evaluations,
        max_targets,
        max_ammo,
        max_escape,
        max_line,
        _fire,
        _board,
        _support,
        bt_failures,
        bt_timeouts,
    ) = map(int, metric.groups())
    if npc_count != 20 or total_decisions != 480:
        fail(f"unexpected scheduler work: npc={npc_count}, decisions={total_decisions}")
    if max_per_tick > 2:
        fail(f"scheduler budget exceeded: {max_per_tick}")
    if tactical_evaluations <= 0:
        fail("tactical scorer did not execute")
    if max_targets > 4 or max_ammo > 8 or max_escape > 4 or max_line > 24:
        fail(
            f"bounded scoring exceeded: targets={max_targets} ammo={max_ammo} "
            f"escape={max_escape} line={max_line}"
        )
    if bt_failures != 0 or bt_timeouts != 0:
        fail(f"Beehave failures/timeouts present: {bt_failures}/{bt_timeouts}")
    print(
        "AI02_VERIFIER_OK "
        f"tests={len(EXPECTED_TESTS)} npc={npc_count} decisions={total_decisions} "
        f"max_per_tick={max_per_tick} tactical={tactical_evaluations}"
    )


if __name__ == "__main__":
    main()
