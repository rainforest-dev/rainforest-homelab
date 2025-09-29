# Qdrant Vector Database Module

This module deploys [Qdrant](https://qdrant.tech/) vector database to the homelab Kubernetes cluster, providing high-performance vector similarity search capabilities for AI/ML applications.

## Features

- **Secure by Default**: API key authentication enabled
- **Persistent Storage**: External storage integration with backup support
- **Web Dashboard**: Built-in management interface
- **Cloudflare Integration**: Automatic HTTPS with Zero Trust authentication
- **Resource Optimized**: Tuned for homelab environments
- **Privacy Focused**: Telemetry disabled by default

## Usage

### Basic Configuration

Add to your `terraform.tfvars`:

```hcl
enable_qdrant = true
```

### Advanced Configuration

Customize in `main.tf`:

```hcl
module "qdrant" {
  source = "./modules/qdrant"
  count  = var.enable_qdrant ? 1 : 0

  # Resource sizing
  cpu_limit             = 2000    # millicores
  memory_limit          = 2048    # MB
  storage_size          = "100Gi" # storage size
  
  # Security
  enable_api_key        = true    # API key auth
  enable_dashboard      = true    # web interface
  
  # Configuration
  qdrant_version       = "v1.11.0"
  log_level           = "INFO"
  disable_telemetry   = true
}
```

## Access

### External Access (Recommended)
- **Web Dashboard**: `https://qdrant.yourdomain.com/dashboard`
- **HTTP API**: `https://qdrant.yourdomain.com`
- **Authentication**: Zero Trust email verification

### Internal Access
- **HTTP API**: `http://homelab-qdrant.homelab.svc.cluster.local:6333`
- **gRPC API**: `homelab-qdrant.homelab.svc.cluster.local:6334`

### Local Development
```bash
# Port forward for local access
kubectl port-forward -n homelab svc/homelab-qdrant 6333:6333

# Access at http://localhost:6333
```

## API Key Retrieval

```bash
# Get API key from Kubernetes secret
kubectl get secret -n homelab homelab-qdrant-secret -o jsonpath='{.data.api-key}' | base64 --decode
```

## Client Libraries

### Python
```bash
pip install qdrant-client
```

```python
from qdrant_client import QdrantClient

client = QdrantClient(
    host="qdrant.yourdomain.com",
    https=True,
    api_key="your-api-key"
)
```

### JavaScript/TypeScript
```bash
npm install @qdrant/js-client-rest
```

```typescript
import { QdrantClient } from '@qdrant/js-client-rest';

const client = new QdrantClient({
    host: 'qdrant.yourdomain.com',
    port: 443,
    https: true,
    apiKey: 'your-api-key'
});
```

### HTTP API
```bash
curl -X GET "https://qdrant.yourdomain.com/collections" \
     -H "api-key: your-api-key"
```

## Common Use Cases

1. **Semantic Search**: Find similar documents or content
2. **RAG Applications**: Store embeddings for context retrieval
3. **Recommendation Systems**: Content similarity matching
4. **AI Workflow Integration**: Vector storage for Flowise/n8n
5. **Open WebUI Enhancement**: Conversation context storage

## Integration Examples

See `examples/qdrant-basic-usage.py` for a complete Python example.

## Monitoring

```bash
# Check pod status
kubectl get pods -n homelab -l app=qdrant

# View logs
kubectl logs -n homelab -l app=qdrant

# Check service
kubectl get svc -n homelab homelab-qdrant
```

## Backup and Restore

Qdrant data is stored in external storage and included in regular homelab backups.

```bash
# Manual backup
docker run --rm -v homelab-qdrant-storage:/data -v $(pwd):/backup \
    alpine tar czf /backup/qdrant-backup.tar.gz -C /data .

# Restore
docker run --rm -v homelab-qdrant-storage:/data -v $(pwd):/backup \
    alpine tar xzf /backup/qdrant-backup.tar.gz -C /data
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `qdrant_version` | Docker image version | `v1.11.0` |
| `cpu_limit` | CPU limit (millicores) | `1000` |
| `memory_limit` | Memory limit (MB) | `1024` |
| `storage_size` | Storage size | `20Gi` |
| `enable_api_key` | Enable API authentication | `true` |
| `enable_dashboard` | Enable web dashboard | `true` |
| `log_level` | Logging level | `INFO` |
| `disable_telemetry` | Disable telemetry | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `qdrant_http_url` | HTTP API endpoint |
| `qdrant_grpc_url` | gRPC API endpoint |
| `qdrant_api_key` | API key (sensitive) |
| `connection_info` | Complete connection info |
| `dashboard_service_url` | Dashboard URL for tunnel |