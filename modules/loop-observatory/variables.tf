variable "project_name" {
  description = "Project name used to prefix container and volume names"
  type        = string
  default     = "homelab"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "dev"
}

variable "image" {
  description = "Container image for loop-observatory"
  type        = string
}

variable "external_port" {
  description = "Host port the app is published on. Executors reach the enrollment API here over the tailnet, so this is also the port pinned on the /setup page."
  type        = number
  default     = 3099
}

variable "vault_path" {
  description = "Host path to the Obsidian vault ROOT (not _system). Mounted READ-WRITE at /vault: task decisions, task notes, the greenlight outbox and the enrollment store all write into it."
  type        = string
}

variable "loop_state_path" {
  description = "Host path to ~/.claude/loop. Mounted read-write at /loop for config.yaml, greenlight/ and greenlight-outbox/."
  type        = string
}

variable "loop_sync_token_path" {
  description = "Host path to the loop-sync bearer token. Mounted read-only; the only secret this container receives."
  type        = string
}

variable "usage_machine" {
  description = "Machine name this instance attributes usage to."
  type        = string
  default     = "rainforest-mini"
}

variable "loop_sync_url" {
  description = "Refresh endpoint of the loop-sync service on the host. It binds 127.0.0.1, which Docker Desktop for Mac still reaches through host.docker.internal (verified 2026-08-27); on a Linux daemon this would need the service rebound."
  type        = string
  default     = "http://host.docker.internal:3310/refresh"
}

variable "memory_limit" {
  description = "Container memory limit. The app parses ~96MB of JSONL ledgers per chart request, so rss-manager's 256Mi would OOM-kill it."
  type        = string
  default     = "2Gi"
}

variable "loop_engine_bundle_path" {
  description = "Host directory holding loop-engine.tar.gz and its .sha256, mounted read-only at /engine. Refreshed from the loop-engine GitHub Release; the app serves a released artifact rather than the mini's working tree, which routinely carries uncommitted changes."
  type        = string
}

# The public address the app is reached at.
#
# It is the origin allowlist for state-changing requests, not decoration: the
# app sits behind a TLS terminator, so Astro cannot derive the browser-facing
# origin from the request it receives. The app defaults to this same value, but
# a default that has to match a DNS name is the kind of agreement that silently
# stops being true -- naming it here makes a domain change one edit rather than
# a rebuild.
variable "site_url" {
  description = "Public origin the Observatory is served from; allowlisted for POSTs."
  type        = string
  default     = "https://loop.rainforest.tools"
}
