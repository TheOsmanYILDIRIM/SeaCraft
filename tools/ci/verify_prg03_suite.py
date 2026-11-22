#!/usr/bin/env python3
import re
import sys
from pathlib import Path

EXPECTED = [
    "test_prg03_definition_schema_dag_cycle_missing_refs_and_thresholds",
    "test_prg03_xp_positive_boundaries_duplicate_conflict_and_overflow",
    "test_prg03_rank_multi_level_and_derived_one_time_points",
    "test_prg03_skill_spend_atomic_gate_points_duplicate_and_lost_ack",
    "test_prg03_respec_refund_and_modifier_removal_are_atomic",
    "test_prg03_gate_prerequisite_rank_and_completion_idempotency",
    "test_prg03_local_challenge_progress_reward_idempotency_and_version_reset",
    "test_prg03_persistence_v3_v2_migration_and_corrupt_rejection",
    "test_prg03_protocol_v6_host_authority_spoof_replay_and_malformed_guards",
    "test_prg03_touch_zoom_pan_intents_and_offline_contract",
]
MARKERS = [
    "PRG03_SKILL_DAG_OK",
    "PRG03_RANK_VALIDATION_OK",
    "PRG03_XP_LEDGER_OK",
    "PRG03_XP_OVERFLOW_OK",
    "PRG03_RANK_THRESHOLD_OK",
    "PRG03_POINT_GRANT_ONCE_OK",
    "PRG03_SKILL_TRANSACTION_OK",
    "PRG03_LOST_ACK_IDEMPOTENCY_OK",
    "PRG03_RESPEC_ATOMIC_OK",
    "PRG03_MODIFIER_PIPELINE_OK",
    "PRG03_GATE_API_OK",
    "PRG03_CHALLENGE_LOCAL_OK",
    "PRG03_CHALLENGE_VERSION_RESET_OK",
    "PRG03_PERSISTENCE_MIGRATION_OK",
    "PRG03_LAN_AUTHORITY_OK",
    "PRG03_CLIENT_OUTCOME_GUARD_OK",
    "PRG03_TOUCH_UI_OK",
    "PRG03_OFFLINE_META_OK",
]

def fail(message: str) -> None:
    print(f"PRG-03 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_prg03_suite.py <gut.log>")
    text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    if "res://tests/unit/test_prg03_progression.gd" not in text:
        fail("PRG-03 test script did not load")
    for token in ["SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Ignoring script"]:
        if token in text:
            fail(f"fatal token present: {token}")
    if re.search(r"Failing Tests\s+[1-9][0-9]*", text):
        fail("GUT reports failing tests")
    if re.search(r"([Oo]rphans?\s+[1-9][0-9]*|[1-9][0-9]*\s+[Oo]rphans?)", text):
        fail("GUT reports orphan nodes")
    for name in EXPECTED:
        if name not in text:
            fail(f"missing test execution: {name}")
    for marker in MARKERS:
        if marker not in text:
            fail(f"missing execution marker: {marker}")
    print("PRG03_VERIFIER_OK tests=10 xp=1 rank=1 skill_dag=1 spend_respec=1 gates=1 challenges=1 persistence=1 lan=1 touch=1 offline=1")

if __name__ == "__main__":
    main()
