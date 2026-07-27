# Theme C · Component 1 — Mac backup gap + tested restore

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or
> superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) tracking.
> This is infrastructure work (Terraform + k8s + backup tooling), so "tests" are real
> restores and actual command output — never a resource's "created" status.

**Goal:** Bring the Mac Mini's stateful data (Docker volumes + the Postgres DB holding all n8n
workflows) into the existing MinIO→Synology backup pipeline, and prove a restore.

**Architecture:** Mirror the Pi's proven `offen/docker-volume-backup` module onto the Mac to
archive Docker volumes nightly to MinIO (`AWS_S3_PATH=mac`). A k8s CronJob runs `pg_dumpall`
into a host directory that the same offen container also ships — so one tool carries both to
MinIO → Synology. Then restore one volume and the DB dump into throwaway targets and verify.

**Tech Stack:** Terraform (kreuzwerker/docker + hashicorp/kubernetes providers), offen
docker-volume-backup, MinIO (S3), Postgres 16 (`pg_dumpall`), Docker Desktop k8s.

---

## Preconditions (verified 2026-07-27)

| Fact | Value |
|---|---|
| Mac Docker volumes | `homelab-calibre-web-config`, `homelab-calibre-web-books`, `homelab-personal-calibre-app-data`, `homelab-rss-manager-app-data`, `homelab-whisper-models` |
| Postgres | k8s `homelab-postgresql-0`, PVC `homelab-postgresql-pvc` → hostPath PV (20Gi); DBs `n8n_db`, `flowise_db`, `homelab` |
| MinIO | helm on Mac, `:9000` on all interfaces; Synology Drive mounted via `var.synology_drive_path` |
| Pi backup template | `~/Repositories/rainforest-iot/modules/docker-volume-backup/` (offen, nightly 03:00, `AWS_S3_PATH=pi5`, stop-during-backup labels) |

---

## Status — reframed 2026-07-27 (Task 1 audit found a live outage)

Task 1's audit revealed the whole backup pipeline was **broken**, not just missing the Mac:
MinIO had **zero buckets**, so nightly Velero backups were `FailedValidation` and the Pi's
`docker-volume-backup` failed every night with `NoSuchBucket` — for days, silently.

**Done (commit `0ebae8d`):**
- Created the missing `velero` + `pi5-docker-backup` buckets → Pi backup now uploads (144MiB
  object landed), Velero backup `verify-upload` → `Completed` (9 objects in `velero`).
- Made buckets IaC-managed in `modules/minio` via a `null_resource` that ensures them and
  **self-heals on reinstall** (re-runs on release-revision change). Also pre-created
  `mac-docker-backup` for Task 2.

**Remaining:** Tasks 2–5 below (Mac Docker volumes + Postgres dump + prove restore) proceed as
written. Note the Synology nuance surfaced by the audit: only the `velero` bucket sits on the
Synology mount (`/data/velero`); `pi5-docker-backup` and `mac-docker-backup` are local-MinIO
only — Task 2 should decide whether Mac/Docker-volume backups also need the offsite copy.

---

### Task 1: Audit coverage and pin the exact wiring

No code yet — resolve the live values the later tasks depend on, and confirm the gap.

**Files:** none (record findings in the task's commit message / scratch)

- [ ] **Step 1: Confirm nothing on the Mac is backed up today**

```bash
# offen backup container on the Mac? (expect: none)
docker ps -a --filter ancestor=offen/docker-volume-backup --format '{{.Names}}' || true
# any CronJob dumping postgres? (expect: none)
kubectl get cronjob -n homelab
```

Expected: no offen container, no postgres CronJob → the gap is real.

- [ ] **Step 2: Pin the MinIO endpoint + credentials the backup will use**

```bash
# MinIO reachable from a Mac Docker container:
docker run --rm curlimages/curl -s -o /dev/null -w "%{http_code}\n" http://host.docker.internal:9000/minio/health/live
# Root creds source — the minio module generates them; find how the Pi module is fed:
grep -nE "minio_(root_user|root_password|access_key|secret_key)" ~/Repositories/rainforest-homelab/main.tf ~/Repositories/rainforest-homelab/modules/minio/outputs.tf
```

Record: the endpoint (`http://host.docker.internal:9000`), the bucket the Pi ships to
(`var.minio_bucket`), and the exact Terraform reference for the access/secret key
(`module.minio.*` output or `var.minio_access_key`). The later tasks use these names.

- [ ] **Step 3: Confirm which MinIO bucket/prefix lands on the Synology drive**

```bash
grep -nE "synology|mountPath|extraVolume|bucket" ~/Repositories/rainforest-homelab/modules/minio/main.tf
```

Record whether the Pi's target bucket is the Synology-backed one (so `AWS_S3_PATH=mac` in the
same bucket inherits the offsite copy) or whether a specific bucket must be used. If unclear,
the safe default is the **same bucket the Pi already uses**.

