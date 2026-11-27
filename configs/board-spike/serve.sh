#!/bin/bash
source "$(dirname "$0")/lib.sh"
[ "$(date +%Y%m%d)" -gt "$BOARD_EXPIRES" ] && exit 0

/usr/bin/python3 - "$BOARD_URL" <<'PY'
import glob, json, os, sys
for f in glob.glob(os.path.expanduser("~/.config/board/local/*.json")):
    try:
        if json.load(open(f)).get("url") == sys.argv[1]:
            os.remove(f)
    except Exception:
        pass
PY
echo "[$(date '+%F %T')] serve start" >> "$BOARD_HOME/serve.log"
cd "$BOARD_HOME" && exec "$NODE_BIN" "$BOARD_CLI" serve --no-open --port "$BOARD_PORT" --dir "$BOARD_HOME/.board"
