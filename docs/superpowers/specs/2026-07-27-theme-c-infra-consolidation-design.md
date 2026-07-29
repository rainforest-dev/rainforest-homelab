# Theme C — Infrastructure consolidation

**Date:** 2026-07-27
**Status:** Approved design, pending implementation plan
**Scope:** Third of three integration themes. Theme A (health digest + HA bridge) is
shipped; Theme B (knowledge capture) was assessed and closed as already-solved (RSS,
Readwise, voice memos, surveys, NotebookLM all exist). This spec covers Theme C only.

## Goal

Reduce operational risk and maintenance drag across the two-machine homelab — without
inventing consolidation for its own sake. Close the one real data-loss gap, make a standing
decision on a service that looks like cruft but isn't, and DRY two places where the same
thing is maintained twice.

## Why this shape — what the audit actually found

The naive "consolidation" targets turned out not to be real:

| Suspected | Reality |
|---|---|
| `calibre-web` duplicates `personal-calibre` | No — one is the ebook server, the other a book-delivery tracker with its own DB |
| Readwise capture missing | Already synced to `readwise/` (articles/books/tweets) |
| homebridge is dead cruft | Running 11 days; a single-purpose WoL→HomeKit bridge (see C2) |

What *is* real is narrower and worth doing:

- **The Mac side has no backup at all.** The Pi is well covered; the Mac — which now holds
  the Postgres DB with all six n8n workflows and their credentials — is not.
- **Two Alloy configs** do the same job, maintained by hand in two repos.
- **MCP infrastructure has grown** without a map of what is actually consumed.

## Current state (verified 2026-07-27)

### Backup topology

| Source | Mechanism | Destination |
|---|---|---|
| Pi k3s (all namespaces + PVs) | `velero` scheduled backup | MinIO (Mac) via S3 |
| Pi Docker volumes | `docker-volume-backup` (offen), nightly 03:00, stop-during-backup | MinIO (Mac) → Synology |
| **Mac Docker volumes** (calibre-web config, whisper models, …) | **none** | — |
| **Mac Postgres** (`n8n_db`, `flowise_db`, `homelab`) | **none** | — |
| **Mac T7 hostPath** (n8n `.n8n` files, voice-inbox) | **none** | — |

`volume-management` (Mac) only *creates* Docker volumes and the external directory; it does
not back anything up. No restore from any of these backups has been tested.

### Homebridge

`homebridge/homebridge` container on the Pi, one plugin (`homebridge-wol`) exposing a single
`NetworkDevice` accessory (Wake-on-LAN) to Apple HomeKit. HA's native `homekit:` integration
is **not** enabled. The household uses Apple devices (Bambii's music plays on a Bedroom
HomePod), so HomeKit is a live surface.

### Observability

`grafana-alloy` (Mac) and `grafana-alloy-pi` (Pi) are near-identical River configs: both ship
Docker container logs to Loki and container/host metrics to Prometheus on the Pi
(`<PI_IP>`), maintained separately in two repos. `node_exporter` runs natively on the
Mac. Grafana dashboards live as configmaps in `prometheus-stack` (a refactor is in flight).

### MCP infrastructure (Mac)

| Piece | Role |
|---|---|
| `docker-mcp-gateway` | Managed Docker MCP gateway, exposed via Cloudflare Tunnel |
| `oauth-worker` | Cloudflare Worker (`homelab-oauth-gateway`) — OAuth for the gateway |
| `grafana-mcp` | Grafana MCP server |
| `obsidian-mcp` | Obsidian MCP server (Streamable HTTP + legacy SSE) |

No map exists of which are actually consumed by which client, or whether the gateway's own
tool coverage has superseded any of the standalone servers.

## Component 1 — Close the backup gap + a tested restore (build first)

The only component that addresses data-loss risk, so it goes first.

1. **Audit coverage** — confirm exactly what on the Mac is and isn't backed up (Docker
   volumes, Postgres, T7 hostPath), and that MinIO itself reaches Synology.
2. **Back up Mac Docker volumes** — add an offen `docker-volume-backup` instance on the Mac,
   mirroring the proven Pi module: read-only volume mounts, stop-during-backup labels where
   needed, nightly to MinIO → Synology.
3. **Back up Postgres logically** — a scheduled `pg_dumpall` (or per-DB `pg_dump`) of the Mac
   Postgres, written to a backed-up location. A logical dump is safer than a volume copy for a
   live database and makes the n8n/flowise data restorable independently.
4. **Prove a restore** — restore one Docker volume AND the Postgres dump into a throwaway
   target and verify the data (e.g. an n8n workflow row is present). **No backup counts as
   done until its restore is demonstrated.**
5. **Runbook** — a short restore procedure in the repo, next to the backup module.

