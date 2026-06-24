# Phase 3: Observability Bridge — Grafana Alloy, Grafana MCP, Flowise Removal

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Grafana Alloy on Mac Mini to ship system + container metrics/logs to RPi, add Grafana MCP server for Claude Code AI queries, remove Flowise to free ~300MB RAM, and bridge MinIO storage to Synology Drive for NAS persistence.

**Architecture:** Alloy runs as a Docker container on Mac Mini, pulling metrics via built-in exporters (unix for host, docker for containers) and **pushing** them to RPi Prometheus (remote_write) and Loki (loki.write). This push model means no inbound connection is needed from RPi to Mac Mini. Grafana MCP is a lightweight Docker container that proxies Grafana API to the MCP protocol. Flowise removal is a `terraform destroy -target` operation. The MinIO Synology bridge creates a Kubernetes PV + PVC backed by `~/SynologyDrive/homelab-velero/` and mounts it into MinIO so Velero backups (Phase 4) land in a directory that Synology Drive syncs to NAS.

**Tech Stack:** Terraform Docker + Kubernetes + Helm providers, grafana/alloy, grafana/mcp-grafana, Kubernetes PV/PVC hostPath

**Spec:** `docs/superpowers/specs/2026-05-21-homelab-security-monitoring-design.md` — Phase 3

---

## File Map

**rainforest-homelab** (worktree: `goofy-northcutt-72b552`)

| Action | File |
|---|---|
| Create | `modules/grafana-alloy/main.tf` |
| Create | `modules/grafana-alloy/variables.tf` |
| Create | `modules/grafana-alloy/outputs.tf` |
| Create | `modules/grafana-alloy/versions.tf` |
| Create | `modules/grafana-alloy/alloy.river` |
| Create | `modules/grafana-mcp/main.tf` |
| Create | `modules/grafana-mcp/variables.tf` |
| Create | `modules/grafana-mcp/outputs.tf` |
| Create | `modules/grafana-mcp/versions.tf` |
| Modify | `main.tf` — add alloy + grafana-mcp modules; remove flowise blocks |
| Modify | `locals.tf` — add grafana-mcp to services map |
| Modify | `variables.tf` — add alloy + mcp version variables |
| Modify | `modules/minio/main.tf` — add Synology Drive extraVolume + mount |
| Modify | `modules/minio/variables.tf` — add synology_drive_path variable |

---

## Task 1: Create Grafana Alloy module

**Goal:** Single agent on Mac Mini that ships system metrics + container metrics + container logs to RPi.

- [ ] **Step 1: Look up the latest Alloy release**

```bash
# Check https://github.com/grafana/alloy/releases for latest stable
# Expected: something like v1.8.2
```

Note the version tag (e.g. `v1.8.2`).

- [ ] **Step 2: Create `modules/grafana-alloy/versions.tf`**

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
```

- [ ] **Step 3: Create `modules/grafana-alloy/variables.tf`**

```hcl
variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana Alloy image version"
  type        = string
  default     = "v1.8.2"   # Update to latest from Step 1
}

variable "prometheus_remote_write_url" {
  description = "RPi Prometheus remote_write endpoint"
  type        = string
  # e.g. "http://raspberrypi-5.local:30090/api/v1/write"
}

variable "loki_push_url" {
  description = "RPi Loki push endpoint"
  type        = string
  # e.g. "http://raspberrypi-5.local:30100/loki/api/v1/push"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
```

- [ ] **Step 4: Create `modules/grafana-alloy/alloy.river`**

This file is the Alloy pipeline config. It is mounted read-only into the container.

```river
// ─── Prometheus: Mac Mini system metrics ────────────────────────────────────

prometheus.exporter.unix "mac_mini" {
  // Exposes host CPU, memory, disk, network metrics
  // Equivalent to node_exporter
}

prometheus.scrape "unix" {
  targets    = prometheus.exporter.unix.mac_mini.targets
  forward_to = [prometheus.remote_write.rpi.receiver]

  scrape_interval = "30s"
  job_name        = "mac-mini-node"
}

// ─── Prometheus: Docker container metrics ───────────────────────────────────

prometheus.exporter.cadvisor "containers" {
  docker_host = "unix:///var/run/docker.sock"
}

prometheus.scrape "cadvisor" {
  targets    = prometheus.exporter.cadvisor.containers.targets
  forward_to = [prometheus.remote_write.rpi.receiver]

  scrape_interval = "30s"
  job_name        = "mac-mini-cadvisor"
}

// ─── Prometheus: Push to RPi ────────────────────────────────────────────────

prometheus.remote_write "rpi" {
  endpoint {
    url = env("PROMETHEUS_REMOTE_WRITE_URL")

    queue_config {
      max_samples_per_send = 1000
      batch_send_deadline  = "5s"
    }
  }
}

// ─── Loki: Docker container logs ────────────────────────────────────────────

loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.running.targets
  forward_to = [loki.write.rpi.receiver]
}

