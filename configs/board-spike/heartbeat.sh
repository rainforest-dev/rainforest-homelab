#!/bin/bash
source "$(dirname "$0")/lib.sh"
if [ "$(date +%Y%m%d)" -gt "$BOARD_EXPIRES" ]; then
  launchctl bootout "$UID_DOMAIN/$SERVE_LABEL" 2>/dev/null
  exit 0
fi
export BOARD_URL
touch "$BOARD_HOME/sent.log"
seq=$(( $(wc -l < "$BOARD_HOME/sent.log") + 1 )); ts=$(date +%s)
out=$("$NODE_BIN" "$BOARD_CLI" post hb "hb $seq $ts" --as mini 2>>"$BOARD_HOME/heartbeat.err"); rc=$?
id=$(printf '%s\n' "$out" | tail -1)
[ "$rc" -eq 0 ] && [ -n "$id" ] || id=-
echo "$seq $ts $id $rc" >> "$BOARD_HOME/sent.log"
