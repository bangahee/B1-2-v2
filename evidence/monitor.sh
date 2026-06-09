#!/bin/bash

LOG_FILE="${MONITOR_LOG:-logs/monitor.log}"
PORT="${AGENT_PORT:-15034}"

mkdir -p "$(dirname "$LOG_FILE")"

echo "=== Monitor started at $(date) ===" >> "$LOG_FILE"
echo "LOG_FILE=$LOG_FILE" >> "$LOG_FILE"
echo "PORT=$PORT" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

while true; do
  echo "[$(date)] --- Monitor Snapshot ---" >> "$LOG_FILE"

  PIDS=$(pgrep -x "agent-app-leak" || true)

  if [ -z "$PIDS" ]; then
    echo "PROCESS: FAIL - agent-app-leak is NOT running" >> "$LOG_FILE"
  else
    echo "PROCESS: OK - agent-app-leak running with PID(s): $PIDS" >> "$LOG_FILE"

    for PID in $PIDS; do
      ps -p "$PID" -o pid,ppid,user,%cpu,%mem,rss,stat,cmd --no-headers >> "$LOG_FILE" 2>/dev/null || true
    done
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -ltnp 2>/dev/null | grep -q ":$PORT "; then
      echo "PORT: OK - $PORT is listening" >> "$LOG_FILE"
    else
      echo "PORT: WARN - $PORT is not listening" >> "$LOG_FILE"
    fi
  else
    echo "PORT: SKIP - ss command not installed" >> "$LOG_FILE"
  fi

  echo "" >> "$LOG_FILE"
  sleep 2
done
