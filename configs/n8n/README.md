# n8n workflows

Workflow definitions kept in git so they survive a machine rebuild.

## Restore after a rebuild

Everything below runs against the n8n CLI **inside the pod**. That path is used
deliberately: the n8n public API cannot create credentials, its `/rest/*` endpoints
require a session cookie, and the `n8n_create_workflow` MCP tool is broken in the
currently-pinned n8n-mcp build (fails with `Cannot read properties of undefined
(reading '_zod')`). The CLI needs none of them.

```bash
POD=$(kubectl get pod -n homelab -l app=n8n -o jsonpath='{.items[0].metadata.name}')
```

### 1. Recreate the Obsidian credential

Workflows authenticate to the Obsidian Local REST API through an n8n credential named
`Obsidian Local REST API` (id `obsidianrestapi1`, Header Auth). The n8n database is the only
place the key lives: it is **not** in git, and Terraform no longer passes it anywhere.

To change the key, edit the credential in the n8n UI (**Credentials → Obsidian Local REST API**):
Name `Authorization`, Value `Bearer <key>`. It takes effect at once for every workflow that uses it.

To recreate it from scratch, read the key from the Obsidian plugin's own settings, so it can
never be a stale copy:

```bash
PLUGIN="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/rainforest-obsidian/.obsidian/plugins/obsidian-local-rest-api/data.json"
python3 - "$PLUGIN" /tmp/cred.json <<'EOF'
import sys, json
key = json.load(open(sys.argv[1]))['apiKey']
json.dump([{
    "id": "obsidianrestapi1",
    "name": "Obsidian Local REST API",
    "type": "httpHeaderAuth",
    "nodesAccess": [{"nodeType": "n8n-nodes-base.httpRequest"}],
    "data": {"name": "Authorization", "value": f"Bearer {key}"},
}], open(sys.argv[2], 'w'))
EOF
chmod 600 /tmp/cred.json
kubectl cp /tmp/cred.json "homelab/$POD:/tmp/cred.json"
kubectl exec -n homelab "$POD" -- n8n import:credentials --input=/tmp/cred.json
kubectl exec -n homelab "$POD" -- rm -f /tmp/cred.json && rm -f /tmp/cred.json
```

The credential must be a JSON **array** and include `nodesAccess`, or the import fails with
an unhelpful "An error occurred while importing credentials".

Do not pass the key to workflows through an environment variable. n8n 2.x denies env access in
expressions by default, and enabling it (`N8N_BLOCK_ENV_ACCESS_IN_NODE=false`) would let
every workflow read the Postgres password. The old `OBSIDIAN_API_KEY` env and the
`obsidian_api_key` tfvar were removed for this reason on 2026-10-14; delete the line from
`terraform.tfvars` if it is still there.

### 1b. Inbox secrets (shared inbox only)

`shared-inbox` needs two more credentials, also not in git, each with its own secret:

- `Inbox secret` (id `inboxsecret00001`, header `x-inbox-secret`, from
  `terraform output -raw inbox_secret`): what n8n sends to personal-calibre with a bujo scan.
- `Inbox upload secret` (id `inboxupload00001`, header `x-inbox-upload-secret`, from
  `terraform output -raw inbox_upload_secret`): what an uploader must send to the
  `/webhook/inbox-upload-0001/inbox/<target>` webhook. Kept separate so an upload client never holds the key
  calibre trusts.

```bash
python3 - /tmp/cred.json "$(terraform output -raw inbox_secret)" \
  "$(terraform output -raw inbox_upload_secret)" <<'PY'
import sys, json
out, secret, upload = sys.argv[1:]
json.dump([
    {"id": "inboxsecret00001", "name": "Inbox secret", "type": "httpHeaderAuth",
     "nodesAccess": [{"nodeType": "n8n-nodes-base.httpRequest"}],
     "data": {"name": "x-inbox-secret", "value": secret}},
    {"id": "inboxupload00001", "name": "Inbox upload secret", "type": "httpHeaderAuth",
     "nodesAccess": [{"nodeType": "n8n-nodes-base.webhook"}],
     "data": {"name": "x-inbox-upload-secret", "value": upload}},
], open(out, "w"))
PY
chmod 600 /tmp/cred.json
kubectl cp /tmp/cred.json "homelab/$POD:/tmp/cred.json"
kubectl exec -n homelab "$POD" -- n8n import:credentials --input=/tmp/cred.json
kubectl exec -n homelab "$POD" -- rm -f /tmp/cred.json && rm -f /tmp/cred.json
```

### 2. Import the workflow

