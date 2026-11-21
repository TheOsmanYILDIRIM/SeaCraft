#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: run_net01_process_integration.sh <combined-log>" >&2
  exit 2
fi

combined="$1"
port="${NET01_TEST_PORT:-24680}"
work="${RUNNER_TEMP:-/tmp}/seacraft-net01-process-$$"
mkdir -p "$work"
host_log="$work/host.log"
stop_file="$work/host.stop"
host_pid=""

cleanup() {
  touch "$stop_file" 2>/dev/null || true
  if [[ -n "$host_pid" ]] && kill -0 "$host_pid" 2>/dev/null; then
    kill "$host_pid" 2>/dev/null || true
    wait "$host_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

: > "$combined"
if ss -ltnH | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
  echo "NET01 port collision: $port" >&2
  exit 1
fi

godot --headless --path . --script res://tools/net01/process_harness.gd -- \
  --mode=host --port="$port" --stop-file="$stop_file" >"$host_log" 2>&1 &
host_pid=$!

ready=0
for _ in {1..200}; do
  if grep -Fq "NET01_HOST_READY" "$host_log"; then
    ready=1
    break
  fi
  if ! kill -0 "$host_pid" 2>/dev/null; then
    cat "$host_log" >&2
    exit 1
  fi
  sleep 0.05
done
if [[ "$ready" != "1" ]]; then
  cat "$host_log" >&2
  echo "NET01 host readiness timeout" >&2
  exit 1
fi

run_client() {
  local scenario="$1"
  local log="$work/client-${scenario}.log"
  timeout 20s godot --headless --path . --script res://tools/net01/process_harness.gd -- \
    --mode=client --scenario="$scenario" --port="$port" >"$log" 2>&1
  cat "$log" >> "$combined"
}

run_client success_security
run_client protocol_mismatch
run_client content_mismatch
run_client prehandshake

touch "$stop_file"
clean=0
for _ in {1..200}; do
  if ! kill -0 "$host_pid" 2>/dev/null; then
    clean=1
    break
  fi
  sleep 0.05
done
if [[ "$clean" != "1" ]]; then
  echo "NET01 host clean shutdown timeout" >&2
  exit 1
fi
wait "$host_pid"
host_pid=""
cat "$host_log" >> "$combined"

for marker in \
  NET01_PROCESS_HANDSHAKE_OK \
  NET01_PROCESS_PEER_MAPPING_OK \
  NET01_PROCESS_INTENT_AUTHORITY_OK \
  NET01_PROCESS_REPLAY_OK \
  NET01_PROCESS_SPOOF_OK \
  NET01_PROCESS_MALFORMED_OK \
  NET01_PROCESS_PROTOCOL_MISMATCH_OK \
  NET01_PROCESS_CONTENT_MISMATCH_OK \
  NET01_PROCESS_PREHANDSHAKE_OK \
  NET01_HOST_AUTHORITY_APPLIED \
  NET01_HOST_CLEAN_EXIT_OK; do
  [[ "$(grep -Fc "$marker" "$combined")" == "1" ]]
done

echo "NET01_PROCESS_INTEGRATION_OK" | tee -a "$combined"
trap - EXIT INT TERM
