import test from 'node:test';
import assert from 'node:assert/strict';
import { loadWorkflow, runCodeNode } from './harness.mjs';

const DAY = 86400000;
const HOUR = 3600000;
const NOW = Date.parse('2026-11-27T00:10:00Z');

const amAlert = (labels, startsAt) => ({
  labels: { severity: 'warning', ...labels },
  startsAt: new Date(startsAt).toISOString(),
  status: { state: 'active', silencedBy: [], inhibitedBy: [] },
});

const sensors = [{ json: { data: { result: [{ metric: { friendly_name: 'Hub 2 Humidity' }, value: [0, '71'] }] } } }];

test('digest: alerts firing more than 3 days collapse to an ack-or-silence line', () => {
  const wf = loadWorkflow('homelab-health-digest.json');
  const alerts = [
    amAlert({ alertname: 'Watchdog', severity: 'none' }, NOW - 20 * DAY),
    amAlert({ alertname: 'RemoteSiteHostDown', instance: 'raspberrypi-4' }, NOW - 18 * DAY - HOUR),
    amAlert({ alertname: 'TargetDown', job: 'node-exporter' }, NOW - 18 * DAY),
    amAlert({ alertname: 'TargetDown', job: 'node-exporter' }, NOW - 18 * DAY),
    amAlert({ alertname: 'KubePodCrashLooping', pod: 'speedtest-0' }, NOW - 2 * HOUR),
    amAlert({ alertname: 'DiskAlmostFull', instance: 'mini' }, NOW - 3 * DAY + HOUR),
  ];
  const [out] = runCodeNode(wf, 'Build prompt', {
    nodes: { 'Fetch alerts': alerts, 'Fetch sensors': sensors.map(s => s.json) },
    now: NOW,
  });
  const { alertLines, staleLines, alertCount, prompt } = out.json;
  assert.deepEqual(staleLines, [
    '- RemoteSiteHostDown (warning): raspberrypi-4，仍在 firing 18 天：ack 或 silence？',
    '- TargetDown (warning): node-exporter，仍在 firing 18 天：ack 或 silence？',
  ]);
  assert.deepEqual(alertLines, [
    '- KubePodCrashLooping (warning): speedtest-0',
    '- DiskAlmostFull (warning): mini',
  ]);
  assert.equal(alertCount, 4);
  assert.ok(!prompt.includes('RemoteSiteHostDown'), 'stale alerts stay out of the model prompt');
});

test('digest: no alerts (alwaysOutputData empty item) reads as none', () => {
  const wf = loadWorkflow('homelab-health-digest.json');
  const [out] = runCodeNode(wf, 'Build prompt', {
    nodes: { 'Fetch alerts': [{}], 'Fetch sensors': sensors.map(s => s.json) },
    now: NOW,
  });
  assert.equal(out.json.alertCount, 0);
  assert.deepEqual(out.json.staleLines, []);
});

test('digest: Fetch alerts reads Alertmanager without silenced or inhibited alerts', () => {
  const wf = loadWorkflow('homelab-health-digest.json');
  const fetch = wf.nodes.find(n => n.name === 'Fetch alerts');
  assert.match(fetch.parameters.url, /:30093\/api\/v2\/alerts$/);
  const q = Object.fromEntries(fetch.parameters.queryParameters.parameters.map(p => [p.name, p.value]));
  assert.deepEqual(q, { active: 'true', silenced: 'false', inhibited: 'false' });
  assert.equal(fetch.alwaysOutputData, true);
  assert.equal(wf.nodes.find(n => n.name === 'Fetch sensors').executeOnce, true);
});

const errorRecord = (over = {}) => ({
  workflow: 'Homelab incident log',
  workflow_id: 'homelabincidlog',
  execution_id: '1',
  node: 'Fetch alerts',
  message: 'The service refused the connection - perhaps it is offline',
  url: 'https://n8n.example/workflow/homelabincidlog/executions/1',
  failed_at: '',
  ...over,
});

test('error alert: one line per workflow+node per hour, repeats counted', () => {
  const wf = loadWorkflow('workflow-error-alert.json');
  const staticData = {};
  const run = (now, input) => runCodeNode(wf, 'Rate limit', { input, now, staticData });
  const t0 = Date.parse('2026-11-07T00:00:00Z');

  const first = run(t0, [errorRecord()]);
  assert.equal(first.length, 1);
  assert.match(first[0].json.body, /^\n- 08:00 ⚠️ workflow failed: \*\*Homelab incident log\*\* at Fetch alerts: The service refused/);

  for (let i = 1; i < 12; i++) assert.deepEqual(run(t0 + i * 5 * 60000, [errorRecord()]), []);

  const other = run(t0 + 10 * 60000, [errorRecord({ workflow: 'Homelab health digest', workflow_id: 'homelabhealthdig' })]);
  assert.equal(other.length, 1, 'a different workflow is not suppressed');

  const next = run(t0 + HOUR, [errorRecord()]);
  assert.equal(next.length, 1);
  assert.match(next[0].json.body, /\(\+11× 08:05–08:55\)/);
});

test('error alert: the hourly flush reports repeats after failures stop, then forgets', () => {
  const wf = loadWorkflow('workflow-error-alert.json');
  const staticData = {};
  const run = (now, input) => runCodeNode(wf, 'Rate limit', { input, now, staticData });
  const t0 = Date.parse('2026-11-07T00:00:00Z');
  const tick = [{}];

  run(t0, [errorRecord()]);
  run(t0 + 5 * 60000, [errorRecord({ message: 'The connection was aborted,\nperhaps the server is offline' })]);
  assert.deepEqual(run(t0 + 30 * 60000, tick), [], 'nothing to flush inside the hour');

  const flushed = run(t0 + HOUR, tick);
  assert.equal(flushed.length, 1);
  assert.match(flushed[0].json.body, /failed 1× more: \*\*Homelab incident log\*\* at Fetch alerts, 08:05–08:05, last: The connection was aborted, perhaps the server is offline/);

  assert.deepEqual(run(t0 + 2 * HOUR, tick), [], 'a flushed window with no repeats writes nothing');
  assert.equal(Object.keys(staticData.errorLines).length, 1);
  run(t0 + 26 * HOUR, tick);
  assert.equal(Object.keys(staticData.errorLines).length, 0, 'quiet keys are dropped after a day');
});

test('error alert: wiring keeps every failure in the table and routes the note through Rate limit', () => {
  const wf = loadWorkflow('workflow-error-alert.json');
  const targets = name => wf.connections[name].main[0].map(c => c.node).sort();
  assert.deepEqual(targets('Build error record'), ['Rate limit', 'Record in workflow_errors']);
  assert.deepEqual(targets('Hourly flush'), ['Rate limit']);
  assert.deepEqual(targets('Rate limit'), ['Append to daily note']);
});
