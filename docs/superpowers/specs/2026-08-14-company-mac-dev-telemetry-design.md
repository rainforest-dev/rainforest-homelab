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

## Outstanding

**Re-enrol the Pi on Tailscale** — `raspberrypi-5` has been offline 279 days and
its node key has almost certainly expired, so re-auth needs a browser. Until
then Alloy buffers to its WAL and replays on reconnect; hours are free, days
lose data (and Loki rejects pushes older than `reject_old_samples_max_age`,
currently 168h).

Then: Tailscale ACL limiting the laptop to ports 30090/30100, and the Grafana
dashboard — `node_load1 / 12` overlaid with hook-event annotations, plus
`dev_vitest_workers` and `dev_hooks_running`.
