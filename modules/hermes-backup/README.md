# hermes-backup

A launchd agent (`tools.rainforest.hermes-backup`) that runs `hermes backup` every night at 04:30
into `backup_dir` on the T7 and keeps the newest 14 zips. Each zip holds all of `~/.hermes` except
the `hermes-agent` checkout: `config.yaml`, `.env`, `auth.json`, `SOUL.md`, profiles, skills,
plugins, memories, cron, `state.db` and sessions. That is about 165 MB, written in about 15 s
(measured 2026-10-29).

The zips hold Hermes's secrets (`.env`, `auth.json`) in plain text. The directory is `0700` and the
job runs with `umask 077`, but that only holds on this Mac: the T7 is unencrypted APFS with owners
disabled, so anyone who plugs it into another machine can read every zip. Encrypting the T7, or
moving `backup_dir` to an encrypted volume, is what protects them.

The run is skipped and logged when the T7 is not mounted. Log: `~/Library/Logs/hermes-backup.log`.

## First run

macOS asks once whether Hermes's Python may access a removable volume. Until someone clicks
Allow on the Mac, the first run blocks inside `open()` with no error. Approve it, or add Hermes's
`python3` (under `~/.hermes/tools/python-*/bin/`) in System Settings → Privacy & Security → Files
and Folders → Removable Volumes. Then check that a new zip appears:

```bash
launchctl kickstart gui/$(id -u)/tools.rainforest.hermes-backup
ls -l "/Volumes/Samsung T7 Touch/homelab-data/hermes-backups"
```

## Restore on a new machine

1. Install Hermes with the official installer, then switch to the release the zip came from
   (`hermes update --set-channel stable`).
2. `hermes import <zip>`.
3. Reapply the local patches in `~/.hermes/local-patches` (they also come back with the import),
   because the checkout itself is not in the zip.
4. `enable_hermes_backup = true` and `terraform apply` to put the nightly job back.
