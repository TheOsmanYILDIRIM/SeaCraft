#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 ]] || { echo "usage: $0 <combined-log>" >&2; exit 2; }
combined="$1"
port="${NET03_TEST_PORT:-24683}"
[[ "$port" =~ ^[0-9]{4,5}$ ]] && (( port >= 1024 && port <= 65535 ))
work="$(mktemp -d "${RUNNER_TEMP:-/tmp}/seacraft-net03.XXXXXX")"
host_pid=
client_pid=

cleanup() {
  local rc=$?
  trap - EXIT
  for pid in "$client_pid" "$host_pid"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  if (( rc != 0 )); then
    for log in "$work"/*.log; do
      if [[ -f "$log" ]]; then echo "--- $log" >&2; cat "$log" >&2; fi
    done
  fi
  rm -rf "$work"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

wait_marker() {
  local pid="$1" log="$2" marker="$3"
  for _ in {1..240}; do
    if grep -Fq "$marker" "$log"; then return 0; fi
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.05
  done
  echo "missing NET-03 readiness/exit marker: $marker" >&2
  return 1
}

: > "$combined"
for scenario in full disconnect; do
  sockets="$(ss -lunH)"
  if awk '{print $5}' <<<"$sockets" | grep -E "(^|:)${port}$" >/dev/null; then
    echo "NET-03 UDP port collision: $port" >&2
    exit 1
  fi
  host_log="$work/$scenario-host.log"
  client_log="$work/$scenario-client.log"
  stop="$work/$scenario.stop"
  timeout --kill-after=2s 55s godot --headless --path . res://tools/net03/process_harness.tscn -- \
    --role=host --case="$scenario" --port="$port" --stop="$stop" >"$host_log" 2>&1 &
  host_pid=$!
  wait_marker "$host_pid" "$host_log" "NET03_HOST_READY case=$scenario"
  timeout --kill-after=2s 45s godot --headless --path . res://tools/net03/process_harness.tscn -- \
    --role=client --case="$scenario" --port="$port" >"$client_log" 2>&1 &
  client_pid=$!
  wait_marker "$client_pid" "$client_log" "NET03_CLIENT_READY case=$scenario player=entity.player"
  wait "$client_pid"
  client_pid=
  if [[ "$scenario" == disconnect ]]; then
    wait_marker "$host_pid" "$host_log" NET03_DISCONNECT_COMBAT_OK
    grep -Fq NET03_CLIENT_DISCONNECT_EXIT "$client_log"
  fi
  touch "$stop"
  wait "$host_pid"
  host_pid=
  grep -Fq "NET03_HOST_CLEAN_EXIT case=$scenario" "$host_log"
  cat "$host_log" "$client_log" >> "$combined"
done
echo "NET03_PROCESS_INTEGRATION_OK host=1 clients=1 cases=2" | tee -a "$combined"
