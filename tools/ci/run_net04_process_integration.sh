#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-${RUNNER_TEMP:-/tmp}/net04-process.log}"
GAME_PORT="${NET04_GAME_PORT:-24684}"
DISCOVERY_PORT="${NET04_DISCOVERY_PORT:-24685}"
WORK="$(mktemp -d "${RUNNER_TEMP:-/tmp}/net04.XXXXXX")"
HOST_LOG="$WORK/host.log"
A_LOG="$WORK/a.log"
B_LOG="$WORK/b.log"
HOST_PID=""
A_PID=""

cleanup() {
  local rc=$?
  trap - EXIT
  for pid in "$A_PID" "$HOST_PID"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  if (( rc != 0 )); then
    for log in "$B_LOG" "$A_LOG" "$HOST_LOG"; do
      if [[ -f "$log" ]]; then
        echo "--- $log" >&2
        cat "$log" >&2
      fi
    done
  fi
  exit "$rc"
}
trap cleanup EXIT

godot --headless --path . res://tools/net04/process_harness.tscn -- --role=host --game-port="$GAME_PORT" --discovery-port="$DISCOVERY_PORT" --work="$WORK" >"$HOST_LOG" 2>&1 &
HOST_PID=$!

for _ in {1..120}; do
  grep -Fq "NET04_HOST_READY" "$HOST_LOG" 2>/dev/null && break
  kill -0 "$HOST_PID" 2>/dev/null || { cat "$HOST_LOG"; exit 1; }
  sleep 0.1
done
grep -Fq "NET04_HOST_READY" "$HOST_LOG" || { cat "$HOST_LOG"; exit 1; }

godot --headless --path . res://tools/net04/process_harness.tscn -- --role=a --game-port="$GAME_PORT" --discovery-port="$DISCOVERY_PORT" --work="$WORK" >"$A_LOG" 2>&1 &
A_PID=$!

for _ in {1..160}; do
  [[ -f "$WORK/a_disconnected" ]] && break
  kill -0 "$A_PID" 2>/dev/null || { cat "$A_LOG"; cat "$HOST_LOG"; exit 1; }
  sleep 0.1
done
[[ -f "$WORK/a_disconnected" ]] || { cat "$A_LOG"; cat "$HOST_LOG"; exit 1; }

if ! godot --headless --path . res://tools/net04/process_harness.tscn -- --role=b --game-port="$GAME_PORT" --discovery-port="$DISCOVERY_PORT" --work="$WORK" >"$B_LOG" 2>&1; then
  cat "$B_LOG" "$A_LOG" "$HOST_LOG"
  exit 1
fi
grep -Fq "NET04_LATE_JOIN_PROCESS_OK" "$B_LOG" || { cat "$B_LOG"; cat "$A_LOG"; cat "$HOST_LOG"; exit 1; }

wait "$A_PID"
A_PID=""
wait "$HOST_PID"
HOST_PID=""

cat "$HOST_LOG" "$A_LOG" "$B_LOG" | tee "$OUT"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|NET04_PROCESS_FAILURE' "$OUT"; then
  exit 1
fi
for marker in   NET04_A_DISCOVERED   NET04_A_ACK_LOSS_DISCONNECT   NET04_HOST_RESUME_READY   NET04_LATE_JOIN_PROCESS_OK   NET04_TRANSACTION_IDEMPOTENCY_OK   NET04_RECONNECT_PROCESS_OK   NET04_DISCOVERY_PROCESS_OK   NET04_PROCESS_INTEGRATION_OK   NET04_HOST_LEDGER_OK   NET04_HOST_CLEAN_EXIT; do
  grep -Fq "$marker" "$OUT"
done
