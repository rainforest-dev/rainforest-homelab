# Docker MCP Gateway → Streamable HTTP (Gemini Spark) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch the launchd-managed Docker MCP Gateway from SSE to streamable HTTP so `docker-mcp.rainforest.tools` can be added as a Gemini Spark custom app.

**Architecture:** One process, one transport. `docker mcp gateway run --transport` accepts exactly one of `stdio|sse|streaming`, so this is a cutover, not an additive change. The port (`3101`) is unchanged, so the Cloudflare Tunnel route and all Terraform stay untouched. The OAuth Worker is **not** modified — `calibre-mcp.rainforest.tools` already proves Spark connects through this exact Worker without Protected Resource Metadata.

**Tech Stack:** macOS launchd (plist), Docker MCP Toolkit CLI, `curl` for verification. No Terraform, no `wrangler`, no npm.

**Spec:** `docs/superpowers/specs/2026-08-01-gemini-spark-mcp-streaming-design.md`

---

## Before you start

**This change will disconnect the `docker-remote` MCP server in your current Claude Code session.** `.mcp.json` declares `"type": "sse"`, and after Task 1 the gateway no longer speaks SSE. Task 3 fixes the config, but the connection only returns after Claude Code reloads MCP servers. If you depend on `MCP_DOCKER` tools mid-plan, finish those first — the plan itself needs only `Bash`, `Read`, and `Edit`.

**Rollback at any point:** revert the plist string, then `launchctl kickstart -k gui/$(id -u)/com.homelab.docker-mcp-gateway`. ~30 seconds.

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist` | Source of truth for how the gateway process is launched | `sse` → `streaming`, comment block extended |
| `~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist` | The **live** copy launchd actually reads (not version-controlled) | Overwritten from the repo copy |
| `.mcp.json` | This repo's MCP client config | `"type"` and `"url"` both change |
| `CLAUDE.md` | Operational reference for the gateway | 4 refs + 1 new subsection |
| `README.md` | Public-facing service docs | 5 refs, incl. 2 pre-existing bugs |

**Why the repo plist and the LaunchAgents plist are separate steps:** editing the repo file changes nothing at runtime. launchd reads only `~/Library/LaunchAgents/`. Forgetting the copy is the most likely way to "apply" this change and see nothing happen.

---

### Task 1: Flip the gateway transport

**Files:**
- Modify: `configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist:44` (and comment block near line 22)

- [ ] **Step 1: Confirm the current state fails the target check**

Run:
```bash
curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}\n" -X POST http://localhost:3101/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}' \
  --max-time 8
```

Expected: `307 -> http://localhost:3101/sse`

This is the defect. If you instead get `200`, the flip has already been applied — skip to Task 2.

> **Always send a complete `initialize` — never `"params":{}`.**
> Gateway v0.43.3 has an upstream bug: `telemetry.RecordInitialize`
> (`pkg/telemetry/telemetry.go:549`) dereferences `clientInfo` without a nil
> check, so an `initialize` with empty params **SIGSEGVs the gateway process**.
> Under SSE this is invisible (the request 307s before it is ever parsed); under
> streaming it is parsed and kills the process, which `KeepAlive` then restarts —
> looking exactly like "streaming transport is broken". It is not. Real clients
> (Claude Code, Gemini Spark) always send `clientInfo`. Reproduced and confirmed
> 2026-08-01. Every curl in this plan sends full params for this reason.

- [ ] **Step 2: Change the transport string**

In `configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist`, inside `ProgramArguments`, change line 44:

```xml
        <string>--transport</string>
        <string>sse</string>
```

to:

```xml
        <string>--transport</string>
        <string>streaming</string>
```

Change **only** that one `<string>`. Leave `--profile default`, `--port 3101`, `--host 0.0.0.0`, `--allow-unauthenticated`, and `--watch` exactly as they are.

- [ ] **Step 3: Record why, in the existing comment block**

The plist's header comment explains every non-obvious choice. Append this paragraph immediately before the closing `-->` (after the existing `--allow-unauthenticated` paragraph, around line 28):

