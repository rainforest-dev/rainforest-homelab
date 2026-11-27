import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const WORKFLOWS = new URL('../workflows/', import.meta.url);

export const loadWorkflow = file => JSON.parse(readFileSync(new URL(file, WORKFLOWS), 'utf8'));

const items = list => list.map(json => ({ json }));

// Runs a Code node's jsCode the way n8n's "Run Once for All Items" mode does.
// `nodes` maps node name -> array of output json, `input` is this node's input json.
export function runCodeNode(workflow, nodeName, { input = [], nodes = {}, now = Date.now(), staticData = {} } = {}) {
  const node = workflow.nodes.find(n => n.name === nodeName);
  if (!node) throw new Error(`no node ${nodeName}`);
  const ref = name => {
    if (!(name in nodes)) throw new Error(`node ${name} not provided`);
    const out = items(nodes[name]);
    return { all: () => out, first: () => out[0] };
  };
  const $now = { toMillis: () => now };
  const context = vm.createContext({
    $: ref,
    $input: { all: () => items(input), first: () => items(input)[0] },
    $json: input[0],
    $now,
    $getWorkflowStaticData: () => staticData,
  });
  const result = vm.runInContext(`(function () {\n${node.parameters.jsCode}\n})()`, context);
  return JSON.parse(JSON.stringify(result));
}
