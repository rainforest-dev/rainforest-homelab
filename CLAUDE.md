# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Terraform-based homelab infrastructure repository that deploys various self-hosted applications to a Kubernetes cluster using Helm charts and custom manifests. The setup uses Docker Desktop as the local Kubernetes environment with **Cloudflare Tunnel** for secure external access with automatic SSL certificates and optional Zero Trust authentication.

## Architecture

### Core Components
- **Terraform**: Infrastructure as Code for managing Kubernetes resources
- **Helm**: Package manager for Kubernetes applications
- **Cloudflare Tunnel**: Secure external access with automatic SSL certificates
- **cloudflared**: Tunnel client running in Kubernetes for secure connectivity
- **Docker Desktop**: Local Kubernetes cluster (context: `docker-desktop`)
- **Docker Volumes**: Managed persistent storage for applications

### Module Structure
Each service is organized as a Terraform module in `modules/`:
- `cloudflare-tunnel/`: Cloudflare Tunnel for secure external access with SSL certificates
- `postgresql/`: Database service for applications that need persistent storage
- `volume-management/`: Docker volume management for persistent storage
- Application modules: `calibre-web/`, `flowise/`, `n8n/`, `open-webui/`, `homepage/`, `whisper/`
- AI/ML services: `whisper/` (Speech-to-Text API using faster-whisper)
- External services: `openspeedtest/` (moved to Raspberry Pi)
- Legacy modules: `traefik/` (removed - replaced by pure Cloudflare Tunnel), `coredns/` (DNS - replaced by Cloudflare), `nfs-persistence/` (storage)

### Standardized Module Structure
All modules follow a consistent structure:
- `main.tf`: Main resource definitions
- `variables.tf`: Input variables with defaults
- `outputs.tf`: Output values for resource information
- `versions.tf`: Provider version constraints (where needed)

### Service Architecture
- All services run in the `homelab` namespace 
- Services use configurable domain suffix (example: `rainforest.tools`)
- Cloudflare Tunnel handles SSL termination and routing via tunnel configuration
- cloudflared pods provide secure connectivity between Cloudflare Edge and Kubernetes services
- Docker proxy container provides secure Docker socket access
- Docker volumes provide managed persistent storage

### Cloudflare Tunnel Flow
1. **Client Request**: Device queries `homepage.yourdomain.com`
2. **Cloudflare DNS**: Resolves to Cloudflare Edge servers
3. **Cloudflare Edge**: Routes to your Cloudflare Tunnel
4. **cloudflared pods**: Receive tunnel traffic and route to Kubernetes services
5. **Service Response**: Returns through encrypted tunnel with automatic SSL

## Common Commands

### Terraform Operations (2-Step Deployment)

**Step 1: Basic Cloudflare Tunnel setup**
```bash
# Initialize and deploy basic tunnel (no authentication)
terraform init
terraform plan
terraform apply
```

**Step 2: Enable Zero Trust authentication (optional)**
```bash
# After enabling Access in Cloudflare dashboard and configuring allowed_email_domains
terraform plan
terraform apply
```

**General operations**
```bash
# Destroy infrastructure
terraform destroy

# Format and validate
terraform fmt
terraform validate
```

### Kubernetes Operations
```bash
# Check cluster context (should be docker-desktop)
kubectl config current-context

# View running services
kubectl get pods -n homelab
kubectl get services -n homelab

# Check cloudflared tunnel status  
kubectl get pods -n homelab -l app=cloudflared
kubectl logs -n homelab -l app=cloudflared

# Get PostgreSQL password
echo $(kubectl get secret --namespace homelab homelab-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

### Cloudflare Tunnel Operations
```bash
# Check tunnel connectivity
kubectl logs -n homelab -l app=cloudflared --tail=20

# View tunnel configuration
kubectl get configmap -n homelab cloudflared-config -o yaml

# Test internal service connectivity
kubectl run test-pod --rm -it --restart=Never --image=curlimages/curl -- curl -I http://homelab-homepage.homelab.svc.cluster.local:3000

# Check tunnel credentials
kubectl get secret -n homelab cloudflare-tunnel-credentials

# View tunnel metrics (if enabled)
kubectl port-forward -n homelab -l app=cloudflared 2000:2000
# Then visit http://localhost:2000/metrics

# Test external DNS resolution
dig homepage.yourdomain.com
nslookup homepage.yourdomain.com 8.8.8.8
```

### Docker Volume Operations
```bash
# List all project volumes
docker volume ls --filter label=project=homelab

# Inspect a specific volume
docker volume inspect homelab-calibre-web-config

# Backup a volume
docker run --rm -v homelab-calibre-web-config:/data -v $(pwd):/backup alpine tar czf /backup/calibre-config-backup.tar.gz -C /data .

# Restore a volume
docker run --rm -v homelab-calibre-web-config:/data -v $(pwd):/backup alpine tar xzf /backup/calibre-config-backup.tar.gz -C /data
```

### Service Access
Services are available at (using `rainforest.tools` domain):

**All Services (via Cloudflare Tunnel with HTTPS):**
- `https://homepage.yourdomain.com` - Homepage dashboard with all services
- `https://open-webui.yourdomain.com` - Open WebUI AI interface
- `https://flowise.yourdomain.com` - Flowise AI workflows
- `https://n8n.yourdomain.com` - n8n automation platform
- `https://calibre-web.yourdomain.com` - Calibre Web ebook server
- `https://whisper.yourdomain.com` - Whisper STT (Speech-to-Text) API
- `https://docker-mcp.yourdomain.com` - Docker MCP Gateway (managed gateway via launchd, host port 3101)

