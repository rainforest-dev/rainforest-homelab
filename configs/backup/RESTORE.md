# Backup & restore runbook

The homelab backs up to **MinIO on the Mac Mini** (`host.docker.internal:9000`, LAN
`192.168.0.126:9000`). Buckets are guaranteed to exist by `modules/minio` (a `null_resource`
that self-heals on reinstall — see the 2026-07 outage note below).

| Bucket | Contents | Offsite (Synology `/data/velero`)? |
|---|---|---|
| `velero` | Entire Pi k3s cluster (Velero, daily 02:00) | **Yes** |
| `pi5-docker-backup` | Pi Docker volumes (HA, Pi-hole, Music Assistant, homebridge…), nightly 03:00, prefix `pi5/` | No (local MinIO only) |
| `mac-docker-backup` | Mac Docker volumes + Postgres dump, nightly 03:30, prefix `mac/` | No (local MinIO only) |

> **2026-07 outage:** MinIO was reinstalled and lost its buckets; because the buckets were not
> IaC-managed, every Velero and docker-volume-backup upload failed silently for days. Fixed by
> `modules/minio`'s `null_resource "minio_buckets"`. If backups ever fail with `NoSuchBucket`
> or Velero shows `FailedValidation`, run `terraform apply -target=module.minio.null_resource.minio_buckets`.

## Credentials

MinIO root creds live in the k8s secret `homelab-minio` (namespace `homelab`), keys
`rootUser` / `rootPassword`. The password contains URL-unsafe characters, so always use
`mc alias set` with separate arguments — never `MC_HOST=http://user:pass@host`:

```bash
RU=$(kubectl get secret homelab-minio -n homelab -o jsonpath='{.data.rootUser}' | base64 -d)
RP=$(kubectl get secret homelab-minio -n homelab -o jsonpath='{.data.rootPassword}' | base64 -d)
alias mc='docker run --rm -e RU="$RU" -e RP="$RP" -v "$PWD":/w -w /w --entrypoint sh minio/mc -c'
mc 'mc alias set m http://host.docker.internal:9000 "$RU" "$RP" >/dev/null && mc ls m/'
```

## Restore a Mac Docker volume (proven 2026-07-27)

```bash
# 1. Download the newest Mac archive
mc 'mc alias set m http://host.docker.internal:9000 "$RU" "$RP" >/dev/null; \
    KEY=$(mc ls m/mac-docker-backup/mac/ | tail -1 | sed -E "s/.* ([^ ]+\.tar\.gz)$/\1/"); \
    mc cp m/mac-docker-backup/mac/$KEY /w/restore.tar.gz'

# 2. Extract the volume subtree into a throwaway (or the real) volume
docker volume create restore-test
docker run --rm -v restore-test:/out -v "$PWD":/in alpine \
  tar xzf /in/restore.tar.gz -C /out --strip-components=2 backup/calibre-web-config

# Verify: app.db / config files present.  To restore for real, extract into the live volume
# (stop the app container first).
```

## Restore the Postgres database (proven 2026-07-27)

The nightly `pg_dumpall` is inside every Mac archive at `backup/postgres/pg_dumpall-*.sql.gz`
and also on the T7 at `/Volumes/Samsung T7 Touch/homelab-data/postgres-backups/`.

```bash
# Into a throwaway DB to verify (recovers n8n_db, flowise_db, homelab):
DUMP=$(ls -1t "/Volumes/Samsung T7 Touch/homelab-data/postgres-backups/"/pg_dumpall-*.sql.gz | head -1)
docker run -d --name pg-restore-test -e POSTGRES_PASSWORD=x postgres:16-alpine
until docker exec pg-restore-test pg_isready -U postgres; do sleep 2; done
gzip -dc "$DUMP" | docker exec -i pg-restore-test psql -U postgres
docker exec pg-restore-test psql -U postgres -d n8n_db -tAc 'select count(*) from workflow_entity;'
docker rm -f pg-restore-test

# To restore into the LIVE cluster Postgres (destructive — coordinate downtime):
#   gzip -dc "$DUMP" | kubectl exec -i -n homelab homelab-postgresql-0 -- \
#     sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres'
```

## Verified restore drill — 2026-07-27

- `calibre-web-config` restored → `app.db`, `client_secrets.json`, `gdrive.db` present.
- Postgres dump restored into a throwaway DB → all 7 n8n workflows recovered by name.

Re-run this drill after any change to the backup pipeline. **A backup is not "done" until its
restore has been demonstrated.**