**Substitute the Prometheus host first.** This repository is public, so the committed
workflows carry the placeholder `PROMETHEUS_HOST_SUBSTITUTE_ME` instead of the Pi's LAN
address. The placeholder is deliberately un-resolvable: an un-substituted import fails
loudly instead of silently querying nothing. Put the real address in `PI_IP`:

```bash
PI_IP=<the Pi's LAN IP>   # same value as raspberry_pi_ip in terraform.tfvars
sed "s/PROMETHEUS_HOST_SUBSTITUTE_ME/$PI_IP/g" \
  configs/n8n/workflows/homelab-health-digest.json > /tmp/wf.json
kubectl cp /tmp/wf.json "homelab/$POD:/tmp/wf.json"
kubectl exec -n homelab "$POD" -- n8n import:workflow --input=/tmp/wf.json
```

Workflows carrying the placeholder: `homelab-health-digest`, `homelab-incident-log`,
`ai-home-query`. The others have no hard-coded host.

The JSON carries a stable `id`, so re-importing updates in place rather than creating a
duplicate.

### 3. Activate

```bash
kubectl exec -n homelab "$POD" -- n8n update:workflow --id=homelabhealthdig --active=true
kubectl rollout restart deployment/homelab-n8n -n homelab
```

The restart is required — the CLI warns that changes do not take effect while n8n is
running.

## Running a workflow on demand

Each workflow carries a `Run now` (`executeWorkflowTrigger`) node alongside its schedule,
so it can be executed without the UI:

```bash
kubectl exec -n homelab "$POD" -- sh -c '
  export N8N_RUNNERS_BROKER_PORT=5690 N8N_RUNNERS_BROKER_LISTEN_ADDRESS=127.0.0.1
  n8n execute --id=homelabhealthdig'
```

The broker port override is required: the default 5679 is already held by the running n8n.

## Workflows

### `homelab-health-digest.json` — daily 08:10

Reads firing Prometheus alerts and Home Assistant sensor values, summarises them with
Ollama, and appends a "Homelab health" section to the Obsidian daily note. It runs after
the `rss-daily-digest` routine (08:03) so both land in the same note.

Design: `docs/superpowers/specs/2026-07-26-theme-a-homelab-health-digest-design.md`

Two constraints worth preserving when editing:

- **Nodes are chained serially, not fanned in.** Two nodes feeding the same input of a
  third do *not* wait for each other — n8n runs the first branch to completion, so the
  second node is still unexecuted when `$('Fetch sensors')` is evaluated.
- **The raw alert list is written alongside the model's summary** on purpose. The summary
  can be vague or wrong; the underlying facts must survive.

### `voice-memo-transcription.json` — superseded by `shared-inbox`

**Keep this workflow inactive.** `shared-inbox` now handles voice (its `voice` target) and
still scans the legacy T7 folder below, so running both would transcribe each file twice.
The file stays in git for its history and constraints, which `shared-inbox` inherits.

```bash
kubectl exec -n homelab "$POD" -- n8n update:workflow --id=<voice workflow id> --active=false
```

Original description (every 2 min):

Watches a drop folder, transcribes any new audio with the self-hosted Whisper STT service,
and writes one Obsidian note per recording into the `Voice memos/` folder.

**Usage:** drop an audio file (`.m4a`, `.aiff`, `.mp3`, …) into
`/Volumes/Samsung T7 Touch/homelab-data/voice-inbox/` on the Mac Mini. Within ~2 minutes a
note named after the file (e.g. `standup-notes.md`) appears in `Voice memos/`, with the
transcript in the body and `source` / `date` / `transcribed` frontmatter.

Design: `docs/superpowers/specs/2026-07-26-theme-a-homelab-health-digest-design.md` (Component 3)

Four constraints worth preserving when editing:

- **The inbox is mounted inside `/home/node/.n8n-files`, not `/data`.** n8n 2.x sandboxes
  the `readWriteFile` node to `/home/node/.n8n-files`; the hostPath mount
  (`modules/n8n/main.tf`) and the node's `fileSelector` must both stay under that prefix,
  or the read fails with *"Access to the file is not allowed."*
- **Idempotency is by note existence, not by moving files.** `executeCommand` is
  unregistered under task-runner mode and `readWriteFile` cannot delete, so files are never
  removed from the inbox. Instead, `List processed` fetches the `Voice memos/` folder once
  and the `Filter new` Code node drops any audio whose note already exists. The dedup key is
  the **basename** (no date prefix) so a file is transcribed exactly once, even if it lingers
  past midnight.
