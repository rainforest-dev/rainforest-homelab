#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib.sh"
REPLACE=0
[ "${1:-}" = "--replace" ] && REPLACE=1

mkdir -p "$BOARD_HOME" "$AGENTS_DIR"
if [ ! -f "$BOARD_HOME/package.json" ]; then
  cp "$HERE/package.json" "$BOARD_HOME/package.json"
fi
if [ ! -f "$BOARD_CLI" ]; then
  (cd "$BOARD_HOME" && npm install --no-audit --no-fund)
fi

for label in "$SERVE_LABEL" "$HEARTBEAT_LABEL"; do
  target="$AGENTS_DIR/$label.plist"
  loaded=0
  launchctl print "$UID_DOMAIN/$label" >/dev/null 2>&1 && loaded=1
  if [ "$loaded" = 1 ] && [ "$REPLACE" = 0 ]; then
    echo "skip $label: already loaded (use --replace to point it at $HERE)"
    continue
  fi
  sed -e "s#__MODULE_DIR__#$HERE#g" -e "s#__BOARD_HOME__#$BOARD_HOME#g" \
      -e "s#__BOARD_PORT__#$BOARD_PORT#g" -e "s#__BOARD_EXPIRES__#$BOARD_EXPIRES#g" \
      "$HERE/launchd/$label.plist.in" > "$target"
  plutil -lint "$target" >/dev/null
  [ "$loaded" = 1 ] && launchctl bootout "$UID_DOMAIN/$label"
  launchctl bootstrap "$UID_DOMAIN" "$target"
  echo "loaded $label"
done

for _ in $(seq 1 20); do
  curl -fsS -o /dev/null "http://127.0.0.1:$BOARD_PORT/" 2>/dev/null && break
  sleep 1
done
curl -fsS -o /dev/null "http://127.0.0.1:$BOARD_PORT/" && echo "inspector up at http://127.0.0.1:$BOARD_PORT"
"$HERE/agents.sh"
