#!/usr/bin/env python3
import re
import sys
from pathlib import Path

SCRIPT = "res://tests/unit/test_net01_session.gd"
EXPECTED_TESTS = [
    "test_net01_protocol_stamp_channel_policy_and_ipv4_contract",
    "test_net01_handshake_exact_shape_matches_canonical_sources",
    "test_net01_protocol_mismatch_is_deterministic",
    "test_net01_content_and_schema_mismatches_are_deterministic",
    "test_net01_envelope_allowlist_and_payload_bounds_reject_malformed_values",
    "test_net01_peer_mapping_slot_selection_is_stable_and_host_owned",
    "test_net01_valid_move_uses_existing_gameplay_command_and_ship_motor_authority",
    "test_net01_spoof_identity_fields_are_rejected_recursively",
    "test_net01_sequence_replay_negative_fraction_and_bounds_are_rejected",
    "test_net01_offline_boot_and_network_boundary_remain_explicit",
]
GUT_MARKERS = [
    "NET01_PROTOCOL_CONTRACT_OK",
    "NET01_HANDSHAKE_OK",
    "NET01_PROTOCOL_MISMATCH_OK",
    "NET01_CONTENT_MISMATCH_OK",
    "NET01_PEER_MAPPING_OK",
    "NET01_INTENT_AUTHORITY_OK",
    "NET01_SPOOF_REJECTION_OK",
    "NET01_REPLAY_REJECTION_OK",
    "NET01_OFFLINE_BOOT_OK",
]
PROCESS_MARKERS = [
    "NET01_PROCESS_HANDSHAKE_OK",
    "NET01_PROCESS_PEER_MAPPING_OK",
    "NET01_PROCESS_INTENT_AUTHORITY_OK",
    "NET01_PROCESS_REPLAY_OK",
    "NET01_PROCESS_SPOOF_OK",
    "NET01_PROCESS_MALFORMED_OK",
    "NET01_PROCESS_PROTOCOL_MISMATCH_OK",
    "NET01_PROCESS_CONTENT_MISMATCH_OK",
    "NET01_PROCESS_PREHANDSHAKE_OK",
    "NET01_HOST_AUTHORITY_APPLIED",
    "NET01_HOST_CLEAN_EXIT_OK",
    "NET01_PROCESS_INTEGRATION_OK",
]
FATAL = ["SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Ignoring script"]
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def fail(message: str) -> None:
    print(f"NET-01 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def normalized(path: Path) -> str:
    if not path.is_file():
        fail(f"missing log: {path}")
    return ANSI.sub("", path.read_text(encoding="utf-8", errors="replace"))


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: verify_net01_suite.py <gut.log> <process.log>")
    gut = normalized(Path(sys.argv[1]))
    process = normalized(Path(sys.argv[2]))
    if SCRIPT not in gut:
        fail(f"missing suite {SCRIPT}")
    for token in FATAL:
        if token in gut or token in process:
            fail(f"fatal log token present: {token}")
    if re.search(r"Failing Tests\s+[1-9][0-9]*", gut):
        fail("GUT reports failing tests")
    if re.search(r"(?:[Oo]rphans?\s+[1-9][0-9]*|[1-9][0-9]*\s+[Oo]rphans?)", gut):
        fail("GUT reports orphan nodes")
    for test in EXPECTED_TESTS:
        count = len(re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", gut, re.M))
        if count != 1:
            fail(f"expected one execution for {test}, got {count}")
    for marker in GUT_MARKERS:
        if gut.count(marker) != 1:
            fail(f"expected one GUT marker {marker}, got {gut.count(marker)}")
    for marker in PROCESS_MARKERS:
        if process.count(marker) != 1:
            fail(f"expected one process marker {marker}, got {process.count(marker)}")
    match = re.search(r"NET01_HOST_AUTHORITY_APPLIED peer=(\d+) player=([^ ]+) sequence=(\d+) target=\(([-0-9.]+),([-0-9.]+)\) beta_has_target=(true|false)", process)
    if not match:
        fail("host authority diagnostic missing or malformed")
    if match.group(2) != "player.alpha" or int(match.group(3)) != 0 or match.group(6) != "false":
        fail("host mapping/authority isolation diagnostic invalid")
    if abs(float(match.group(4)) - 321.0) > 0.001 or abs(float(match.group(5)) + 45.0) > 0.001:
        fail("authoritative move target diagnostic invalid")
    print(f"NET01_VERIFIER_OK tests={len(EXPECTED_TESTS)} real_process_rpc=1 host_authority=1")


if __name__ == "__main__":
    main()
