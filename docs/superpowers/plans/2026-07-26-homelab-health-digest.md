# Homelab health digest implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scheduled n8n workflow that reads firing Prometheus alerts and Home Assistant
sensor values, has Ollama summarise them, and appends a "Homelab health" section to today's
Obsidian daily note — closing the visibility gap that let five defects rot for months.

**Architecture:** One n8n workflow, five nodes in a line: Schedule → Prometheus HTTP →
Ollama HTTP → Obsidian HTTP. No new alert rules (kube-prometheus-stack defaults already
fire correctly), no Alertmanager receiver, no new credentials. The workflow JSON is
exported to this repo so it is version-controlled and reproducible.

**Tech Stack:** n8n (Kubernetes, `homelab` namespace), Prometheus on the Pi
(`192.168.0.128:30090`), Ollama on the Mac (`host.docker.internal:11434`), Obsidian Local
REST API (`host.docker.internal:27124`).

---

## Preconditions (verified 2026-07-26)

All three endpoints were confirmed reachable **from inside the n8n pod**. Do not re-derive;
re-verify only if a task fails.

| Endpoint | Verified result |
|---|---|
| `http://192.168.0.128:30090/api/v1/query?query=up` | 200, full JSON |
| `http://host.docker.internal:11434/api/tags` | 200, 8 models |
| `https://host.docker.internal:27124/periodic/daily/` | 200 (self-signed TLS) |

`ALERTS{alertstate="firing"}` currently returns 5 real alerts plus `Watchdog`.

## File structure

| File | Responsibility |
|---|---|
| `configs/n8n/workflows/homelab-health-digest.json` | Version-controlled workflow export |
| `configs/n8n/README.md` | How to import/re-import a workflow after a rebuild |

No Terraform changes. The workflow is data, not infrastructure; Terraform has no n8n
provider and wrapping the API in `null_resource` would be worse than an explicit import
step.

---

### Task 1: Confirm the data the digest will report

**Files:** none (read-only reconnaissance)

- [ ] **Step 1: Query the alerts the digest will surface**

```bash
curl -s "http://192.168.0.128:30090/api/v1/query" \
  --data-urlencode 'query=ALERTS{alertstate="firing",alertname!="Watchdog"}' \
  | python3 -m json.tool | grep -E '"alertname"|"pod"|"job_name"' | sort -u
```

Expected: at least `KubePodCrashLooping` (speedtest-exporter) and `KubeJobFailed`
(pihole-gravity-update). `Watchdog` is excluded deliberately — it is a permanently-firing
heartbeat and would be noise in every digest.

- [ ] **Step 2: Query the home sensors the digest will report**

```bash
curl -s "http://192.168.0.128:30090/api/v1/query" \
  --data-urlencode 'query=homeassistant_sensor_humidity_percent or homeassistant_sensor_temperature_celsius' \
  | python3 -m json.tool | grep -E '"friendly_name"|"value"' | head
```

Expected: humidity and temperature values with a `friendly_name` label.

- [ ] **Step 3: Record the exact PromQL in the plan's Task 3 node**

No commit — this task only confirms the queries return data before they are embedded.

---

### Task 2: Give n8n the Obsidian key as an environment variable

The Obsidian key already exists in `terraform.tfvars`. Injecting it as an env var means the
workflow JSON can reference `$env.OBSIDIAN_API_KEY` and stay free of secrets when committed
— and it avoids an n8n UI credential, which the public API cannot create.

`N8N_BLOCK_ENV_ACCESS_IN_NODE` is unset on this deployment (verified), so expressions may
read env vars.

**Files:**
- Modify: `modules/n8n/main.tf` (container env block)
- Modify: `main.tf` (pass the variable into the module)
- Modify: `modules/n8n/variables.tf` (declare the variable)

- [ ] **Step 1: Declare the variable in the n8n module**

Add to `modules/n8n/variables.tf`:

```hcl
variable "obsidian_api_key" {
  description = "Obsidian Local REST API key, exposed to workflows as $env.OBSIDIAN_API_KEY"
  type        = string
  sensitive   = true
  default     = ""
}
```

- [ ] **Step 2: Add the env var to the n8n container**

In `modules/n8n/main.tf`, find the container's `env` blocks (near the other `env { name = ... }`
entries around line 94-190) and add:

```hcl
          env {
            name  = "OBSIDIAN_API_KEY"
            value = var.obsidian_api_key
          }
```

- [ ] **Step 3: Pass the existing variable through in the root module**

