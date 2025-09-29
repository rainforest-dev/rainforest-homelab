# Example Qdrant configuration for terraform.tfvars
# Copy these settings to your terraform.tfvars file to enable Qdrant

# Enable Qdrant vector database
enable_qdrant = true

# Qdrant will be available at:
# - Internal: http://homelab-qdrant.homelab.svc.cluster.local:6333
# - External: https://qdrant.yourdomain.com (when Cloudflare Tunnel is enabled)

# Optional: Customize Qdrant configuration in main.tf module block:
# module "qdrant" {
#   # ... existing configuration ...
#   
#   # Custom settings (all optional):
#   qdrant_version        = "v1.11.0"       # Qdrant version
#   cpu_limit             = 2000            # CPU in millicores (default: 1000)
#   memory_limit          = 2048            # Memory in MB (default: 1024)
#   storage_size          = "100Gi"         # Storage size (default: 50Gi)
#   enable_api_key        = true            # Enable API key auth (default: true)
#   enable_dashboard      = true            # Enable web dashboard (default: true)
#   log_level            = "INFO"           # Log level (default: INFO)
#   disable_telemetry    = true             # Disable telemetry (default: true)
# }

# Vector Database Use Cases:
# 1. AI/ML Applications: Store and search embeddings from OpenAI, Hugging Face, etc.
# 2. Semantic Search: Find similar documents, images, or other content
# 3. Recommendation Systems: Build content recommendation engines
# 4. RAG (Retrieval Augmented Generation): Enhance LLM responses with context
# 5. Similarity Detection: Find duplicate or similar content

# Integration with Other Services:
# - Open WebUI: Store conversation embeddings for context
# - Flowise: Vector storage for AI workflow outputs
# - n8n: Vector operations in automation workflows
# - Custom apps: Use Qdrant API for vector operations

# Connection Examples:
# Python: pip install qdrant-client
# from qdrant_client import QdrantClient
# client = QdrantClient("qdrant.yourdomain.com", api_key="your-api-key")

# JavaScript/TypeScript: npm install @qdrant/js-client-rest
# import { QdrantClient } from '@qdrant/js-client-rest';
# const client = new QdrantClient({ host: 'qdrant.yourdomain.com', apiKey: 'your-api-key' });

# curl: Direct HTTP API access
# curl -X GET "https://qdrant.yourdomain.com/collections" -H "api-key: your-api-key"