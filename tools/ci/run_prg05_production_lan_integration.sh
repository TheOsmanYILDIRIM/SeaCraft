#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-${RUNNER_TEMP:-/tmp}/prg05-production-lan.log}"
GAME_PORT="${PRG05_PRODUCTION_GAME_PORT:-24705}"
DISCOVERY_PORT="${PRG05_PRODUCTION_DISCOVERY_PORT:-24706}"
WORK="$(mktemp -d "${RUNNER_TEMP:-/tmp}/prg05-prod-lan.XXXXXX")"
HOST_LOG="$WORK/host.log"
CLIENT_LOG="$WORK/client.log"
HOST_PID=""

cleanup() {
  local rc=$?
  trap - EXIT
  if [[ -n "$HOST_PID" ]] && kill -0 "$HOST_PID" 2>/dev/null; then
    kill "$HOST_PID" 2>/dev/null || true
    wait "$HOST_PID" 2>/dev/null || true
  fi
  if (( rc != 0 )); then
    for log in "$CLIENT_LOG" "$HOST_LOG"; do
      [[ -f "$log" ]] && { echo "--- $log" >&2; cat "$log" >&2; }
    done
  fi
  exit "$rc"
}
trap cleanup EXIT

godot --headless --path . res://tools/prg05_production_lan/process_harness.tscn -- \
  --role=host --game-port="$GAME_PORT" --discovery-port="$DISCOVERY_PORT" --work="$WORK" >"$HOST_LOG" 2>&1 &
HOST_PID=$!

for _ in {1..160}; do
  grep -Fq "PRG05_PRODUCTION_LAN_HOST_READY" "$HOST_LOG" 2>/dev/null && break
  kill -0 "$HOST_PID" 2>/dev/null || { cat "$HOST_LOG"; exit 1; }
  sleep 0.1
done
grep -Fq "PRG05_PRODUCTION_LAN_HOST_READY" "$HOST_LOG" || { cat "$HOST_LOG"; exit 1; }

if ! godot --headless --path . res://tools/prg05_production_lan/process_harness.tscn -- \
  --role=client --game-port="$GAME_PORT" --discovery-port="$DISCOVERY_PORT" --work="$WORK" >"$CLIENT_LOG" 2>&1; then
  cat "$CLIENT_LOG" "$HOST_LOG"
  exit 1
fi

wait "$HOST_PID"
HOST_PID=""

cat "$HOST_LOG" "$CLIENT_LOG" | tee "$OUT"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|PRG05_PRODUCTION_LAN_FAILURE' "$OUT"; then
  exit 1
fi
for marker in \
  PRG05_PRODUCTION_LAN_HOST_READY \
  PRG05_PRODUCTION_LAN_CLIENT_TRADE_OK \
  PRG05_PRODUCTION_LAN_SAVE_OK \
  PRG05_PRODUCTION_LAN_RELOAD_OK \
  PRG05_PRODUCTION_LAN_CLIENT_REPLAY_OK \
  PRG05_PRODUCTION_LAN_REPLAY_OK \
  PRG05_PRODUCTION_LAN_HOST_CLEAN_EXIT; do
  grep -Fq "$marker" "$OUT"
done
