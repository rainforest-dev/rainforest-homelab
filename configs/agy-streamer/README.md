# agy-streamer deployment

Code lives in `rainforest-monorepo` at `apps/agy-streamer` — this directory only
holds the launchd config that runs it persistently on this Mac, bound to the
Tailscale IP, since the app needs local PTY-spawn access to `agy` and `claude`
that only exists here (it cannot run on a cloud platform).

**Deployment target: the `feat/agy-streamer-migration` worktree, not `main`.**
As of this deployment, `agy-streamer` only exists on the `feat/agy-streamer-migration`
branch — it hasn't been merged into `main` yet. `WorkingDirectory` in the plist
points at `/Users/rainforest/Repositories/rainforest-monorepo/.worktrees/agy-streamer-migration`
rather than the standard main checkout. This is a deliberate, explicit choice
(made over the alternative of merging to `main` first) to get the service
running without touching `main`, which currently has unrelated in-progress
work sitting in its working tree.

**Caveat of this choice**: the service is tied to that worktree's lifetime. If
the worktree is ever removed (e.g. via `git worktree remove`) or the feature
branch is deleted after merging, this plist's `WorkingDirectory` breaks and the
service needs to be repointed (see Update, below) — either at the worktree's
new state or at `main` once `feat/agy-streamer-migration` is merged there.

## Install

1. One-time: `cd ~/Repositories/rainforest-monorepo/.worktrees/agy-streamer-migration && pnpm install` (builds `node-pty`'s native module for this machine)
2. Copy `tools.rainforest.agy-streamer.plist` to `~/Library/LaunchAgents/`
3. `launchctl load -w ~/Library/LaunchAgents/tools.rainforest.agy-streamer.plist`
4. Confirm: `launchctl list | grep agy-streamer`, then open `http://100.111.143.71:3010` from another Tailnet device.

**Why port 3010, not 3000**: the original `rainforest-homelab/agy-streamer/frontend` dev server (the pre-migration app this whole project replaces) is often already running on port 3000 on this Mac. Vite auto-increments past a busy port, but that makes the actual port unpredictable across restarts depending on what else happens to be running — so the plist pins `--port 3010` explicitly instead of relying on that.

## Update

After pulling new code in the worktree:
```bash
launchctl kickstart -k gui/$(id -u)/tools.rainforest.agy-streamer
```

If `feat/agy-streamer-migration` is later merged to `main` and you want to
repoint the service at the standard checkout instead of the worktree, edit
`WorkingDirectory` in the plist to `/Users/rainforest/Repositories/rainforest-monorepo`,
then:
```bash
launchctl unload ~/Library/LaunchAgents/tools.rainforest.agy-streamer.plist
cp tools.rainforest.agy-streamer.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/tools.rainforest.agy-streamer.plist
```

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/tools.rainforest.agy-streamer.plist
rm ~/Library/LaunchAgents/tools.rainforest.agy-streamer.plist
```