discovery.docker "running" {
  host = "unix:///var/run/docker.sock"
}

// ─── Loki: Push to RPi ──────────────────────────────────────────────────────

loki.write "rpi" {
  endpoint {
    url = env("LOKI_PUSH_URL")
  }
}
```

- [ ] **Step 5: Create `modules/grafana-alloy/main.tf`**

```hcl
resource "docker_image" "alloy" {
  name         = "grafana/alloy:${var.image_version}"
  keep_locally = true
}

# Ship config file to Docker named volume so the container can read it
resource "docker_volume" "alloy_config" {
  name = "${var.project_name}-alloy-config"
  labels {
    label = "project"
    value = var.project_name
  }
}

resource "docker_container" "alloy" {
  name  = "${var.project_name}-alloy"
  image = docker_image.alloy.image_id

  restart = "unless-stopped"

  command = [
    "run",
    "--server.http.listen-addr=0.0.0.0:12345",
    "--storage.path=/var/lib/alloy",
    "/etc/alloy/alloy.river",
  ]

  env = [
    "PROMETHEUS_REMOTE_WRITE_URL=${var.prometheus_remote_write_url}",
    "LOKI_PUSH_URL=${var.loki_push_url}",
  ]

  # Mount Alloy config file
  volumes {
    host_path      = abspath("${path.module}/alloy.river")
    container_path = "/etc/alloy/alloy.river"
    read_only      = true
  }

  # Mount Docker socket so Alloy can read container metrics + logs
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  # Alloy UI port — LAN-accessible for debugging, not exposed via Cloudflare
  ports {
    internal = 12345
    external = 12345
    protocol = "tcp"
  }

  memory = 128

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:12345/-/healthy"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
```

- [ ] **Step 6: Create `modules/grafana-alloy/outputs.tf`**

```hcl
output "ui_url" {
  description = "Grafana Alloy debug UI"
  value       = "http://localhost:12345"
}
```

- [ ] **Step 7: Add version + endpoint variables to root `variables.tf`**

```hcl
variable "grafana_alloy_version" {
  type    = string
  default = "v1.8.2"   # Update to latest from Step 1
}

variable "rpi_prometheus_url" {
  description = "RPi Prometheus remote_write URL for Alloy push"
  type        = string
  default     = "http://raspberrypi-5.local:30090/api/v1/write"
}

variable "rpi_loki_url" {
  description = "RPi Loki push URL for Alloy"
  type        = string
  default     = "http://raspberrypi-5.local:30100/loki/api/v1/push"
}
```

- [ ] **Step 8: Wire module in root `main.tf`**

```hcl
module "grafana_alloy" {
  source = "./modules/grafana-alloy"

  project_name                = var.project_name
  image_version               = var.grafana_alloy_version
  prometheus_remote_write_url = var.rpi_prometheus_url
  loki_push_url               = var.rpi_loki_url
  log_opts                    = {}
}
```

- [ ] **Step 9: Validate and plan**

```bash
cd /Users/rainforest/Repositories/rainforest-homelab
terraform validate
terraform plan -target=module.grafana_alloy
```

Expected: plan shows 1 new image, 1 container, 1 volume.

- [ ] **Step 10: Apply and verify Alloy is running**

```bash
terraform apply -target=module.grafana_alloy

docker ps | grep homelab-alloy
curl http://localhost:12345/-/healthy
```

Expected: `{"status":"healthy"}` or `OK`.

- [ ] **Step 11: Verify metrics are reaching RPi Prometheus**

Wait 60s for first scrape, then on RPi:
```bash
# Port-forward to Prometheus on RPi
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 \
  --context=<rpi-kubeconfig-context> &

curl -s "http://localhost:9090/api/v1/query?query=node_cpu_seconds_total{job='mac-mini-node'}" \
  | python3 -m json.tool | grep '"status"'
```

Expected: `"status": "success"` with results.

- [ ] **Step 12: Commit**

```bash
git add modules/grafana-alloy/ main.tf variables.tf
git commit -m "feat: add Grafana Alloy observability agent on Mac Mini"
```

---

## Task 2: Create Grafana MCP server module

**Goal:** Claude Code can query Prometheus metrics, Loki logs, and Grafana dashboards via natural language.

- [ ] **Step 1: Look up the latest grafana/mcp-grafana release**

```bash
# Check https://github.com/grafana/mcp-grafana/releases
# Expected: something like v0.4.0
```

Note the version tag.

- [ ] **Step 2: Create `modules/grafana-mcp/versions.tf`**

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
```

- [ ] **Step 3: Create `modules/grafana-mcp/variables.tf`**

```hcl
variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana MCP server image version"
  type        = string
  default     = "v0.4.0"   # Update to latest from Step 1
}

variable "grafana_url" {
  description = "Grafana URL (internal LAN address)"
  type        = string
  # e.g. "http://raspberrypi-5.local:30080"
}

variable "grafana_api_key" {
  description = "Grafana service account API key (read-only)"
  type        = string
  sensitive   = true
}

variable "mcp_port" {
  description = "Port for the MCP SSE server"
  type        = number
  default     = 8765
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
```

- [ ] **Step 4: Create `modules/grafana-mcp/main.tf`**

```hcl
resource "docker_image" "grafana_mcp" {
  name         = "grafana/mcp-grafana:${var.image_version}"
  keep_locally = true
}

resource "docker_container" "grafana_mcp" {
  name  = "${var.project_name}-grafana-mcp"
  image = docker_image.grafana_mcp.image_id

  restart = "unless-stopped"

  ports {
    internal = var.mcp_port
    external = var.mcp_port
    protocol = "tcp"
  }

  env = [
    "GRAFANA_URL=${var.grafana_url}",
    "GRAFANA_API_KEY=${var.grafana_api_key}",
    "MCP_PORT=${var.mcp_port}",
  ]

  memory = 64

  log_driver = "json-file"
  log_opts   = var.log_opts

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:${var.mcp_port}/health"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "20s"
  }
}
```

- [ ] **Step 5: Create `modules/grafana-mcp/outputs.tf`**

```hcl
output "service_url" {
  description = "Grafana MCP SSE endpoint (LAN)"
  value       = "http://localhost:${var.mcp_port}/sse"
}
```

- [ ] **Step 6: Create a read-only Grafana service account API key**

Before applying, you need a Grafana API key. Log into Grafana at `http://raspberrypi-5.local:30080`:

1. Navigate to **Administration → Service accounts → Add service account**
2. Name: `grafana-mcp`, Role: **Viewer** (read-only)
3. Click **Add service account token**, copy the token

Add to `terraform.tfvars`:
```hcl
grafana_mcp_api_key = "<paste token here>"
```

Add to root `variables.tf`:
```hcl
variable "grafana_mcp_api_key" {
  description = "Grafana read-only service account token for MCP server"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_mcp_version" {
  type    = string
  default = "v0.4.0"   # Update to latest from Step 1
}
```

- [ ] **Step 7: Wire module in root `main.tf`**

```hcl
module "grafana_mcp" {
  source = "./modules/grafana-mcp"

  project_name    = var.project_name
  image_version   = var.grafana_mcp_version
  grafana_url     = "http://raspberrypi-5.local:${var.rpi_grafana_port}"
  grafana_api_key = var.grafana_mcp_api_key
  log_opts        = {}
}
```

Add `rpi_grafana_port` to root `variables.tf`:
```hcl
variable "rpi_grafana_port" {
  description = "RPi Grafana NodePort"
  type        = number
  default     = 30080
}
```

- [ ] **Step 8: Add grafana-mcp to `locals.tf` services map**

In `locals.tf`, add to the `services = merge(...)` block:

```hcl
{
  "grafana-mcp" = {
    hostname    = "grafana-mcp"
    service_url = "http://host.docker.internal:${module.grafana_mcp.service_url == "" ? 8765 : 8765}"
    enable_auth = true
    type        = "docker"
  }
},
```

Or more cleanly, reference the module output:
```hcl
var.grafana_mcp_api_key != "" ? {
  "grafana-mcp" = {
    hostname    = "grafana-mcp"
    service_url = "http://host.docker.internal:8765"
    enable_auth = true
    type        = "docker"
  }
} : {},
```

- [ ] **Step 9: Validate and plan**

```bash
terraform validate
terraform plan -target=module.grafana_mcp
```

Expected: plan shows 1 new image + 1 new container. Also shows cloudflare-tunnel update adding the grafana-mcp DNS record.

- [ ] **Step 10: Apply and verify**

```bash
terraform apply -target=module.grafana_mcp
terraform apply -target=module.cloudflare_tunnel   # propagate DNS record

docker ps | grep grafana-mcp
curl http://localhost:8765/health
```

- [ ] **Step 11: Add Grafana MCP to Claude Code `.mcp.json`**

After deployment, add to `~/.claude/mcp.json` (or the project-level `.mcp.json`):

```json
{
  "mcpServers": {
    "grafana": {
      "type": "sse",
      "url": "https://grafana-mcp.rainforest.tools/sse"
    }
  }
}
```

Test by asking Claude Code: "What is the current CPU usage on the Mac Mini?"

- [ ] **Step 12: Commit**

```bash
git add modules/grafana-mcp/ main.tf locals.tf variables.tf terraform.tfvars
git commit -m "feat: add Grafana MCP server for Claude Code AI observability queries"
```

---

## Task 3: Remove Flowise

**Goal:** Free ~200-400MB RAM on Mac Mini for local LLM workloads.

- [ ] **Step 1: Confirm Flowise database has no data to keep**

```bash
# Check if Flowise has any flows defined (connect to its DB)
kubectl exec -n homelab \
  $(kubectl get pod -n homelab -l app.kubernetes.io/name=flowise -o jsonpath='{.items[0].metadata.name}') \
  -- wget -qO- http://localhost:3000/api/v1/chatflows | python3 -m json.tool
```

Expected: `{"ChatFlows":[]}` — empty. If there are flows you want to keep, export them from the Flowise UI first.

- [ ] **Step 2: Destroy Flowise resources**

```bash
terraform destroy \
  -target=module.flowise \
  -target=module.flowise_database \
  -target=random_password.flowise_password
```

Confirm the prompt — expected destruction: Flowise Helm release, PostgreSQL database, password resource.

- [ ] **Step 3: Remove Flowise blocks from `main.tf`**

Delete these three blocks from `main.tf`:

```hcl
# REMOVE this entire block:
resource "random_password" "flowise_password" {
  count   = 1
  length  = 16
  special = true
}

# REMOVE this entire block:
module "flowise_database" {
  source       = "./modules/postgresql"
  service_name = "flowise"
  ...
  depends_on = [module.flowise_database]
}

# REMOVE this entire block:
module "flowise" {
  source = "./modules/flowise"
  ...
  depends_on = [module.flowise_database]
}
```

- [ ] **Step 4: Remove Flowise from `locals.tf`**

Delete the flowise entry from `locals.tf`:

```hcl
# REMOVE:
{
  flowise = {
    hostname    = "flowise"
    service_url = "http://homelab-flowise.homelab.svc.cluster.local:3000"
    enable_auth = true
    type        = "kubernetes"
  }
},
```

- [ ] **Step 5: Validate and plan**

```bash
terraform validate
terraform plan
```

Expected: no flowise resources in plan. Plan should show only the removal of the Flowise DNS/Cloudflare records.

- [ ] **Step 6: Apply and verify**

```bash
terraform apply

kubectl get pods -n homelab | grep flowise
```

Expected: no flowise pods.

- [ ] **Step 7: Commit**

```bash
git add main.tf locals.tf
git commit -m "feat: remove Flowise to free Mac Mini RAM for local LLM workloads"
```

---

## Task 4: MinIO → Synology Drive bridge

**Goal:** Velero backup data from RPi lands in `~/SynologyDrive/homelab-velero/` on Mac Mini, which Synology Drive passively syncs to NAS — no extra compute, no Tailscale on RPi.

- [ ] **Step 1: Verify SynologyDrive directory exists on Mac Mini**

```bash
ls ~/SynologyDrive/ 2>/dev/null || echo "SynologyDrive not found"
```

If not found, the Synology Drive client may not be running or the sync folder may have a different path. Adjust `synology_drive_path` accordingly.

- [ ] **Step 2: Create the velero subdirectory**

```bash
mkdir -p ~/SynologyDrive/homelab-velero
```

- [ ] **Step 3: Add `synology_drive_path` variable to `modules/minio/variables.tf`**

```hcl
variable "synology_drive_path" {
  description = "Host path for Synology Drive sync — MinIO velero bucket data will land here"
  type        = string
  default     = ""  # Empty = disabled
}
```

- [ ] **Step 4: Add extraVolume for Synology Drive in `modules/minio/main.tf`**

Find the `extraVolumes` block in the Helm values and add a new entry when `synology_drive_path` is set:

```hcl
extraVolumes = concat(
  var.use_external_storage ? [
    {
      name = "external-storage"
      hostPath = {
        path = "/Volumes/Samsung T7 Touch/homelab-data/minio"
        type = "DirectoryOrCreate"
      }
    }
  ] : [],
  var.synology_drive_path != "" ? [
    {
      name = "synology-velero"
      hostPath = {
        path = var.synology_drive_path
        type = "DirectoryOrCreate"
      }
    }
  ] : []
),

extraVolumeMounts = concat(
  var.use_external_storage ? [
    {
      name      = "external-storage"
      mountPath = "/data"
    }
  ] : [],
  var.synology_drive_path != "" ? [
    {
      name      = "synology-velero"
      mountPath = "/data/velero"   # MinIO bucket "velero" → SynologyDrive
    }
  ] : []
),
```

- [ ] **Step 5: Pass variable from root `main.tf`**

```hcl
module "minio" {
  # ... existing ...
  synology_drive_path = var.synology_drive_path
}
```

Add to root `variables.tf`:
```hcl
variable "synology_drive_path" {
  description = "Path to Synology Drive sync folder for Velero backups"
  type        = string
  default     = ""
}
```

Add to `terraform.tfvars`:
```hcl
synology_drive_path = "/Users/rainforest/SynologyDrive/homelab-velero"
```

- [ ] **Step 6: Validate and plan**

```bash
terraform validate
terraform plan -target=module.minio
```

Expected: plan shows MinIO Helm release update with new volume mount.

- [ ] **Step 7: Apply and verify**

```bash
terraform apply -target=module.minio

# Verify the mount exists inside MinIO pod
kubectl exec -n homelab \
  $(kubectl get pod -n homelab -l app=minio -o jsonpath='{.items[0].metadata.name}') \
  -- ls /data/velero
```

Expected: directory exists (may be empty — Velero will write to it in Phase 4).

- [ ] **Step 8: Verify MinIO still healthy**

```bash
kubectl get pods -n homelab | grep minio
```

Expected: minio pod `Running` and `Ready`.

- [ ] **Step 9: Commit**

```bash
git add modules/minio/ variables.tf terraform.tfvars main.tf
git commit -m "feat: bridge MinIO velero bucket to Synology Drive path for NAS backup"
```

---

## Phase 3 Complete — Verification Checklist

```bash
# Alloy running
docker ps | grep homelab-alloy
curl http://localhost:12345/-/healthy

# Grafana MCP running
docker ps | grep homelab-grafana-mcp
curl http://localhost:8765/health

# No Flowise pods
kubectl get pods -n homelab | grep flowise
# Expected: no output

# MinIO healthy with Synology mount
kubectl get pods -n homelab | grep minio
kubectl exec -n homelab $(kubectl get pod -n homelab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- ls /data/velero

# Mac Mini metrics in RPi Prometheus
# (Port-forward RPi Prometheus first, then:)
curl -s "http://localhost:9090/api/v1/query?query=up{job='mac-mini-node'}" \
  | python3 -m json.tool | grep '"value"'
# Expected: value 1 (up)
```
