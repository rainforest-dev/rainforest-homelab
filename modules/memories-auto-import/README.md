# memories-auto-import (launchd)

Runs `apps/personal-memories/src/cli/auto-import.ts` from rainforest-monorepo on the Mac mini:
nightly at 03:30, and whenever something lands in the LINE drop folder (`WatchPaths`). The
container cannot run it. It mounts the data directory read-only, and the job needs the Photos
library, `uvx osxphotos` and the host's Ollama.

- Label: `tools.rainforest.memories-auto-import`, plist in `~/Library/LaunchAgents/`.
- Runner: `~/.local/share/memories-runner`, a blobless sparse clone (`apps/personal-memories`
  only) at `memories_runner_ref`.
- Logs: `~/Library/Logs/memories-auto-import/{stdout,stderr}.log`.
- State: `<MEMORIES_DATA_DIR>/auto-import/state.json`.
- Failures: posted to n8n `ha-events` at `http://localhost:5678/webhook/ha-events`.

The runner is never the owner's working checkout. Terraform fetches and checks out the pinned SHA
when `memories_runner_ref` changes. No `pnpm install` is needed: the CLI imports only Node
built-ins and relative files, and Node 24+ strips the types itself.

n8n is reached on `localhost`, not the Mac's LAN address. The `homelab-n8n` Service is a
`LoadBalancer`, so Docker Desktop binds it on the host, and loopback is exempt from macOS Local
Network privacy, which can block a launchd-started `node` from LAN hosts.

## Enable

In `terraform.tfvars`:

```hcl
enable_memories_auto_import = true
memories_runner_ref         = "<40-char rainforest-monorepo commit SHA that contains auto-import.ts>"
```

Then `terraform apply -target=module.memories_auto_import`. Loading the agent does not start a
run (`RunAtLoad` is false).

## One-time: Full Disk Access

osxphotos must read the Photos library from a launchd-started process, which does not inherit
Terminal's grant. TCC attributes the read to the binary launchd starts and to the Python that
`uvx` runs, so both need Full Disk Access. Grant the resolved paths, not the symlinks:

```bash
realpath /opt/homebrew/bin/node
# e.g. /opt/homebrew/Cellar/node/26.8.2/bin/node
uvx --from osxphotos@0.77.2 python -c 'import os, sys; print(os.path.realpath(sys.executable))'
# e.g. ~/.local/share/uv/python/cpython-3.13.x-macos-aarch64-none/bin/python3.13
```

System Settings → Privacy & Security → Full Disk Access → `+`, press ⌘⇧G, paste each path,
and switch both on. A `brew upgrade node` or a new uv Python moves the real path, so the grant
has to be repeated after one.

## Verify

```bash
launchctl print gui/$(id -u)/tools.rainforest.memories-auto-import | grep -E 'state|last exit'
launchctl kickstart -k gui/$(id -u)/tools.rainforest.memories-auto-import
tail -f ~/Library/Logs/memories-auto-import/stdout.log ~/Library/Logs/memories-auto-import/stderr.log
cat ~/.local/share/memories/auto-import/state.json
```

A good run ends with exit 0 (`last exit code = 0` in `launchctl print`) and a fresh
`lastSuccessAt` in `state.json`. A Photos permission failure shows up in `stderr.log` as an
osxphotos error reading the library, and as a `memories_import_failed` entry in the Obsidian
daily note. Exit 0 with `busy` in the log means a manual `ingest` held the lock; the next
trigger retries.

## Update the runner

Set `memories_runner_ref` to the new SHA and apply. The runner checks it out, and the agent is
reloaded.

## Remove

`terraform destroy -target=module.memories_auto_import` unloads the agent and deletes the plist.
The runner checkout and the logs stay on disk.
