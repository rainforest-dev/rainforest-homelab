# n8n + Grafana on the Docker MCP Gateway

**Date:** 2026-07-24
**Status:** SHIPPED — with a deliberate architecture change from this design (see As-built).
**Verified against:** the working state of `/Users/rainforest/Repositories/rainforest-homelab`,
including ~26 uncommitted modified files — **not** the committed tree at `7e208c9`.

## As-built (what actually shipped — read this first)

This document is the original design. During implementation the architecture pivoted from a
**Terraform-managed standalone container + `secrets.env`** to the **Docker Desktop *managed*
gateway run under launchd**, because the user wanted to manage tokens through the Docker
Desktop UI. The operational reference is now **CLAUDE.md → "Docker MCP Gateway (n8n,
Grafana, and more)"**. Key divergences from the design below:

- **Gateway is a launchd host process, not a container.** It runs `docker mcp gateway run
  --profile default --transport sse --port 3101 --host 0.0.0.0 --allow-unauthenticated`.
  Plist: `configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist`. This was the
  decisive discovery: a host process can read the Docker Desktop **Keychain** (via
  `docker-credential-desktop`); a plain container cannot. A standalone container **could**
  read a mounted `secrets.env` (verified), but the managed gateway is cleaner for
  UI-managed secrets.
- **Secrets live in the Keychain, config in the `default` profile** — not in a
  Terraform-rendered `config.yaml`/`secrets.env`. So Section C/D below (Terraform owning the
  gateway config files, the `fileexists()` mount fix) did **not** apply — those files and the
  standalone container were retired entirely.
- **Port stayed 3101** (not 3100). Investigation found the "Tailscale occupies 3100" comment
  was a misdiagnosis (no evidence Tailscale ever used it), but 3101 was kept for parity so
  the tunnel route (`host.docker.internal:3101` in `locals.tf`) needed no change.
- **n8n LoadBalancer (Section A/B): DONE and applied.** `modules/n8n/main.tf` is
  `type = LoadBalancer`; the API is reached at `host.docker.internal:5678`, bypassing Access.
- **Grafana folded in (Section B/C): DONE.** `modules/grafana-mcp/` and the
  `docker-mcp-gateway` module were removed; the standalone containers deleted. Grafana MCP
  now arrives via the gateway profile. The Cloudflare-side `grafana-mcp` DNS/ZT destroys are
  pending the user's next `terraform apply` (entangled with an unrelated, uncommitted
  `cloudflare-tunnel` policy refactor, so not applied as part of this work).
- **New gotcha not anticipated:** the managed gateway hard-fails on a tool-name collision
  (`memory` and `n8n` both expose `search_nodes`). Fixed with
  `docker mcp profile tools default --disable memory.search_nodes`. `--dry-run` does not
  surface it (the check runs at config load, after tool listing).
- **Backup (Section D):** the launchd plist + this repo are the reproducible record. Keychain
  secrets remain non-exportable (re-set on a rebuild via `docker mcp secret set`), same class
  as OAuth grants.

The remaining sections are the original design, kept for rationale and history.

## Implementation hazard — read first

This design was authored from a git worktree pinned at commit `7e208c9`. That worktree does
**not** contain the uncommitted work in the main checkout, which includes the gateway port
fix, the `grafana-mcp` SSE fix, and changes to `locals.tf`, `main.tf`, `variables.tf`, and
`outputs.tf`.

**Implementation must target the main checkout, not the worktree.** Applying these changes
from the worktree would revert roughly 26 files of in-flight work.

