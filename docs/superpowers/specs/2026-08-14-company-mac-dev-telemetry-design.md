# Company Mac dev telemetry → homelab

**Date:** 2026-08-14
**Status:** implemented; one manual step outstanding (Tailscale on the Pi)

## Problem

Concurrent `pre-push` hooks across git worktrees on the company MacBook Air
contend for CPU. Suspicion: Vitest sizes its worker pool from
`os.availableParallelism()` and has no knowledge of other Vitest processes, so
N concurrent pushes each claim the whole machine.

Goal: permanent observability of the work machine, shipped to the homelab, good
enough to prove where the contention is and to verify a fix afterwards.

## Decisions

| Question | Decision |
|---|---|
| Scope | Permanent monitoring, not a time-boxed probe |
| Transport | Re-enrol the Pi on Tailscale; laptop pushes directly |
| Events captured | git hooks, Vitest, agent sessions, top-process CPU |
| Data egress | Raw — real branch/worktree names ship; retention bounds exposure |
| Work-record rollup | Deferred; diagnostics first |
| Ownership | `configs/`, not Terraform |

Terraform here owns the Docker Desktop cluster and Mac Mini containers. A
company laptop is outside that blast radius and `terraform destroy` must never
reach it. Follows the `configs/grafana-tunnel/` precedent.

## Measurements that shaped the design

All taken 2026-08-14 against the live Pi and laptop.

| Quantity | Value |
|---|---|
| Pi rootfs | 72.2 GB used / 125.3 GB, **46.7 GB free** |
| Prometheus on-disk | 2.0 GB at 7d retention → 287 MB/day |
| Prometheus ingest | 2,828 samples/sec, 84,802 series, ~1.18 bytes/sample |
| Loki on-disk | 904 MB, oldest chunk **2025-10-05** → 2.9 MB/day |
| macOS node_exporter | **758 series** (Linux is ~2x that) |
| Laptop's added load | 50.5 samples/sec = **1.8% of existing ingest**, 5.1 MB/day |
| Worktrees on `service-dashboard-frontend` | **81** |

The laptop's contribution is negligible. What actually constrained retention
was a k3s artefact: **42.6% of all series were duplicates.** k3s runs apiserver,
etcd and kubelet in one binary, so the kubelet `:10250/metrics` endpoint
re-exports `apiserver_*`/`etcd_*`/`workqueue_*` that `job=apiserver` already
collects — 36,121 of 84,802 series. Dropping them from `job=kubelet` costs no
capability at all.

## Architecture

```
Company MacBook Air (native launchd, no Docker)      Raspberry Pi
  node_exporter :9100 ──┐                              Prometheus :30090
    + textfile dir      ├── Alloy ── Tailscale ──▶     Loki       :30100
  ps-sampler (30s) ─────┘                              Grafana
  devlog ▶ events.jsonl ┘
```

Native, not containerised: Docker Desktop on macOS runs containers in a Linux
VM, so a containerised collector measures the VM rather than the Mac — fatal
when the subject is real core contention.

Split by data nature: **Prometheus for continuous numeric state, Loki for
discrete events.** Only `event`, `status`, `job`, `host` become Loki labels;
branch, worktree and durations ride in the log body where Loki does not index
them. A branch name as a label would create a stream per feature branch.

Emitters append to a spool file; they never call Alloy over HTTP. A `curl` in
`pre-push` would put telemetry in the critical path of a real push. A single
`printf` to an `O_APPEND` fd is atomic for short lines, which matters because
concurrent worktrees writing at once *is* the phenomenon being measured.

Vitest has no dedicated emitter. Reporting its own pool size would need either a
committed `vitest.config.ts` change or a `--reporter` flag on an invocation the
hook makes internally. Counting the processes from outside needs neither.

## What the instrumentation found before it collected anything

`service-dashboard-frontend/.husky/pre-push` **already contains a mitigation**,
with a comment recording "~30 concurrent jsdom heaps drove this box to load 434
and 24.5 GB of swap". It caps `VITEST_MAX_FORKS=3` when another suite is already
running, and runs `nx affected -t lint typecheck test --parallel=3`.

Two gaps remain, and they are now what the telemetry is for:

1. **TOCTOU race.** `running_vitest_workers()` is evaluated once at hook start.
   Two pushes beginning within seconds of each other both observe zero and both
   run unbounded.
2. **Is 3 the right cap?** Unverified. `nx --parallel=3` also multiplies pools
   within a single push.

`ps-sampler`'s `dev_vitest_workers` uses the **same regex** as the hook's
`running_vitest_workers()`. If the metric counted something else, the dashboard
would disagree with the mechanism it exists to explain.

## Changes made

**Pi** (helm, values backed up in `/tmp/pi-helm-backup/`):

- `prometheus` rev 19 — `retention: 90d`, `retentionSize: 20GB`; drop
  `(apiserver|etcd|workqueue)_.*` from `job=kubelet`. Verified: kubelet
  `/metrics` fell from 44,098 to 3,917 samples per scrape.
- `loki` rev 10 — `compactor.retention_enabled: true`, `retention_period: 90d`.

`retentionSize` is not optional: `local-path` PVCs do not enforce quota, so
nothing else would stop Prometheus consuming the node's free space.

**Laptop** — `configs/dev-telemetry/` installed to `~/.config/dev-telemetry/`;
three launchd agents; `core.hooksPath` redirected on
`service-dashboard-frontend` (repo level plus 27 worktree-scoped overrides);
Claude Code `SessionStart`/`SessionEnd` hooks added.

No commits to any Angible repository. The only change inside one is
`.git/config`, which git does not track.

## Gotchas discovered

