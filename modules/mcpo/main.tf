# MCPO configuration file
resource "local_file" "mcpo_config" {
  filename = "${path.root}/mcpo-config.json"
  content = jsonencode({
    mcpServers = {
      MCP_DOCKER = {
        command = "docker"
        args    = ["mcp", "gateway", "run"]
        type    = "stdio"
      }
    }
  })
}

# MCPO server as local process
resource "null_resource" "mcpo_server" {
  depends_on = [local_file.mcpo_config]

  provisioner "local-exec" {
    command = <<-EOT
      # Install uv if not present
      if ! command -v uv &> /dev/null; then
        echo "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$PATH"
      fi
      
      # Kill existing MCPO process if running
      pkill -f "mcpo.*--port.*8090" || true
      lsof -ti:8090 | xargs kill -9 || true
      sleep 3
      
      # Start MCPO server in background using uvx
      nohup uv tool run mcpo --port 8090 --config mcpo-config.json > mcpo.log 2>&1 &
      echo $! > mcpo.pid
      
      # Wait for server to start
      sleep 10
      
      # Verify server is running
      if curl -s http://localhost:8090/docs > /dev/null; then
        echo "MCPO server started successfully on http://localhost:8090"
      else
        echo "Failed to start MCPO server, checking logs..."
        tail -20 mcpo.log || echo "No log file found"
        exit 1
      fi
    EOT

    working_dir = path.root
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Stop MCPO server
      if [ -f mcpo.pid ]; then
        kill $(cat mcpo.pid) || true
        rm -f mcpo.pid
      fi
      pkill -f "mcpo.*--port.*8090" || true
    EOT

    working_dir = path.root
  }

  triggers = {
    config_hash = md5(local_file.mcpo_config.content)
  }
}

