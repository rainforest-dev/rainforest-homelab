# Teleport Module

This module deploys [Teleport OSS](https://goteleport.com/) to provide secure, unified access to your homelab infrastructure.

## Overview

Teleport is an open-source access proxy that provides:
- **SSH Access**: Secure shell access to any machine in your homelab
- **Kubernetes Access**: `kubectl` commands through Teleport proxy
- **Application Access**: Reverse proxy for internal web services
- **Database Access**: Secure connections to PostgreSQL, MySQL, MongoDB
- **Audit & Session Recording**: Complete visibility into access events
- **Certificate-Based Auth**: Zero-trust authentication (no passwords!)

## Features

### Free & Open Source
- Teleport Community Edition (Apache 2.0 license)
- No limits on resources, users, or features
- All core functionality available for free

### Key Capabilities
- **Single Sign-On**: GitHub OAuth integration (optional)
- **Web UI**: Modern web interface for managing access
- **CLI Tools**: `tsh` and `tctl` for command-line access
- **Zero Trust**: Certificate-based authentication
- **High Security**: Session recording and audit logs
- **Global Access**: Works from anywhere (no VPN needed)

## Architecture

```
Internet → Cloudflare Tunnel → Teleport Proxy (Web UI)
                                      ↓
                          Teleport Auth Server
                                      ↓
         ┌────────────────────────────┼────────────────────┐
         ↓                            ↓                    ↓
   SSH Nodes                   Kubernetes            PostgreSQL
   (future)                 (docker-desktop)      (homelab database)
```

### Components Deployed

1. **Teleport Auth Server**: Handles authentication and issues certificates
2. **Teleport Proxy**: Provides web UI and handles client connections
3. **Kubernetes Integration**: Automatic access to your Kubernetes cluster
4. **Persistent Storage**: Session recordings stored on Samsung T7 external drive
5. **Cloudflare Tunnel**: Automatic HTTPS access via `teleport.yourdomain.com`
6. **Zero Trust Auth**: Optional email/GitHub authentication via Cloudflare

## Usage

### 1. Enable Teleport

In your `terraform.tfvars`:
```hcl
enable_teleport = true
```

### 2. Deploy
```bash
terraform apply
```

### 3. Get Connection Info
```bash
# Get Teleport URL
terraform output teleport_url

# Get admin token (sensitive)
terraform output teleport_admin_token

# Get full instructions
terraform output teleport_connection_instructions
```

### 4. Create Admin User

Connect to the Teleport pod:
```bash
kubectl exec -n homelab -it deployment/homelab-teleport-auth -- tctl users add admin \
  --roles=editor,access \
  --logins=root,ubuntu
```

This will output a signup URL. Open it in your browser to set up your admin account.

### 5. Install Client Tools

**macOS:**
```bash
brew install teleport
```

**Linux:**
```bash
curl https://get.gravitational.com/teleport-v15.4.22-linux-amd64-bin.tar.gz | tar -xz
sudo mv teleport/tsh /usr/local/bin/
```

### 6. Login

```bash
tsh login --proxy=teleport.yourdomain.com:443 --user=admin
```

## Access Your Resources

### Kubernetes Access

```bash
# Login to Kubernetes cluster
tsh kube login docker-desktop

# Now use kubectl normally
kubectl get pods --all-namespaces
kubectl get services -n homelab

# All kubectl commands go through Teleport
```

### Database Access (PostgreSQL)

First, register your PostgreSQL database with Teleport:

```bash
kubectl exec -n homelab -it deployment/homelab-teleport-auth -- tctl create <<EOF
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

Then connect:
```bash
# Login to database
tsh db login homelab-postgres --db-user=postgres --db-name=postgres

# Connect interactively
tsh db connect homelab-postgres

# Or get connection string
tsh db config homelab-postgres
```

### SSH Access (Future)

To add SSH access to other machines:

1. Install Teleport node on the target machine
2. Join it to your cluster using a join token
3. SSH through Teleport:
```bash
tsh ssh user@hostname
```

### Application Access (Future)

You can expose internal web apps through Teleport:

```bash
# Forward local port through Teleport
tsh app login myapp --port=8080
```

## Configuration

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_name` | Project name for resource naming | - | Yes |
| `namespace` | Kubernetes namespace | `homelab` | No |
| `cluster_name` | Teleport cluster name | `homelab` | No |
| `public_hostname` | Public hostname (e.g., teleport.example.com) | - | Yes |
| `kubernetes_cluster_name` | Kubernetes cluster name | `docker-desktop` | No |
| `teleport_version` | Teleport Helm chart version | `15.4.22` | No |
| `use_external_storage` | Use external storage for persistence | `false` | No |
| `external_storage_path` | Path to external storage | `/var/lib/teleport` | No |
| `github_client_id` | GitHub OAuth client ID | `""` | No |
| `github_client_secret` | GitHub OAuth client secret | `""` | No |
| `allowed_github_organizations` | GitHub orgs allowed to access | `[]` | No |

### GitHub SSO (Optional)

To enable GitHub authentication:

1. **Create GitHub OAuth App**: https://github.com/settings/developers
   - Application name: `Teleport Homelab`
   - Homepage URL: `https://teleport.yourdomain.com`
   - Authorization callback URL: `https://teleport.yourdomain.com/v1/webapi/github/callback`

2. **Configure in terraform.tfvars**:
```hcl
teleport_github_client_id     = "your-github-client-id"
teleport_github_client_secret = "your-github-client-secret"
teleport_github_organizations = ["your-github-org"]
```

3. **Redeploy**:
```bash
terraform apply
```

Users from your GitHub organization can now login with GitHub!

## Outputs

| Output | Description |
|--------|-------------|
| `service_name` | Name of the Teleport Helm release |
| `namespace` | Kubernetes namespace |
| `web_service_url` | Internal Kubernetes service URL |
| `public_url` | Public HTTPS URL |
| `admin_token` | Initial admin invitation token (sensitive) |
| `cluster_name` | Teleport cluster name |
| `connection_instructions` | Full setup instructions |

## Security

### Authentication
- **Local Auth**: Username/password (default)
- **GitHub OAuth**: Single Sign-On via GitHub (optional)
- **Cloudflare Zero Trust**: Email verification via Cloudflare (automatic)

### Authorization
- **Role-Based Access Control (RBAC)**: Fine-grained permissions
- **Just-in-Time Access**: Temporary elevated privileges
- **Session Recording**: All sessions recorded for audit

### Network Security
- **Cloudflare Tunnel**: Home IP address never exposed
- **TLS Encryption**: All traffic encrypted end-to-end
- **Certificate Auth**: Short-lived certificates instead of passwords

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n homelab -l app.kubernetes.io/name=teleport-cluster
```

### View Logs
```bash
# Auth server logs
kubectl logs -n homelab -l app.kubernetes.io/component=auth --tail=50

# Proxy logs
kubectl logs -n homelab -l app.kubernetes.io/component=proxy --tail=50
```

### Test Internal Connectivity
```bash
# Port-forward to Teleport web UI
kubectl port-forward -n homelab svc/homelab-teleport-web 3080:3080

# Open browser to http://localhost:3080
```

### Reset Admin Password
```bash
kubectl exec -n homelab -it deployment/homelab-teleport-auth -- tctl users reset admin
```

### Check Teleport Status
```bash
kubectl exec -n homelab -it deployment/homelab-teleport-auth -- tctl status
```

## Cost

**100% Free!**
- Teleport Community Edition: Free forever
- No user limits, no resource limits, no time limits
- All core features included

## Resources

- **Teleport Docs**: https://goteleport.com/docs/
- **GitHub**: https://github.com/gravitational/teleport
- **Community Forum**: https://github.com/gravitational/teleport/discussions
- **Slack Community**: https://goteleport.com/slack

## Examples

### Add New User
```bash
kubectl exec -n homelab -it deployment/homelab-teleport-auth -- \
  tctl users add alice --roles=access --logins=ubuntu
```

### List Active Sessions
```bash
tsh sessions ls
```

### Replay Session Recording
```bash
tsh play <session-id>
```

### Export Audit Log
```bash
tsh events --format=json > audit.json
```

## Comparison with Other Solutions

| Feature | Teleport | VPN | SSH Keys |
|---------|----------|-----|----------|
| **Setup** | Easy (Helm chart) | Complex | Manual |
| **Web UI** | ✅ Yes | ❌ No | ❌ No |
| **Audit Logs** | ✅ Yes | ⚠️  Limited | ❌ No |
| **SSO** | ✅ Yes | ⚠️  Depends | ❌ No |
| **Certificate Auth** | ✅ Yes | ❌ No | ⚠️  Manual |
| **Session Recording** | ✅ Yes | ❌ No | ❌ No |
| **Kubernetes Access** | ✅ Yes | ⚠️  Via kubectl | ⚠️  Via kubectl |
| **Database Access** | ✅ Yes | ⚠️  Manual | ⚠️  Manual |
| **Cost** | Free | Varies | Free |

## Future Enhancements

- [ ] Add SSH access to Raspberry Pi nodes
- [ ] Configure application access for internal web services
- [ ] Enable desktop access (RDP/VNC)
- [ ] Set up automatic database discovery
- [ ] Configure access workflows and approval plugins
- [ ] Integrate with Slack for access requests