In `main.tf`, inside `module "n8n" { ... }`, add:

```hcl
  obsidian_api_key = var.obsidian_api_key
```

- [ ] **Step 4: Apply**

```bash
cd ~/Repositories/rainforest-homelab
terraform apply -target=module.n8n -auto-approve
```

Expected: `Apply complete!`, n8n pod restarts.

- [ ] **Step 5: Verify the variable is present without printing it**

```bash
kubectl wait --for=condition=ready pod -l app=n8n -n homelab --timeout=180s
POD=$(kubectl get pod -n homelab -l app=n8n -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n homelab "$POD" -- sh -c '[ -n "$OBSIDIAN_API_KEY" ] && echo "OBSIDIAN_API_KEY set (len ${#OBSIDIAN_API_KEY})" || echo MISSING'
```

Expected: `OBSIDIAN_API_KEY set (len 64)`

- [ ] **Step 6: Commit**

```bash
git add modules/n8n/variables.tf modules/n8n/main.tf main.tf
git commit -m "feat(n8n): expose Obsidian API key to workflows as an env var

Lets workflow JSON reference \$env.OBSIDIAN_API_KEY instead of embedding the
secret or requiring a hand-made n8n credential (the public API cannot create
credentials). Reuses the existing obsidian_api_key variable."
```

---

### Task 3: Write the workflow definition

Written as a file first, then imported — so the version-controlled JSON is the source of
truth rather than an after-the-fact export.

