# Voice memo transcription implementation plan

> **For agentic workers:** Theme A Component 3. Built iteratively in-session (the
> workflow is tightly coupled and its file/binary handling needs runtime testing), not
> dispatched task-by-task. Steps use checkbox (`- [x]`) tracking.

**Goal:** Drop an audio file into a watched folder on the T7; n8n transcribes it with the
(now-working) Whisper service and files the transcript as an Obsidian note, then moves the
audio to `processed/`.

**Architecture:** One n8n workflow, polled on a schedule (inotify does not cross the Docker
Desktop VM boundary). Reads the mounted folder, POSTs each audio file to Whisper's
OpenAI-compatible endpoint, creates a note via the Obsidian REST API, and `mv`s the file to
`processed/` for idempotency.

**Tech Stack:** n8n (Kubernetes), Whisper (`host.docker.internal:9090`), Obsidian Local
REST API (`host.docker.internal:27124`), a hostPath mount of the Samsung T7.

---

## As-built (completed 2026-07-27) — diverged from plan in three ways

Two preconditions below turned out to be wrong at runtime, and the fixes reshaped the design.
The task steps that follow are kept as the original plan; this is what actually shipped:

1. **Mount path: `/data/voice-inbox` → `/home/node/.n8n-files/voice-inbox`.** n8n 2.x
   sandboxes the `readWriteFile` node to `/home/node/.n8n-files`. Reading from `/data`
   failed with *"Access to the file is not allowed."* Mounting inside the sandbox fixes it
   without widening n8n's file-access allowlist.

2. **No `executeCommand` "move to processed" — idempotency is by note existence instead.**
   The precondition *"executeCommand available"* was false: it is unregistered under n8n's
   task-runner mode, and `readWriteFile` cannot delete. Files now stay in the inbox
   permanently; a `List processed` node lists `Voice memos/` once and a `Filter new` Code
   node drops any audio whose note already exists. Verified idempotent (the note's
   `transcribed:` timestamp is frozen across re-runs).

3. **Dedup key is the audio basename, not a date-prefixed name.** A `YYYY-MM-DD <name>`
   note name would re-transcribe any file lingering past midnight. Keying on the basename
   (`standup-notes.md`) makes "processed" permanent; the date lives in frontmatter.

Net node graph: `trigger → List processed → Read audio files → Filter new → Whisper →
Build note → Create note`. See `configs/n8n/README.md` for the maintained description.

---

## Preconditions (verified 2026-07-27)

