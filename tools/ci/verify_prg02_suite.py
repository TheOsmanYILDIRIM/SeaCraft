#!/usr/bin/env python3
import re
import sys
from pathlib import Path

EXPECTED = [
    "test_prg02_definition_registry_schema_and_missing_refs",
    "test_prg02_craft_success_bounds_and_missing_input",
    "test_prg02_craft_capacity_rollback_duplicate_conflict_and_lost_ack",
    "test_prg02_salvage_determinism_rng_persistence_and_rollback",
    "test_prg02_upgrade_dag_cycle_missing_prereq_and_atomic_unlock",
    "test_prg02_core_compatibility_replace_modifier_guard_and_remove_rollback",
    "test_prg02_trophy_event_ledger_idempotent_reward",
    "test_prg02_progression_save_restore_legacy_migration_and_corrupt_rejection",
    "test_prg02_protocol_host_authority_spoof_replay_and_malformed_guards",
    "test_prg02_touch_panel_emits_bounded_intents_only",
]
MARKERS = [
    "PRG02_RECIPE_REGISTRY_OK",
    "PRG02_CRAFT_ATOMIC_OK",
    "PRG02_CRAFT_BOUNDARY_OK",
    "PRG02_CRAFT_ROLLBACK_OK",
    "PRG02_LOST_ACK_IDEMPOTENCY_OK",
    "PRG02_SALVAGE_DETERMINISM_OK",
    "PRG02_SALVAGE_RNG_PERSISTENCE_OK",
    "PRG02_SALVAGE_ROLLBACK_OK",
    "PRG02_UPGRADE_DAG_OK",
    "PRG02_UPGRADE_ATOMIC_OK",
    "PRG02_CORE_COMPATIBILITY_OK",
    "PRG02_MODIFIER_GUARD_OK",
    "PRG02_CORE_ROLLBACK_OK",
    "PRG02_TROPHY_LEDGER_OK",
    "PRG02_PERSISTENCE_MIGRATION_OK",
    "PRG02_LAN_AUTHORITY_OK",
    "PRG02_TOUCH_UI_OK",
]

def fail(message: str) -> None:
    print(f"PRG-02 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_prg02_suite.py <gut.log>")
    text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    if "res://tests/unit/test_prg02_progression.gd" not in text:
        fail("PRG-02 test script did not load")
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
    print("PRG02_VERIFIER_OK tests=10 craft_atomic=1 salvage_rng=1 upgrade_dag=1 cores=1 trophies=1 persistence=1 lan=1 touch=1")

if __name__ == "__main__":
    main()
