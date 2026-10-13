# Review guide

Pull requests here are reviewed by the subagents in `.claude/agents/review-*.md`.
The `Claude Review` workflow runs the ones the changed paths call for, checks their
findings and posts them as inline comments plus one summary. The loop runs the same
subagents before it opens a PR.

| Reviewer | Runs when the PR changes | Asks |
|---|---|---|
| `review-correctness` | anything | Does the change do what it says without breaking what it touches? |
| `review-exposure` | `*.tf`, `modules/**`, `workers/**`, `configs/**`, `scripts/**`, any docs or example file | After apply, can anyone reach something new? Does a secret land in this public repo? |
| `review-apply-safety` | `*.tf`, `.terraform.lock.hcl`, `modules/**`, `workers/**`, `configs/**`, `CLAUDE.md`, module READMEs | What will apply really do to running services and data, and is the runbook still true? |

## Rules reviewers cite

- CLAUDE.md "Cloudflare Tunnel Configuration", including "The remote tunnel config
  overrides the ConfigMap"
- CLAUDE.md "Docker MCP Gateway" (loopback binding, Host header rewrite, reload with
  `bootout`/`bootstrap`, not `kickstart`)
- CLAUDE.md "Memories MCP" and "Calibre MCP" (`^/mcp$` tunnel rules, gateway secret,
  `127.0.0.1` publishing, apply before `wrangler deploy`)
- CLAUDE.md "Security Considerations"

## Severity

`🔴 blocking`: a new unauthenticated path from the internet, a secret in the repo, data
loss on apply, a change that silently does nothing, or a runbook made wrong.
`🟡 optional`: everything else.

## Not worth a comment

`terraform fmt` style, provider version taste, and anything in code the PR did not
change. Placeholders such as `<PI_IP>` are intentional.
