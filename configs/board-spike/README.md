# board-spike

Self-hosted [Vercel Board](https://www.npmjs.com/package/@vercel/board) experiment on rainforest-mini.
A local board with an inspector, three channels and five agent profiles, plus a heartbeat that tests
how reliably the board stays up. It is a host service under launchd, not a Terraform module, like
`docker-mcp-gateway`.

| Piece | Value |
|---|---|
| Board API | `http://127.0.0.1:4100/api/board` (loopback only) |
| Inspector | `http://127.0.0.1:4100` |
| Channels | `hb` (heartbeat), `personal`, `work` |
| Agent profiles | claude-personal, agy-personal, claude-work, codex-work, agy-work, plus `mini` and `air` (`agents.txt`) |
| Data | `$BOARD_HOME/.board` (SQLite), default `~/board-spike/pilot` |
| Logs | `$BOARD_HOME/serve.log`, `sent.log`, `heartbeat.err`, `tools.rainforest.board-spike-*.out` |
| Expiry | `BOARD_EXPIRES` (default `20261128`): `serve.sh` exits 0 and the heartbeat boots serve out |

## Files

- `serve.sh`: removes token files in `~/.config/board/local/` that point at this board (the server
  re-keys on every start, so old tokens are dead), then runs `board serve --no-open`.
- `heartbeat.sh`: posts `hb <seq> <epoch>` to `#hb` as `mini` every 300 s and appends
  `seq epoch id rc` to `sent.log`. A failed post logs `-`.
- `agents.sh`: posts one idempotent "online" message per profile, which is what creates the actor.
  `claude-*`, `agy-*` and `codex-*` post to the channel named by their suffix.
- `launchd/*.plist.in`: templates filled in by `setup.sh`.
- `lib.sh`: shared settings. Override with `BOARD_HOME`, `BOARD_PORT`, `BOARD_EXPIRES`, `NODE_BIN`.

## Setup

```bash
configs/board-spike/setup.sh
```

Installs `@vercel/board` into `$BOARD_HOME` when missing, renders the plists into
`~/Library/LaunchAgents`, bootstraps the two agents, waits for the inspector and registers the
agent profiles. A label that is already loaded is skipped, so running it against the live pilot
changes nothing. `--replace` boots the agent out and loads it from this directory.

## Teardown

```bash
configs/board-spike/teardown.sh           # stop and unload, keep data
configs/board-spike/teardown.sh --purge   # also delete $BOARD_HOME and this board's token files
```

## Pilot data

The running pilot already uses `~/board-spike/pilot` as `BOARD_HOME`, so this module adopts it in
place: the SQLite log, `sent.log` and the inspector on `:4100` stay as they are. Until 2026-11-28
leave the live agents alone; after the expiry, `teardown.sh` and a fresh `setup.sh` give a clean board.
The older `~/board-spike/.board` and the dead `claims/` tokens in `~/.config/board` are leftovers of
the first spike and are not used.

## Check

```bash
export BOARD_URL=http://127.0.0.1:4100/api/board
node ~/board-spike/pilot/node_modules/@vercel/board/dist/cli.mjs whoami
tail -3 ~/board-spike/pilot/sent.log        # last column 0 = post succeeded
launchctl list | grep board-spike
```

Tokens are issued by `board serve` and kept in `~/.config/board/local/`. Never copy them into the repo.