- **Prometheus 3.x moved retention into the config file.** `/api/v1/status/flags`
  reports a vestigial `1w` and the operator emits no
  `--storage.tsdb.retention.*` argument. Check `/api/v1/status/config`. The
  change hot-reloads; no restart.
- **Loki's `table_manager` retention does not delete chunks** under
  boltdb-shipper + filesystem, only index tables. `retention_deletes_enabled:
  true` was set and 313 days of chunks had accumulated regardless.
- **`helm --dry-run=client` silently ignores `--reuse-values`** — no cluster
  contact means no values to reuse, and sections render empty.
- **Alloy's `stage.labels` takes a `values` map**, unlike Promtail's YAML.
- **`env()` is deprecated in Alloy 1.18**; `alloy validate` fails on the
  warning. Use `sys.env()`.
- **`launchctl bootout` returns before teardown completes**, so an immediate
  `bootstrap` fails with `5: Input/output error`. Poll, then retry.
- **`launchctl list | grep -q` under `set -o pipefail` gives false negatives.**
  `grep -q` exits on first match, `launchctl` takes SIGPIPE (141), pipefail
  promotes it. Whether it bites depends on where the match falls in the stream.
- **`extensions.worktreeConfig`** lets a worktree override `core.hooksPath`;
  27 of 81 did. Repo-level instrumentation alone would have missed exactly the
  worktrees that push concurrently.

- **`loki.write` has no disk WAL by default**, unlike
  `prometheus.remote_write`. On the Pi's first reconnect 32,623 metric samples
  replayed while a ten-minute-old log entry had already been dropped. Now
  enabled explicitly — the weaker default happened to cover the data that
  cannot be reconstructed.
- **The Pi had two independent faults producing one symptom**: `tailscaled` was
  `systemctl disabled`, *and* its backend state was `Logged out.` Fixing only
  the first survives until the next reboot and then fails identically.

## Verification (complete)

| Step | Result |
|---|---|
| 1. node_exporter | 631 series on `127.0.0.1:9100` |
| 2. Alloy | ready, 0 errors |
| 3. Transport | `up{host="angible-macbook-air"} = 1` on the Pi; all `dev_*` present |
| 4. Log pipeline | event in Loki with exactly `{event,status,job,host}` as labels |
| 4b. LogQL | `unwrap dur_ms` → `4210`, so durations are graphable without parsing |
| 5. Real push | pending — happens on the next `git push` |

## Tailscale ACL (done)

Scoped the wrong way round at first. The ask was "the Pi should expose only a
few ports to the tailnet"; the first draft was a tailnet-wide default-deny,
which would have cut SSH to the laptop for no reason.

The Pi was reachable on **27 ports** from every tailnet device — including 22,
5900 (VNC), 3389 (RDP), 6443 (k3s API) and 10250 (kubelet). Now 2.

Tailscale has no deny rule and no destination exclusion, so "restrict the Pi,
leave everything else" cannot be written as an added restriction: any surviving
`dst: *` re-opens it. The Pi has to *leave* the set the catch-all covers, which
is what `tag:homelab` does.

```jsonc
"grants": [
  { "src": ["autogroup:member"], "dst": ["tag:homelab"],
    "ip": ["tcp:30090", "tcp:30100"] },
  { "src": ["autogroup:member"], "dst": ["autogroup:member", "autogroup:internet"],
    "ip": ["*"] },
]
```

Everything else already has a Cloudflare Tunnel route. Tailscale carries only
what a tunnel cannot: machine-to-machine API pushes, which Cloudflare Access
would 302 into a login page.

The tailnet uses the newer `grants` syntax; `acls` and `grants` cannot be mixed
in one policy file. A `tests` block asserts 30090/30100 accept and 22/6443/5900
deny, so a future regression fails the save rather than going unnoticed.

Verified from the laptop: 30090 → 302, 30100 → 404 (both reachable), and 22,
6443, 5900, 30080, 8123 all blocked.

## Outstanding

- **Confirm key expiry is disabled on the Pi.** Tagging it did not clear
  `KeyExpiry` (still 2027-02-10). Expired keys are what caused the 279-day
  outage, so set it explicitly in the admin console rather than relying on the
  tag.
- **Grafana dashboard** — `node_load1 / 12` overlaid with hook-event
  annotations, plus `dev_vitest_workers` and `dev_hooks_running`. Deferred
  until real contention data exists to validate the panels against.
- **Revisit `cap=3` and the TOCTOU race** in `.husky/pre-push` once a week or
  two of data is in.

## Memory baseline — 2026-08-19, before Chrome Memory Saver

Recorded so the next change can be judged against something. Medians over the
preceding 48h, not peaks: peaks are transient, the median is what a process
actually holds while everything else needs room.

| Series | Median (GB) |
|---|---|
| Chrome, visible browser | 2.29 |
| `chrome-headless-shell` + `chrome-devtools-mcp` | 0.86 |
| Notion | 1.90 |
| swap used | 9.66 |
| swap used, p95 | 14.39 |
| free memory, minimum over 48h | 0.04 |

Two things this changes about the obvious advice:

**Chrome's Memory Saver cannot touch `chrome-headless-shell`.** That 0.86 GB
median (2.29 GB peak) is headless Chrome spawned by the chrome-devtools MCP
server. Memory Saver discards inactive background *tabs*; a headless instance
has none and never idles by that definition.

**Moving Notion into a Chrome tab is worth more than the process accounting
suggests.** The desktop app is a separate Electron instance, so macOS can only
page it to swap — there is no mechanism to hand the memory back. The same
content in a tab becomes eligible for Memory Saver, which discards the renderer
outright and reloads on return. On a machine whose median swap is ~10 GB,
"reclaimable" beats "slightly smaller".