**Local Development Access:**
- Use `kubectl port-forward` for internal service access during development

**Cloudflare Tunnel Benefits:**
- Real SSL certificates from Cloudflare (trusted by all browsers)
- Global CDN access via Cloudflare's network
- Hidden home IP address (enhanced security)
- DDoS protection and enterprise-grade security
- Optional Zero Trust authentication
- Works from any internet connection worldwide

Note: Domain suffix is configurable via `domain_suffix` variable in `terraform.tfvars`

## Development Patterns

### Adding New Services
1. Create new module directory in `modules/[service-name]/`
2. Create standardized module files:
   - `main.tf`: Main resource definitions
   - `variables.tf`: Standard variables (project_name, environment, etc.)
   - `outputs.tf`: Resource outputs including service_url
   - `versions.tf`: Provider constraints (if needed)
3. Add service to main `main.tf` as a module with standard variables
4. **Add ingress rule in `modules/cloudflare-tunnel/main.tf`** to tunnel configuration
5. **Add DNS record in `modules/cloudflare-tunnel/main.tf`** to services list
6. **Add Zero Trust app in `modules/cloudflare-tunnel/main.tf`** for authentication (optional)
7. For persistent storage, use the `volume-management` module
8. Run `terraform plan` and `terraform apply`

Note: New services automatically get SSL certificates and DNS records via Cloudflare

### Cloudflare Tunnel Configuration

**IMPORTANT**: The repository uses a **centralized service configuration pattern** via `locals.tf`. All service configurations are defined in one place and automatically propagate to tunnel ingress, DNS records, and Zero Trust policies.

**To add a new service:**

1. **Add service configuration to `locals.tf`**:
```hcl
services = merge(
  # ... existing services ...

  var.enable_my_service ? {
    "my-service" = {
      hostname    = "my-service"
      service_url = "http://my-service.homelab.svc.cluster.local:8080"
      enable_auth = true  # Enable Zero Trust authentication
      type        = "kubernetes"  # or "docker" for Docker containers
    }
  } : {},
)
```

2. **The `cloudflare-tunnel` module automatically creates**:
   - Tunnel ingress rules (from `service_url`)
   - DNS CNAME records (from `hostname`)
   - Zero Trust applications (when `enable_auth = true` and email domains configured)

**Service Configuration Options:**
- `hostname`: Subdomain for the service (e.g., "my-service" → "my-service.yourdomain.com")
- `service_url`: Internal service URL (Kubernetes service or Docker host)
- `enable_auth`: Enable/disable Zero Trust authentication
- `type`: "kubernetes" or "docker" (for documentation)
- `internal`: Set to `true` to skip DNS record creation (for OAuth Worker proxy pattern)

**For Docker containers**, use `host.docker.internal` to route to Docker host:
```hcl
service_url = "http://host.docker.internal:8083"  # For Docker containers
```

**For Kubernetes services**, use the internal DNS format:
```hcl
service_url = "http://service-name.homelab.svc.cluster.local:port"
```

This pattern ensures consistency and eliminates the need to update multiple locations when adding services.

- `http_host_header`: Rewrite the `Host` sent to the origin. Needed by origins that
  reject unexpected `Host` values — see the Docker MCP Gateway's DNS-rebinding guard.

**⚠️ The remote tunnel config overrides the ConfigMap — edit the right one.**

Ingress is defined in **two** places in `modules/cloudflare-tunnel/main.tf`:

| Resource | Authoritative? |
|---|---|
| `cloudflare_zero_trust_tunnel_cloudflared_config.homelab` (API-managed) | **YES** |
| `kubectl_manifest.cloudflared_config` (the `cloudflared-config` ConfigMap) | No |

The Deployment passes `--config /etc/cloudflared/config/config.yaml`, which makes
the ConfigMap *look* authoritative. It is not: this tunnel has a remote
configuration, and cloudflared fetches and applies that instead, logging
`Updated to new configuration ... version=N` at startup. **Editing only the
ConfigMap silently does nothing** — a live `kubectl patch` of it was verified to
have zero effect. Per-route options must go in the remote config resource, which
means a `terraform apply`. Both are kept in sync so the local file is correct if
the remote config is ever removed.

To see what cloudflared is actually serving:
```bash
kubectl logs -n homelab -l app=cloudflared --tail=100 | grep -o "Updated to new configuration.*version=[0-9]*"
```

**Cloudflare Tunnel Features:**
- **Automatic SSL**: Real certificates from Cloudflare for all services
- **Zero Trust Ready**: Email authentication for sensitive services  
- **Global CDN**: Fast access via Cloudflare's global network
- **DDoS Protection**: Enterprise-grade security included
- **Hidden Infrastructure**: Home IP never exposed
- **High Availability**: Multiple tunnel connections for redundancy

### Configuration Management
- **Centralized Variables**: Common settings defined in root `variables.tf`
- **Environment Configuration**: Use `terraform.tfvars` for environment-specific values
- **Module Variables**: Each module has standardized variables for consistency
- **Feature Flags**: Enable/disable services using `enable_*` variables
- **Resource Sizing**: Standardized CPU, memory, and storage limits
- **Sensitive Data**: Use Terraform sensitive variables for secrets

## Important Notes

- The repository uses Docker Desktop's local Kubernetes cluster
- All HTTP traffic is automatically redirected to HTTPS via Cloudflare
- Cloudflare Tunnel provides secure external access with real SSL certificates
- Global CDN access enables fast connectivity from anywhere
- Docker socket access is secured through a proxy container
- PostgreSQL service provides shared database functionality
- Docker volumes provide persistent storage with backup/restore capabilities
- All modules follow standardized variable and output patterns
- Feature flags allow selective service deployment

