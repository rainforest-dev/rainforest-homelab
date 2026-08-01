# Wiring the Docker MCP Gateway to Gemini Spark (SSE → Streamable HTTP)

**Date:** 2026-08-01
**Status:** DESIGN — approved, not yet implemented.
**Goal:** Make `docker-mcp.rainforest.tools` connectable as a Gemini Spark custom app.
**Verified against:** the live stack on 2026-08-01 — running launchd gateway (pid 25711,
`:3101`), the deployed OAuth Worker, and worktree `relaxed-cannon-823fd0` at `ed751ba`.

## Why this work exists

Gemini Spark accepts custom MCP servers by URL under **Connected Apps → Custom apps for
Spark**. Two properties of our gateway currently make it unconnectable, and a third is an
external gate we do not control.

## Findings (measured, not assumed)

Every row below was probed against the live stack, not inferred from documentation.

| Check | Result |
|---|---|
| Gateway `/sse` on `localhost:3101` | `200`, `text/event-stream` — works |
| Gateway `/mcp` on `localhost:3101` | `307 → /sse`, then `400` — **not** streamable HTTP |
| Worker `/.well-known/oauth-authorization-server` | `200`, advertises `registration_endpoint` (DCR works) |
| Worker `/.well-known/oauth-protected-resource` | **`404`** |
| Public `401` challenge on `/sse` and `/mcp` | `WWW-Authenticate: Bearer realm="OAuth"` — **no `resource_metadata=` parameter** |
| Trial gateway with `--transport streaming` on `:3199` | `200` + `Mcp-Session-Id`, **163 tools** enumerated |

### Gap 1 — transport

Google's custom-MCP connector supports **Streamable HTTP only**. The gateway runs
`--transport sse`.

`docker mcp gateway run --transport` takes exactly one of `stdio|sse|streaming`. It is not a
multiplexer: **one process cannot serve both transports.** This is the constraint that forces
a cutover rather than an additive change.

The redirect behaviour is symmetric and worth recording, because it makes failures look like
successes:

- SSE gateway: `/mcp` → `307` → `/sse`
- Streaming gateway: `/sse` → `307` → `/mcp`

An old SSE client after the flip therefore does **not** get a clean `404`. It follows a
redirect into a transport it cannot speak and fails obscurely. Expect confusing client-side
errors, not obvious ones.

### Gap 2 — OAuth 2.1 discovery

Spark speaks OAuth 2.1, which discovers the authorization server via RFC 9728 Protected
Resource Metadata: the `/.well-known/oauth-protected-resource` document plus the
`resource_metadata=` hint in the `401` challenge. Both are absent.

Root cause is the pinned dependency: `@cloudflare/workers-oauth-provider@^0.0.6` (latest
`0.8.3`). RFC 9728 support — including path-aware metadata and the `resource_metadata` hint
in `WWW-Authenticate` — landed in that gap.

Dynamic Client Registration itself already works, so once PRM exists Spark should
self-register without manually provisioned credentials.

### Gap 3 — account eligibility (external, unresolved)

Google gates this feature on **18+, in the US, personal Google Account** (not Workspace).
The operator is in Taipei on `contact@rainforest.tools`.

**This is not fixable from this repo.** Confirm that
**gemini.google.com/apps → Custom apps for Spark → Add a custom app** is visible before
expecting a working Spark connection. Gaps 1 and 2 remain worth closing regardless — they are
correctness fixes for *any* modern OAuth 2.1 MCP client, not Spark-specific hacks.

## Blast radius

Complete inventory of SSE consumers, from searching `~/Repositories`, `~/.claude.json`,
Claude Desktop config, `~/.gemini`, and `~/.codex`:

| File | References |
|---|---|
| `.mcp.json` | 2 — lines 33 (`"type": "sse"`) and 34 (`/sse` URL) |
| `CLAUDE.md` | 2 — lines 433, 519 |
| `README.md` | 3 — lines 242, 277, 314 |

Nothing else on the machine consumes the SSE endpoint.

**Explicitly unaffected:** `~/.gemini/config/mcp_config.json` runs
`docker mcp gateway run --profile antigravity` over **stdio**, on a *different profile*. `agy`
does not touch `:3101` or the SSE URL. Other repos' `.mcp.json` files contain no
`docker-mcp` reference (`rainforest-monorepo` points at `calibre-mcp`, a separate service).
Other hits under `.claude/worktrees/` are copies of this repo.

## Worktree safety

The July gateway spec was authored from a stale worktree and nearly reverted ~26 files of
in-flight work. That hazard was checked for here and does **not** apply:

