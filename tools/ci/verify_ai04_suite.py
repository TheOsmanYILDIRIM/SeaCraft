#!/usr/bin/env python3
import re
import sys
from pathlib import Path

SCRIPT = "res://tests/unit/test_ai04_world_lod.gd"
EXPECTED_TESTS = [
    "test_ai04_lod_transition_preserves_identity_semantic_state_and_fleet_membership",
    "test_ai04_lod_hysteresis_and_minimum_residency_prevent_threshold_thrash",
    "test_ai04_mid_scheduler_is_sparse_bounded_and_authority_disabled_is_read_only",
    "test_ai04_far_travel_uses_sector_graph_hazards_and_advances_world_jobs_without_physics",
    "test_ai04_far_combat_replay_is_byte_equal_rng_isolated_and_reuses_fleet_succession",
    "test_ai04_path_queue_is_bounded_coalesced_deterministic_and_starvation_free",
    "test_ai04_population_cap_spawn_ids_content_validation_and_retry_idempotency",
    "test_ai04_admiral_threshold_is_exact_idempotent_cooldown_bounded_and_persistent",
    "test_ai04_persistence_roundtrip_continuation_is_deterministic_and_restore_is_atomic",
    "test_ai04_100_entity_long_simulated_time_soak_respects_all_work_and_population_bounds",
]
MARKERS = [
    "AI04_LOD_TRANSITION_OK", "AI04_LOD_HYSTERESIS_OK", "AI04_MID_SCHEDULER_OK",
    "AI04_FAR_TRAVEL_OK", "AI04_FAR_COMBAT_REPLAY_OK", "AI04_PATH_BUDGET_OK",
    "AI04_POPULATION_CAP_OK", "AI04_ADMIRAL_COUNTER_OK", "AI04_PERSISTENCE_OK",
    "AI04_LONG_SOAK_OK",
]
FATAL = ["SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Ignoring script"]


def fail(message: str) -> None:
    print(f"AI04 verifier failure: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_ai04_suite.py <gut.log>")
    path = Path(sys.argv[1])
    if not path.is_file():
        fail(f"missing log: {path}")
    text = re.sub(r"\\x1b\\[[0-9;]*m", "", path.read_text(encoding="utf-8", errors="replace"))
    if SCRIPT not in text:
        fail(f"missing suite {SCRIPT}")
    for needle in FATAL:
        if needle in text:
            fail(f"fatal log token present: {needle}")
    if re.search(r"Failing Tests\s+[1-9]", text):
        fail("GUT reports failing tests")
    if re.search(r"([Oo]rphans?\s+[1-9][0-9]*|[1-9][0-9]*\s+[Oo]rphans?)", text):
        fail("GUT reports orphan nodes")
    for test in EXPECTED_TESTS:
        count = len(re.findall(r"^\s*\*\s+" + re.escape(test) + r"\s*$", text, re.M))
        if count != 1:
            fail(f"expected one execution for {test}, got {count}")
    for marker in MARKERS:
        if text.count(marker) != 1:
            fail(f"expected one execution marker {marker}, got {text.count(marker)}")
    metric = re.search(
        r"AI04_LONG_SOAK_OK\s+world_entities=(\d+)\s+near_count=(\d+)\s+mid_count=(\d+)\s+far_count=(\d+)\s+"
        r"max_near_decisions_per_tick=(\d+)\s+max_mid_updates_per_tick=(\d+)\s+max_far_updates_per_tick=(\d+)\s+"
        r"max_path_jobs_per_tick=(\d+)\s+max_spawn_jobs_per_tick=(\d+)\s+max_pending_jobs=(\d+)\s+"
        r"lod_transitions=(\d+)\s+far_encounters_resolved=(\d+)\s+spawn_accepted=(\d+)\s+spawn_rejected=(\d+)\s+"
        r"population_peak=(\d+)\s+starvation_count=(\d+)\s+simulated_ticks=(\d+)\s+duplicate_ids=(\d+)\s+id_loss=(\d+)\s+ledger_size=(\d+)",
        text,
    )
    if not metric:
        fail("100-entity long-soak diagnostic missing or malformed")
    values = list(map(int, metric.groups()))
    (world, near, mid, far, max_near, max_mid, max_far, max_path, max_spawn,
     max_pending, transitions, encounters, accepted, rejected, peak, starvation,
     ticks, duplicates, id_loss, ledger) = values
    if (world, near, mid, far) != (100, 20, 30, 50):
        fail(f"unexpected fixture distribution: {world}/{near}/{mid}/{far}")
    if max_near > 8 or max_mid > 6 or max_far > 8 or max_path > 4 or max_spawn > 4:
        fail("scheduler work budget exceeded")
    if max_pending > 512 or peak > 256 or starvation != 0:
        fail("bounded scheduler/population invariant failed")
    if ticks != 1440 or duplicates != 0 or id_loss != 0:
        fail("long simulated time identity invariant failed")
    if ledger > 1024:
        fail("ledger growth exceeded bound")
    print(
        f"AI04_VERIFIER_OK tests={len(EXPECTED_TESTS)} world_entities={world} "
        f"near={near} mid={mid} far={far} max_near={max_near} max_mid={max_mid} "
        f"max_far={max_far} max_path={max_path} max_spawn={max_spawn} starvation={starvation}"
    )


if __name__ == "__main__":
    main()