```
  --transport streaming (not sse): Gemini Spark's custom-MCP connector speaks
  Streamable HTTP only, and modern OAuth 2.1 MCP clients expect it. `--transport`
  takes a SINGLE value — one process cannot serve both SSE and streaming — so
  this is a cutover. The gateway now serves /mcp; /sse 307-redirects to it, which
  means stale SSE clients fail obscurely rather than cleanly. Port 3101 is
  unchanged, so the Cloudflare Tunnel route needs no edit.
```

- [ ] **Step 4: Install the plist where launchd actually reads it**

Run:
```bash
cp configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist ~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist
```

- [ ] **Step 5: Verify the installed copy really changed**

Run:
```bash
grep -A1 -- '--transport' ~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist
```

Expected output contains `<string>streaming</string>`. If it still says `sse`, the copy in Step 4 did not happen — do not continue.

- [ ] **Step 6: Reload the gateway (NOT `kickstart`)**

Run:
```bash
launchctl bootout gui/$(id -u)/com.homelab.docker-mcp-gateway 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist
```

Produces no output on success.

> **`launchctl kickstart -k` will NOT work here.** It restarts the process from
> launchd's already-loaded, in-memory job definition — it does not re-read the
> plist from disk. After a `kickstart`, the gateway silently keeps running the
> **old** `--transport sse` while reporting success, which is indistinguishable
> from the change having worked. `bootout` + `bootstrap` is the correct sequence
> when the plist file itself changed. (`kickstart -k` remains fine for restarting
> after a *profile or Keychain* change, where the plist is unchanged — which is
> why CLAUDE.md documents it; Task 4 clarifies that distinction.)

- [ ] **Step 6b: Prove the running process actually picked up the new flag**

Run:
```bash
ps -o command= -p "$(pgrep -f 'docker-mcp-gateway|mcp gateway run' | head -1)" | tr ' ' '\n' | grep -A1 -- '--transport'
```

Expected: `--transport` followed by `streaming`. If it says `sse`, Step 6 did not
take effect — do not continue to Task 2.

- [ ] **Step 7: Commit**

```bash
git add configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist
git commit -m "$(cat <<'EOF'
feat(mcp): serve the gateway over streamable HTTP

Gemini Spark's custom-MCP connector speaks Streamable HTTP only. The
gateway ran --transport sse, so /mcp merely 307-redirected to /sse.
--transport is single-valued, so this is a cutover: /sse now redirects
to /mcp and stale SSE clients fail obscurely.

Port 3101 is unchanged, so the tunnel route and Terraform are untouched.

Refs: no-ticket
EOF
)"
```

---

### Task 2: Verify the gateway actually serves streamable HTTP

No files change. This task exists because Task 1 can appear to succeed while the gateway silently fails to start — `KeepAlive` will restart it in a crash loop and the port stays bound.

- [ ] **Step 1: Confirm the initialize handshake**

Run:
```bash
curl -s -D - -o /dev/null -X POST http://localhost:3101/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}' \
  --max-time 20 | grep -iE '^HTTP|^Mcp-Session-Id'
```

Expected:
```
HTTP/1.1 200 OK
Mcp-Session-Id: <some opaque id>
```

If you get `307`, the plist copy or the restart did not take effect — revisit Task 1 Steps 4-6.

- [ ] **Step 2: Confirm all servers still load**

A gateway that starts but fails to load its profile will return `200` with an empty tool list. Tool-name collisions also surface here.

Run:
```bash
SID=$(curl -s -D - -o /dev/null -X POST http://localhost:3101/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"p","version":"1"}}}' --max-time 30 | grep -i '^Mcp-Session-Id' | tr -d '\r' | awk '{print $2}')
curl -s -X POST http://localhost:3101/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -H "Mcp-Session-Id: $SID" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' --max-time 10 >/dev/null
curl -s -X POST http://localhost:3101/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -H "Mcp-Session-Id: $SID" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' --max-time 60 \
  | python3 -c "import sys,json;[print('tools:',len(json.loads(l[6:])['result']['tools'])) for l in sys.stdin if l.startswith('data: ')]"
```

