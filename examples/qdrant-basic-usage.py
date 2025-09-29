#!/usr/bin/env python3
"""
Basic Qdrant usage example for homelab integration.

This script demonstrates how to connect to and interact with Qdrant
running in the homelab Kubernetes cluster.

Prerequisites:
- Qdrant is deployed and running in homelab
- Python qdrant-client library: pip install qdrant-client
- kubectl access to homelab namespace (for API key retrieval)
"""

import os
import subprocess
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
import numpy as np

def get_qdrant_api_key():
    """Get the Qdrant API key from Kubernetes secret."""
    try:
        result = subprocess.run([
            "kubectl", "get", "secret", "-n", "homelab", 
            "homelab-qdrant-secret", "-o", 
            "jsonpath={.data.api-key}"
        ], capture_output=True, text=True, check=True)
        
        # Decode base64
        import base64
        return base64.b64decode(result.stdout).decode('utf-8')
    except subprocess.CalledProcessError as e:
        print(f"Error getting API key: {e}")
        return None

def connect_to_qdrant(use_tunnel=True):
    """
    Connect to Qdrant instance.
    
    Args:
        use_tunnel: If True, use Cloudflare Tunnel URL (external access)
                   If False, use port-forward (local development)
    """
    if use_tunnel:
        # External access via Cloudflare Tunnel
        # Replace 'yourdomain.com' with your actual domain
        host = "qdrant.yourdomain.com"
        port = 443
        https = True
        api_key = get_qdrant_api_key()
    else:
        # Local development via kubectl port-forward
        # Run: kubectl port-forward -n homelab svc/homelab-qdrant 6333:6333
        host = "localhost"
        port = 6333
        https = False
        api_key = get_qdrant_api_key()
    
    client = QdrantClient(
        host=host,
        port=port,
        https=https,
        api_key=api_key
    )
    
    return client

def create_example_collection(client, collection_name="example_vectors"):
    """Create a simple vector collection for demonstration."""
    
    # Check if collection exists
    try:
        collection_info = client.get_collection(collection_name)
        print(f"Collection '{collection_name}' already exists")
        return
    except Exception:
        pass
    
    # Create collection with 384-dimensional vectors (common for sentence embeddings)
    client.create_collection(
        collection_name=collection_name,
        vectors_config=VectorParams(
            size=384,
            distance=Distance.COSINE
        )
    )
    print(f"Created collection: {collection_name}")

def add_example_vectors(client, collection_name="example_vectors"):
    """Add some example vectors to the collection."""
    
    # Generate some random example vectors
    vectors = np.random.random((10, 384)).tolist()
    
    points = [
        PointStruct(
            id=i,
            vector=vector,
            payload={
                "text": f"Example document {i}",
                "category": "demo",
                "timestamp": "2024-01-01T00:00:00Z"
            }
        )
        for i, vector in enumerate(vectors)
    ]
    
    # Upload points
    client.upsert(
        collection_name=collection_name,
        points=points
    )
    print(f"Added {len(points)} vectors to collection")

def search_example(client, collection_name="example_vectors"):
    """Perform a basic vector search."""
    
    # Generate a random query vector
    query_vector = np.random.random(384).tolist()
    
    # Search for similar vectors
    results = client.search(
        collection_name=collection_name,
        query_vector=query_vector,
        limit=3
    )
    
    print(f"\nSearch results:")
    for result in results:
        print(f"ID: {result.id}, Score: {result.score:.4f}")
        print(f"Payload: {result.payload}")
        print("---")

def main():
    """Main function demonstrating basic Qdrant usage."""
    print("Qdrant Homelab Integration Example")
    print("=" * 40)
    
    # Choose connection method
    use_tunnel = input("Use Cloudflare Tunnel? (y/N): ").lower() == 'y'
    
    try:
        # Connect to Qdrant
        print(f"Connecting to Qdrant ({'external' if use_tunnel else 'local'})...")
        client = connect_to_qdrant(use_tunnel=use_tunnel)
        
        # Test connection
        print("Testing connection...")
        collections = client.get_collections()
        print(f"Connected! Found {len(collections.collections)} collections")
        
        # Create example collection
        create_example_collection(client)
        
        # Add example vectors
        add_example_vectors(client)
        
        # Perform search
        search_example(client)
        
        print("\nExample completed successfully!")
        
    except Exception as e:
        print(f"Error: {e}")
        print("\nTroubleshooting tips:")
        print("- Ensure Qdrant is running: kubectl get pods -n homelab | grep qdrant")
        print("- Check service: kubectl get svc -n homelab homelab-qdrant")
        print("- For local access, run: kubectl port-forward -n homelab svc/homelab-qdrant 6333:6333")

if __name__ == "__main__":
    main()