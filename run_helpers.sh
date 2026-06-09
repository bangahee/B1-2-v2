#!/bin/bash

start_monitor() {
  local log_file="$1"
  mkdir -p logs
  : > "$log_file"
  MONITOR_LOG="$log_file" AGENT_PORT="${AGENT_PORT:-15034}" ./monitor.sh &
  MONITOR_PID=$!
  echo "$MONITOR_PID" > /tmp/b12_monitor.pid
  echo "Started monitor PID=$MONITOR_PID, log=$log_file"
}

stop_monitor() {
  if [ -f /tmp/b12_monitor.pid ]; then
    kill "$(cat /tmp/b12_monitor.pid)" 2>/dev/null || true
    rm -f /tmp/b12_monitor.pid
  fi
  pkill -f monitor.sh 2>/dev/null || true
  echo "Stopped monitor"
}

cleanup_app() {
  pkill -f agent-app-leak 2>/dev/null || true
  sleep 2
}

set_common_env() {
  export AGENT_HOME=/app
  export AGENT_LOG_DIR=/app/logs
  export AGENT_PORT=15034
  export AGENT_UPLOAD_DIR=/app/upload_files
  export AGENT_KEY_PATH=/app/api_keys
}

get_app_pid() {
  pgrep -x agent-app-leak | tail -n 1
}
