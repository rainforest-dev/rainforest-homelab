# Wiring the Docker MCP Gateway to Gemini Spark (SSE → Streamable HTTP)

**Date:** 2026-08-01
**Status:** DESIGN — approved. **Revised after live verification: scope reduced to one change.**
**Goal:** Make `docker-mcp.rainforest.tools` connectable as a Gemini Spark custom app.
**Verified against:** the live stack on 2026-08-01 — running launchd gateway (pid 25711,
`:3101`), the deployed OAuth Worker, the operator's Gemini Connected Apps page, and worktree
`relaxed-cannon-823fd0` at `ed751ba`.

## Revision note (read first)

The first draft of this design identified **three** gaps and planned a risky
`@cloudflare/workers-oauth-provider` upgrade to close one of them. Live verification refuted
that gap and closed another. **Only the transport gap is real.**

The decisive evidence: `calibre-mcp.rainforest.tools` is **already connected to Gemini Spark
and syncing** (modal reads `Connected`, `Last synced: 8/1/2026, 2:42:51 PM`) while running the
*same* OAuth Worker, the *same* `0.0.6` library, and serving *no* Protected Resource Metadata.
It is a working reference implementation on our own infrastructure.

Scope is therefore one plist string plus documentation. The Worker is not touched.

## Why this work exists

Gemini Spark accepts custom MCP servers by URL under **Connected Apps → Custom apps for
Spark**. The gateway serves the wrong transport.

## Findings (measured, not assumed)

Every row below was probed against the live stack, not inferred from documentation.

| Check | Result |
|---|---|
| Gateway `/sse` on `localhost:3101` | `200`, `text/event-stream` — works |
| Gateway `/mcp` on `localhost:3101` | `307 → /sse`, then `400` — **not** streamable HTTP |
| Trial gateway with `--transport streaming` on `:3199` | `200` + `Mcp-Session-Id`, **163 tools** enumerated |
| Worker `/.well-known/oauth-authorization-server` | `200`, advertises `registration_endpoint` (DCR works) |
| Worker `/.well-known/oauth-protected-resource` | `404` — **and this turns out not to matter** |
| Public `401` on `/sse` and `/mcp` | `WWW-Authenticate: Bearer realm="OAuth"`, no `resource_metadata=` |
| Gemini → Connected Apps → Custom apps for Spark | **present**, with `Add a custom app` |
| `calibre-mcp.rainforest.tools` in Spark | **Connected**, `Last synced: 8/1/2026, 2:42:51 PM` |

### The reference implementation

`calibre-mcp.rainforest.tools` and `docker-mcp.rainforest.tools` are served by the same OAuth
Worker (`HOSTNAME_BACKENDS` in `workers/oauth-gateway/src/index.ts` routes `calibre-mcp` to
`personal-calibre-internal`). Their `/.well-known/oauth-authorization-server` documents are
byte-identical after hostname normalization, confirming one shared `0.0.6` stack.

| Property | `calibre-mcp` (works in Spark) | `docker-mcp` (target) |
|---|---|---|
| OAuth Worker version | `0.0.6` | `0.0.6` (identical) |
| `/.well-known/oauth-protected-resource` | `404` | `404` |
| `/.well-known/oauth-authorization-server` | `200` | `200` |
| `/mcp` unauthenticated | `401`, no `resource_metadata=` | `401`, no `resource_metadata=` |
| Transport | **streamable HTTP** | **SSE** ← the only difference |

The single controlled variable is transport. That is the whole fix.

### Gap 1 — transport (REAL, the only blocker)

Google's custom-MCP connector supports **Streamable HTTP only**. The gateway runs
`--transport sse`.

`docker mcp gateway run --transport` takes exactly one of `stdio|sse|streaming`. It is not a
multiplexer: **one process cannot serve both transports.** This is what forces a cutover
rather than an additive change.

The redirect behaviour is symmetric and worth recording, because it makes failures look like
successes:

- SSE gateway: `/mcp` → `307` → `/sse`
- Streaming gateway: `/sse` → `307` → `/mcp`

An old SSE client after the flip therefore does **not** get a clean `404`. It follows a
redirect into a transport it cannot speak and fails obscurely. Expect confusing client-side
errors, not obvious ones.

### Gap 2 — OAuth 2.1 PRM (REFUTED, no action)

