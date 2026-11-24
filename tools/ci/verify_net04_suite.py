#!/usr/bin/env python3
from __future__ import annotations
import re
import sys
from pathlib import Path

gut = Path(sys.argv[1]).read_text(errors="replace")
process = Path(sys.argv[2]).read_text(errors="replace")
ansi = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
gut = ansi.sub("", gut)
process = ansi.sub("", process)

tests = [
    "test_net04_discovery_protocol_encode_decode_and_exact_shape",
    "test_net04_discovery_fuzz_fixed_seed_2000_packets",
    "test_net04_discovery_ttl_dedupe_and_rate_budget",
    "test_net04_reconnect_token_handshake_contract",
    "test_net04_reconnect_sequence_and_rotation_contract",
    "test_net04_late_join_baseline_exact_current_truth",
    "test_net04_baseline_reconciles_prehandshake_mirror_same_sequence",
    "test_net04_transaction_idempotency_and_conflict",
    "test_net04_transaction_persistence_round_trip",
    "test_net04_permission_fallback_and_runtime_api",
    "test_net04_offline_boot_and_manual_ipv4_remain_default",
    "test_net04_static_security_and_network_boundary",
    "test_net04_protocol_mismatch_stays_deterministic_after_version_bump",
]
markers = [
    "NET04_DISCOVERY_PROTOCOL_OK",
    "NET04_DISCOVERY_FUZZ_OK",
    "NET04_DISCOVERY_TTL_OK",
    "NET04_RECONNECT_TOKEN_OK",
    "NET04_RECONNECT_SEQUENCE_OK",
    "NET04_LATE_JOIN_BASELINE_OK",
    "NET04_BASELINE_RECONCILE_OK",
    "NET04_TRANSACTION_IDEMPOTENCY_OK",
    "NET04_TRANSACTION_PERSISTENCE_OK",
    "NET04_PERMISSION_FALLBACK_OK",
    "NET04_OFFLINE_BOOT_OK",
    "NET04_PROTOCOL_MISMATCH_OK",
]
for name in tests:
    if name not in gut:
        raise SystemExit(f"missing NET04 GUT test: {name}")
for marker in markers:
    if marker not in gut:
        raise SystemExit(f"missing NET04 marker: {marker}")
if "count=2000 seed=20261122" not in gut:
    raise SystemExit("NET04 fuzz evidence missing")
for marker in [
    "NET04_A_DISCOVERED",
    "NET04_A_ACK_LOSS_DISCONNECT",
    "NET04_HOST_RESUME_READY",
    "NET04_LATE_JOIN_PROCESS_OK",
    "NET04_TRANSACTION_IDEMPOTENCY_OK",
    "NET04_RECONNECT_PROCESS_OK",
    "NET04_DISCOVERY_PROCESS_OK",
    "NET04_PROCESS_INTEGRATION_OK",
    "NET04_HOST_LEDGER_OK",
    "NET04_HOST_CLEAN_EXIT",
    "PRG05_LAN_ECONOMY_PROCESS_OK",
    "PRG05_LAN_MARKET_RECONNECT_OK",
    "PRG05_LAN_MARKET_REMOTE_REJECT_OK",
]:
    if marker not in process:
        raise SystemExit(f"missing NET04 process marker: {marker}")
if re.search(r"SCRIPT ERROR:|Parse Error:|NET04_PROCESS_FAILURE", gut + process):
    raise SystemExit("NET04 parse/process failure")
print("NET04_VERIFIER_OK unit=13 fuzz=2000 discovery_process=1 reconnect=1 late_join=1 lost_ack=1")