Expected: `tools: 163` (a number near 163 is fine — the count moves as catalog servers change; a count of `0` or an error is a failure).

- [ ] **Step 3: Check the log for startup errors**

Run:
```bash
tail -30 ~/Library/Logs/docker-mcp-gateway.log
```

Expected: no repeated panic/restart lines. A tool-name collision appears here as a hard failure at "loading configuration" — if one appears, disable the duplicate with `docker mcp profile tools default --disable <server>.<tool>` and restart.

- [ ] **Step 4: Confirm the public endpoint still authenticates**

The Worker is untouched, so this must be unchanged from before.

Run:
```bash
curl -s -o /dev/null -D - -X POST https://docker-mcp.rainforest.tools/mcp -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' --max-time 15 | grep -iE '^HTTP|www-authenticate'
```

Expected:
```
HTTP/2 401
www-authenticate: Bearer realm="OAuth", error="invalid_token", error_description="Missing or invalid access token"
```

A `401` here is **success** — it proves the tunnel reaches the Worker and the Worker is guarding the route.

---

### Task 3: Point this repo's MCP client at `/mcp`

**Files:**
- Modify: `.mcp.json:33-34`

- [ ] **Step 1: Update both lines**

In `.mcp.json`, change the `docker-remote` block from:

```json
    "docker-remote": {
      "type": "sse",
      "url": "https://docker-mcp.rainforest.tools/sse"
    }
```

to:

```json
    "docker-remote": {
      "type": "http",
      "url": "https://docker-mcp.rainforest.tools/mcp"
    }
```

Both lines must change. Changing only the URL leaves the client negotiating SSE against a streaming endpoint.

Do **not** touch the `cloudflare-*` entries above it — `https://docs.mcp.cloudflare.com/sse` is a third-party server and is correctly SSE.

- [ ] **Step 2: Verify the JSON is still valid**

Run:
```bash
python3 -c "import json;d=json.load(open('.mcp.json'));print(d['mcpServers']['docker-remote'])"
```

Expected: `{'type': 'http', 'url': 'https://docker-mcp.rainforest.tools/mcp'}`

- [ ] **Step 3: Confirm no stale docker-mcp SSE refs remain in config**

Run:
```bash
grep -rn "docker-mcp.rainforest.tools/sse" --include="*.json" . || echo "clean"
```

Expected: `clean`

- [ ] **Step 4: Commit**

```bash
git add .mcp.json
git commit -m "$(cat <<'EOF'
fix(mcp): point docker-remote at the streamable HTTP endpoint

The gateway no longer speaks SSE. Both the transport type and the URL
path change; updating only the URL would leave the client negotiating
SSE against /mcp.

Refs: no-ticket
EOF
)"
```

---

### Task 4: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md:289`, `CLAUDE.md:432-433`, `CLAUDE.md:468`, `CLAUDE.md:517-518`
- Modify: `CLAUDE.md` — new subsection after the bullet list ending at line 302

- [ ] **Step 1: Fix the command description at line 289**

Change:

```
It runs `docker mcp gateway run --profile default --transport sse --port 3101
```

to:

```
It runs `docker mcp gateway run --profile default --transport streaming --port 3101
```

- [ ] **Step 2: Fix the service-token example at lines 432-433**

Change:

```json
       "docker-remote": {
         "type": "sse",
         "url": "https://docker-mcp.yourdomain.com/sse",
```

to:

```json
       "docker-remote": {
         "type": "http",
         "url": "https://docker-mcp.yourdomain.com/mcp",
```

- [ ] **Step 3: Fix the local-development example at lines 467-468**

Note the server key here is `docker-local`, not `docker-remote` — do not rename it.

Change:

```json
    "docker-local": {
      "type": "sse",
      "url": "http://localhost:3101/sse"  // Bypasses Cloudflare entirely
    }
```

to:

```json
    "docker-local": {
      "type": "http",
      "url": "http://localhost:3101/mcp"  // Bypasses Cloudflare entirely
    }
```

Both lines change, same as `.mcp.json` in Task 3.