The first draft assumed Spark requires RFC 9728 Protected Resource Metadata, and planned a
`0.0.6 → 0.8.3` library upgrade to provide it.

`calibre-mcp` disproves this. It serves **no** PRM (`404`) and a `401` challenge with **no**
`resource_metadata=` parameter, yet Spark connected to it and syncs successfully. Spark falls
back to `/.well-known/oauth-authorization-server` — which `docker-mcp` already serves with a
`200` — and completes Dynamic Client Registration via `/register`.

**The Worker is not modified.** This removes the only step capable of taking all remote MCP
access offline.

The upgrade remains worthwhile as independent hygiene (`0.0.6` is far behind `0.8.3`), but it
is unrelated to Spark and must not be bundled into this change, where a login-flow regression
would be misattributed to the transport flip.

### Gap 3 — account eligibility (CLOSED)

Verified directly in the operator's browser: **Connected Apps → Custom apps for Spark** is
present, with a working `Add a custom app` control and one app already connected. The
US-only/personal-account gate does not block this account.

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
does not touch `:3101` or the SSE URL. Other repos' `.mcp.json` files contain no `docker-mcp`
reference (`rainforest-monorepo` points at `calibre-mcp`, a separate service — and one that
must keep working, since it is the Spark reference implementation). Other hits under
`.claude/worktrees/` are copies of this repo.

## Worktree safety

The July gateway spec was authored from a stale worktree and nearly reverted ~26 files of
in-flight work. That hazard was checked for here and does **not** apply:

- All target files are byte-identical between this worktree and the main checkout.
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

Extend the plist's comment block to record why streaming was chosen, keeping the file's
existing convention of explaining non-obvious choices inline.

Deploy: copy to `~/Library/LaunchAgents/`, then
`launchctl kickstart -k gui/$(id -u)/com.homelab.docker-mcp-gateway`.

### 2. Client and documentation updates

Flip the seven references in the blast-radius table from `/sse` → `/mcp` and
`"type": "sse"` → `"type": "http"`. Note `.mcp.json` needs **both** lines changed — changing
only the URL leaves the client still negotiating SSE against a streaming endpoint.

Add a short CLAUDE.md subsection under the existing "Docker MCP Gateway" heading recording:

- the gateway serves **streamable HTTP** at `/mcp`
- `--transport` is single-valued, so SSE and streaming cannot coexist on one process
- the symmetric-redirect gotcha, so a future reader does not misread a `307` as a working
  endpoint
- that Spark needs no PRM, with `calibre-mcp` cited as the precedent — so nobody re-derives
  the refuted Gap 2 later

### 3. Verification

Each check gates the next:

1. `curl` `localhost:3101/mcp` initialize → `200` + `Mcp-Session-Id` (transport flip works)
2. `tools/list` over that session → expect ~163 tools (servers still load; no name collision)
3. `curl` public `/mcp` unauthenticated → `401` (Worker untouched, should be unchanged)
4. Reconnect `docker-remote` in Claude Code with `"type": "http"`; confirm tools resolve
5. Add `https://docker-mcp.rainforest.tools/mcp` in Gemini Spark → **Add a custom app**,
   matching the URL shape `calibre-mcp` already uses successfully
6. Confirm the new app shows `Connected` with a fresh `Last synced` timestamp

No OAuth login re-test is required, because the Worker is not modified.

### 4. Rollback

Revert the plist string and `launchctl kickstart -k`. ~30 seconds, single file, no deploy.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A forgotten SSE client fails obscurely via the `307` rather than a clean error | Low | Inventory is complete and small; gotcha documented in CLAUDE.md |
| Streaming gateway behaves differently under sustained load than in the `:3199` trial | Low | Trial enumerated all 163 tools cleanly; rollback is one string |
| Spark rejects the server for an undocumented reason | Low | `calibre-mcp` proves the exact Worker + DCR + URL shape already works |

Removing the Worker upgrade eliminated the only High-severity risk in the original design.

## Out of scope

- Upgrading `@cloudflare/workers-oauth-provider` (worthwhile hygiene; unrelated to Spark —
  track separately so a login regression is never misattributed to this change).
- Migrating other MCP endpoints (`obsidian`) to streamable HTTP.
- Changing Zero Trust or tunnel topology.
- Adding new MCP servers to the `default` profile.
