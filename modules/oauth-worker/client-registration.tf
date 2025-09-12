# OAuth Client Registration
# This registers a persistent OAuth client for Claude MCP authentication

# Run client registration script when OAuth Worker is deployed
resource "null_resource" "register_oauth_client" {
  # Re-run when OAuth Worker URL changes
  triggers = {
    worker_url = "https://docker-mcp.${var.domain_suffix}"
  }

  # Wait for the Worker domain to be ready
  depends_on = [cloudflare_workers_domain.oauth_gateway]

  provisioner "local-exec" {
    command = <<-EOT
      # Set environment variables for the registration script
      export OAUTH_WORKER_URL="https://docker-mcp.${var.domain_suffix}"
      export CLIENT_NAME="Claude"
      export REDIRECT_URI="https://claude.ai/api/mcp/auth_callback"
      
      # Run the registration script and capture output
      ${path.root}/scripts/register-oauth-client.sh > ${path.module}/client-registration-output.json
      
      # Extract client credentials from the output
      CLIENT_ID=$(grep '"client_id":' ${path.module}/client-registration-output.json | grep -o '"[^"]*"' | tail -1 | tr -d '"')
      CLIENT_SECRET=$(grep '"client_secret":' ${path.module}/client-registration-output.json | grep -o '"[^"]*"' | tail -1 | tr -d '"')
      
      # Store credentials in local files for Terraform to read
      echo "$CLIENT_ID" > ${path.module}/client-id.txt
      echo "$CLIENT_SECRET" > ${path.module}/client-secret.txt
      
      echo "OAuth client registered: $CLIENT_ID"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/client-*.txt ${path.module}/client-registration-output.json"
  }
}

# Read the registered client credentials
data "local_file" "client_id" {
  filename   = "${path.module}/client-id.txt"
  depends_on = [null_resource.register_oauth_client]
}

data "local_file" "client_secret" {
  filename   = "${path.module}/client-secret.txt"
  depends_on = [null_resource.register_oauth_client]
}