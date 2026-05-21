output "service_url" {
  description = "Grafana MCP SSE endpoint (LAN)"
  value       = "http://localhost:${var.mcp_port}/sse"
}
