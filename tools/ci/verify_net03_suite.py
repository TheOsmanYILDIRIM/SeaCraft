#!/usr/bin/env python3
"""Join offline baseline, authoritative host and presentation-client evidence."""
import hashlib
import json
import re
import sys
from pathlib import Path

from verify_net02_suite import ANSI, FATAL

TESTS = (
    "select_contract", "fire_contract", "pickup_contract", "outcomes_are_not_intents",
    "fresh_sequence_is_not_a_fresh_drop", "npc_semantic_shape_and_budget",
    "semantics_are_npc_only", "proxy_does_not_replay_stale_ai_state", "offline_semantic_baseline",
)
MARKERS = (
    "REMOTE_MOVE_OK", "REMOTE_TARGET_OK", "REMOTE_FIRE_OK", "HOST_AI_ONLY_OK",
    "AI_PARITY_OK", "COMBAT_REPLICATION_OK", "LOOT_CLAIM_ONCE_OK", "AUTHORITY_REJECTION_OK",
    "DISCONNECT_COMBAT_OK", "PROCESS_INTEGRATION_OK", "CLIENT_DISCONNECT_EXIT",
)


def require(condition, reason):
    if not condition:
        raise SystemExit(f"NET-03 verification failed: {reason}")


def digest(log, marker):
    rows = re.findall(r"^\s*" + marker + r" (\{[^\n]+\})\s*$", log, re.M)
    require(len(rows) == 1, f"expected exactly one {marker}")
    return json.loads(rows[0])


def main():
    require(len(sys.argv) == 3, "usage: verify_net03_suite.py <gut.log> <process.log>")
    gut, processes = (ANSI.sub("", Path(p).read_text(encoding="utf-8")) for p in sys.argv[1:])
    for token in (*FATAL, "NET03_PROCESS_FAILURE", "ObjectDB instances leaked"):
        require(token not in processes and token not in gut, token)
    require(not re.search(r"(?:[Oo]rphans?\s+[1-9][0-9]*|[1-9][0-9]*\s+[Oo]rphans?)", gut), "GUT orphans")
    for suffix in TESTS:
        require(len(re.findall(r"^\s*\*\s+test_net03_" + suffix + r"\s*$", gut, re.M)) == 1, suffix)
    for marker in MARKERS:
        require(processes.count("NET03_" + marker) == 1, marker)
    for case in ("full", "disconnect"):
        for marker in ("HOST_READY", "CLIENT_READY", "HOST_CLEAN_EXIT"):
            require(processes.count(f"NET03_{marker} case={case}") == 1, f"{marker} {case}")
    for marker in ("VS04_SCENARIO_COMPLETE", "VS04_CHECKPOINT_REPLAY_OK", "VS04_SOAK_OK"):
        require(marker in gut, f"missing {marker}")

    offline = digest(gut, "NET03_OFFLINE_DIGEST")
    host = digest(processes, "NET03_HOST_DIGEST")
    client = digest(processes, "NET03_CLIENT_DIGEST")
    require(host == client == offline, f"semantic digest disagreement: {host!r} / {client!r} / {offline!r}")
    require(host["sunk"] == host["drops"] == host["claims"] == 1, "once-only outcome")
    require(host["hull"] == 0 and host["reward"] > 0 and host["fires"] >= 3, "combat/reward proof")
    require(host["transitions"] == [0, 1, 2, 3, 4], "AI chain")
    signature = hashlib.sha256(json.dumps(host, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    print(f"NET03_OFFLINE_PARITY_OK scenario=vs04 semantic_sha256={signature}")
    print(f"NET03_VERIFIER_OK tests={len(TESTS)} host=1 clients=1 cases=2 semantic_sha256={signature}")


if __name__ == "__main__":
    main()
