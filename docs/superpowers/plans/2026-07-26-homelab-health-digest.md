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

### Task 2: Create the n8n credential for Obsidian

The Obsidian key already exists in `terraform.tfvars`; this only teaches n8n to use it. No
new credential is created anywhere.

**Files:** none in git (credential lives in n8n's database)

- [ ] **Step 1: Read the existing key without printing it**

```bash
OBS_KEY=$(grep -oE 'obsidian_api_key *= *"[^"]*"' ~/Repositories/rainforest-homelab/terraform.tfvars | sed -E 's/.*"(.*)"/\1/')
[ -n "$OBS_KEY" ] && echo "key loaded (not shown)" || echo "FAILED to read key"
```

Expected: `key loaded (not shown)`

- [ ] **Step 2: Create an HTTP Header Auth credential in n8n**

In the n8n UI (`http://localhost:5678`) → Credentials → New → **Header Auth**:
- Name: `Obsidian Local REST API`
- Header Name: `Authorization`
- Header Value: `Bearer <the key from step 1>`

The n8n public API does not expose credential creation, so this is a one-time UI step. It
consumes an existing secret rather than minting a new one, which satisfies the
"no new manual credentials" constraint from the spec.

- [ ] **Step 3: Verify the credential saves without error**

Expected: credential appears in the list as `Obsidian Local REST API`.

---

### Task 3: Build the workflow — Prometheus stage

**Files:** none yet (built in the n8n UI, exported in Task 7)

- [ ] **Step 1: Create a new workflow named `Homelab health digest`**

- [ ] **Step 2: Add an HTTP Request node named `Fetch alerts`**

- Method: `GET`
- URL: `http://192.168.0.128:30090/api/v1/query`
- Send Query Parameters: on
  - Name `query`, Value: `ALERTS{alertstate="firing",alertname!="Watchdog"}`
- Response → Format: `JSON`

- [ ] **Step 3: Execute the node alone and verify output**

Click **Test step**.
Expected: `data.result` is an array containing objects whose
`metric.alertname` includes `KubePodCrashLooping`.

If `data.result` is empty, the digest has nothing to report — re-run Task 1 Step 1 to
confirm alerts are still firing before assuming the node is misconfigured.

- [ ] **Step 4: Add a second HTTP Request node named `Fetch sensors`**

- Method: `GET`
- URL: `http://192.168.0.128:30090/api/v1/query`
- Send Query Parameters: on
  - Name `query`, Value:
    `homeassistant_sensor_humidity_percent or homeassistant_sensor_temperature_celsius`
- Response → Format: `JSON`

- [ ] **Step 5: Execute and verify**

Expected: `data.result` contains entries with `metric.friendly_name` and numeric values.

---

### Task 4: Build the workflow — summarise with Ollama

**Files:** none yet

- [ ] **Step 1: Add a Code node named `Build prompt`**

Connect `Fetch alerts` → `Build prompt`, and `Fetch sensors` → `Build prompt`.

```javascript
// Collapse both Prometheus responses into one compact prompt.
// items[0] = alerts, items[1] = sensors (order follows node connection order).
const alerts = $('Fetch alerts').first().json.data.result || [];
const sensors = $('Fetch sensors').first().json.data.result || [];

const alertLines = alerts.map(a => {
  const m = a.metric;
  const what = m.pod || m.job_name || m.instance || 'unknown';
  return `- ${m.alertname} (${m.severity || 'n/a'}): ${what}`;
});

const sensorLines = sensors.map(s => {
  const name = s.metric.friendly_name || s.metric.entity || 'sensor';
  const val = Number(s.value[1]).toFixed(1);
  return `- ${name}: ${val}`;
});

const prompt = [
  'Summarise this homelab status in at most 4 short sentences.',
  'State plainly what is wrong and what looks normal. No preamble, no bullet points.',
  '',
  `Firing alerts (${alertLines.length}):`,
  alertLines.length ? alertLines.join('\n') : '- none',
  '',
  'Home sensors:',
  sensorLines.length ? sensorLines.join('\n') : '- none',
].join('\n');

return [{ json: { prompt, alertCount: alertLines.length, alertLines, sensorLines } }];
```

- [ ] **Step 2: Execute and verify the prompt**

Expected: `prompt` is a string mentioning `KubePodCrashLooping`, and `alertCount` is a
number greater than 0.

- [ ] **Step 3: Add an HTTP Request node named `Summarise`**

- Method: `POST`
- URL: `http://host.docker.internal:11434/api/generate`
- Send Body: on, Body Content Type: `JSON`, Specify Body: **Using JSON**

```json
{
  "model": "gemma4:e4b-mlx",
  "prompt": "={{ $json.prompt }}",
  "stream": false
}
```

`gemma4:e4b-mlx` is chosen for speed — it is the smallest MLX-optimised model available
locally, and this is a short summarisation run on shared hardware. Any name from
`ollama list` works if you prefer a larger one.

- [ ] **Step 4: Set the node timeout**

Options → Timeout: `120000` (ms). Local inference on a busy Mac Mini can exceed the 30s
default, and a timeout here would silently produce an empty digest.

- [ ] **Step 5: Execute and verify**

Expected: response JSON contains a non-empty `response` string describing the alerts.

---

### Task 5: Build the workflow — write to Obsidian

**Files:** none yet

- [ ] **Step 1: Add a Code node named `Format section`**

```javascript
const summary = ($('Summarise').first().json.response || '').trim();
const p = $('Build prompt').first().json;
const stamp = new Date().toISOString().slice(11, 16); // HH:MM

const body = [
  '',
  '## Homelab health',
  '',
  `*checked ${stamp}*`,
  '',
  summary || '_summary unavailable_',
  '',
  `**Firing alerts:** ${p.alertCount}`,
  ...(p.alertLines.length ? p.alertLines : ['- none']),
  '',
  '**Sensors**',
  ...(p.sensorLines.length ? p.sensorLines : ['- none']),
  '',
].join('\n');

return [{ json: { body } }];
```

The raw alert list is included alongside the summary on purpose: the model can be wrong or
vague, and the underlying facts must remain in the note.

- [ ] **Step 2: Execute and verify**

Expected: `body` starts with `## Homelab health` and contains the alert lines.

- [ ] **Step 3: Add an HTTP Request node named `Append to daily note`**

- Method: `POST`
- URL: `https://host.docker.internal:27124/periodic/daily/`
- Authentication: Generic Credential Type → Header Auth → `Obsidian Local REST API`
- Send Headers: on → `Content-Type`: `text/markdown`
- Send Body: on → Body Content Type: `RAW` → Content: `={{ $json.body }}`
- Options → **Ignore SSL Issues: on** (the endpoint uses a self-signed certificate; this is
  expected, not a workaround)

- [ ] **Step 4: Execute and verify the write landed**

```bash
OBS_KEY=$(grep -oE 'obsidian_api_key *= *"[^"]*"' ~/Repositories/rainforest-homelab/terraform.tfvars | sed -E 's/.*"(.*)"/\1/')
curl -sk -H "Authorization: Bearer $OBS_KEY" https://localhost:27124/periodic/daily/ | tail -25
```

Expected: the daily note now ends with the `## Homelab health` section, including the
`KubePodCrashLooping` line.

This is the verification that matters. Per the spec, prove the **output**, not that a node
reported success — n8n and Grafana health checks both lied during the audit.

---

### Task 6: Add the schedule and activate

**Files:** none yet

- [ ] **Step 1: Add a Schedule Trigger node**

- Trigger Interval: `Days`, Days Between Triggers: `1`
- Trigger at Hour: `8`, Trigger at Minute: `10`

08:10 sits after the existing `rss-daily-digest` routine (08:03) so both land in the same
daily note without racing to create it.

- [ ] **Step 2: Connect `Schedule Trigger` → `Fetch alerts` and `Schedule Trigger` → `Fetch sensors`**

- [ ] **Step 3: Activate the workflow**

Toggle **Active** in the top right.

- [ ] **Step 4: Verify it is registered as scheduled**

```bash
curl -s "http://localhost:5678/api/v1/workflows?active=true" \
  -H "X-N8N-API-KEY: $(printf '%s' "$N8N_API_KEY")" | python3 -m json.tool | grep -E '"name"|"active"'
```

Expected: `Homelab health digest` listed with `"active": true`.

If `$N8N_API_KEY` is not set in the shell, read it from the Docker MCP gateway secret
store instead: `docker mcp secret ls` shows `n8n.api_key` exists; the value can be supplied
by whatever process needs it. Confirming via the n8n UI's workflow list is equally valid.

---

### Task 7: Version-control the workflow

**Files:**
- Create: `configs/n8n/workflows/homelab-health-digest.json`
- Create: `configs/n8n/README.md`

- [ ] **Step 1: Export the workflow from n8n**

In the n8n UI: workflow menu (⋯) → **Download**. Save the file to
`configs/n8n/workflows/homelab-health-digest.json`.

- [ ] **Step 2: Confirm the export contains no secret**

```bash
grep -ciE 'bearer |api[_-]?key|password|eyJ' configs/n8n/workflows/homelab-health-digest.json
```

Expected: `0`. n8n exports credential *references*, not values. If this returns anything
other than 0, stop and inspect before committing.

- [ ] **Step 3: Write the import instructions**

Create `configs/n8n/README.md`:

```markdown
# n8n workflows

Workflow definitions exported from n8n, kept in git so they survive a rebuild.

## Restore after a rebuild

1. Recreate the `Obsidian Local REST API` credential (Header Auth):
   Header Name `Authorization`, Header Value `Bearer <obsidian_api_key from terraform.tfvars>`
2. In n8n: Workflows → Import from File → select the JSON in `workflows/`
3. Activate the workflow

Credentials are intentionally NOT exported — the JSON references them by name only.

## Workflows

- `homelab-health-digest.json` — daily 08:10. Reads firing Prometheus alerts and Home
  Assistant sensors, summarises with Ollama, appends a "Homelab health" section to the
  Obsidian daily note. Design: `docs/superpowers/specs/2026-07-26-theme-a-homelab-health-digest-design.md`
```

- [ ] **Step 4: Commit**

```bash
cd ~/Repositories/rainforest-homelab
git add configs/n8n/workflows/homelab-health-digest.json configs/n8n/README.md
git commit -m "feat(n8n): add homelab health digest workflow

Daily workflow reading firing Prometheus alerts and Home Assistant sensors,
summarising with Ollama, and appending a health section to the Obsidian daily
note. Closes the visibility gap that let a crash-looping exporter and a failing
Pi-hole gravity update go unnoticed for weeks.

No new alert rules were needed — kube-prometheus-stack defaults were already
firing correctly; only delivery was missing."
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
