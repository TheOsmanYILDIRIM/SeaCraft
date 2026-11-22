#!/usr/bin/env python3
import re
import sys
from pathlib import Path

EXPECTED = [
    "test_prg04_definition_schema_refs_cycles_regions_and_registry_type",
    "test_prg04_prerequisite_gate_rank_and_npc_authority",
    "test_prg04_all_objective_semantics",
    "test_prg04_event_duplicate_conflict_wrong_filters_and_party_policy",
    "test_prg04_completion_atomic_reward_retry_and_rollback",
    "test_prg04_timed_failure_save_load_v4_migration_and_corrupt_rejection",
    "test_prg04_protocol_v7_host_authority_spoof_replay_malformed_and_client_outcome_guard",
    "test_prg04_detached_journal_mirror_reconnect_and_late_join_contract",
    "test_prg04_touch_journal_accept_turnin_track_timer_and_detached_state",
]
MARKERS = [
    "PRG04_SCHEMA_OK", "PRG04_REFERENCE_VALIDATION_OK", "PRG04_CHAIN_CYCLE_OK", "PRG04_REGION_VALIDATION_OK",
    "PRG04_PREREQUISITE_GATE_RANK_OK", "PRG04_NPC_INTERACTION_AUTHORITY_OK",
    "PRG04_OBJECTIVE_KILL_OK", "PRG04_OBJECTIVE_DAMAGE_OK", "PRG04_OBJECTIVE_CAPTURE_OK", "PRG04_OBJECTIVE_COLLECT_OK",
    "PRG04_OBJECTIVE_ACQUIRE_OK", "PRG04_OBJECTIVE_TIMED_OK", "PRG04_OBJECTIVE_ESCORT_OK", "PRG04_OBJECTIVE_SALVAGE_OK", "PRG04_OBJECTIVE_TRADE_OK",
    "PRG04_EVENT_IDEMPOTENCY_OK", "PRG04_EVENT_CONFLICT_OK", "PRG04_EVENT_FILTERS_OK", "PRG04_PARTY_POLICY_OK",
    "PRG04_COMPLETION_TRANSITION_OK", "PRG04_REWARD_ATOMIC_OK", "PRG04_REWARD_ROLLBACK_OK", "PRG04_REWARD_LOST_ACK_OK",
    "PRG04_PERSISTENCE_V4_OK", "PRG04_MIGRATION_V3_OK", "PRG04_CORRUPT_REJECTION_OK", "PRG04_TIMED_RELOAD_OK",
    "PRG04_LAN_HOST_AUTHORITY_OK", "PRG04_LAN_SPOOF_REPLAY_MALFORMED_OK", "PRG04_CLIENT_OUTCOME_GUARD_OK",
    "PRG04_JOURNAL_DTO_OK", "PRG04_RECONNECT_SNAPSHOT_OK", "PRG04_LATE_JOIN_SNAPSHOT_OK",
    "PRG04_TOUCH_UI_OK", "PRG04_TRACKING_UI_OK", "PRG04_DETACHED_UI_OK", "PRG04_OFFLINE_FIRST_OK",
]

def fail(message: str) -> None:
    print(f"PRG-04 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_prg04_suite.py <gut.log>")
    text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    if "res://tests/unit/test_prg04_quest.gd" not in text:
        fail("PRG-04 test script did not load")
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
    print(f"PRG04_VERIFIER_OK tests={len(EXPECTED)} markers={len(MARKERS)} objectives=9 atomic_reward=1 persistence=1 lan=1 journal=1 touch=1")

if __name__ == "__main__":
    main()
