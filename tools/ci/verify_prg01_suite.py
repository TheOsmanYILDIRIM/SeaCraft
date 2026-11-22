#!/usr/bin/env python3
import re
import sys
from pathlib import Path

EXPECTED = [
    "test_prg01_item_schema_and_stack_boundaries",
    "test_prg01_transfer_is_atomic_and_rolls_back",
    "test_prg01_equipment_crew_trainer_pet_and_rollback",
    "test_prg01_gem_socket_progression_and_atomic_cost",
    "test_prg01_modifier_pipeline_deterministic_and_duplicate_guard",
    "test_prg01_preset_safe_state_and_atomic_apply",
    "test_prg01_transaction_idempotency_conflict_and_restore",
    "test_prg01_host_ledger_and_protocol_authority",
    "test_prg01_loot_uses_inventory_state_as_single_quantity_truth",
    "test_prg01_touch_panel_emits_intents_without_mutating_authority",
]
MARKERS = [
    "PRG01_STACK_SCHEMA_OK",
    "PRG01_TRANSFER_ROLLBACK_OK",
    "PRG01_EQUIPMENT_SLOTS_OK",
    "PRG01_SOCKET_PROGRESSION_OK",
    "PRG01_MODIFIER_PIPELINE_OK",
    "PRG01_PRESET_ATOMIC_OK",
    "PRG01_TRANSACTION_IDEMPOTENCY_OK",
    "PRG01_PERSISTENCE_OK",
    "PRG01_LAN_AUTHORITY_OK",
    "PRG01_SINGLE_INVENTORY_TRUTH_OK",
    "PRG01_TOUCH_UI_OK",
]

def fail(message: str) -> None:
    print(f"PRG-01 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)

def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_prg01_suite.py <gut.log>")
    text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    if "res://tests/unit/test_prg01_progression.gd" not in text:
        fail("PRG-01 test script did not load")
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
    print("PRG01_VERIFIER_OK tests=10 atomic=1 persistence=1 lan_authority=1 touch=1")

if __name__ == "__main__":
    main()
