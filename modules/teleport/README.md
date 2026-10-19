# Teleport Module

Deploys [Teleport OSS](https://goteleport.com/) via Helm for secure access to homelab infrastructure (SSH, Kubernetes, databases).

## Quick Start

### 1. Enable and Deploy

```hcl
# terraform.tfvars
enable_teleport = true
```

```bash
terraform apply
```

### 2. Install Client

```bash
brew install teleport
```

### 3. Create Admin User

```bash
kubectl exec -n homelab -it deploy/homelab-teleport-auth -- \
  tctl users add admin --roles=editor,access --logins=root
```

This outputs a signup URL. Open it in your browser to set your password.

### 4. Login

```bash
tsh login --proxy=tp.rainforest.tools:443 --user=admin
```

### 5. Access Kubernetes

```bash
tsh kube login docker-desktop
kubectl get pods -n homelab
```

## Architecture

```
Internet -> Cloudflare Tunnel -> Teleport Proxy (tp.rainforest.tools)
                                       |
                           Teleport Auth Server
                                       |
              +------------------------+-------------------+
              |                        |                   |
        SSH Nodes               Kubernetes           PostgreSQL
        (future)             (docker-desktop)     (homelab database)
```

All protocols are multiplexed on a single port via `proxyListenerMode: multiplex`, which is required for Cloudflare Tunnel routing.

## Direct access (skip Cloudflare)

From HiNet, `tp.rainforest.tools` is served by Cloudflare's San Jose edge (`/cdn-cgi/trace` shows
`colo=SJC`). Every connection through the tunnel goes to California and back, about 300 ms each way.
The Teleport UI showed 289 ms from you to the proxy and 308 ms from the proxy to the server, 597 ms
in total. Agents that join through `tp.rainforest.tools:443` pay the same cost even when they run on
the Mac itself.

With `teleport_direct_access = true` (plus `acme_email`):

- cert-manager issues a Let's Encrypt cert for `tp.<domain>` and `*.tp.<domain>` (DNS-01 via Cloudflare).
- The proxy Service becomes `LoadBalancer`, so Docker Desktop binds `:443` on the Mac's LAN and tailnet
  addresses. Nothing else may hold host :443 first: as of 2026-10-19 `tailscale serve` (ttyd) does,
  so move it (`tailscale serve --https=8443 ...`) before applying.
- Cloudflare Tunnel keeps working unchanged, as a fallback for devices that are off the tailnet.

Then point clients at the Mac when they can reach it directly. The hostname stays `tp.<domain>`, so the
cert matches:

| Who | How it resolves `tp.rainforest.tools` |
|-----|----------------------------------------|
| The Mac's own agent (`scripts/enroll-teleport-node.sh`) | `/etc/hosts`: `127.0.0.1 tp.rainforest.tools` |
| Pi agent | `extra_hosts` in rainforest-iot (`teleport_proxy_direct_ip`) |
| Laptop/phone on Tailscale | Pi-hole record → `100.86.67.66`, and in the Tailscale admin console under DNS, a split-DNS entry for `tp.rainforest.tools` → Pi-hole (`100.81.160.108`) |
| Anything else | Public DNS → Cloudflare (unchanged) |

### On a phone

Teleport has no mobile app, so a phone only gets the web UI. Before direct access, the admin apps
(Pi-hole, Homebridge, ntopng) could not be opened from it at all. Teleport serves each app at
`<app>.tp.rainforest.tools`, and those names have no public DNS record (checked 2026-10-19: no
answer for `pihole.tp.rainforest.tools`). Cloudflare's free Universal SSL also covers only one
level of `*.rainforest.tools`, so routing them through the tunnel would fail TLS. On a desktop,
`tsh proxy app` hides this.

With direct access, Tailscale on the phone fixes it. The split-DNS entry and the Pi-hole wildcard
(rainforest-iot `local_dns_hosts`) resolve `tp.rainforest.tools` and every `*.tp.rainforest.tools`
to the Mac, and the Let's Encrypt cert covers both. Log in once at `https://tp.rainforest.tools`
with a passkey, then tap an app.

To check: `curl -so /dev/null -w '%{time_total}\n' https://tp.rainforest.tools/webapi/ping`
should drop from ~0.3 s to a few ms, and the "Network Connection" panel in the Teleport UI should show
both legs well under 50 ms.

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name for resource naming | (required) |
| `public_hostname` | Public FQDN (used as cluster name) | (required) |
| `namespace` | Kubernetes namespace | `homelab` |
| `kubernetes_cluster_name` | Kubernetes cluster name | `docker-desktop` |
| `teleport_version` | Helm chart version | `15.4.22` |
| `memory_limit` | Memory limit | `1Gi` |
| `storage_size` | PV size for session data | `10Gi` |
| `use_external_storage` | Use host path PV | `false` |
| `external_storage_path` | Host path for PV | `/var/lib/teleport` |
| `direct_access` | Expose the proxy on host port 443 (LoadBalancer) | `false` |
| `cert_manager_issuer_name` | cert-manager issuer for the proxy cert; empty = self-signed | `""` |
| `cert_manager_issuer_kind` | `Issuer` or `ClusterIssuer` | `ClusterIssuer` |

## Outputs

| Output | Description |
|--------|-------------|
| `service_name` | Helm release name |
| `web_service_url` | Internal K8s service URL |
| `public_url` | Public HTTPS URL |
| `admin_token` | Initial admin token (sensitive) |
| `connection_instructions` | Setup steps |

## Database Access

Register PostgreSQL with Teleport:

```bash
kubectl exec -n homelab -it deploy/homelab-teleport-auth -- tctl create <<'EOF'
kind: db
version: v3
metadata:
  name: homelab-postgres
spec:
  protocol: postgres
  uri: homelab-postgresql.homelab.svc.cluster.local:5432
  admin_user:
    name: postgres
EOF
```

Connect:

```bash
tsh db login homelab-postgres --db-user=postgres --db-name=postgres
tsh db connect homelab-postgres
```

## User Management

```bash
# Add user
kubectl exec -n homelab -it deploy/homelab-teleport-auth -- \
  tctl users add alice --roles=access --logins=ubuntu

# Reset password
kubectl exec -n homelab -it deploy/homelab-teleport-auth -- \
  tctl users reset admin

# Check cluster status
kubectl exec -n homelab -it deploy/homelab-teleport-auth -- \
  tctl status
```

## Security

Teleport does **not** use Cloudflare Zero Trust authentication. This is intentional — Teleport is itself an authentication gateway with its own auth system. Placing Zero Trust in front would cause double authentication, break `tsh` CLI flows, and interrupt OAuth/SAML.

Cloudflare Tunnel still provides HTTPS/SSL, hidden IP, DDoS protection, and CDN access.

## Troubleshooting

```bash
# Pod status
kubectl get pods -n homelab -l app.kubernetes.io/name=teleport-cluster

# Auth logs
kubectl logs -n homelab -l app.kubernetes.io/component=auth --tail=50

# Proxy logs
kubectl logs -n homelab -l app.kubernetes.io/component=proxy --tail=50

# Local access (bypass Cloudflare)
kubectl port-forward -n homelab svc/homelab-teleport-web 3080:3080
# Then open http://localhost:3080
```
