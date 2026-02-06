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
