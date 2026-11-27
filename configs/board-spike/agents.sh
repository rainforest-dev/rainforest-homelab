#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib.sh"
export BOARD_URL

while read -r agent; do
  [ -n "$agent" ] || continue
  case "$agent" in
    mini|air) continue ;;
  esac
  zone="${agent##*-}"
  "$NODE_BIN" "$BOARD_CLI" post "$zone" "$agent online." --as "$agent" --idempotency-key "board-spike-online-$agent" >/dev/null
  echo "ok $agent -> #$zone"
done < "$HERE/agents.txt"
