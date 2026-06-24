# Alloy Mac Mini Deployment Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Grafana Alloy on the Mac Mini to ship Docker container logs and Kubernetes pod logs to Loki, and system + container metrics to Prometheus — both running on the Pi at 192.168.0.128.

**Architecture:** Alloy runs as a Docker container on the Mac Mini. It discovers Docker containers via the Docker socket, discovers Kubernetes pods via a mounted kubeconfig, and pushes logs to Loki (port 30100) and metrics to Prometheus (port 30090) on the Pi. The module already exists as a stub in a worktree and needs to be promoted to main with K8s log collection added.

**Tech Stack:** Grafana Alloy v1.8.2, Terraform kreuzwerker/docker provider, Alloy River config language, Docker Desktop Kubernetes

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `modules/grafana-alloy/main.tf` | Create | Docker image + container resource |
| `modules/grafana-alloy/alloy.river` | Create | Alloy pipeline: Docker logs, K8s pod logs, system metrics, cAdvisor metrics |
| `modules/grafana-alloy/variables.tf` | Create | Input variables |
| `modules/grafana-alloy/outputs.tf` | Create | Alloy UI URL output |
| `modules/grafana-alloy/versions.tf` | Create | Docker provider constraint |
| `main.tf` | Modify | Wire module with variables |
| `variables.tf` | Modify | Add alloy-related variables |
| `terraform.tfvars` | Modify | Set rpi_prometheus_url, rpi_loki_url, grafana_alloy_version |

---

## Task 1: Create grafana-alloy module files

**Files:**
- Create: `modules/grafana-alloy/versions.tf`
- Create: `modules/grafana-alloy/variables.tf`
- Create: `modules/grafana-alloy/outputs.tf`
- Create: `modules/grafana-alloy/main.tf`
- Create: `modules/grafana-alloy/alloy.river`

- [ ] **Step 1: Create versions.tf**

```hcl
# modules/grafana-alloy/versions.tf
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}
```

- [ ] **Step 2: Create variables.tf**

```hcl
# modules/grafana-alloy/variables.tf
variable "project_name" {
  type    = string
  default = "homelab"
}

variable "image_version" {
  description = "Grafana Alloy Docker image version"
  type        = string
  default     = "v1.8.2"
}

variable "prometheus_remote_write_url" {
  description = "Prometheus remote_write endpoint on RPi"
  type        = string
  default     = "http://raspberrypi-5.local:30090/api/v1/write"
}

variable "loki_push_url" {
  description = "Loki push endpoint on RPi"
  type        = string
  default     = "http://raspberrypi-5.local:30100/loki/api/v1/push"
}

variable "kubeconfig_path" {
  description = "Absolute path to kubeconfig for K8s pod log discovery"
  type        = string
  default     = "/Users/rainforest/.kube/config"
}

variable "log_opts" {
  type = map(string)
  default = {
    "max-size" = "10m"
    "max-file" = "3"
  }
}
```

- [ ] **Step 3: Create outputs.tf**

```hcl
# modules/grafana-alloy/outputs.tf
output "ui_url" {
  description = "Grafana Alloy debug UI (local only)"
  value       = "http://localhost:12345"
}
```

- [ ] **Step 4: Create main.tf**

```hcl
# modules/grafana-alloy/main.tf
resource "docker_image" "alloy" {
  name         = "grafana/alloy:${var.image_version}"
  keep_locally = true
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

  volumes {
    host_path      = abspath("${path.module}/alloy.river")
    container_path = "/etc/alloy/alloy.river"
    read_only      = true
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    host_path      = var.kubeconfig_path
    container_path = "/etc/alloy/kubeconfig"
    read_only      = true
  }

  ports {
    internal = 12345
    external = 12345
    protocol = "tcp"
  }

  memory = 192

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

- [ ] **Step 5: Create alloy.river**

```river
// modules/grafana-alloy/alloy.river

// ─── Prometheus: Mac Mini system metrics ────────────────────────────────────

prometheus.exporter.unix "mac_mini" {}

prometheus.scrape "unix" {
  targets         = prometheus.exporter.unix.mac_mini.targets
  forward_to      = [prometheus.remote_write.rpi.receiver]
  scrape_interval = "30s"
  job_name        = "mac-mini-node"
}

// ─── Prometheus: Docker container metrics (cAdvisor) ────────────────────────