- All five target files are byte-identical between this worktree and the main checkout.
- The worktree is at `ed751ba`, which already contains main's `39b64cd`.
- The only dirty path in the main checkout is `modules/comfyui/server` (unrelated submodule).

## Design

### 1. Gateway transport flip

**File:** `configs/docker-mcp-gateway/com.homelab.docker-mcp-gateway.plist`

Change the single `<string>sse</string>` in `ProgramArguments` to `<string>streaming</string>`.

Everything else stays: port `3101`, `--host 0.0.0.0`, `--allow-unauthenticated`, `--watch`,
`--profile default`. Because the port is unchanged, the tunnel route
`docker-mcp-internal → host.docker.internal:3101` in `locals.tf` needs **no change** and no
`terraform apply` is required.

Extend the plist's comment block to record why streaming was chosen (Spark requires it; OAuth
2.1 clients generally expect it), keeping the file's existing convention of explaining
non-obvious choices inline.

Deploy: copy to `~/Library/LaunchAgents/`, then
`launchctl kickstart -k gui/$(id -u)/com.homelab.docker-mcp-gateway`.

### 2. Worker OAuth upgrade

**Files:** `workers/oauth-gateway/package.json`, `workers/oauth-gateway/src/index.ts`

Bump `@cloudflare/workers-oauth-provider` from `^0.0.6` to `^0.8.3` and adapt the
`new OAuthProvider({...})` construction (`index.ts:75-86`, the file's default export) to the
current API. This yields
`/.well-known/oauth-protected-resource` and the `resource_metadata=` hint as library
built-ins rather than a hand-rolled shim on a pinned old dependency.

No routing change is needed: `apiHandlers` already registers `/mcp`. That route is presently a
dead end only because the *backend* 307s it away — step 1 fixes that, and the route starts
working with no edit.

`mcpProxyHandler` needs no changes. It forwards method, headers and body verbatim and is
transport-agnostic; the `X-Forwarded-*` / `X-GitHub-*` header injection and hostname-based
backend routing are unaffected.

### 3. Client and documentation updates

Flip the six references in the blast-radius table from `/sse` → `/mcp` and
`"type": "sse"` → `"type": "http"`.

Add a short CLAUDE.md subsection under the existing "Docker MCP Gateway" heading recording
that the gateway serves **streamable HTTP**, that `--transport` is single-valued, and the
symmetric-redirect gotcha — so a future reader debugging a client does not misread a `307` as
a working endpoint.

### 4. Sequencing

Step 1 before step 2, deliberately. The transport flip is trivially reversible and
independently verifiable; the Worker upgrade touches the auth path guarding *all* remote MCP
access. Sequencing them separately keeps any failure attributable to one change.

### 5. Verification

Each check gates the next:

1. `curl` `localhost:3101/mcp` initialize → `200` + `Mcp-Session-Id` (transport flip works)
2. `tools/list` over that session → expect ~163 tools (servers still load; no name collision)
3. `curl` public `/mcp` unauthenticated → `401` whose `WWW-Authenticate` **contains
   `resource_metadata=`** (upgrade works)
4. `curl` public `/.well-known/oauth-protected-resource` → `200` (currently `404`)
5. **Re-run the GitHub OAuth login end-to-end.** Not optional — the upgrade modifies the auth
   path, and metadata endpoints returning `200` does not prove the login flow survived.
6. Reconnect `docker-remote` in Claude Code; confirm tools resolve.
7. Add `https://docker-mcp.rainforest.tools/mcp` in Gemini Spark (gated on Gap 3).

### 6. Rollback

- **Gateway:** revert the plist string, `launchctl kickstart -k`. ~30 seconds.
- **Worker:** `git revert`, `wrangler deploy`. ~30 seconds.

Both are independent, matching the sequencing rationale.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Worker upgrade breaks the GitHub login flow, taking `docker-mcp.rainforest.tools` offline | High | Sequenced second, verified independently, fast `git revert` + redeploy |
| A forgotten SSE client fails obscurely via the `307` rather than a clean error | Low | Inventory is complete and small; gotcha documented in CLAUDE.md |
| Spark rejects the server for an undocumented reason (no client-side logs) | Medium | Steps 1–6 verify our side against the spec independently of Spark |
| Gap 3 blocks the connection entirely | Medium | External; unblocks nothing else — steps 1–3 remain correct regardless |

## Out of scope

- Migrating other MCP endpoints (`calibre-mcp`, `obsidian`) to streamable HTTP.
- Changing Zero Trust or tunnel topology.
- Adding new MCP servers to the `default` profile.
