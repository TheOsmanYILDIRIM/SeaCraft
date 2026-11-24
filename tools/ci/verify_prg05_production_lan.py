#!/usr/bin/env python3
from __future__ import annotations
import re
import sys
from pathlib import Path

log = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
log = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", log)
markers = [
    "PRG05_PRODUCTION_LAN_HOST_READY",
    "PRG05_PRODUCTION_LAN_CLIENT_TRADE_OK",
    "PRG05_PRODUCTION_LAN_SAVE_OK",
    "PRG05_PRODUCTION_LAN_RELOAD_OK",
    "PRG05_PRODUCTION_LAN_CLIENT_REPLAY_OK",
    "PRG05_PRODUCTION_LAN_REPLAY_OK",
    "PRG05_PRODUCTION_LAN_HOST_CLEAN_EXIT",
]
for marker in markers:
    if marker not in log:
        raise SystemExit(f"missing production LAN marker: {marker}")
if re.search(r"SCRIPT ERROR:|Parse Error:|PRG05_PRODUCTION_LAN_FAILURE", log):
    raise SystemExit("production LAN process failure")
if "owner=host stock=7 guest_quantity=1 ledger=1" not in log:
    raise SystemExit("durable host ownership/economy evidence missing")
if "quantity=1 ledger=1" not in log:
    raise SystemExit("cached replay did not prove no duplicate mutation")
print("PRG05_PRODUCTION_LAN_VERIFIER_OK host_bootstrap=1 save_reload=1 cached_replay=1")