- **The existence check is a single folder listing, done before the read.** An inline
  per-file GET cannot be used: n8n's HTTP node replaces an item's binary with the response,
  which would destroy the audio before Whisper sees it. Filtering happens in a Code node
  (pure JS, no network) that reads `$('List processed')` and passes binary through.
- **An empty inbox is a clean no-op.** `Read audio files` has `continueOnFail`, so a run
  with nothing to do still ends `success` and never spams the execution log.

### `shared-inbox.json` — every 2 min + webhook

One inbox for every target:

| Target | Drop into iCloud Drive | Delivered to |
|---|---|---|
| `bujo` | `Inbox/bujo/<notebook>/` | personal-calibre `POST /api/inbox/bujo` (needs `CALIBRE_INBOX_SECRET`) |
| `voice` | `Inbox/voice/` (and the legacy T7 `voice-inbox/`) | Whisper, then an Obsidian note in `Voice memos/` |
| `memories` | `Inbox/memories/` | not n8n: the `memories-auto-import` launchd job watches it |

**Upload instead of a folder:** `POST http://<MAC_MINI_IP>:5678/webhook/inbox-upload-0001/inbox/<target>`,
multipart, one file per request, plus `notebook` for bujo, with the header
`x-inbox-upload-secret: <terraform output -raw inbox_upload_secret>`. Unlike `ha-events`,
this webhook checks a header even on the LAN: what it accepts lands in calibre and the
vault. The public `n8n.rainforest.tools` route also sits behind Access. The
`inbox-upload-0001` segment is the node's `webhookId`: n8n prefixes it to any path with a
`:param`, so `/webhook/inbox/<target>` answers 404 "not registered".

```bash
curl -fsS -H "x-inbox-upload-secret: $(terraform output -raw inbox_upload_secret)" \
  -F data=@page.jpg -F notebook=2026-A5 http://<MAC_MINI_IP>:5678/webhook/inbox-upload-0001/inbox/bujo
```

Constraints worth preserving when editing:

- **Only `Inbox/` is mounted** (`inbox_host_path`, default
  `~/Library/Mobile Documents/com~apple~CloudDocs/Inbox`), at
  `/home/node/.n8n-files/inbox`, inside the `readWriteFile` sandbox. Never widen it to all of
  iCloud Drive. Set Finder's **Keep Downloaded** on `Inbox/`: an evicted file is a
  `.name.icloud` placeholder, which the scan skips until it is local again.
- **Idempotency is a ledger, not moving files**, for the same reason as the voice workflow
  (`readWriteFile` cannot delete). `Pick new` keys each file by target, path and size in
  `$getWorkflowStaticData('global')`. Voice also keeps the old "note already exists" check,
  so files the old workflow transcribed are not redone.
- **Three attempts, then a report.** A file that fails three runs is marked rejected and
  posted once to `ha-events` as `inbox_rejected`, so it shows up in the daily note. Renaming
  the file retries it. The delivery nodes send a failed item to their error output, so one
  bad file never fails the run or counts against the rest of its batch.
- **Delivery is the target app's job.** n8n only routes; the bujo branch forwards the file to
  personal-calibre, which owns cropping, storage and dedup (by content hash).

Not verified against a live n8n yet: that `readWriteFile` sets `binary.directory` for files in
subfolders (the bujo notebook name comes from it) and that static data persists from these
Code nodes under task runners. Check the first real run.

**Agents** use the existing `n8n` server in the Docker MCP gateway; there is no separate inbox
MCP. To deliver a file, an agent uploads it to the webhook above or writes it into the folder;
`n8n_trigger_webhook_workflow` sends JSON only, so it cannot carry a file. The table above is
the whole contract an agent needs.

### `ha-event-bridge.json` — webhook (always active)

The n8n side of the Home Assistant → n8n bridge (Theme A Component 2). A `POST` webhook
receives home events and appends one bullet to the Obsidian daily note.

**Endpoint (LAN, no Cloudflare):** `http://<MAC_MINI_IP>:5678/webhook/ha-events`
(the Mac Mini's LAN IP; Docker Desktop publishes the n8n LoadBalancer on `*:5678`, so the
Pi — where Home Assistant runs — reaches it directly).

**Payload contract** (all fields optional; defensive defaults in the Code node):

```json
{ "event": "bambii_music_on", "detail": "living room", "ts": "2026-07-27T15:30:45+08:00" }
```

`ts` is HA's own local-time string — n8n extracts `HH:MM` from it verbatim rather than
doing timezone math (the container clock is UTC and `GENERIC_TIMEZONE` is America/New_York,
neither of which is home time). Result in the daily note:
`- 15:30 **bambii_music_on** — living room #home-event`.

