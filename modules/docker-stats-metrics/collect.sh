#!/bin/bash
# Collects per-container CPU/memory/network via `docker stats` and writes
# Prometheus text format for node_exporter's textfile collector to pick up.
# Runs every 30s via launchd (see com.homelab.docker-stats-metrics.plist).

set -euo pipefail

OUTFILE="${TEXTFILE_DIR:-/opt/homebrew/var/node_exporter/textfile_collector}/docker_stats.prom"
TMPFILE="${OUTFILE}.tmp"
DOCKER="${DOCKER_BIN:-/usr/local/bin/docker}"

{
  echo "# HELP docker_container_cpu_percent CPU usage percentage per container"
  echo "# TYPE docker_container_cpu_percent gauge"
  echo "# HELP docker_container_memory_usage_bytes Memory usage in bytes per container"
  echo "# TYPE docker_container_memory_usage_bytes gauge"
  echo "# HELP docker_container_memory_limit_bytes Memory limit in bytes per container"
  echo "# TYPE docker_container_memory_limit_bytes gauge"
  echo "# HELP docker_container_net_rx_bytes Network bytes received per container"
  echo "# TYPE docker_container_net_rx_bytes counter"
  echo "# HELP docker_container_net_tx_bytes Network bytes transmitted per container"
  echo "# TYPE docker_container_net_tx_bytes counter"

  "$DOCKER" stats --no-stream --format \
    '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}' 2>/dev/null \
  | while IFS=$'\t' read -r name cpu mem net; do
      # Strip % from CPU
      cpu_val="${cpu//%/}"

      # Parse memory: "123MiB / 456GiB" → bytes
      mem_used=$(echo "$mem" | awk '{print $1}' | \
        awk '/GiB/{printf "%.0f", $1*1073741824; next}
             /MiB/{printf "%.0f", $1*1048576; next}
             /kB/{printf "%.0f", $1*1000; next}
             /MB/{printf "%.0f", $1*1000000; next}
             /GB/{printf "%.0f", $1*1000000000; next}
             {print $1}')
      mem_limit=$(echo "$mem" | awk '{print $3}' | \
        awk '/GiB/{printf "%.0f", $1*1073741824; next}
             /MiB/{printf "%.0f", $1*1048576; next}
             /kB/{printf "%.0f", $1*1000; next}
             /MB/{printf "%.0f", $1*1000000; next}
             /GB/{printf "%.0f", $1*1000000000; next}
             {print $1}')

      # Parse net: "1.23kB / 4.56MB"
      net_rx=$(echo "$net" | awk '{print $1}' | \
        awk '/kB/{printf "%.0f", $1*1000; next}
             /MB/{printf "%.0f", $1*1000000; next}
             /GB/{printf "%.0f", $1*1000000000; next}
             /B$/{printf "%.0f", $1; next}
             {print $1}')
      net_tx=$(echo "$net" | awk '{print $3}' | \
        awk '/kB/{printf "%.0f", $1*1000; next}
             /MB/{printf "%.0f", $1*1000000; next}
             /GB/{printf "%.0f", $1*1000000000; next}
             /B$/{printf "%.0f", $1; next}
             {print $1}')

      label="name=\"${name}\""
      echo "docker_container_cpu_percent{${label}} ${cpu_val}"
      echo "docker_container_memory_usage_bytes{${label}} ${mem_used:-0}"
      echo "docker_container_memory_limit_bytes{${label}} ${mem_limit:-0}"
      echo "docker_container_net_rx_bytes{${label}} ${net_rx:-0}"
      echo "docker_container_net_tx_bytes{${label}} ${net_tx:-0}"
    done
} > "$TMPFILE"

# Atomic replace so node_exporter never reads a partial file
mv "$TMPFILE" "$OUTFILE"