**Files:**
- Create: `configs/n8n/workflows/homelab-health-digest.json`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p ~/Repositories/rainforest-homelab/configs/n8n/workflows
```

- [ ] **Step 2: Write the workflow JSON**

Create `configs/n8n/workflows/homelab-health-digest.json` with exactly this content:

```json
{
  "name": "Homelab health digest",
  "nodes": [
    {
      "id": "schedule",
      "name": "Daily 08:10",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [0, 300],
      "parameters": {
        "rule": {
          "interval": [
            { "field": "days", "triggerAtHour": 8, "triggerAtMinute": 10 }
          ]
        }
      }
    },
    {
      "id": "alerts",
      "name": "Fetch alerts",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [220, 200],
      "parameters": {
        "url": "http://192.168.0.128:30090/api/v1/query",
        "sendQuery": true,
        "queryParameters": {
          "parameters": [
            { "name": "query", "value": "ALERTS{alertstate=\"firing\",alertname!=\"Watchdog\"}" }
          ]
        },
        "options": { "timeout": 30000 }
      }
    },
    {
      "id": "sensors",
      "name": "Fetch sensors",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [220, 400],
      "parameters": {
        "url": "http://192.168.0.128:30090/api/v1/query",
        "sendQuery": true,
        "queryParameters": {
          "parameters": [
            { "name": "query", "value": "homeassistant_sensor_humidity_percent or homeassistant_sensor_temperature_celsius" }
          ]
        },
        "options": { "timeout": 30000 }
      }
    },
    {
      "id": "prompt",
      "name": "Build prompt",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [440, 300],
      "parameters": {
        "jsCode": "const alerts = $('Fetch alerts').first().json.data.result || [];\nconst sensors = $('Fetch sensors').first().json.data.result || [];\n\nconst alertLines = alerts.map(a => {\n  const m = a.metric;\n  const what = m.pod || m.job_name || m.instance || 'unknown';\n  return `- ${m.alertname} (${m.severity || 'n/a'}): ${what}`;\n});\n\nconst sensorLines = sensors.map(s => {\n  const name = s.metric.friendly_name || s.metric.entity || 'sensor';\n  const val = Number(s.value[1]).toFixed(1);\n  return `- ${name}: ${val}`;\n});\n\nconst prompt = [\n  'Summarise this homelab status in at most 4 short sentences.',\n  'State plainly what is wrong and what looks normal. No preamble, no bullet points.',\n  '',\n  `Firing alerts (${alertLines.length}):`,\n  alertLines.length ? alertLines.join('\\n') : '- none',\n  '',\n  'Home sensors:',\n  sensorLines.length ? sensorLines.join('\\n') : '- none',\n].join('\\n');\n\nreturn [{ json: { prompt, alertCount: alertLines.length, alertLines, sensorLines } }];"
      }
    },
    {
      "id": "summarise",
      "name": "Summarise",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [660, 300],
      "parameters": {
        "method": "POST",
        "url": "http://host.docker.internal:11434/api/generate",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify({ model: 'gemma4:e4b-mlx', prompt: $json.prompt, stream: false }) }}",
        "options": { "timeout": 120000 }
      }
    },
    {
      "id": "format",
      "name": "Format section",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [880, 300],
      "parameters": {
        "jsCode": "const summary = ($('Summarise').first().json.response || '').trim();\nconst p = $('Build prompt').first().json;\nconst stamp = new Date().toISOString().slice(11, 16);\n\nconst body = [\n  '',\n  '## Homelab health',\n  '',\n  `*checked ${stamp} UTC*`,\n  '',\n  summary || '_summary unavailable_',\n  '',\n  `**Firing alerts:** ${p.alertCount}`,\n  ...(p.alertLines.length ? p.alertLines : ['- none']),\n  '',\n  '**Sensors**',\n  ...(p.sensorLines.length ? p.sensorLines : ['- none']),\n  '',\n].join('\\n');\n\nreturn [{ json: { body } }];"
      }
    },
    {
      "id": "append",
      "name": "Append to daily note",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [1100, 300],
      "parameters": {
        "method": "POST",
        "url": "https://host.docker.internal:27124/periodic/daily/",
        "sendHeaders": true,
        "headerParameters": {
          "parameters": [
            { "name": "Authorization", "value": "=Bearer {{ $env.OBSIDIAN_API_KEY }}" },
            { "name": "Content-Type", "value": "text/markdown" }
          ]
        },
        "sendBody": true,
        "contentType": "raw",
        "rawContentType": "text/markdown",
        "body": "={{ $json.body }}",
        "options": { "allowUnauthorizedCerts": true, "timeout": 30000 }
      }
    }
  ],
  "connections": {
    "Daily 08:10": {
      "main": [[{ "node": "Fetch alerts", "type": "main", "index": 0 },
                { "node": "Fetch sensors", "type": "main", "index": 0 }]]
    },
    "Fetch alerts": { "main": [[{ "node": "Build prompt", "type": "main", "index": 0 }]] },
    "Fetch sensors": { "main": [[{ "node": "Build prompt", "type": "main", "index": 0 }]] },
    "Build prompt": { "main": [[{ "node": "Summarise", "type": "main", "index": 0 }]] },
    "Summarise": { "main": [[{ "node": "Format section", "type": "main", "index": 0 }]] },
    "Format section": { "main": [[{ "node": "Append to daily note", "type": "main", "index": 0 }]] }
  },
  "settings": { "executionOrder": "v1" }
}
```

Design notes for the reviewer:
- The raw alert list is written to the note alongside the model's summary on purpose — the
  model can be vague or wrong, and the underlying facts must survive.
- `allowUnauthorizedCerts` is required: the Obsidian endpoint uses a self-signed
  certificate. Expected, not a workaround.
- `Watchdog` is excluded from the query — it is a permanently-firing heartbeat and would be
  noise in every single digest.
- 08:10 sits after the existing `rss-daily-digest` routine (08:03) so both append to the
  same daily note without racing to create it.

- [ ] **Step 3: Verify it is valid JSON and contains no secret**

```bash
cd ~/Repositories/rainforest-homelab
python3 -m json.tool configs/n8n/workflows/homelab-health-digest.json > /dev/null && echo "valid JSON"
grep -ciE 'bearer [a-z0-9]{20,}|eyJ|glsa_' configs/n8n/workflows/homelab-health-digest.json
```

Expected: `valid JSON`, then `0`. The only "Bearer" is the `$env` expression, which holds
no value.

- [ ] **Step 4: Commit**

```bash
git add configs/n8n/workflows/homelab-health-digest.json
git commit -m "feat(n8n): add homelab health digest workflow definition"
```

---

### Task 4: Import the workflow into n8n

**Files:** none (creates state inside n8n)

- [ ] **Step 1: Import via the n8n API**

Use the MCP tool `n8n_create_workflow`, passing `name`, `nodes`, `connections` and
`settings` exactly as written in the JSON file from Task 3.

Equivalent curl, if the API key is available in the shell:

```bash
curl -s -X POST http://localhost:5678/api/v1/workflows \
  -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" \
  --data @configs/n8n/workflows/homelab-health-digest.json | python3 -m json.tool | head -5
