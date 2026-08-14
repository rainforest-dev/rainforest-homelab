# dev-telemetry — company laptop → homelab

Ships host metrics and dev-activity events from the company MacBook Air
(`angibles-macbook-air`) to Prometheus and Loki on the Raspberry Pi, over
Tailscale.

Built to answer one question: **are concurrent `pre-push` hooks across git
worktrees fighting each other for CPU, and is Vitest's default worker pool the
reason?**

Not managed by Terraform. Terraform in this repo owns the Docker Desktop k8s
cluster and Docker containers on the Mac Mini; a company laptop is outside that
blast radius and a `terraform destroy` must never be able to reach it. This
follows the `configs/grafana-tunnel/` pattern instead: version-controlled files
plus a documented install.

## What runs where

| Component | Where | How |
|---|---|---|
| `node_exporter` | laptop, native | launchd, `:9100`, textfile collector enabled |
| `alloy` | laptop, native | launchd, `:12345`, pushes to the Pi |
| `ps-sampler` | laptop | launchd, every 30s → `.prom` textfile |
| `git-hook-wrapper` | laptop | via `core.hooksPath`, per repo |
| Prometheus / Loki / Grafana | Pi | already deployed (`monitoring` ns) |

Everything on the laptop is a **native process, not a container**. Docker
Desktop on macOS runs containers inside a Linux VM, so a containerised
collector reports the VM's CPU rather than the Mac's — useless when the whole
point is real core contention.

## Install

```bash
./install.sh              # install/upgrade + start
./install.sh --verify     # status only
```

Then instrument a repo (this is the only thing that touches a repository):

```bash
./instrument-repo.sh /path/to/angible-monorepo
./instrument-repo.sh /path/to/angible-monorepo -u    # undo
```

**Nothing is committed to the instrumented repo.** The only change is
`git config --local core.hooksPath`, which lives in `.git/config` — untracked.
The wrapper scripts live in `~/.config/dev-telemetry/`. `git status` stays
clean. `instrument-repo.sh` prints a confirmation of this at the end.

`core.hooksPath` is stored in the repository's *common* config, so one run
covers every linked worktree. That sharing is also why the hooks contend.

## Data model

Two backends, split by the nature of the data:

- **Prometheus** — continuous numeric state. Low-cardinality labels only.
- **Loki** — discrete events. Only `event` and `status` become labels;
  everything else (branch, worktree, durations) rides in the log body, where
  Loki does not index it and it therefore costs nothing.

A branch name promoted to a label — in either backend — creates a new
series/stream per feature branch and is an unbounded-cardinality bomb.

Event line:

```json
{"ts":"2026-08-14T09:58:54Z","event":"git-hook","status":"ok","hook":"pre-push",
 "dur_ms":74210,"exit":0,"worktree":"feat-x","branch":"feat/central-pos-sync"}
```

`status` is `ok` / `fail` / `interrupted`. Numbers are emitted unquoted so
LogQL `unwrap` reads them directly.

Metrics from `ps-sampler`:

| Metric | Meaning |
|---|---|
| `dev_vitest_workers` | live vitest processes — **the number you will end up capping** |
| `dev_hooks_running` | git hooks in flight — overlap is the contention |
| `dev_proc_cpu_percent{name}` | top-10 by CPU, plus a fixed allowlist |
| `dev_proc_rss_bytes{name}` | same set, resident memory |

## Verify

```bash
curl -s 127.0.0.1:9100/metrics | grep -c '^node_'   # 1. collector up
curl -s 127.0.0.1:12345/-/ready                     # 2. shipper up
# 3. transport — on any machine that can reach the Pi:
curl -sG http://raspberrypi-5:30090/api/v1/query --data-urlencode \
     'query=up{host="angible-macbook-air"}'
# 4. log pipeline
~/.config/dev-telemetry/bin/devlog test ok note hello
# 5. real push — run one, then check the event landed
```

Step 3 is the watershed: it proves Tailscale, the ACL and remote_write at once.
Failures at 1–2 are collection; failures at 3 are transport.

## Gotchas

**`launchctl kickstart -k` does not re-read the plist.** It restarts from
launchd's in-memory job definition, so an edited plist appears to apply while
the old arguments keep running. Always:

```bash
launchctl bootout gui/$(id -u)/com.homelab.dev-alloy
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.homelab.dev-alloy.plist
```

**Prometheus 3.x moved retention out of the CLI flags.** On the Pi,
`/api/v1/status/flags` still reports a vestigial `1w` and the operator's
StatefulSet has no `--storage.tsdb.retention.*` argument. The real value is at
`/api/v1/status/config` under `storage.tsdb.retention`. Checking `flags` gives
the wrong answer.

**`helm --dry-run=client` silently ignores `--reuse-values`.** It does not
contact the cluster, so there are no existing values to reuse and the render
comes out with empty sections that look like a config bug. Use
`--dry-run=server`.

**Loki's `table_manager` retention does not delete chunks** under
boltdb-shipper + filesystem — it only drops index tables. Only the compactor
with `retention_enabled: true` reclaims disk. A config showing
`retention_deletes_enabled: true` can still be growing forever.

**The Pi must be on the tailnet.** If it drops off, Alloy buffers to its
remote_write WAL and replays on reconnect, so a few hours offline costs
nothing. Days will drop data — and Loki additionally rejects pushes older than
`reject_old_samples_max_age` (currently 168h).

## Uninstall

```bash
for l in dev-node-exporter dev-alloy dev-ps-sampler; do
  launchctl bootout "gui/$(id -u)/com.homelab.$l" 2>/dev/null
  rm -f ~/Library/LaunchAgents/com.homelab.$l.plist
done
rm -rf ~/.config/dev-telemetry ~/.local/state/dev-telemetry
# plus ./instrument-repo.sh <repo> -u for each instrumented repo
```