Design: `docs/superpowers/specs/2026-07-26-theme-a-homelab-health-digest-design.md` (Component 2)

Two constraints worth preserving when editing:

- **Webhooks register only at n8n startup.** `update:workflow --active=true` flips the DB
  flag but the running process will not serve the route until it reloads active workflows —
  `n8n` itself prints *"Please restart n8n for changes to take effect."* After importing or
  activating a webhook workflow, `kubectl rollout restart deployment/homelab-n8n` (this
  re-registers every active workflow, not just this one). Verify with a real POST, not the
  DB flag.
- **The Home Assistant side is separate.** HA reaches this endpoint via a `rest_command`
  called from an HA automation; that config lives in the `rainforest-iot` repo
  (`modules/homeassistant`), injected into `/config/configuration.yaml` with the same
  `null_resource` + base64-append pattern as the existing proxy/prometheus blocks.

### `homelab-incident-log.json` — every 5 min

Polls Prometheus for firing alerts and logs each service that needs fixing **when it
breaks and when it recovers** — the event-driven complement to the once-a-day health
digest. Covers both machines (the Pi's Prometheus scrapes the Mac). Reuses Component 1's
alert query `ALERTS{alertstate="firing",alertname!="Watchdog"}` against
`http://<PI_IP>:30090`. Result in the daily note, e.g.:

```
- 15:29 🔴 down: **KubePodCrashLooping** monitoring/speedtest-exporter-… _(sev: warning)_ #homelab-incident
- 15:41 🟢 recovered: **KubePodCrashLooping** monitoring/speedtest-exporter-… _(sev: warning)_ #homelab-incident
```

Three constraints worth preserving when editing:

- **Only state *transitions* are logged, never the standing set.** The `Diff + build` Code
  node keeps the open-incident set in `$getWorkflowStaticData('global').firing` and emits
  only the edges (newly down / newly recovered), so a chronically-broken service is logged
  once, not every 5 minutes. Verified: static data persists across runs, and
  `import:workflow` preserves it (so re-importing the definition does not reset the state).
- **One incident per `alertname|namespace|pod|instance`.** Prometheus emits several
  label-series per alert; the fingerprint collapses them so a single failure is one bullet.
- **No Ollama summary here — raw facts only.** The daily digest does the prose; this log is
  the ground truth that must survive a vague summary. Timestamps are `Asia/Taipei`
  (n8n's `GENERIC_TIMEZONE` is America/New_York, which is not home time).

> Note: on a fresh n8n database the open-incident state is empty, so the first poll logs
> every currently-firing alert once as `🔴 down` — an intentional initial snapshot.

### `ai-home-query.json` — webhook (always active)

Answers a natural-language home question by having Ollama write a PromQL query, running it
against Prometheus, and having Ollama phrase the result. Component 5.

**Ask:** `POST http://<MAC_MINI_IP>:5678/webhook/home-query` with `{"question": "how is the humidity?"}`
→ responds `{"answer": "The humidity is currently 42.", "promql": "...", "data": "..."}`.

Two constraints worth preserving when editing:

- **Guard the small model with deterministic code, don't trust it to reason.** `gemma4:e4b-mlx`
  will over-filter (`up{job=~".*homelab.*"}` matches nothing) unless the prompt explicitly
  forbids it, so the PromQL prompt carries hard rules + examples and `temperature: 0`. The
  empty-result meaning is decided in the `Build answer prompt` Code node (`up == 0` empty =
  "all healthy", not "sensor missing"), never left to the model.
- **Best at current-state questions.** Instant queries about sensors/services are reliable;
  historical/range questions ("was it humid last night?") are not yet supported.

### `bambii-care-reminder.json` — daily 08:15

Appends a Bambii care checklist to the Obsidian daily note each morning (Component 4, the
reminder half; the activity-logging half is the HA `bambii_music` → webhook path). The
checklist in the `Build reminder` node is a **starter template — edit it** to match Bambii's
real routine (meds, vet dates).

## Re-importing a workflow (IMPORTANT)

`n8n import:workflow` **sets the workflow `active = false`**, silently unregistering any
webhook (`POST` returns `404 "Active version not found"`) and dropping schedule triggers.
After re-importing an active workflow, always:

```bash
kubectl exec -n homelab "$POD" -- n8n update:workflow --id=<id> --active=true
kubectl rollout restart deployment/homelab-n8n -n homelab   # re-registers routes/schedules
```

Then verify with a real call, never the DB flag alone.