- [ ] **Step 4: Commit the findings note**

```bash
cd ~/Repositories/rainforest-homelab
# write docs/backup-coverage.md with the table of {source -> backed up? -> destination}
git add docs/backup-coverage.md && git commit -m "docs(backup): audit Mac-side backup coverage (Theme C1)"
```

---

### Task 2: Mac docker-volume-backup module (Docker volumes → MinIO)

**Files:**
- Create: `modules/docker-volume-backup/main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- Modify: `main.tf` (root — add the module block), `variables.tf` (root — backup vars)

- [ ] **Step 1: Create the module, mirroring the Pi's**

`modules/docker-volume-backup/main.tf` (mirror of `rainforest-iot/modules/docker-volume-backup`,
retargeted with `AWS_S3_PATH=mac` and the Mac's volumes):

```hcl
terraform {
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0", configuration_aliases = [docker] }
  }
}

resource "docker_image" "backup" {
  name = "offen/docker-volume-backup:${var.image_version}"
}

# Nightly backup of Mac Mini Docker volumes + the Postgres dump dir → MinIO (localhost)
# → Synology, using the same S3 pipeline as the Pi. AWS_S3_PATH=mac keeps the Mac's
# archives in a separate prefix from the Pi's (pi5).
resource "docker_container" "backup" {
  image   = docker_image.backup.image_id
  name    = "homelab-docker-volume-backup"
  restart = "unless-stopped"

  env = [
    "BACKUP_CRON_EXPRESSION=${var.backup_schedule}",
    "AWS_S3_BUCKET_NAME=${var.minio_bucket}",
    "AWS_ACCESS_KEY_ID=${var.minio_access_key}",
    "AWS_SECRET_ACCESS_KEY=${var.minio_secret_key}",
    "AWS_ENDPOINT=${var.minio_endpoint}",
    "AWS_ENDPOINT_PROTO=http",
    "AWS_S3_FORCE_PATH_STYLE=true",
    "AWS_S3_PATH=mac",
    "BACKUP_RETENTION_DAYS=${var.retention_days}",
    "BACKUP_PRUNING_PREFIX=backup-",
    "BACKUP_STOP_DURING_BACKUP_LABEL=docker-volume-backup.stop-during-backup",
    "BACKUP_FILENAME=backup-%Y%m%d-%H%M%S.tar.gz",
  ]

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  # Stateful app volumes (read-only). whisper-models is re-downloadable and books can be
  # large — include the config/data volumes that cannot be regenerated.
  volumes { volume_name = "homelab-calibre-web-config", container_path = "/backup/calibre-web-config", read_only = true }
  volumes { volume_name = "homelab-personal-calibre-app-data", container_path = "/backup/personal-calibre", read_only = true }
  volumes { volume_name = "homelab-rss-manager-app-data", container_path = "/backup/rss-manager", read_only = true }

  # Postgres logical dumps produced by the CronJob in Task 3 (host dir on the T7).
  volumes {
    host_path      = "${var.postgres_dump_host_path}"
    container_path = "/backup/postgres"
    read_only      = true
  }
}
```

- [ ] **Step 2: Module variables**

`modules/docker-volume-backup/variables.tf`:

```hcl
variable "image_version" { type = string, default = "v2.43.0" }
variable "backup_schedule" { type = string, default = "30 3 * * *" } # 03:30, after Pi (03:00) + pg dump (03:15)
variable "retention_days" { type = number, default = 14 }
variable "minio_bucket" { type = string }
variable "minio_endpoint" { type = string, default = "host.docker.internal:9000" }
variable "minio_access_key" { type = string, sensitive = true }
variable "minio_secret_key" { type = string, sensitive = true }
variable "postgres_dump_host_path" { type = string }
```

`modules/docker-volume-backup/versions.tf`: copy the `required_providers` docker block from an
existing module (e.g. `modules/whisper/versions.tf`).

`modules/docker-volume-backup/outputs.tf`:

```hcl
output "container_name" { value = docker_container.backup.name }
```

- [ ] **Step 3: Wire the module in root `main.tf`**

Use the MinIO reference confirmed in Task 1 (shown here as the module outputs):

```hcl
module "docker_volume_backup" {
  source                  = "./modules/docker-volume-backup"
  providers               = { docker = docker }
  minio_bucket            = var.minio_bucket
  minio_access_key        = module.minio.root_user
  minio_secret_key        = module.minio.root_password
  postgres_dump_host_path = "${var.external_storage_path}/postgres-backups"
}
```

If `module.minio` does not output `root_user`/`root_password`, add those outputs to
`modules/minio/outputs.tf` first (they exist as `minio_root_user` / the `random_password`).

- [ ] **Step 4: Format, validate, plan**

```bash
cd ~/Repositories/rainforest-homelab
terraform fmt -recursive >/dev/null
terraform validate
terraform plan -target=module.docker_volume_backup 2>&1 | grep -iE "will be created|Plan:|Error"
```

Expected: `docker_image.backup` + `docker_container.backup` will be created; `Plan: 2 to add`.
(The postgres host dir is created by Task 3 before first run.)

- [ ] **Step 5: Commit (do NOT apply yet — Task 3 creates the dump dir first)**

```bash
git add modules/docker-volume-backup/ main.tf variables.tf
git commit -m "feat(backup): Mac docker-volume-backup module -> MinIO (Theme C1)"
```

---

### Task 3: Postgres logical dump CronJob

**Files:**
- Create: `modules/postgres-backup/main.tf`, `variables.tf`, `versions.tf`
- Modify: `main.tf` (root — add module block)

- [ ] **Step 1: CronJob that runs `pg_dumpall` into the shared host dir**

`modules/postgres-backup/main.tf` — a k8s CronJob in `homelab`, using the same Postgres image,
writing a gzipped dump to a hostPath the offen container also mounts:

```hcl
resource "kubernetes_cron_job_v1" "pg_dump" {
  metadata { name = "postgres-backup", namespace = var.namespace }
  spec {
    schedule                      = var.schedule          # "15 3 * * *"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3
    concurrency_policy            = "Forbid"
    job_template {
      metadata { labels = { app = "postgres-backup" } }
      spec {
        backoff_limit = 2
        template {
          metadata { labels = { app = "postgres-backup" } }
          spec {
            restart_policy = "Never"
            container {
              name    = "pg-dump"
              image   = var.postgres_image           # match homelab-postgresql image/tag
              command = ["/bin/sh", "-c"]
              args    = ["set -e; ts=$(date +%Y%m%d-%H%M%S); pg_dumpall -h $PGHOST -U postgres | gzip > /dump/pg_dumpall-$ts.sql.gz; ls -1t /dump/pg_dumpall-*.sql.gz | tail -n +${var.keep + 1} | xargs -r rm -f; echo dumped"]
              env {
                name = "PGPASSWORD"
                value_from { secret_key_ref { name = "homelab-postgresql-auth", key = "postgres-password" } }
              }
              env { name = "PGHOST", value = "homelab-postgresql" }
              volume_mount { name = "dump", mount_path = "/dump" }
            }
            volume {
              name = "dump"
              host_path { path = var.dump_host_path, type = "DirectoryOrCreate" } # = external_storage_path/postgres-backups
            }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Variables + wire in root**

`modules/postgres-backup/variables.tf`: `namespace`, `schedule` (default `"15 3 * * *"`),
`postgres_image` (read from `kubectl get statefulset homelab-postgresql -o jsonpath` — set it
explicitly, no `latest`), `dump_host_path`, `keep` (default 7).

Root `main.tf`:

```hcl
module "postgres_backup" {
  source         = "./modules/postgres-backup"
  namespace      = "homelab"
  postgres_image = "<exact image:tag from the running statefulset>"
  dump_host_path = "${var.external_storage_path}/postgres-backups"
  keep           = 7
}
```

- [ ] **Step 3: Apply postgres-backup, then trigger one run and verify the dump exists**

```bash
cd ~/Repositories/rainforest-homelab
terraform apply -target=module.postgres_backup -auto-approve 2>&1 | grep -iE "Apply complete|Error"
# trigger immediately instead of waiting for 03:15
kubectl create job -n homelab pg-dump-manual --from=cronjob/postgres-backup
kubectl wait -n homelab --for=condition=complete job/pg-dump-manual --timeout=180s
kubectl logs -n homelab job/pg-dump-manual | tail -2
ls -lh "/Volumes/Samsung T7 Touch/homelab-data/postgres-backups/"
```

Expected: log prints `dumped`; a `pg_dumpall-*.sql.gz` file exists and is non-trivial in size.

- [ ] **Step 4: Verify the dump actually contains the n8n data (not an empty/errored dump)**

```bash
F=$(ls -1t "/Volumes/Samsung T7 Touch/homelab-data/postgres-backups/"/pg_dumpall-*.sql.gz | head -1)
gzip -dc "$F" | grep -c "CREATE DATABASE n8n_db"        # expect 1
gzip -dc "$F" | grep -c "workflow_entity"                # expect > 0 (the n8n workflow table)
```

Expected: the dump references `n8n_db` and `workflow_entity` → the workflows are captured.

- [ ] **Step 5: Commit**

```bash
git add modules/postgres-backup/ main.tf
git commit -m "feat(backup): nightly postgres pg_dumpall CronJob (Theme C1)"
```

---

### Task 4: Apply the volume backup and prove one full backup cycle

**Files:** none (apply + verify)

- [ ] **Step 1: Add stop-during-backup labels to app containers that write mid-backup**

For calibre-web / rss-manager containers (in their modules), add the label so offen quiesces
them during the archive — mirror the Pi pattern:

```hcl
labels { label = "docker-volume-backup.stop-during-backup", value = "true" }
```

(Only if the container writes continuously; calibre config is low-churn, so this is optional —
note the decision in the commit.)

- [ ] **Step 2: Apply the offen module and run a backup on demand**

```bash
cd ~/Repositories/rainforest-homelab
terraform apply -target=module.docker_volume_backup -auto-approve 2>&1 | grep -iE "Apply complete|Error"
docker exec homelab-docker-volume-backup backup   # run now instead of waiting for 03:30
docker logs homelab-docker-volume-backup --tail=20
```

Expected: log shows each `/backup/<name>` archived and uploaded to MinIO with no errors.

- [ ] **Step 3: Confirm the archive landed in MinIO under the `mac/` prefix**

```bash
docker run --rm --entrypoint sh minio/mc -c "\
  mc alias set m http://host.docker.internal:9000 <access> <secret> >/dev/null && \
  mc ls --recursive m/<bucket>/mac/ | tail -10"
```

Expected: a `backup-<timestamp>.tar.gz` object under `mac/`.

- [ ] **Step 4: Commit any label changes**

```bash
git add modules/calibre-web modules/rss-manager
git commit -m "chore(backup): quiesce app volumes during backup (Theme C1)"
```

---

### Task 5: Prove a RESTORE (the task that makes the backups real)

**Files:** none (restore into throwaway targets, verify, discard)

- [ ] **Step 1: Restore one Docker volume into a throwaway volume and inspect**

```bash
# pull the newest mac archive that contains calibre-web-config
docker run --rm --entrypoint sh minio/mc -c "\
  mc alias set m http://host.docker.internal:9000 <access> <secret> >/dev/null && \
  mc cp m/<bucket>/mac/$(mc ls m/<bucket>/mac/ | awk '{print $NF}' | tail -1) /tmp/" # or copy to host
docker volume create restore-test
# extract the calibre-web-config subtree from the archive into the throwaway volume
docker run --rm -v restore-test:/out -v /tmp:/in alpine \
  sh -c "tar xzf /in/<archive>.tar.gz -C /out --strip-components=1 backup/calibre-web-config && ls -la /out | head"
```

Expected: the restored volume contains calibre-web's config files (e.g. `app.db` / metadata).

- [ ] **Step 2: Restore the Postgres dump into a throwaway database and verify a workflow row**

```bash
# spin a throwaway postgres, load the dump, count n8n workflows
F=$(ls -1t "/Volumes/Samsung T7 Touch/homelab-data/postgres-backups/"/pg_dumpall-*.sql.gz | head -1)
docker run -d --name pg-restore-test -e POSTGRES_PASSWORD=x postgres:16
sleep 8
gzip -dc "$F" | docker exec -i pg-restore-test psql -U postgres >/dev/null 2>&1
docker exec pg-restore-test psql -U postgres -d n8n_db -tAc "select count(*) from workflow_entity;"
```

Expected: a count matching the six live workflows (± any inactive) → the DB restore works.

- [ ] **Step 3: Tear down the throwaway targets**

```bash
docker rm -f pg-restore-test; docker volume rm restore-test; rm -f /tmp/<archive>.tar.gz
```

- [ ] **Step 4: Write the restore runbook**

Create `configs/backup/RESTORE.md` documenting, for each source: where the archive lives
(MinIO `mac/` + Synology), the exact restore commands proven above, and the verification check.

- [ ] **Step 5: Commit**

```bash
git add configs/backup/RESTORE.md
git commit -m "docs(backup): tested restore runbook for Mac sources (Theme C1)"
```

---

## Verification (whole component)

1. A `pg_dumpall-*.sql.gz` is produced nightly and contains `n8n_db` + `workflow_entity`.
2. The offen container archives the Mac volumes + the postgres dump dir to MinIO under `mac/`.
3. The `mac/` prefix inherits the Synology offsite copy (same bucket as the Pi).
4. A Docker volume AND the Postgres dump were **restored into throwaway targets and inspected**,
   not merely listed.
5. `configs/backup/RESTORE.md` documents each proven restore.

## Notes for the implementer

- Reuse the Pi module verbatim where possible — same image, same env var names, only
  `AWS_S3_PATH`, the volume list, and the endpoint differ.
- Never back up the raw Postgres data dir; the logical `pg_dumpall` is the restorable artifact.
- Isolate commits to the new `modules/docker-volume-backup`, `modules/postgres-backup`, and the
  root module blocks — the repo has extensive unrelated in-flight work; do not stage it.