```

Expected: JSON response containing an `id`. Record it — later steps need it.

- [ ] **Step 2: Validate the imported workflow**

Use the MCP tool `n8n_validate_workflow` with the id from step 1.

Expected: no errors. Warnings about unused nodes or missing credentials are acceptable;
connection or expression errors are not — fix the JSON in Task 3 and re-import.

- [ ] **Step 3: Confirm it is listed**

Use `n8n_list_workflows` (limit 20).

Expected: `Homelab health digest` present, `active: false` (imports arrive inactive).

---

### Task 5: Prove each stage produces real output

Do not trust node success indicators. Every stage is verified by its actual output — n8n's
own health check reported `ok` for weeks while every authenticated call failed.

**Files:** none

- [ ] **Step 1: Execute the workflow manually**

In n8n (`http://localhost:5678`), open `Homelab health digest` and click **Execute
Workflow**. Manual execution cannot be triggered through the public API, so this single
click is unavoidable.

Expected: all seven nodes complete.

- [ ] **Step 2: Verify the alert query returned real data**

```bash
curl -s "http://192.168.0.128:30090/api/v1/query" \
  --data-urlencode 'query=count(ALERTS{alertstate="firing",alertname!="Watchdog"})' \
  | python3 -c "import sys,json; print('alerts firing:', json.load(sys.stdin)['data']['result'][0]['value'][1])"
```

Expected: a non-zero count (`KubePodCrashLooping` and `KubeJobFailed` are currently firing).
Note the number — Task 9 compares it against the note.

- [ ] **Step 3: Verify the note was written**

```bash
OBS_KEY=$(grep -oE 'obsidian_api_key *= *"[^"]*"' ~/Repositories/rainforest-homelab/terraform.tfvars | sed -E 's/.*"(.*)"/\1/')
curl -sk -H "Authorization: Bearer $OBS_KEY" https://localhost:27124/periodic/daily/ | tail -25
```

Expected: the daily note ends with a `## Homelab health` section naming
`KubePodCrashLooping`.

If the section is missing but the node reported success, the most likely cause is
`$env.OBSIDIAN_API_KEY` not resolving — re-check Task 2 Step 5.

---

### Task 6: Activate the schedule

**Files:** none

- [ ] **Step 1: Activate**

```bash
curl -s -X POST "http://localhost:5678/api/v1/workflows/<ID>/activate" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" | python3 -m json.tool | grep -E '"active"'
```

Substitute the id recorded in Task 4 Step 1.

Expected: `"active": true`

- [ ] **Step 2: Confirm via listing**

Use `n8n_list_workflows` with `active: true`.

Expected: `Homelab health digest` appears.

---

### Task 7: Document the restore procedure

**Files:**
- Create: `configs/n8n/README.md`

- [ ] **Step 1: Write the README**

```markdown
# n8n workflows

Workflow definitions kept in git so they survive a machine rebuild.

## Restore after a rebuild

Workflows reference `$env.OBSIDIAN_API_KEY`, which Terraform injects into the n8n
deployment from `obsidian_api_key` in `terraform.tfvars`. No n8n credential needs to be
created by hand.

1. `terraform apply -target=module.n8n` — ensures the env var is present
2. Import: `POST /api/v1/workflows` with the JSON from `workflows/`, or use the n8n UI's
   Import from File
3. Activate: `POST /api/v1/workflows/<id>/activate`

## Workflows

- `homelab-health-digest.json` — daily 08:10. Reads firing Prometheus alerts and Home
  Assistant sensors, summarises with Ollama, appends a "Homelab health" section to the
  Obsidian daily note.
  Design: `docs/superpowers/specs/2026-07-26-theme-a-homelab-health-digest-design.md`
```

- [ ] **Step 2: Commit**

```bash
git add configs/n8n/README.md
git commit -m "docs(n8n): restore procedure for version-controlled workflows"
```

---

### Task 8: Add the missing blackbox probe alert rule

The spec calls for an `EndpointProbeFailed` condition. The 134 default rules cover
crash-looping (`KubePodCrashLooping`), disk (`NodeFilesystemSpaceFillingUp`) and dead
targets (`TargetDown`), but contain **no probe or blackbox rule** — so all 17 public
endpoints currently have no alerting. This is the one rule that must be written.

**Files:**
- Modify: `~/Repositories/rainforest-iot/modules/prometheus-stack/main.tf` (helm values)

- [ ] **Step 1: Confirm the gap still exists**

```bash
curl -s "http://192.168.0.128:30090/api/v1/rules" | python3 -c "
import sys,json
d=json.load(sys.stdin)
names=[r['name'] for g in d['data']['groups'] for r in g['rules'] if r.get('type')=='alerting']
print('probe/blackbox rules:', [n for n in names if 'probe' in n.lower() or 'blackbox' in n.lower()])
"
```

Expected: `probe/blackbox rules: []`

