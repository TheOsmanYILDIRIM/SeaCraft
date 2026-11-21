#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: run_net02_process_integration.sh <combined-log>" >&2
  exit 2
fi

combined="$1"
port="${NET02_TEST_PORT:-24681}"
work="${RUNNER_TEMP:-/tmp}/seacraft-net02-process-$$"
mkdir -p "$work"
host_log="$work/host.log"
client_a_log="$work/client-a.log"
client_b_log="$work/client-b.log"
stop_file="$work/host.stop"
host_pid=""
client_a_pid=""
client_b_pid=""

cleanup() {
  touch "$stop_file" 2>/dev/null || true
  for pid in "$client_a_pid" "$client_b_pid" "$host_pid"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT INT TERM

: > "$combined"
if ss -lunH | awk '{print $5}' | grep -Eq "(^|:)${port}$"; then
  echo "NET02 port collision: $port" >&2
  exit 1
fi

godot --headless --path . res://tools/net02/process_harness.tscn --   --mode=host --port="$port" --stop-file="$stop_file" >"$host_log" 2>&1 &
host_pid=$!

wait_marker() {
  local file="$1"
  local marker="$2"
  local label="$3"
  for _ in {1..240}; do
    if grep -Fq "$marker" "$file"; then
      return 0
    fi
    if [[ "$label" == "host" ]] && ! kill -0 "$host_pid" 2>/dev/null; then
      cat "$host_log" >&2 || true
      return 1
    fi
    sleep 0.05
  done
  echo "NET02 readiness timeout: $marker" >&2
  cat "$file" >&2 || true
  return 1
}

wait_marker "$host_log" "NET02_HOST_READY" host

godot --headless --path . res://tools/net02/process_harness.tscn --   --mode=client --label=A --port="$port" >"$client_a_log" 2>&1 &
client_a_pid=$!
wait_marker "$client_a_log" "NET02_CLIENT_READY label=A player=player.alpha" client-a

godot --headless --path . res://tools/net02/process_harness.tscn --   --mode=client --label=B --port="$port" >"$client_b_log" 2>&1 &
client_b_pid=$!
wait_marker "$client_b_log" "NET02_CLIENT_READY label=B player=player.beta" client-b

wait_process() {
  local pid="$1"
  local file="$2"
  local label="$3"
  for _ in {1..600}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      if wait "$pid"; then
        return 0
      fi
      echo "NET02 process failed: $label" >&2
      cat "$file" >&2 || true
      cat "$host_log" >&2 || true
      return 1
    fi
    sleep 0.05
  done
  echo "NET02 process timeout: $label" >&2
  cat "$file" >&2 || true
  cat "$host_log" >&2 || true
  return 1
}

wait_process "$client_a_pid" "$client_a_log" client-a
client_a_pid=""
wait_process "$client_b_pid" "$client_b_log" client-b
client_b_pid=""

touch "$stop_file"
for _ in {1..240}; do
  if ! kill -0 "$host_pid" 2>/dev/null; then
    if wait "$host_pid"; then
      host_pid=""
      break
    fi
    cat "$host_log" >&2 || true
    exit 1
  fi
  sleep 0.05
done
if [[ -n "$host_pid" ]]; then
  echo "NET02 host clean shutdown timeout" >&2
  cat "$host_log" >&2 || true
  exit 1
fi

cat "$client_a_log" "$client_b_log" "$host_log" > "$combined"

for marker in   NET02_HOST_BASELINE_SPAWN_OK   NET02_HOST_STATE_EVENTS_OK   NET02_HOST_LATE_SPAWN_OK   NET02_HOST_DESPAWN_OK   NET02_HOST_MUTATION_UNCHANGED_OK   NET02_HOST_METRICS   NET02_HOST_CLEAN_EXIT_OK   "NET02_CLIENT_READY label=A"   "NET02_CLIENT_READY label=B"   "NET02_CLIENT_MUTATION_REJECT_OK label=A"; do
  [[ "$(grep -Fc "$marker" "$combined")" == "1" ]]
done

for marker in   NET02_CLIENT_BASELINE_OK   NET02_CLIENT_SNAPSHOT_OK   NET02_CLIENT_AOI_OK   NET02_CLIENT_COMBAT_EVENT_OK   NET02_CLIENT_LOOT_EVENT_OK   NET02_CLIENT_LATE_SPAWN_OK   NET02_CLIENT_DESPAWN_OK   NET02_CLIENT_METRICS   NET02_CLIENT_COMPLETE; do
  [[ "$(grep -Fc "$marker" "$combined")" == "2" ]]
done

echo "NET02_PROCESS_INTEGRATION_OK host=1 clients=2" | tee -a "$combined"
trap - EXIT INT TERM