## Zero Trust Authentication (2-Step Deployment)

**Step 1: Basic deployment** (no authentication required)
- Deploy with empty `allowed_email_domains = []` in `terraform.tfvars`
- Services are publicly accessible via HTTPS with real SSL certificates
- Perfect for testing and initial setup

**Step 2: Enable authentication** (optional but recommended)
1. **Enable Cloudflare Access**:
   - Go to https://dash.cloudflare.com/ → Zero Trust → Settings
   - Enable "Access" (requires billing info, but Zero Trust is free for up to 50 users)
2. **Configure authentication** in `terraform.tfvars`:
   ```hcl
   # Option A: Domain-specific (recommended for security)
   allowed_email_domains = ["yourdomain.com"]  # Only allow emails from your domain
   allowed_emails        = []                  # Or specific emails if needed
   
   # Option B: Public email providers (less secure)
   allowed_email_domains = ["gmail.com"]       # Allow any Gmail addresses
   allowed_emails        = ["user@domain.com"] # Specific emails
   ```
3. **Deploy authentication**: `terraform apply`

**Zero Trust Features:**
- **Email Verification**: Users must verify their email before accessing services
- **Session Management**: 24-hour sessions (configurable)
- **CORS Support**: Modern web applications work properly
- **Domain Restrictions**: Limit access by email domain or specific addresses
- **Access Policies**: Granular control per service

## Docker MCP Gateway (n8n, Grafana, and more)

The Docker MCP Gateway aggregates many MCP servers (n8n, Grafana, GitHub, Obsidian,
Notion, memory, terraform, …) behind one SSE endpoint, exposed at
`https://docker-mcp.rainforest.tools` via the Cloudflare Tunnel + OAuth Worker.

**Architecture: the gateway is a launchd host service, NOT a Terraform container.**
It runs `docker mcp gateway run --profile default --transport streaming --port 3101
--host 0.0.0.0 --allow-unauthenticated`. This is the *managed* gateway — it executes on
the host, so it reads config from the Docker Desktop `default` profile and secrets from
the macOS Keychain (via `docker-credential-desktop`). A plain `docker run` container
cannot reach the Keychain, which is why the retired standalone container had to keep
plaintext secrets in `~/.docker/mcp/config.yaml`.

- **Plist (version-controlled):** `configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist`
- **Install:** `cp` it to `~/Library/LaunchAgents/`, then `launchctl load -w <plist>`
- **Port:** listens on `3101` (host). Tunnel route `docker-mcp-internal` in `locals.tf`
  points at `host.docker.internal:3101`. `--host 0.0.0.0` is required — cloudflared runs
  in the K8s cluster and reaches the host over the bridge gateway, not loopback.
- **Restart after a profile/Keychain change:** `launchctl kickstart -k gui/$(id -u)/com.homelab.docker-mcp-gateway`
- **Reload after editing the plist:** `kickstart` does **not** re-read the plist from
  disk — it restarts from launchd's in-memory job definition, so the gateway keeps
  running the old arguments while appearing to succeed. Use:
  ```bash
  launchctl bootout gui/$(id -u)/com.homelab.docker-mcp-gateway 2>/dev/null
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist
  ```
  Then confirm with `ps -o command= -p "$(pgrep -f 'mcp gateway run' | head -1)"`.
- **Logs:** `~/Library/Logs/docker-mcp-gateway.log`

### Transport: streamable HTTP only

The gateway serves **streamable HTTP at `/mcp`**. `docker mcp gateway run
--transport` takes a **single** value (`stdio|sse|streaming`) — it is not a
multiplexer, so SSE and streaming cannot coexist on one process. Clients must use
`"type": "http"` with the `/mcp` path.

**Gotcha — the redirect makes failures look like successes.** The redirect is
symmetric: an SSE gateway 307s `/mcp` → `/sse`, and a streaming gateway 307s
`/sse` → `/mcp`. A stale SSE client therefore does *not* get a clean 404. It
follows the redirect into a transport it cannot speak and fails obscurely. When
debugging a client, never read a `307` as "the endpoint works".

**Gotcha — never probe with `"params":{}`.** Gateway v0.43.3 has an upstream bug:
`telemetry.RecordInitialize` (`pkg/telemetry/telemetry.go:549`) dereferences
`clientInfo` without a nil check, so an `initialize` with empty params SIGSEGVs
the gateway process. This was invisible under SSE (the 307 fires before the body
is parsed) but crashes the streaming server, and `KeepAlive` restarts it — which
looks exactly like "streaming is broken". Always send a full `protocolVersion` +
`capabilities` + `clientInfo`. Real clients do. Unauthenticated internet requests
cannot reach this: the OAuth Worker returns 401 first. LAN access to `:3101` can,
which is the pre-existing accepted risk of `--allow-unauthenticated`.

**Gotcha — streaming validates the `Host` header (DNS-rebinding guard).** The
streaming transport accepts only `localhost:<port>` and `127.0.0.1:<port>` as
`Host`; anything else gets `403 Forbidden: invalid Host header "<value>"`.
Measured against `:3101`:

| `Host` | Result |
|---|---|
| `localhost:3101`, `127.0.0.1:3101` | `200` |
| `docker-mcp-internal.rainforest.tools` | `403` |
| `host.docker.internal:3101` | `403` |