prometheus.exporter.cadvisor "containers" {
  docker_host = "unix:///var/run/docker.sock"
}

prometheus.scrape "cadvisor" {
  targets         = prometheus.exporter.cadvisor.containers.targets
  forward_to      = [prometheus.remote_write.rpi.receiver]
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

discovery.docker "running" {
  host = "unix:///var/run/docker.sock"
}

loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.running.targets
  forward_to = [loki.write.rpi.receiver]
}

// ─── Loki: Kubernetes pod logs (Docker Desktop) ─────────────────────────────

discovery.kubernetes "pods" {
  role            = "pod"
  kubeconfig_file = "/etc/alloy/kubeconfig"
}

loki.source.kubernetes "k8s_pods" {
  targets    = discovery.kubernetes.pods.targets
  forward_to = [loki.write.rpi.receiver]
}

// ─── Loki: Push to RPi ──────────────────────────────────────────────────────

loki.write "rpi" {
  endpoint {
    url = env("LOKI_PUSH_URL")
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add modules/grafana-alloy/
git commit -m "feat: add grafana-alloy module for Mac Mini log and metric collection"
```

---

## Task 2: Wire module into root config

**Files:**
- Modify: `main.tf`
- Modify: `variables.tf`
- Modify: `terraform.tfvars`

- [ ] **Step 1: Add variables to variables.tf**

Add these blocks to `variables.tf`:

```hcl
variable "grafana_alloy_version" {
  description = "Grafana Alloy Docker image version"
  type        = string
  default     = "v1.8.2"
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

variable "alloy_kubeconfig_path" {
  description = "Absolute path to kubeconfig for Alloy K8s pod log discovery"
  type        = string
  default     = "/Users/rainforest/.kube/config"
}
```

- [ ] **Step 2: Add module block to main.tf**

```hcl
module "grafana_alloy" {
  source = "./modules/grafana-alloy"

  project_name                = var.project_name
  image_version               = var.grafana_alloy_version
  prometheus_remote_write_url = var.rpi_prometheus_url
  loki_push_url               = var.rpi_loki_url
  kubeconfig_path             = var.alloy_kubeconfig_path
  log_opts                    = {}
}
```

- [ ] **Step 3: Set values in terraform.tfvars**

Add to `terraform.tfvars`:

```hcl
grafana_alloy_version = "v1.8.2"
rpi_prometheus_url    = "http://192.168.0.128:30090/api/v1/write"
rpi_loki_url          = "http://192.168.0.128:30100/loki/api/v1/push"
alloy_kubeconfig_path = "/Users/rainforest/.kube/config"
```

- [ ] **Step 4: Commit**

```bash
git add main.tf variables.tf terraform.tfvars
git commit -m "feat: wire grafana-alloy module into root config"
```

---

## Task 3: Deploy and verify

- [ ] **Step 1: Plan**

```bash
terraform plan
```

Expected: `1 to add` (docker_image.alloy + docker_container.alloy)

- [ ] **Step 2: Apply**

```bash
terraform apply
```

- [ ] **Step 3: Verify Alloy is healthy**

```bash
curl -s http://localhost:12345/-/healthy
```

Expected: `Alloy is Healthy.`

- [ ] **Step 4: Check Alloy debug UI — confirm components are running**

Open `http://localhost:12345` in browser. Go to **Graph** tab. All components should show green (no red errors). Key components to confirm:
- `loki.source.docker.containers` — should show discovered containers
- `loki.source.kubernetes.k8s_pods` — should show discovered pods
- `prometheus.exporter.cadvisor.containers` — should show container targets

- [ ] **Step 5: Verify logs arriving in Loki**

Open Grafana at `http://192.168.0.128:30080`. Go to **Explore → Loki datasource**.

Run this query to confirm Mac Mini Docker logs are flowing:
```logql
{job="docker"} | limit 20
```

Expected: log lines from Mac Mini containers (whisper, calibre-web, etc.)

Run this to confirm K8s pod logs:
```logql
{namespace="homelab"} | limit 20
```

Expected: log lines from open-webui, n8n, minio pods

- [ ] **Step 6: Verify metrics arriving in Prometheus**

In Grafana **Explore → Prometheus datasource**, run:
```promql
node_cpu_seconds_total{job="mac-mini-node"}
```

Expected: CPU metrics from Mac Mini

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "chore: verify alloy deployment on Mac Mini"
```