- [ ] **Step 4: Fix the persistent-OAuth example at lines 517-518**

Change:

```json
    "docker-remote": {
      "type": "sse",
      "url": "https://docker-mcp.rainforest.tools/sse",
```

to:

```json
    "docker-remote": {
      "type": "http",
      "url": "https://docker-mcp.rainforest.tools/mcp",
```

- [ ] **Step 4b: Correct the restart instruction at line 300**

CLAUDE.md currently says:

```markdown
- **Restart / apply config changes:** `launchctl kickstart -k gui/$(id -u)/com.homelab.docker-mcp-gateway`
```

That is right for profile/Keychain changes but **wrong for plist changes**, and the
difference is silent. Replace with:

```markdown
- **Restart after a profile/Keychain change:** `launchctl kickstart -k gui/$(id -u)/com.homelab.docker-mcp-gateway`
- **Reload after editing the plist:** `kickstart` does **not** re-read the plist from
  disk — it restarts from launchd's in-memory job definition, so the gateway keeps
  running the old arguments while appearing to succeed. Use:
  ```bash
  launchctl bootout gui/$(id -u)/com.homelab.docker-mcp-gateway 2>/dev/null
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist
  ```
  Then confirm with `ps -o command= -p "$(pgrep -f 'mcp gateway run' | head -1)"`.
```

- [ ] **Step 5: Add the transport subsection**

Insert immediately after the `- **Logs:**` bullet (line 302) and before `### Config and secrets (profile + Keychain, never in git)`:

```markdown
### Transport: streamable HTTP only

The gateway serves **streamable HTTP at `/mcp`**. `docker mcp gateway run
--transport` takes a **single** value (`stdio|sse|streaming`) — it is not a
multiplexer, so SSE and streaming cannot coexist on one process. Clients must use
`"type": "http"` with the `/mcp` path.

**Gotcha — the redirect makes failures look like successes.** The redirect is
symmetric: an SSE gateway 307s `/mcp` → `/sse`, and a streaming gateway 307s
`/sse` → `/mcp`. A stale SSE client therefore does *not* get a clean 404. It
follows the redirect into a transport it cannot speak and fails obscurely. When
debugging a client, never read a `307` as "the endpoint works".

**Gemini Spark does not need Protected Resource Metadata.** Spark's custom-MCP
connector requires streamable HTTP, but *not* RFC 9728 PRM. The OAuth Worker
returns 404 for `/.well-known/oauth-protected-resource` and omits
`resource_metadata=` from its 401 challenge, and Spark connects anyway by falling
back to `/.well-known/oauth-authorization-server` (200) and completing Dynamic
Client Registration at `/register`. `calibre-mcp.rainforest.tools` is the
precedent — same Worker, same 0.0.6 library, connected and syncing. Do not
upgrade `@cloudflare/workers-oauth-provider` on the theory that Spark requires
it; that was investigated and refuted on 2026-08-01.

**Add to Gemini Spark:** gemini.google.com/apps → Custom apps for Spark → Add a
custom app → `https://docker-mcp.rainforest.tools/mcp`.
```

- [ ] **Step 6: Verify no stale refs remain**

Run:
```bash
grep -n "docker-mcp.*\/sse\|localhost:3101/sse\|--transport sse" CLAUDE.md || echo "clean"
```

Expected: `clean`

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(mcp): document the streamable-HTTP transport

Updates the three client examples and the gateway command description,
and adds a Transport subsection recording the single-valued --transport
constraint, the symmetric-redirect gotcha, and why Spark needs no PRM
(so the refuted Worker upgrade is not re-derived later).

Refs: no-ticket
EOF
)"
```

---

### Task 5: Update README.md

**Files:**
- Modify: `README.md:238`, `README.md:242-243`, `README.md:277`, `README.md:314`

Two of these are **pre-existing bugs** unrelated to the transport flip, on lines this task already edits: line 238 claims two transports, and line 243 names port `3100` when the gateway has always listened on `3101`.

- [ ] **Step 1: Correct the transport capability claim at line 238**

Change:

```markdown
- **Multiple Transports**: SSE and HTTP streaming support
```

to:

```markdown
- **Streamable HTTP**: single-transport gateway; `--transport` takes one value, so SSE is not served concurrently
```

- [ ] **Step 2: Fix both usage URLs at lines 242-243**

Change:

```markdown
1. **OAuth-Protected (Recommended)**: `https://docker-mcp.rainforest.tools/sse`
2. **Local Development**: `http://localhost:3100/sse` (bypasses authentication)
```

to:

```markdown
1. **OAuth-Protected (Recommended)**: `https://docker-mcp.rainforest.tools/mcp`
2. **Local Development**: `http://localhost:3101/mcp` (bypasses authentication)
```

The port correction from `3100` to `3101` is deliberate — `3100` was never right.

- [ ] **Step 3: Fix the endpoint at line 277**

Change:

```markdown
4. **Access OAuth-protected endpoint**: `https://docker-mcp.yourdomain.com/sse`
```

to:

```markdown
4. **Access OAuth-protected endpoint**: `https://docker-mcp.yourdomain.com/mcp`
```

- [ ] **Step 4: Fix the endpoint at line 314**

Change:

```markdown
- **OAuth-Protected URL**: `https://docker-mcp.yourdomain.com/sse`
```

to:

```markdown
- **OAuth-Protected URL**: `https://docker-mcp.yourdomain.com/mcp`
```

- [ ] **Step 5: Verify no stale refs remain**

Run:
```bash
grep -n "docker-mcp.*\/sse\|localhost:3100" README.md || echo "clean"
```

Expected: `clean`

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs(mcp): correct gateway URLs, transport claim, and local port

Points the four documented endpoints at /mcp. Also fixes two pre-existing
errors on the same lines: the gateway serves one transport, not "SSE and
HTTP streaming", and local development is port 3101, never 3100.

Refs: no-ticket
EOF
)"
```

---

### Task 6: Reconnect clients and add to Gemini Spark

No files change. These are the end-to-end checks.

- [ ] **Step 1: Repo-wide stale-reference sweep**

Run:
```bash
grep -rn "docker-mcp.rainforest.tools/sse\|docker-mcp.yourdomain.com/sse" --include="*.md" --include="*.json" . | grep -v "^./docs/superpowers/" || echo "clean"
```

Expected: `clean`. Hits under `docs/superpowers/` are historical specs and are excluded deliberately — do not rewrite past design documents.

- [ ] **Step 2: Reconnect `docker-remote` in Claude Code**

Reload MCP servers so the new `.mcp.json` takes effect, then confirm a `MCP_DOCKER` tool resolves. If the server still fails, re-check `.mcp.json` has **both** `"type": "http"` and the `/mcp` path.

- [ ] **Step 3: Add the custom app in Gemini Spark**

In a browser: gemini.google.com/apps → **Custom apps for Spark** → **Add a custom app** → enter:

```
https://docker-mcp.rainforest.tools/mcp
```

Complete the GitHub OAuth consent when prompted. This is the same flow `calibre-mcp` already uses.

- [ ] **Step 4: Confirm the connection**

On the Connected Apps page, the new app should show **Connected** with a fresh `Last synced` timestamp, exactly like the `Calibre Mcp` card. Click **More details** to confirm it lists available actions.

If Spark reports a failure, capture the exact message — the likeliest causes are a typo in the URL path and an incomplete OAuth consent, in that order. The gateway side is already proven by Task 2.

---

## Rollback

If anything in Tasks 1-2 misbehaves:

```bash
git revert --no-edit HEAD
cp configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist ~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist
launchctl bootout gui/$(id -u)/com.homelab.docker-mcp-gateway 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.homelab.docker-mcp-gateway.plist
```

`bootout` + `bootstrap`, not `kickstart` — the plist file changed, so launchd must
re-read it from disk.

Then confirm SSE is back:

```bash
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" http://localhost:3101/sse --max-time 5
```

Expected: `200 text/event-stream`

Remember to restore `.mcp.json` to `"type": "sse"` / `/sse` if Task 3 was already committed.