- [ ] **Step 2: Add the rule to the chart values**

In `modules/prometheus-stack/main.tf`, inside the `yamlencode({ ... })` values map, add a
top-level `additionalPrometheusRulesMap` key alongside `prometheus` and `grafana`:

```hcl
      # Blackbox probes have no default rule in kube-prometheus-stack, so a public
      # endpoint could go down silently. probe_success is emitted per target by the
      # blackbox exporter.
      additionalPrometheusRulesMap = {
        blackbox-rules = {
          groups = [
            {
              name = "blackbox"
              rules = [
                {
                  alert = "BlackboxProbeFailed"
                  expr  = "probe_success == 0"
                  for   = "5m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Probe failing for {{ $labels.instance }}"
                  }
                }
              ]
            }
          ]
        }
      }
```

- [ ] **Step 3: Apply**

```bash
cd ~/Repositories/rainforest-iot
terraform apply -target=module.prometheus_stack -auto-approve
```

Expected: `Apply complete!` with `helm_release.prometheus_stack` changed.

- [ ] **Step 4: Verify the rule is loaded**

```bash
sleep 30
curl -s "http://192.168.0.128:30090/api/v1/rules" | python3 -c "
import sys,json
d=json.load(sys.stdin)
names=[r['name'] for g in d['data']['groups'] for r in g['rules'] if r.get('type')=='alerting']
print('BlackboxProbeFailed present:', 'BlackboxProbeFailed' in names)
"
```

Expected: `BlackboxProbeFailed present: True`

- [ ] **Step 5: Commit**

```bash
cd ~/Repositories/rainforest-iot
git add modules/prometheus-stack/main.tf
git commit -m "feat(monitoring): alert when a blackbox probe fails

kube-prometheus-stack ships no probe rule, so all 17 public endpoints had no
alerting — a service could go down publicly with nothing firing. Adds
BlackboxProbeFailed on probe_success == 0 for 5m."
```

---

### Task 9: End-to-end verification

**Files:** none

- [ ] **Step 1: Trigger a full manual run**

In n8n, open the workflow and click **Execute Workflow**.
Expected: all five nodes show green.

- [ ] **Step 2: Verify the note content matches reality**

```bash
OBS_KEY=$(grep -oE 'obsidian_api_key *= *"[^"]*"' ~/Repositories/rainforest-homelab/terraform.tfvars | sed -E 's/.*"(.*)"/\1/')
curl -sk -H "Authorization: Bearer $OBS_KEY" https://localhost:27124/periodic/daily/ | tail -25
curl -s "http://192.168.0.128:30090/api/v1/query" \
  --data-urlencode 'query=count(ALERTS{alertstate="firing",alertname!="Watchdog"})' \
  | python3 -m json.tool | grep -A2 '"value"'
```

Expected: the `**Firing alerts:** N` line in the note equals the count from Prometheus.
A mismatch means the Code node dropped entries.

- [ ] **Step 3: Verify it catches a fault it did not know about**

This step depends on `BlackboxProbeFailed` from Task 8 — without that rule nothing fires
when a public endpoint dies, and this check would pass vacuously.

Stop a non-critical container, wait for the alert to fire, and re-run the workflow:

```bash
docker stop homelab-calibre-web
# wait ~6 minutes for the blackbox probe alert to fire, then Execute Workflow in n8n
docker start homelab-calibre-web
```

Expected: the digest names `calibre-web` while it is down. This proves the digest reflects
live state rather than a cached or hard-coded list.

- [ ] **Step 4: Confirm no new credential was created**

```bash
docker mcp secret ls
```

Expected: the same entries as before this work — `grafana.api_key`, `n8n.api_key`,
`obsidian.api_key`, and the OAuth entries. Nothing new.

---

## Follow-ups discovered during planning (NOT part of this plan)

Both were found sitting in `ALERTS` and are exactly what the digest is meant to surface.
Fix them separately; leaving them firing makes a useful first digest.

1. **`speedtest-exporter` still crash-looping** — 411 restarts in 30h, `exit 137`. Raising
   memory to 320Mi did not change the rate (~330/day before and after), so the cause is not
   a memory ceiling. Prime suspect: the liveness probe (`httpGet /healthz`, timeout 5s,
   period 30s, failureThreshold 3) killing the container while a speedtest run blocks the
   HTTP handler.
2. **Pi-hole gravity updates failing for 14 days** — `pihole-gravity-update` jobs failed
   14d, 7d20h and 20h ago. The blocklist has not refreshed in two weeks.