**Accepted limitation:** point-in-time granularity is one day (nightly). Given this is a
homelab, that is an acceptable trade; higher frequency can be added per-source later.

## Component 2 — Homebridge: a documented decision

Recommendation: **keep it, and record why.** It is one small container doing one thing HA
does not currently do (WoL → HomeKit). Migrating WoL into HA + enabling HA's HomeKit bridge
is strictly more moving parts for no gain, and HA HomeKit has its own re-pairing friction.

**Deliverable:** a short decision record (in the homebridge module or repo docs) stating the
scope (WoL bridge only), why it is not folded into HA, and the trigger that would change the
decision (e.g. HA HomeKit bridge adopted for other reasons). No code change expected.

## Component 3 — Observability consolidation

Two near-identical Alloy configs are the maintenance smell. Extract the shared River pipeline
(Docker log discovery → Loki, container/host metrics → Prometheus remote_write) into **one
source of truth** parameterised by host, so a change to the shipping pipeline is made once.

Land a single **"homelab overview" Grafana dashboard** spanning both machines (up/down,
restarts, disk, CPU/mem, log volume), building on the dashboard configmap work already in
flight rather than starting fresh.

**Accepted limitation:** the two Alloy instances still deploy separately (different hosts,
different providers — Docker on Mac, Docker on Pi); only the *config* is unified, not the
deployment.

## Component 4 — MCP topology map + tidy

1. **Map it** — for each of `docker-mcp-gateway`, `grafana-mcp`, `obsidian-mcp`,
   `oauth-worker`: what it serves, who consumes it (Claude Code MCP clients, the gateway
   itself), and whether it is reachable/used.
2. **Retire the unused** — likely candidates: `grafana-mcp` if the gateway's Grafana tools
   already cover it; `obsidian-mcp` if the local Obsidian REST API (used by all the n8n
   workflows) makes the remote server redundant. Confirm before removing.
3. **Document the survivor topology** so the next change has a map.

**Accepted limitation:** this is an audit that may conclude "keep all" — the deliverable is
the map and a justified decision per piece, not a mandatory deletion.

### Outcome (2026-07-29) — Component 4 done

The Docker MCP gateway's `default` profile already carries eleven servers, `obsidian` and
`grafana` among them, so both standalone servers were redundant:

| Piece | Decision |
|---|---|
| `docker-mcp-gateway` (module) | **Retired.** Superseded by the launchd-managed gateway on port 3101, which the Cloudflare route now points at directly. |
| `grafana-mcp` | **Retired.** Its tools arrive through the gateway profile. |
| `obsidian-mcp` | **Retired.** Verified the gateway's catalog Obsidian server reads the vault, then removed the module, its `obsidian-internal` tunnel route, the `obsidian.<domain>` Workers domain, and the `.mcp.json` client entry. The n8n workflows were never affected — they talk to the Obsidian REST API directly, not through MCP. |
| `oauth-worker` | **Kept.** Still fronts the gateway (and calibre-mcp) for remote clients. |

**Known trade-off:** the gateway starts each MCP server container on demand, so the first
Obsidian call after an idle period can exceed the client's short read timeout and fail;
a retry hits the warm container and succeeds. The retired container was always-on and did
not have this behaviour. The vault API itself is not the cause — it answers in ~0.02 s from
a container.

## Build order

1. **Backup** — real data-loss risk; independently shippable and the highest value.
2. **Homebridge** — a quick documented decision; unblocks nothing but closes an open question.
3. **MCP tidy** — an audit; low risk, clarifies the platform.
4. **Observability DRY** — a refactor; most code churn, least urgency.

Each is independently shippable. Stopping after Component 1 already removes the data-loss risk.

## Verification

Prove the **outcome**, never a resource's "created" status — the discipline that held through
Theme A.

1. Backup: a restore of a real Mac Docker volume AND the Postgres dump into a throwaway
   target, with the restored data inspected and matching.
2. Backup coverage: every Mac stateful source appears in a backup manifest; MinIO→Synology
   confirmed reaching the offsite.
3. Homebridge: the decision record exists and states the scope + change-trigger.
4. Observability: one config change to the shared Alloy pipeline propagates to both hosts; the
   overview dashboard renders data from both machines.
5. MCP: the topology doc lists every piece with its consumer; any retired piece is confirmed
   gone with nothing broken.

## Out of scope

- **Migrating services between machines** — placement is deliberate (observability on the Pi,
  AI/compute on the Mac); no re-homing.
- **Replacing MinIO or Synology** — the storage backend is fine; only the Mac→backup gap is.
- **A new backup tool on the Mac** — reuse the proven offen `docker-volume-backup`, do not
  introduce a second technology.
- **Rebuilding the Alloy deployment** — only the config is unified; the two deployments stay.
- **Theme B** — assessed and closed as already-solved.