An earlier revision of this spec contained a fabricated defect ("the gateway's tunnel route
points at a dead port") that was an artifact of reading the stale tree. Code, Terraform state,
and the live container all agree on `internal=3100, external=3101, ip=0.0.0.0`. There is no
port drift, and `docker-mcp.rainforest.tools` is not broken. Port 3101 is deliberate and
documented in-module as avoiding a Tailscale conflict on 3100.

## Goal

Serve both the n8n and Grafana MCP servers from the single Docker MCP Gateway, fix the defects
that prevent this today, and give the gateway a real backup and restore path.

## Current state

| Component | State before this work |
|---|---|
| Docker MCP Gateway | Running, SSE, 9 servers / 91 tools, port `3100` internal / `3101` published |
| n8n MCP | Registered in the gateway, 42 tools listed, **every authenticated call fails** |
| Grafana MCP | **Not** on the gateway — standalone container from `modules/grafana-mcp/` on 8765 |
| Gateway secrets | Plaintext in `~/.docker/mcp/config.yaml`, outside Terraform |
| Gateway backup | None |

## Findings

Each item was verified against the live system and against the main checkout's working tree.

### 1. n8n fails because Cloudflare Access intercepts its API

`locals.tf:20` sets `enable_auth = true` for n8n, so the public API redirects to the Access
login page:

```
curl https://n8n.rainforest.tools/api/v1/workflows
  -> 302, content-type: text/html, "cloudflare"
```

`n8n-mcp` parses that HTML as JSON and fails with
`Invalid response from n8n API for workflows: response is not an object`.

The usual escape hatch does not apply: `n8n-mcp` reads only `N8N_API_URL` and `N8N_API_KEY`
and cannot inject `CF-Access-Client-Id` / `CF-Access-Client-Secret` headers.

`n8n_health_check` reports `status: ok` throughout, because `/healthz` sits outside Access.
The health check does not exercise auth and cannot be trusted as a signal here.

Secondarily, the stored n8n API token expired on 2026-04-19 and needs rotating regardless.

### 2. n8n is not reachable from Docker containers

`modules/n8n/main.tf:254` declares `type = "ClusterIP"` (module unmodified in the working
tree), so nothing is published on host `:5678`. The catalog's hint — use
`http://host.docker.internal:5678` — assumes n8n runs in Docker; this deployment runs it in
Kubernetes.

MinIO already demonstrates the fix. Docker Desktop maps `LoadBalancer` services to
`localhost`, and containers reach them through `host.docker.internal`:

```
curl localhost:9000/minio/health/live   -> 200
container -> host.docker.internal:9000  -> reachable
```

### 3. Two parallel sources of truth for enabled servers

| | `registry.yaml` | Docker Desktop profiles |
|---|---|---|
| Servers | 9 | 11 (adds `grafana`, `sentry-remote`) |
| Read by | the gateway container | Docker Desktop UI / CLI |

`grafana` was already added to the `default` profile, but the gateway is launched with
`--registry /mcp/registry.yaml` and never sees it. Profiles live in the `working_set` table of
`~/.docker/mcp/mcp-toolkit.db`.

Critically, **the published gateway image does not support profiles**:

```
docker run docker/mcp-gateway:latest --profile default
  -> unknown flag: --profile
```

`--profile` exists only in the Docker Desktop CLI plugin. Profiles cannot be the gateway's
runtime source of truth; they can only serve as a snapshot.

### 4. Profile exports embed plaintext secrets

Because credentials are stored as `config` values rather than as secrets,
`docker mcp profile export` writes them in the clear — the n8n JWT and the Obsidian API key
both appear verbatim in the exported YAML. **Profile exports are not git-safe until secrets
move out of `config.yaml`.**

### 5. A file-based secret source works and fixes this

`--secrets` accepts an env file and already defaults to the search path
`docker-desktop:/run/secrets/mcp_secret:/.env`. A full dry-run with both target servers,
credentials supplied only via `.env` and `config.yaml` holding no secrets at all:

```
grafana: url=http://192.168.0.128:30080  api_key_set=true
grafana: [GET /datasources][401] "Invalid API key"    <- dummy token rejected by real Grafana
> grafana: (65 tools)
> n8n:     (42 tools)
> 107 tools listed
```

The 401 confirms the container reached the real Pi Grafana and that the `.env` secret was
injected. The gateway's current `command` has **no** `--secrets` flag; adding it is part of
this work.

### 6. The config mount has a bootstrapping bug

`modules/docker-mcp-gateway/main.tf` mounts the config directory conditionally:

```hcl
dynamic "volumes" {
  for_each = fileexists("${pathexpand("~/.docker/mcp")}/config.yaml") ? [1] : []
```

`fileexists()` evaluates at **plan** time. Once Terraform generates `config.yaml`, a fresh
machine has no such file when the plan is computed, so the mount is silently skipped and the
gateway starts with no configuration. A second apply would fix it. This defeats the
reproducible-restore goal and must be addressed as part of putting config under Terraform.

### 7. Grants cannot be backed up

```
docker mcp secret  -> ls | rm | set              (no export)
docker mcp oauth   -> authorize | ls | revoke    (no export)
```

OAuth grants (`github`, `notion-remote`, `sentry-remote`) live in the macOS Keychain with no
export path and must be re-authorized by hand after a rebuild.

### 8. Costs of adopting the catalog's Grafana server

- Grafana ships **65 tools**, not the 50 listed in the cached catalog. The gateway goes from
  91 to roughly 156 tools.
- The catalog maps `grafana.api_key` to `GRAFANA_API_KEY`, which upstream has **deprecated**
  in favour of `GRAFANA_SERVICE_ACCOUNT_TOKEN`. It still works today.
- The `grafana_mcp_version` pin (`0.5.0`) is replaced by the catalog's digest pin.
- The catalog's n8n image is `n8n-mcp` **2.22.17** against upstream 2.65.2.
- Deleting `modules/grafana-mcp/` discards a recent hard-won fix recorded in that module: the
  image ignores env-based port configuration and only honours `-address`, so it was given
  `command = ["-t", "sse", "-address", "0.0.0.0:${var.mcp_port}"]`. The catalog image is
  driven over stdio by the gateway, so this does not apply there — but the knowledge is worth
  keeping in the commit message that removes it.

## Design

### A. Give n8n a path that bypasses Access

1. `modules/n8n/main.tf`: `type = "ClusterIP"` becomes `"LoadBalancer"`.
2. Gateway config: `n8n.api_url = http://host.docker.internal:5678`.
3. New sensitive variable `n8n_api_key`. **A fresh token must be minted**; the current one
   expired 2026-04-19.

API traffic stays on the Mac and never touches Cloudflare. The public `n8n.rainforest.tools`
UI keeps its Zero Trust protection unchanged.

### B. Fold Grafana into the gateway

- Add `grafana` to `registry.yaml`.
- Config `grafana.url` from `var.raspberry_pi_ip` and `var.rpi_grafana_port`, giving
  `http://192.168.0.128:30080`. The existing module uses `raspberrypi-5.local`; mDNS did
  resolve inside containers during testing, but a literal address removes an avoidable
  dependency.
- Secret `grafana.api_key` from the existing `grafana_mcp_api_key` variable.
- Delete `modules/grafana-mcp/`, its `module` block at `main.tf:364`, and the `grafana-mcp`
  entry at `locals.tf:136`.

Removing the `locals.tf` entry cascades cleanly: tunnel ingress, DNS record, and the Zero
Trust application all derive from `var.services`, and `outputs.tf` contains no Grafana
references.

### C. Put the gateway's configuration under Terraform

Terraform renders three files into `~/.docker/mcp/`:

| File | Contents | Git |
|---|---|---|
| `config.yaml` | `grafana.url`, `n8n.api_url` — no secrets | committable |
| `registry.yaml` | enabled server list | committable |
| `secrets.env` | `grafana.api_key`, `n8n.api_key`, `obsidian.api_key` | gitignored, mode `0600` |

Because `~/.docker/mcp` is already mounted read-only at `/mcp`, the gateway reads secrets from
`/mcp/secrets.env` via `--secrets` with no additional mount.

Replace the conditional `dynamic "volumes"` block from finding 6 with an unconditional mount,
ordered after the file resources with `depends_on`. Terraform now guarantees the directory
exists, so the `fileexists()` guard is both unnecessary and actively harmful.

`obsidian.api_key` is included even though Obsidian is otherwise untouched: it currently sits
in `config.yaml` and would leak into the Layer 2 profile export, defeating the backup design.
The `OBSIDIAN_API_KEY` environment variable the gateway module already passes is a separate
path used by the Obsidian REST integration and is left in place.

Terraform becomes the source of truth for which servers are enabled. Enabling a server through
the Docker Desktop UI will be reverted on the next `terraform apply`; this is accepted and
will be documented.

### D. Backup and restore

**Layer 1 — Terraform and git (primary).** With `config.yaml` and `registry.yaml` generated
and secret-free, the repository is the restore path: `terraform apply` on a fresh machine
reconstitutes the gateway. This is the only authoritative layer, because the gateway image
cannot consume profiles.

**Layer 2 — profile export snapshot.** `docker mcp profile export default <file>.yaml`
committed to the repo. Safe only once secrets have moved to `secrets.env`. Captures digest
pins and tool allowlists for the Docker Desktop side.

**Layer 3 — OCI push (documented, not automated).** `docker mcp profile push <id> <oci-ref>`
to a private `ghcr.io/rainforest-dev` tag for offsite backup. Documented as an optional
command. Must not be run before the secret split.

**Restore runbook**, including the manual step that cannot be automated: re-authorize OAuth
grants with `docker mcp oauth authorize <app>` for `github`, `notion-remote`, and
`sentry-remote`.

### E. Client configuration and documentation

- Remove the `grafana-remote` entry from `~/.claude.json`, which currently reaches
  `http://rainforest-mini.local:8765/sse` over plain LAN HTTP. Those tools now arrive through
  the gateway.
- Document both servers, the secret split, and the restore runbook in `CLAUDE.md`, whose MCP
  section currently covers neither.

## Accepted risks

Decided deliberately; recorded so they are not mistaken for oversights.

1. **LAN exposure of the gateway.** It binds `0.0.0.0:3101` and mounts the Docker socket, so
   any device on the LAN can drive Docker on the Mac Mini unauthenticated. The `0.0.0.0`
   binding is required for `cloudflared` pods to reach it and cannot simply be narrowed.
   Tracked as a follow-up; a packet-filter rule scoped to the Docker bridge is the likely
   remedy.
2. **No tool scoping.** All ~156 tools stay exposed, including `n8n_delete_workflow`,
   `n8n_update_full_workflow`, `delete_alert_rule`, and `update_dashboard`. Context cost is
   handled by client-side deferral and the gateway's `dynamic-tools` feature; the residual
   concern is blast radius, guarded only by the OAuth Worker. The n8n token carries full API
   access, so n8n writes are the sharper edge — `grafana_mcp_api_key` is documented as
   read-only.
3. **`dynamic-tools` stays enabled**, retaining `mcp-add` and `mcp-config-set`, which let a
   connected client mutate the gateway's server list and config at runtime. Terraform reverts
   any such change on the next apply.

## Verification

The work is complete when all of the following hold:

1. `terraform plan` is clean after apply, and the ~26 previously-uncommitted files are intact.
2. `n8n_list_workflows` returns workflow data rather than `response is not an object`.
3. A Grafana tool such as `list_datasources` returns data rather than 401.
4. `grep -E 'eyJ|api_key' ~/.docker/mcp/config.yaml` finds no credentials, and the same check
   against the committed profile export is clean.
5. `secrets.env` is mode `0600` and gitignored.
6. On a simulated fresh bootstrap (config files absent at plan time), a **single**
   `terraform apply` produces a gateway with its config mounted — proving finding 6 is fixed.
7. `homelab-grafana-mcp` is gone, along with the `grafana-mcp` DNS record and Zero Trust
   application.

## Out of scope

- Hardening the gateway's LAN exposure (follow-up).
- A `tools.yaml` allowlist.
- Enabling `use-embeddings`, which would improve `mcp-find` routing but requires an
  `OPENAI_API_KEY`.
- Upgrading `n8n-mcp` beyond the catalog's digest pin.
- The unrelated in-flight work in the main checkout (`cadvisor`, `docker-stats-metrics`,
  `agy-streamer`, Teleport, ComfyUI).
