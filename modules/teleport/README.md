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
  It reuses `cloudflare_api_token`, which must have `Zone:DNS:Edit`. The apply does not wait for the
  Certificate: if the challenge fails, Terraform still succeeds and the new proxy pod waits on
  `teleport-tls`. Check with `kubectl get certificate -n homelab` (READY should be True).
- The proxy Service becomes `LoadBalancer`, so Docker Desktop binds `:443` on the Mac's LAN and tailnet
  addresses. Nothing else may hold host :443 first. ttyd's `tailscale serve` was moved
  to :8443 on 2026-10-19 for this.
- Cloudflare Tunnel keeps working unchanged, as a fallback for devices that are off the tailnet.

Then point clients at the Mac when they can reach it directly. The hostname stays `tp.<domain>`, so the
cert matches:

| Who | How it resolves `tp.rainforest.tools` |
|-----|----------------------------------------|
| The Mac's own agent (`scripts/enroll-teleport-node.sh`) | `/etc/hosts`: `127.0.0.1 tp.rainforest.tools` |
| Pi agent | `extra_hosts` in rainforest-iot (`teleport_proxy_direct_ip`) |
| Laptop/phone on Tailscale | Pi-hole record → `<MAC_TAILNET_IP>`, and in the Tailscale admin console under DNS, a split-DNS entry for `tp.rainforest.tools` → Pi-hole (`<PIHOLE_TAILNET_IP>`) |
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

## Upgrading

Teleport supports upgrading the cluster one major version at a time: 15 to 18 is three applies
(16, 17, 18), never one. Change `teleport_version` in the root `main.tf`, `git pull`,
`terraform apply`, and check before the next step:

```bash
kubectl get pods -n homelab -l app.kubernetes.io/instance=homelab-teleport
kubectl exec -n homelab deploy/homelab-teleport-auth -- tctl status
tsh login --proxy=tp.rainforest.tools --user=rainforest
```

Back up the auth data first. The PVC is on internal disk (see `use_external_storage`) and is
the only copy of the cluster CA, users and MFA devices, and Teleport cannot be downgraded:

```bash
B=~/Backups/teleport/$(date +%F); mkdir -p "$B" && chmod 700 "$B"
kubectl exec -n homelab deploy/homelab-teleport-auth -- tar czf - -C /var/lib/teleport . > "$B/var-lib-teleport.tgz"
kubectl exec -n homelab deploy/homelab-teleport-auth -- tctl get all --with-secrets > "$B/tctl-get-all.yaml"
chmod 600 "$B"/*
```

`tctl-get-all.yaml` holds the CA private keys: keep it off the repo and cloud. To restore after
a failed upgrade, set `teleport_version` back, apply, scale `homelab-teleport-auth` to 0, unpack
`var-lib-teleport.tgz` into the PVC (for example from a busybox pod that mounts it), and scale
back to 1.

Teleport agents must be the cluster's major or one below. Before each apply, check
`/usr/local/bin/teleport version` on the Mac, whose node agent (a LaunchDaemon) is not managed
here, and upgrade it with sudo to at least the target major minus one. The NAS is an agentless
OpenSSH node and has no agent to upgrade.

Keep `tsh` within one major of the cluster, and never ahead of it: the cluster refuses a client
on a newer major. `tsh` comes from Homebrew, which always follows the latest release, so keep it
pinned and move it only after the cluster apply:

```bash
brew pin teleport                                               # once
brew unpin teleport && brew upgrade teleport && brew pin teleport   # after each cluster step
```

Renovate (`renovate.json`) opens a PR for each new `teleport-cluster` chart release, one major
per PR, never automerged. The order per release is: merge the PR, back up, apply, check, then
upgrade the Mac's agent and `tsh`.
On 2026-11-08 a Homebrew `tsh` 18 against the 15 cluster wrote an empty key file and
`tsh login` failed with `ssh: no key found`; the matching 15.x `tsh` worked.

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
