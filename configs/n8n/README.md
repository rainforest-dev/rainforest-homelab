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
`Obsidian Local REST API` (id `obsidianrestapi1`). It is **not** in git — recreate it from
`obsidian_api_key` in `terraform.tfvars`.

```bash
python3 - /tmp/cred.json <<'EOF'
import re, sys, json
tf = open('terraform.tfvars').read()
key = re.search(r'obsidian_api_key\s*=\s*"([^"]+)"', tf).group(1)
json.dump([{
    "id": "obsidianrestapi1",
    "name": "Obsidian Local REST API",
    "type": "httpHeaderAuth",
    "nodesAccess": [{"nodeType": "n8n-nodes-base.httpRequest"}],
    "data": {"name": "Authorization", "value": f"Bearer {key}"},
}], open(sys.argv[1], 'w'))
EOF
chmod 600 /tmp/cred.json
kubectl cp /tmp/cred.json "homelab/$POD:/tmp/cred.json"
kubectl exec -n homelab "$POD" -- n8n import:credentials --input=/tmp/cred.json
kubectl exec -n homelab "$POD" -- rm -f /tmp/cred.json && rm -f /tmp/cred.json
```

The credential must be a JSON **array** and include `nodesAccess`, or the import fails with
an unhelpful "An error occurred while importing credentials".

Do not substitute `$env.OBSIDIAN_API_KEY` for the credential. n8n 2.x denies env access in
expressions by default, and enabling it (`N8N_BLOCK_ENV_ACCESS_IN_NODE=false`) would let
every workflow read the Postgres password.

### 2. Import the workflow

```bash
kubectl cp configs/n8n/workflows/homelab-health-digest.json "homelab/$POD:/tmp/wf.json"
kubectl exec -n homelab "$POD" -- n8n import:workflow --input=/tmp/wf.json
```

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

### `voice-memo-transcription.json` — every 2 min

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

### `ha-event-bridge.json` — webhook (always active)

The n8n side of the Home Assistant → n8n bridge (Theme A Component 2). A `POST` webhook
receives home events and appends one bullet to the Obsidian daily note.

**Endpoint (LAN, no Cloudflare):** `http://192.168.0.126:5678/webhook/ha-events`
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
