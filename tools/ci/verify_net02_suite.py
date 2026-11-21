#!/usr/bin/env python3
import re
import sys
from pathlib import Path

SCRIPT = "res://tests/unit/test_net02_replication.gd"
EXPECTED_TESTS = [
    "test_net02_entity_registry_stable_id_generation_and_idempotency",
    "test_net02_spawn_dto_is_primitive_bounded_and_host_only",
    "test_net02_snapshot_order_rejects_stale_and_duplicate_sequences",
    "test_net02_interpolation_buffer_is_bounded_to_four_samples",
    "test_net02_aoi_visibility_uses_authoritative_sector_and_radius",
    "test_net02_combat_events_are_reliable_contract_and_idempotent",
    "test_net02_loot_events_are_idempotent_and_primitive_safe",
    "test_net02_client_outcome_mutations_have_no_authority_rpc",
    "test_net02_snapshot_payload_and_entity_budget_are_explicit",
    "test_net02_snapshot_rows_are_deterministic_and_object_free",
    "test_net02_offline_network_boundary_and_snapshot_channel_are_explicit",
]
GUT_MARKERS = [
    "NET02_ENTITY_REGISTRY_OK",
    "NET02_HOST_SPAWN_OK",
    "NET02_SNAPSHOT_ORDER_OK",
    "NET02_INTERPOLATION_OK",
    "NET02_AOI_OK",
    "NET02_COMBAT_EVENT_OK",
    "NET02_LOOT_EVENT_OK",
    "NET02_CLIENT_MUTATION_REJECT_OK",
    "NET02_BUDGET_OK",
]
PROCESS_MARKERS_ONCE = [
    "NET02_HOST_BASELINE_SPAWN_OK",
    "NET02_HOST_STATE_EVENTS_OK",
    "NET02_HOST_LATE_SPAWN_OK",
    "NET02_HOST_DESPAWN_OK",
    "NET02_HOST_MUTATION_UNCHANGED_OK",
    "NET02_HOST_METRICS",
    "NET02_HOST_CLEAN_EXIT_OK",
    "NET02_CLIENT_MUTATION_REJECT_OK label=A",
    "NET02_PROCESS_INTEGRATION_OK",
]
PROCESS_MARKERS_TWICE = [
    "NET02_CLIENT_BASELINE_OK",
    "NET02_CLIENT_SNAPSHOT_OK",
    "NET02_CLIENT_AOI_OK",
    "NET02_CLIENT_COMBAT_EVENT_OK",
    "NET02_CLIENT_LOOT_EVENT_OK",
    "NET02_CLIENT_LATE_SPAWN_OK",
    "NET02_CLIENT_DESPAWN_OK",
    "NET02_CLIENT_COMPLETE",
]
FATAL = ["SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Ignoring script", "NET02_PROCESS_FAILURE:"]
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def fail(message: str) -> None:
    print(f"NET-02 verifier failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def normalized(path: Path) -> str:
    if not path.is_file():
        fail(f"missing log: {path}")
    return ANSI.sub("", path.read_text(encoding="utf-8", errors="replace"))


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: verify_net02_suite.py <gut.log> <process.log>")
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
    for marker in PROCESS_MARKERS_ONCE:
        if process.count(marker) != 1:
            fail(f"expected one process marker {marker}, got {process.count(marker)}")
    for marker in PROCESS_MARKERS_TWICE:
        if process.count(marker) != 2:
            fail(f"expected two process markers {marker}, got {process.count(marker)}")
    if process.count("NET02_CLIENT_READY label=A player=player.alpha") != 1:
        fail("client A mapping missing")
    if process.count("NET02_CLIENT_READY label=B player=player.beta") != 1:
        fail("client B mapping missing")
    metric = re.search(
        r"NET02_HOST_METRICS peers=2 spawned=(\d+) despawned=(\d+) snapshots_sent=(\d+) "
        r"max_entities=(\d+) max_snapshot_bytes=(\d+) interval_ticks=(\d+) stale_ignored=(\d+) "
        r"interpolation_max_samples=(\d+) combat_events=(\d+) loot_events=(\d+) rejected_client_mutations=(\d+)",
        process,
    )
    if not metric:
        fail("host telemetry diagnostic missing")
    spawned, despawned, sent, max_entities, max_bytes, interval, stale, interpolation, combat, loot, mutations = map(int, metric.groups())
    if spawned < 8 or despawned != 1 or sent < 4 or max_entities != 64 or not (0 < max_bytes <= 8192):
        fail("spawn/snapshot budget metrics invalid")
    if interval != 3 or interpolation != 4 or combat < 1 or loot < 1 or mutations != 2 or stale != 0:
        fail("cadence/event/mutation metrics invalid")
    print(
        f"NET02_VERIFIER_OK tests={len(EXPECTED_TESTS)} real_process_rpc=1 host=1 clients=2 "
        f"spawned={spawned} snapshots_sent={sent} max_snapshot_bytes={max_bytes}"
    )


if __name__ == "__main__":
    main()
