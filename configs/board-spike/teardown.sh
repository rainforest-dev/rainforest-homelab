#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib.sh"

for label in "$HEARTBEAT_LABEL" "$SERVE_LABEL"; do
  launchctl bootout "$UID_DOMAIN/$label" 2>/dev/null && echo "stopped $label" || echo "not loaded $label"
  rm -f "$AGENTS_DIR/$label.plist"
done

if [ "${1:-}" = "--purge" ]; then
  rm -rf "$BOARD_HOME"
  /usr/bin/python3 - "$BOARD_URL" <<'PY'
import glob, json, os, sys
for f in glob.glob(os.path.expanduser("~/.config/board/local/*.json")):
    try:
        if json.load(open(f)).get("url") == sys.argv[1]:
            os.remove(f)
    except Exception:
        pass
PY
  echo "purged $BOARD_HOME"
else
  echo "kept data in $BOARD_HOME (add --purge to delete it)"
fi