cloudflared forwards the public hostname, so the tunnel route **must** rewrite it.
`locals.tf` sets `http_host_header = "localhost:3101"` on `docker-mcp-internal`
for exactly this. SSE had no such check, so this only appears after a cutover to
streaming — and it fires *after* OAuth succeeds, which is why a client like Spark
fails late and opaquely. A `401` from the public endpoint proves only that the
Worker is guarding the route; it does **not** prove the backend is reachable.
Verify the authenticated path separately.

**Gemini Spark does not need Protected Resource Metadata.** Spark's custom-MCP
connector requires streamable HTTP, but *not* RFC 9728 PRM. The OAuth Worker
returns 404 for `/.well-known/oauth-protected-resource` and omits
`resource_metadata=` from its 401 challenge, and Spark connects anyway by falling
back to `/.well-known/oauth-authorization-server` (200) and completing Dynamic
Client Registration at `/register`. `calibre-mcp.rainforest.tools` is the
precedent — same Worker, same 0.0.6 library, connected and syncing. Do not
upgrade `@cloudflare/workers-oauth-provider` on the theory that Spark requires
it; that was investigated and refuted on 2026-08-01.

**Add to Gemini Spark:** gemini.google.com/apps → Custom apps for Spark → Add a
custom app → `https://docker-mcp.rainforest.tools/mcp`.

### Config and secrets (profile + Keychain, never in git)

Config values live in the `default` profile; secrets live in the Keychain:

```bash
# Config (non-secret) — profile
docker mcp profile config default --set grafana.url=http://<PI_IP>:30080
docker mcp profile config default --set n8n.api_url=http://host.docker.internal:5678

# Secrets — Keychain (value from stdin, never echoed)
printf '<grafana-viewer-token>' | docker mcp secret set grafana.api_key
printf '<n8n-api-key>'          | docker mcp secret set n8n.api_key

# Inspect (secrets show as redacted / not printed)
docker mcp profile config default --get-all
docker mcp secret ls
```

Verify a server end-to-end (host CLI reads the same profile + Keychain):

```bash
docker mcp tools call --gateway-arg="--servers=grafana" list_datasources
docker mcp tools call --gateway-arg="--servers=n8n" --gateway-arg="--config=<url-only.yaml>" n8n_list_workflows
```

### n8n specifics — bypassing Cloudflare Access

n8n runs in Kubernetes. Its public URL (`n8n.rainforest.tools`) sits behind Cloudflare
Access, which 302-redirects `/api/v1/*` to a login page — `n8n-mcp` parses that HTML as
JSON and fails (`response is not an object`). The fix: the `homelab-n8n` Service is
`type = LoadBalancer` (`modules/n8n/main.tf`), so Docker Desktop binds it on the host at
`localhost:5678`. The gateway reaches it via `host.docker.internal:5678`, staying
Mac-local and never touching Cloudflare. The public UI keeps its Zero Trust protection.
`n8n_health_check` returns `ok` even when auth is broken (`/healthz` is outside Access) —
only an authenticated call like `n8n_list_workflows` proves the token works.

**⚠️ The n8n MCP server cannot WRITE. Read tools work; use the UI to change workflows.**

`mcp/n8n` in the catalog ships `n8n-mcp` **v2.22.17** against a current **v2.67.3**.
Every write path fails identically:

```
Cannot read properties of undefined (reading '_zod')
```

`n8n_create_workflow`, `n8n_update_partial_workflow` and `n8n_update_full_workflow` are
all affected. Reads — `n8n_get_workflow`, `n8n_validate_workflow`, `n8n_list_executions`
— are fine, so the server looks healthy until you try to save.

Two traps in how it fails:

- **`validateOnly: true` passes.** The tool applies operations in memory, *then* runs a
  whole-workflow structural check, and that second step is what is broken — it reports
  every node invalid and even calls its own well-formed `connections` a string. So a
  green validation says nothing about whether the write will land.
- **Nothing is corrupted.** It refuses to save (`"The workflow was NOT saved"`), so a
  failed write leaves the workflow untouched. Don't go hunting for damage.

**Upgrading is not currently an option** — the catalog pins the image by digest, and
`mcp/n8n:latest` resolves to that *same* digest (`sha256:061cdb8f…`), so there is no
newer published image to move to. Re-check with:

```bash
docker buildx imagetools inspect mcp/n8n:latest | grep Digest
```

Until that digest changes, edit workflows in the n8n UI: **⋯ → Import from File**, or
build the JSON elsewhere and import it. The n8n REST API also works, but its key lives
in the Keychain and is not printable.

### Grafana specifics

Grafana runs on the Raspberry Pi. Use a **Viewer** (read-only) service-account
token; the gateway exposes all tools including writes, so a read-only token is the
guard against accidental mutation. Never point `grafana.url` at
`gfn.rainforest.tools` — that goes through Cloudflare Access and the MCP server
chokes on the login HTML.

**⚠️ Containers on this Mac cannot reach the LAN — do NOT use the Pi's LAN address.**

`grafana.url = http://<PI_IP>:30080` looks right and fails. The gateway spawns each
MCP server as a container, and containers here have no route to the LAN. Measured
from a plain `alpine` container:

| From | To | Result |
|---|---|---|
| container | `ping 192.168.0.128` | **100% packet loss** |
| container | `curl 192.168.0.128:30080` | fails |
| container | `ping host.docker.internal` | works |
| host (this shell) | `curl 192.168.0.128:30080` | `200` in 35ms |

The symptom is
`list datasources: Get "http://192.168.0.128:30080/api/datasources": dial tcp ...: connect: connection refused`.

**PROVEN: the packets never leave this Mac.** Captured on `en1` while firing one
probe from a container and one from the host, seconds apart:

| Probe | Packets on `en1` | Result |
|---|---|---|
| from the host | **10** — full SYN / SYN-ACK / data / FIN | `200` |
| from a container | **0** | timeout |

So the drop happens **inside the Mac**. Everything downstream is innocent and
cannot fix it: not the router, not the Pi's UFW (which explicitly allows
`30000:32767/tcp` and `8123/tcp` from Anywhere), not CrowdSec (`cscli` is not even
installed on the Pi). The Pi's UFW log records plenty of other traffic and **zero**
packets from `192.168.0.126` — it never receives anything to block.

Re-run this test any time the theory is in doubt — it turns "is it us or them?"
into a binary fact in about 10 seconds:

```bash
sudo tcpdump -i en1 -nn "host <PI_IP> and tcp port 30080"
# then, in another shell, probe once from a container and once from the host
```

Also refuted, each tested: Tailscale/WireGuard `utun` default routes; a missing
macOS Local Network grant for Docker (the toggle is ON in System Settings);
Docker Desktop needing a restart to pick that grant up (restarted, no change);
the router refusing to hairpin same-subnet traffic (the packets never reach it).

**Root cause: a macOS bug. NOT Docker Desktop, and NOT this homelab's config.**

[docker/for-mac#7836](https://github.com/docker/for-mac/issues/7836) was opened as a
Docker 4.57.0 regression and **closed as completed on 2026-05-01** with that
attribution overturned. The maintainer's summary:

| macOS | Containers reach the LAN? |
|---|---|
| 26.0.1 | yes |
| 26.2 – 26.3.x | **no** |
| 26.4.1 | yes — reported fixed |

**Downgrading Docker Desktop does not help.** A reporter downgraded to 4.56.0 on an
affected machine and the problem persisted; that is what settled it as a macOS bug.
Do not spend a downgrade on this.

Two independent observations in that thread match ours exactly, which is why the
attribution is trustworthy: containers reach *the router but no other LAN host*, and
a host-side capture shows container packets never reach the host's network interface.

**This Mac is still affected**, on `ProductVersion 27.0` / build `26A5388g` — a
macOS 27 "Golden Gate" pre-release.

Do not assume a newer beta will fix it. The obvious theory — that this build forked
before the 26.4.1 fix — does **not** survive the dates:

| | |
|---|---|
| 26.4.1 (carries the fix) | 2026-04-09 |
| macOS 27 beta 1 `26A5353q` | 2026-06-08 — two months *later* |
| macOS 27 beta 4 `26A5387n` | 2026-07-20 |
| this Mac `26A5388g` | newer still — ~four months after the fix |

Four months was ample time to merge forward, so 27 more likely reintroduced the bug
than missed the fix. Either way it is unexplained, and **chasing beta updates is a
poor bet**: this Mac already runs the newest build. Worth re-testing at the 27.0
release (expected ~September 2026), not before.

Downgrading to a 26.x stable would very likely fix it but needs a wipe — a major
macOS version cannot be rolled back in place. Not worth it to remove a working
30-line tunnel.

**There is no changelog to check.** macOS 26.4.1's notes say only "provides bug
fixes"; the named fixes are Wi-Fi 802.1X, iCloud sync and folder icons. The
LAN-access fix is documented **nowhere** — the only evidence it exists is one user's
empirical report in that thread. So the presence of the fix in any given build
cannot be looked up, only tested:

```bash
docker run --rm alpine ping -c1 -W2 <a_LAN_host>   # reply = fixed, loss = affected
```

Options:
- **Move to a macOS build that has the fix** — the real root-cause removal. Test with
  the one-liner above after any OS update; there will be no release note announcing it.
- **Keep the tunnel below** until then. It costs nothing to leave in place.
- **Move the consumer to the Pi** so nothing on this Mac needs LAN access —
  architectural avoidance, but immune to Apple's timeline.

Settings that do **not** help, so nobody re-tries them: `HostNetworkingEnabled` true
*or* false, `KernelForUDP: true`, restarting `vmnetd`, restarting Docker Desktop, and
granting Docker the macOS **Local Network** permission (it was already granted here
and made no difference).

#### The mitigation: an SSH tunnel (`configs/grafana-tunnel/`)

Containers reach `host.docker.internal`, so the host bridges the gap. A launchd
agent holds `ssh -N rpi5-tunnel` open, binding host `0.0.0.0:30080` and forwarding
to the Pi's `localhost:30080`; `grafana.url` is `http://host.docker.internal:30080`.
All connection detail lives in `~/.ssh/config` under `Host rpi5-tunnel`, so the
plist stays a one-liner.

**Why ssh and not the old Python relay — the transport is the whole point.**
`configs/lan-forwarder/` (removed, see git history) did the same job as a socket
pump and could never work unattended: under launchd it bound the port, accepted
connections, and failed every upstream connect with `[Errno 65] No route to host`,
while the identical script from an interactive shell succeeded.

That split was misread as a launchd problem. **It is a *binary* problem.** macOS
Local Network privacy gates `/usr/bin/python3` as a generic interpreter with no
grant; `/usr/bin/ssh` is an Apple-signed platform binary and is not gated the same
way. The measurement that settles it — a launchd-spawned ssh to the Pi returns:

```
rainforest@192.168.0.128: Permission denied (publickey).
```

An **auth** rejection proves the TCP connection to `192.168.0.128:22` completed.
A Local Network block yields `No route to host` instead — precisely what the
Python relay got. Same launchd, same host, same LAN target, opposite outcome.

So when something on this Mac must reach the LAN unattended, reach for `ssh`, not
a hand-rolled forwarder in an interpreter.

**The tunnel key is powerless by design.** It is passphrase-less so launchd needs
no agent and no Keychain — and it is pinned on the Pi to forwarding one port:

```
restrict,port-forwarding,permitopen="localhost:30080",command="/bin/false" ssh-ed25519 …
```

Verified: shell denied (exit 1, no output) · forward to `localhost:30080` allowed
(`200`) · forward to `:22` refused (`administratively prohibited`).

⚠️ **`restrict` alone does NOT block command execution.** It expands to
`no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding`, and
`no-pty` only stops *terminal allocation* — `ssh host 'cmd'` needs no PTY and runs
fine. The forced `command="/bin/false"` is what blocks it, and it does not disturb
the tunnel: `ssh -N` opens no session channel, so the forced command never fires.

`IdentityAgent none` in the host block is deliberate — without it the tunnel could
silently fall back to the full-shell `id_ed25519.rpi5` key in the interactive agent.

**Self-healing, no autossh.** `ServerAliveInterval 15` / `ServerAliveCountMax 3`
make ssh exit within ~45s of a wedged link and `KeepAlive` restarts it; verified by
`kill -9`, respawned with a new PID. `ExitOnForwardFailure yes` turns a failed bind
into an exit rather than a silent half-up tunnel.

Health check — an empty log is the healthy state, so check the port and the process:

```bash
launchctl list | grep grafana-tunnel && pgrep -fl "ssh -N rpi5-tunnel" && curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:30080/api/health
```

⚠️ **Only one thing may bind `:30080`.** A leftover agent in
`~/Library/LaunchAgents/` auto-loads at next login and will race the tunnel for the
port — `ExitOnForwardFailure` then makes ssh exit and you are left with a listener
that answers but reaches nothing. If Grafana breaks right after a reboot, check for
a second listener first: `lsof -nP -iTCP:30080 -sTCP:LISTEN`.

The same trap applies to **any** MCP server that needs a service on another machine.
The old rule of thumb "service on another machine → its LAN IP" does not hold on this
host; route it through the relay instead.

### Gotcha: tool-name collisions

The managed gateway refuses to start on a tool-name collision (older gateway versions
silently deduped). `memory` and `n8n` both expose `search_nodes`. Resolved by disabling
one: `docker mcp profile tools default --disable memory.search_nodes` (n8n's is kept —
it's core to workflow building). A `--dry-run` does NOT surface this — the collision
check runs at "loading configuration", after tool listing.

### Adding a new MCP server that needs config or secrets

Recipe for any catalog server (n8n and Grafana were done exactly this way):

**1. Find out what it needs.** Two reliable ways to see a server's `config` (non-secret)
and `secrets` keys:
- **Docker Desktop UI** — MCP Toolkit → the server → **Configuration** tab lists
  "Configuration" (config keys) and "Secrets" (secret keys).
- **CLI** — grep the local catalog:
  ```bash
  grep -A30 '^  <server>:' ~/.docker/mcp/catalogs/docker-mcp.yaml | grep -A6 -E 'config:|secrets:'
  ```
  Each `secrets:` entry maps a `name` (e.g. `grafana.api_key`) to an `env` var
  (`GRAFANA_API_KEY`); each `config:` property (e.g. `grafana.url`) becomes an env var too.

**2. Add the server to the profile** (or use the UI "Add to"):
```bash
docker mcp profile server add default --server catalog://mcp/docker-mcp-catalog/<server>
```

**3. Set config values** (non-secret → stored in the profile):
```bash
docker mcp profile config default --set <server>.<key>=<value>
```

**4. Set secrets** (→ macOS Keychain, value via stdin so it is never echoed or shell-logged):
```bash
printf '<secret-value>' | docker mcp secret set <server>.<secret_key>
```

**5. Restart the gateway** to pick up profile/secret changes:
```bash
launchctl kickstart -k gui/$(id -u)/com.homelab.docker-mcp-gateway
```

**6. Verify it loaded and authenticated** (the dry-run log reads the same profile + Keychain
and tolerates unrelated broken servers, unlike a full `tools call`):
```bash
docker mcp gateway run --profile default --dry-run --verbose 2>&1 | grep -iE '<server>:|api_key_set|401|Invalid'
```
Then confirm from a client (Claude Code's `MCP_DOCKER`) by calling one of its tools.

**Networking rule of thumb** for the `*.url` / `*.api_url` config value — the gateway spawns
each server as a container, so the value is resolved *from inside a container*:
- Service on **this Mac's host** (a `docker run -p` container, or a K8s `LoadBalancer`
  service Docker Desktop binds to localhost) → `http://host.docker.internal:<port>`.
  K8s `ClusterIP` is NOT reachable — switch it to `LoadBalancer` first.
- Service on **another machine** (e.g. the Pi) → **NOT its LAN IP.** Containers here
  have no route to the LAN (see "Grafana specifics"). Add an SSH tunnel modelled on
  `configs/grafana-tunnel/` and use `http://host.docker.internal:<local_port>`.
  Use `ssh -N`, not a forwarder script — an interpreter is blocked by macOS Local
  Network privacy under launchd, and `/usr/bin/ssh` is not.
- **Never** point at a `*.rainforest.tools` tunnel URL for the API — Cloudflare Access will
  302-redirect and the MCP server will choke on the HTML.

**Two traps** (both bit us): a full `docker mcp tools call --profile default` fails with
`initialize: EOF` if any profile server is broken (e.g. an unauthorized remote) — isolate
with `--gateway-arg="--servers=<name>"` or use the dry-run above; and `--servers=<name>`
reads `config.yaml`, not the profile, so it won't see profile-set config — the dry-run with
`--profile default` is the faithful check.

## MCP Client Authentication

### For Non-Web MCP Clients (Claude Code, etc.)

**Option 1: Service Tokens (Recommended for Production)**

1. **Create Service Token**:
   ```bash
   # In Cloudflare Zero Trust Dashboard:
   # Access → Service Auth → Service Tokens → Create Service Token
   # Name: "Docker MCP Gateway"
   # Copy the Client ID and Client Secret
   ```

2. **Configure MCP Client**:
   ```json
   {
     "mcpServers": {
       "docker-remote": {
         "type": "http",
         "url": "https://docker-mcp.yourdomain.com/mcp",
         "headers": {
           "CF-Access-Client-Id": "your-service-token-id",
           "CF-Access-Client-Secret": "your-service-token-secret"
         }
       }
     }
   }
   ```

3. **Update Zero Trust Policy** (add to Docker MCP service):
   ```bash
   # In Cloudflare Dashboard:
   # Access → Applications → Docker MCP → Policies
   # Edit policy → Add Include rule → Service Token
   # Select your created service token
   ```

**Option 2: Disable Authentication (Development Only)**
```hcl
# In locals.tf - set enable_auth = false for docker-mcp
"docker-mcp" = {
  hostname     = "docker-mcp"
  service_url  = "http://host.docker.internal:3101"
  enable_auth  = false  # No Zero Trust authentication
  type         = "docker"
}
```

**Option 3: Local Development**
```json
{
  "mcpServers": {
    "docker-local": {
      "type": "http",
      "url": "http://localhost:3101/mcp"  // Bypasses Cloudflare entirely
    }
  }
}
```

**Service Token Benefits:**
- **Programmatic Access**: No browser interaction required
- **Secure**: Scoped to specific applications  
- **Rotatable**: Can be regenerated/revoked anytime
- **Auditable**: All access logged in Cloudflare Analytics

## Persistent OAuth Setup (Recommended)

The OAuth Worker now provides **persistent client registration** managed by Terraform. This ensures OAuth credentials survive deployments and infrastructure changes.

### **Automatic Client Registration**

Terraform automatically registers an OAuth client when deploying the infrastructure:

```bash
terraform apply
```

The client registration happens via:
1. **OAuth Worker Deployment**: Professional TypeScript OAuth Worker with GitHub authentication
2. **Client Registration**: Terraform runs `scripts/register-oauth-client.sh` automatically
3. **Credential Storage**: Client ID and secret stored in local files for persistence
4. **Output Generation**: Terraform outputs provide ready-to-use MCP configuration

### **Using Persistent Credentials**

After `terraform apply`, get your persistent OAuth credentials:

```bash
# Get client ID
terraform output claude_oauth_client_id

# Get client secret
terraform output claude_oauth_client_secret
```

### **MCP Client Configuration**

Use the Terraform-generated credentials for permanent OAuth setup:

```json
{
  "mcpServers": {
    "docker-remote": {
      "type": "http",
      "url": "https://docker-mcp.rainforest.tools/mcp",
      "oauth": {
        "client_id": "3E4n4MoSYkyIXXBo",
        "client_secret": "jkpYLZKtgGJfi0gT6wKgIqEm8KGBimGt"
      }
    }
  }
}
```

### **Benefits of Persistent OAuth**

- ✅ **Infrastructure as Code**: OAuth client managed by Terraform
- ✅ **Deployment Resilience**: Credentials persist across Worker redeployments  
- ✅ **Automatic Registration**: No manual client setup required
- ✅ **Team Sharing**: Consistent credentials across team members
- ✅ **Backup & Restore**: Credentials stored in Terraform state
- ✅ **Professional OAuth 2.0**: Full GitHub authentication flow with approval dialog

### **Manual Client Registration** (Alternative)

If needed, you can manually register additional clients:

```bash
# Run the registration script
./scripts/register-oauth-client.sh

# Or use curl directly
curl -X POST "https://docker-mcp.rainforest.tools/register" \
  -H "Content-Type: application/json" \
  -d '{"client_name": "My Client", "redirect_uris": ["https://example.com/callback"]}'
```

## Whisper Speech-to-Text Service

The homelab includes a self-hosted **Whisper STT API** for speech-to-text transcription using OpenAI's Whisper model.

### **Architecture**
- **Deployment**: Docker container (simple, like Calibre Web)
- **Engine**: faster-whisper (4-5x faster than vanilla Whisper)
- **API**: OpenAI-compatible endpoint (`/v1/audio/transcriptions`)
- **Model Cache**: Persistent Docker volume (~1-2GB)
- **Access**: HTTPS via Cloudflare Tunnel with optional Zero Trust auth

### **Features**
- ✅ **OpenAI API Compatible** - Works with n8n, Flowise, Open WebUI
- ✅ **Fast CPU Performance** - Optimized for Docker Desktop (no GPU required)
- ✅ **GPU Ready** - Set `enable_gpu = true` if GPU available later
- ✅ **Automatic Language Detection** - Supports 99+ languages
- ✅ **Voice Activity Detection** - Filters silence for better accuracy
- ✅ **Built with UV** - Fast Python package management

### **Enabling Whisper**

**1. Enable in `terraform.tfvars`:**
```hcl
enable_whisper = true
```

**2. Deploy:**
```bash
terraform apply
```

**3. First run downloads model (~150MB for 'base'):**
```bash
# Check logs to see model download progress
docker logs -f homelab-whisper
```

### **Model Selection**

**Default Configuration** (optimized for Mac CPU):
```hcl
module "whisper" {
  model_size = "base"  # Fast, low-memory, good quality
  enable_gpu = false   # Set true for PC with GPU
}
```

**Model Performance Comparison** (Tested on Mac CPU):
| Model | Size | Speed (39min audio) | CPU | Memory | Quality | Use Case |
|-------|------|---------------------|-----|--------|---------|----------|
| tiny | 39MB | 61s (38x) | 606% | 500MB | 96% conf | Ultra-fast drafts |
| **base** | **74MB** | **65s (36x)** | **606%** | **750MB** | **97% conf** | **✓ Recommended for Mac** |
| small | 244MB | 312s (7.5x) | 476% | 1.5GB | 99% conf | Important meetings |
| medium | 769MB | ~600s (4x) | 500% | 2GB | 99% conf | Production quality |
| large-v3 | 1.5GB | ~900s (2.5x) | 500% | 3GB | 99% conf | Maximum accuracy |

**Recommendations:**
- **Mac (Dev)**: Use `base` - Fast processing, low resource usage, good for iteration
- **PC with RTX 5070**: Use `medium` or `large-v3` with GPU - 10-20x faster than CPU

### **Dynamic Model Selection** (New Feature)

Override default model per request:
```bash
curl -X POST "https://whisper.yourdomain.com/v1/audio/transcriptions" \
  -F "file=@audio.mp3" \
  -F "whisper_model=small"  # Use specific model for this request
```

Available models: `tiny`, `base`, `small`, `medium`, `large-v2`, `large-v3`

### **API Usage**

**Direct API call:**
```bash
curl -X POST "https://whisper.yourdomain.com/v1/audio/transcriptions" \
  -F "file=@audio.mp3" \
  -F "model=whisper-1"
```

**Response:**
```json
{
  "text": "This is the transcribed text from your audio file.",
  "language": "en",
  "duration": 12.5,
  "language_probability": 0.98
}
```

### **Service Integration**

**Open WebUI** (Automatic):
- Whisper STT automatically configured when `enable_whisper = true`
- Click microphone icon in chat to use voice input
- Transcription happens via `https://whisper.yourdomain.com`

**n8n** (Manual configuration):
1. Add OpenAI node to workflow
2. Set custom base URL: `https://whisper.yourdomain.com/v1`
3. Use "Create Transcription" operation
4. Upload audio file via workflow

**Flowise** (Manual configuration):
1. Add "OpenAI Whisper" node to flow
2. Configure custom endpoint: `https://whisper.yourdomain.com/v1`
3. Connect to your workflow

### **Local Development**

**Test without Cloudflare Tunnel:**
```bash
# Internal URL (no auth required)
curl -X POST "http://localhost:9000/v1/audio/transcriptions" \
  -F "file=@test.mp3"
```

**Health check:**
```bash
curl http://localhost:9000/health
# {"status": "healthy", "model": "base", "device": "cpu"}
```

### **Performance Optimization**

**CPU (Current Setup):**
- Model: `base` (~5x realtime speed)
- Memory: ~1GB during transcription
- Typical: 30-second audio transcribed in ~6 seconds

**GPU (Future):**
```hcl
module "whisper" {
  enable_gpu = true  # Requires NVIDIA GPU + drivers
  model_size = "large-v3"  # Can use larger models
}
```

### **Troubleshooting**

**View logs:**
```bash
docker logs -f homelab-whisper
```

**Rebuild after code changes:**
```bash
terraform taint module.whisper[0].docker_image.whisper
terraform apply
```

**Clear model cache:**
```bash
docker volume rm homelab-whisper-models-data
terraform apply  # Will re-download models
```

**Check container status:**
```bash
docker ps --filter "name=homelab-whisper"
```

## Grafana Alloy (Observability Agent)

Grafana Alloy runs as a Docker container on the Mac Mini, shipping Docker container logs to Loki and container metrics (cAdvisor) to Prometheus on the Pi at <PI_IP>.

**Module:** `modules/grafana-alloy/` — managed by Terraform via the kreuzwerker/docker provider.

**Config file:** `modules/grafana-alloy/alloy.river` — bind-mounted into the container. Edit this file and restart the container (`docker restart homelab-alloy`) to apply config changes without a full `terraform apply`.

### node_exporter (Mac Mini host metrics)

`node_exporter` must be installed natively on macOS — it cannot run in Docker because Docker Desktop on Mac runs containers inside a Linux VM, so a containerized exporter reports VM metrics rather than actual Mac Mini CPU/memory/disk/network.

**This is a manual prerequisite — not managed by Terraform:**

```bash
brew install node_exporter
brew services start node_exporter
```

Once running, Alloy scrapes it at `host.docker.internal:9100` and pushes metrics to Prometheus with `job="mac-mini-node"`.

**To check status:**
```bash
brew services info node_exporter
curl http://localhost:9100/metrics | grep node_cpu_seconds_total | head -3
```

## Security Considerations

- **Cloudflare API Credentials**: The `cloudflare_api_token` and `cloudflare_account_id` variables are marked as sensitive in Terraform
- **Tunnel Security**: Runs with minimal privileges, non-root user, and read-only filesystem
- **Network Isolation**: Home IP address is completely hidden from the internet
- **HTTPS Everywhere**: All traffic encrypted end-to-end through Cloudflare tunnels with automatic SSL termination
- **Zero Trust Ready**: Optional email authentication for additional security layers
- **DDoS Protection**: Enterprise-grade protection via Cloudflare's global network
- **Whisper API Access**: Protected by Cloudflare Zero Trust authentication (recommended for production)