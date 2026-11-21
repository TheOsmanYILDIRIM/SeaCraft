#!/usr/bin/env python3
import re
import sys
from pathlib import Path

EXPECTED_TESTS = [
    "test_core04_migration_chain_is_sequential_and_deterministic",
    "test_core04_registry_manifest_and_unknown_content_policy",
    "test_core04_content_hash_mismatch_is_transactional",
    "test_core04_entity_index_is_bounded_sorted_and_multi_sector",
    "test_core04_npc_route_cooldown_and_scheduler_resume",
    "test_core04_recovery_fault_matrix_and_dirty_retry",
    "test_core04_malformed_corpus_is_controlled_and_transactional",
    "test_core04_large_entity_roundtrip_is_bounded_and_deterministic",
    "test_core04_world_ledgers_survive_roundtrip_without_duplicate_claims",
    "test_core04_host_world_and_client_settings_are_separated",
]
MARKERS = [
    "CORE04_MIGRATION_CHAIN_OK",
    "CORE04_CONTENT_REGISTRY_OK",
    "CORE04_CONTENT_HASH_MISMATCH_OK",
    "CORE04_ENTITY_INDEX_OK",
    "CORE04_NPC_RESUME_OK",
    "CORE04_RECOVERY_OK",
    "CORE04_MALFORMED_CORPUS_OK",
    "CORE04_LARGE_ROUNDTRIP_OK",
]
FATAL = [
    "SCRIPT ERROR:",
    "Parse Error:",
    "Failed to load script",
    "Ignoring script",
]


def fail(message: str) -> None:
    print(f"CORE-04 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_core04_suite.py <gut.log>")
    text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    if "res://tests/unit/test_core04_persistence.gd" not in text:
        fail("CORE-04 test script did not load")
    for token in FATAL:
        if token in text:
            fail(f"fatal GUT token present: {token}")
    if re.search(r"Failing Tests\s+[1-9][0-9]*", text):
        fail("GUT reports failing tests")
    if re.search(r"Orphans\s+[1-9][0-9]*", text):
        fail("GUT reports orphan nodes")
    for test in EXPECTED_TESTS:
        if test not in text:
            fail(f"missing test execution: {test}")
    for marker in MARKERS:
        if marker not in text:
            fail(f"missing execution marker: {marker}")
    large = re.search(
        r"CORE04_LARGE_ROUNDTRIP_OK\s+entity_count=(\d+)\s+encoded_bytes=(\d+)\s+save_ms=([0-9.]+)\s+load_restore_ms=([0-9.]+)",
        text,
    )
    if not large:
        fail("large round-trip diagnostic is malformed or missing")
    entity_count, encoded_bytes = int(large.group(1)), int(large.group(2))
    if entity_count < 512 or encoded_bytes <= 0:
        fail("large round-trip diagnostic does not meet bounded fixture requirement")
    section_start = text.find("res://tests/unit/test_core04_persistence.gd")
    section_end = text.find("res://tests/unit/", section_start + 1)
    section = text[section_start:] if section_end < 0 else text[section_start:section_end]
    passed = re.search(r"(\d+)\/(\d+) passed", section)
    if passed and (int(passed.group(1)) != 10 or int(passed.group(2)) != 10):
        fail(f"CORE-04 suite count is not 10/10: {passed.group(0)}")
    print(
        f"CORE-04 verifier passed: 10 tests, entity_count={entity_count}, encoded_bytes={encoded_bytes}"
    )


if __name__ == "__main__":
    main()