| Fact | Result |
|---|---|
| `/Volumes/Samsung T7 Touch/homelab-data/voice-inbox` (+ `processed/`) | created |
| Docker Desktop hostPath surfaces Mac T7 files in the n8n pod | confirmed via marker file |
| `executeCommand` node available | ~~yes~~ **NO** — unregistered under task-runner mode (see As-built #2) |
| Obsidian `PUT /vault/{path}` creates a note | 204 |
| Obsidian credential `obsidianrestapi1` exists in n8n | yes (from Component 1) |

---

### Task 1: Mount the voice-inbox folder into n8n

**Files:**
- Modify: `modules/n8n/main.tf` (add volume_mount + volume)

- [x] **Step 1: Add a volume_mount to the container**

In the container spec, after the existing `volume_mount { name = "n8n-data" ... }`:

```hcl
          volume_mount {
            name       = "voice-inbox"
            mount_path = "/data/voice-inbox"
          }
```

- [x] **Step 2: Add the volume**

After the existing `volume { name = "n8n-data" ... }` block:

```hcl
        volume {
          name = "voice-inbox"
          host_path {
            # Direct hostPath (not a PV/PVC) — this is a shared drop folder, not
            # stateful data needing persistence guarantees. Docker Desktop surfaces
            # the Mac's T7 path into the pod (verified).
            path = "${var.external_storage_path}/voice-inbox"
            type = "DirectoryOrCreate"
          }
        }
```

- [x] **Step 3: Apply**

```bash
cd ~/Repositories/rainforest-homelab
terraform apply -target=module.n8n -auto-approve
kubectl rollout status deployment/homelab-n8n -n homelab --timeout=180s
```

- [x] **Step 4: Verify the pod sees the folder**

```bash
POD=$(kubectl get pod -n homelab -l app=n8n -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n homelab "$POD" -- sh -c 'ls -la /data/voice-inbox && echo "---" && ls -d /data/voice-inbox/processed'
```

Expected: the directory listing, including `processed/`. If "No such file", the mount
failed — check `external_storage_path` resolves to the T7.

- [x] **Step 5: Commit** (isolate the hunk — `main.tf`/module files carry unrelated in-flight work)

```
feat(n8n): mount voice-inbox drop folder for transcription workflow
```

---

### Task 2: Author the workflow definition

**Files:**
- Create: `configs/n8n/workflows/voice-memo-transcription.json`

- [x] **Step 1: Write the JSON**

```json
{
  "id": "voicememotranscr",
  "name": "Voice memo transcription",
  "active": false,
  "nodes": [
    {
      "id": "sched",
      "name": "Every 2 min",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [0, 200],
      "parameters": { "rule": { "interval": [ { "field": "minutes", "minutesInterval": 2 } ] } }
    },
    {
      "id": "run",
      "name": "Run now",
      "type": "n8n-nodes-base.executeWorkflowTrigger",
      "typeVersion": 1,
      "position": [0, 360],
      "parameters": {}
    },
    {
      "id": "read",
      "name": "Read audio files",
      "type": "n8n-nodes-base.readWriteFile",
      "typeVersion": 1,
      "position": [240, 280],
      "parameters": {
        "operation": "read",
        "fileSelector": "/data/voice-inbox/*.*",
        "options": { "dataPropertyName": "data" }
      },
      "continueOnFail": true
    },
    {
      "id": "transcribe",
      "name": "Whisper",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [480, 280],
      "parameters": {
        "method": "POST",
        "url": "http://host.docker.internal:9090/v1/audio/transcriptions",
        "sendBody": true,
        "contentType": "multipart-form-data",
        "bodyParameters": {
          "parameters": [
            { "parameterType": "formBinaryData", "name": "file", "inputDataFieldName": "data" },
            { "name": "model", "value": "whisper-1" }
          ]
        },
        "options": { "timeout": 120000 }
      }
    },
    {
      "id": "build",
      "name": "Build note",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [720, 280],
      "parameters": {
        "jsCode": "const text = ($json.text || '').trim();\nconst src = $('Read audio files').item.binary.data.fileName || 'memo';\nconst base = src.replace(/\\.[^.]+$/, '').replace(/[\\\\/:*?\"<>|]/g, '-');\nconst now = new Date().toISOString();\nconst date = now.slice(0, 10);\nconst noteName = `${date} ${base}`;\nconst body = [\n  '---',\n  'type: voice-memo',\n  `source: ${src}`,\n  `transcribed: ${now}`,\n  '---',\n  '',\n  text || '_(empty transcription)_',\n  '',\n].join('\\n');\nreturn [{ json: { noteName, body, src } }];"
      }
    },
    {
      "id": "note",
      "name": "Create note",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [960, 280],
      "parameters": {
        "method": "PUT",
        "url": "=https://host.docker.internal:27124/vault/Voice%20memos/{{ encodeURIComponent($json.noteName) }}.md",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendHeaders": true,
        "headerParameters": { "parameters": [ { "name": "Content-Type", "value": "text/markdown" } ] },
        "sendBody": true,
        "contentType": "raw",
        "rawContentType": "text/markdown",
        "body": "={{ $json.body }}",
        "options": { "allowUnauthorizedCerts": true, "timeout": 30000 }
      },
      "credentials": { "httpHeaderAuth": { "id": "obsidianrestapi1", "name": "Obsidian Local REST API" } }
    },
    {
      "id": "move",
      "name": "Move to processed",
      "type": "n8n-nodes-base.executeCommand",
      "typeVersion": 1,
      "position": [1200, 280],
      "parameters": {
        "command": "=mv -- \"/data/voice-inbox/{{ $('Build note').item.json.src }}\" \"/data/voice-inbox/processed/\""
      }
    }
  ],
  "connections": {
    "Every 2 min": { "main": [[{ "node": "Read audio files", "type": "main", "index": 0 }]] },
    "Run now":     { "main": [[{ "node": "Read audio files", "type": "main", "index": 0 }]] },
    "Read audio files": { "main": [[{ "node": "Whisper", "type": "main", "index": 0 }]] },
    "Whisper":     { "main": [[{ "node": "Build note", "type": "main", "index": 0 }]] },
    "Build note":  { "main": [[{ "node": "Create note", "type": "main", "index": 0 }]] },
    "Create note": { "main": [[{ "node": "Move to processed", "type": "main", "index": 0 }]] }
  },
  "settings": { "executionOrder": "v1" }
}
```

Nodes most likely to need runtime adjustment (verify by executing, not by inspection —
Component 1 needed three such fixes):
- **Read audio files** — whether the glob returns zero items cleanly when the folder is
  empty (hence `continueOnFail`), and the exact binary metadata path for the filename
  (`$('Read audio files').item.binary.data.fileName`).
- **Whisper** — multipart field name (`file`) and that `formBinaryData` picks up the `data`
  property.
- **Move to processed** — filename quoting for names with spaces (the `--` and quotes guard
  this).

- [x] **Step 2: Validate JSON + no secrets**

```bash
cd ~/Repositories/rainforest-homelab
python3 -m json.tool configs/n8n/workflows/voice-memo-transcription.json > /dev/null && echo valid
grep -ciE 'bearer [a-z0-9]{20,}|eyJ|glsa_' configs/n8n/workflows/voice-memo-transcription.json
```

Expected: `valid`, then `0`.

- [x] **Step 3: Commit**

```
feat(n8n): add voice memo transcription workflow definition
```

---

### Task 3: Import, execute, and fix until it works

Iterative, using the CLI-in-pod pattern from `configs/n8n/README.md`. Do NOT trust node
success — verify the note exists and the file moved.

- [x] **Step 1: Import**

```bash
POD=$(kubectl get pod -n homelab -l app=n8n -o jsonpath='{.items[0].metadata.name}')
kubectl cp configs/n8n/workflows/voice-memo-transcription.json "homelab/$POD:/tmp/vm.json"
kubectl exec -n homelab "$POD" -- n8n import:workflow --input=/tmp/vm.json
```

- [x] **Step 2: Drop a test audio file**

```bash
say -o "/Volumes/Samsung T7 Touch/homelab-data/voice-inbox/test-memo.aiff" \
  "This is a test voice memo. Buy milk and call the vet about Bambii."
ls -lh "/Volumes/Samsung T7 Touch/homelab-data/voice-inbox/"
```

- [x] **Step 3: Execute**

```bash
kubectl exec -n homelab "$POD" -- sh -c '
  export N8N_RUNNERS_BROKER_PORT=5690 N8N_RUNNERS_BROKER_LISTEN_ADDRESS=127.0.0.1
  n8n execute --id=voicememotranscr 2>&1 | grep -viE "deprecation|error tracking|Python" | tail -12'
```

Expected: `"status": "success"`. On failure, read the error, fix the JSON, re-import
(`import:workflow` updates in place via the stable id), re-execute. Likely fixes mirror
Component 1: binary-field path, multipart shape, or fan-in — but here it is a serial chain
already.

- [x] **Step 4: Verify the OUTPUT (the note and the move)**

```bash
OBS_KEY=$(grep -oE 'obsidian_api_key *= *"[^"]*"' ~/Repositories/rainforest-homelab/terraform.tfvars | sed -E 's/.*"(.*)"/\1/')
echo "--- note content ---"
curl -sk -H "Authorization: Bearer $OBS_KEY" "https://localhost:27124/vault/Voice%20memos/" | python3 -m json.tool | grep -i test
echo "--- file moved? ---"
ls "/Volumes/Samsung T7 Touch/homelab-data/voice-inbox/" "/Volumes/Samsung T7 Touch/homelab-data/voice-inbox/processed/"
```

Expected: a note dated today containing "Buy milk and call the vet about Bambii", inbox
empty, file now under `processed/`.

- [x] **Step 5: Commit any JSON fixes**

```
fix(n8n): make voice memo workflow run end to end
```

---

### Task 4: Activate and document

- [x] **Step 1: Activate + restart**

```bash
kubectl exec -n homelab "$POD" -- n8n update:workflow --id=voicememotranscr --active=true
kubectl rollout restart deployment/homelab-n8n -n homelab
kubectl rollout status deployment/homelab-n8n -n homelab --timeout=180s
```

- [x] **Step 2: Confirm active**

Use `n8n_list_workflows` (active only) or the CLI. Expected: `Voice memo transcription`,
active.

- [x] **Step 3: Add to the n8n README workflows section**

Append an entry describing the workflow, its 2-minute poll, the drop folder, and the
`processed/` idempotency, pointing at the Theme A spec.

- [x] **Step 4: Commit**

```
docs(n8n): document the voice memo transcription workflow
```

---

## Verification (whole feature)

1. A note appears in the `Voice memos/` folder with correct transcribed text.
2. The audio file is in `processed/`, not the inbox.
3. Re-running with an empty inbox does not error (the `continueOnFail` path).
4. Dropping two files at once produces two notes and moves both.
5. No secret is present in the committed workflow JSON.
