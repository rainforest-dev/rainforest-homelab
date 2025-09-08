# Cloudflare Tunnel Module

This Terraform module creates and manages a Cloudflare Zero Trust Tunnel for secure external access to Kubernetes services without exposing your home IP address.

## Overview

The module provides:
- **Cloudflare Tunnel**: Secure outbound-only connection to Cloudflare's edge
- **DNS Records**: Automatic CNAME records for all services
- **Zero Trust Authentication**: Optional email-based access control
- **Kubernetes Deployment**: cloudflared pods running in your cluster
- **SSL Certificates**: Automatic HTTPS certificates from Cloudflare

## Architecture

```
Internet → Cloudflare Edge → Tunnel → cloudflared pods → Kubernetes Services
```

## Features

- ✅ **Zero Trust Security**: Email domain verification for service access
- ✅ **Automatic SSL**: Real certificates with perfect forward secrecy
- ✅ **Hidden IP**: Your home IP is never exposed
- ✅ **Global CDN**: Fast access via Cloudflare's worldwide network
- ✅ **DDoS Protection**: Enterprise-grade protection included
- ✅ **Resource Limits**: CPU/memory constraints for stability

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| cloudflare | ~> 4.0 |
| kubectl | ~> 1.14 |
| random | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| cloudflare | ~> 4.0 |
| kubectl | ~> 1.14 |
| random | ~> 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | `string` | n/a | yes |
| domain_suffix | Domain suffix for services | `string` | n/a | yes |
| cloudflare_account_id | Cloudflare account ID | `string` | n/a | yes |
| cloudflare_api_token | Cloudflare API token with appropriate permissions | `string` | n/a | yes |
| kubernetes_namespace | Kubernetes namespace for tunnel deployment | `string` | `"homelab"` | no |
| allowed_email_domains | List of email domains allowed to access services | `list(string)` | `[]` | no |
| allowed_emails | List of specific email addresses allowed to access services | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| tunnel_id | Cloudflare Tunnel ID |
| tunnel_cname | Cloudflare Tunnel CNAME |
| service_urls | Service URLs accessible via Cloudflare Tunnel |
| zero_trust_applications | Zero Trust application IDs |
| zero_trust_policies | Zero Trust access policy IDs |
| dns_records | DNS record IDs created for services |

## Usage

### Basic Usage (No Authentication)

```hcl
module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"

  project_name          = "homelab"
  domain_suffix         = "example.com"
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_api_token  = var.cloudflare_api_token

  # No authentication - services publicly accessible
  allowed_email_domains = []
}
```

### With Zero Trust Authentication

```hcl
module "cloudflare_tunnel" {
  source = "./modules/cloudflare-tunnel"

  project_name          = "homelab"
  domain_suffix         = "example.com"
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_api_token  = var.cloudflare_api_token

  # Email domain authentication
  allowed_email_domains = ["company.com"]
  allowed_emails        = ["admin@company.com"]
}
```

## Service Configuration

The module automatically creates ingress rules and DNS records for these services:

- **homepage**: `https://homepage.yourdomain.com`
- **open-webui**: `https://open-webui.yourdomain.com`
- **flowise**: `https://flowise.yourdomain.com`
- **n8n**: `https://n8n.yourdomain.com`
- **minio**: `https://minio.yourdomain.com` (console)
- **s3**: `https://s3.yourdomain.com` (API)

## Cloudflare Permissions Required

Your API token needs these permissions:
- `Zone:Zone:Read`
- `Zone:DNS:Edit`
- `Account:Cloudflare Tunnel:Edit`
- `Account:Access: Apps and Policies:Edit`

## Zero Trust Setup

1. **Enable Cloudflare Access** at https://dash.cloudflare.com/ → Zero Trust → Settings
2. **Configure email domains** in your terraform variables
3. **Deploy**: `terraform apply`
4. **Test**: Visit any service URL and complete email verification

## Troubleshooting

### Check Tunnel Status
```bash
kubectl logs -n homelab -l app=cloudflared --tail=20
```

### View Configuration
```bash
kubectl get configmap -n homelab cloudflared-config -o yaml
```

### Restart Tunnel
```bash
kubectl rollout restart deployment/cloudflared -n homelab
```

### Common Issues

**"Email verification not working"**
- Check that Zero Trust is enabled in Cloudflare dashboard
- Verify email domain is correctly configured
- Ensure API token has Access permissions

**"Service not accessible"**
- Check ingress rules in tunnel configuration
- Verify DNS records are created
- Confirm Kubernetes service is running

**"Tunnel not connecting"**
- Check cloudflared pod logs
- Verify credentials secret exists
- Confirm Cloudflare account has tunnel quota

## Security Considerations

- **API tokens are sensitive** - mark as `sensitive = true` in variables
- **Email domains control access** - use specific domains for production
- **Tunnel secrets are encrypted** - stored securely in Kubernetes secrets
- **Resource limits prevent abuse** - CPU/memory constraints applied

## Cost Considerations

- **Cloudflare Tunnel**: Free for personal use
- **Zero Trust**: Free for up to 50 users
- **DNS**: Included with domain registration
- **SSL Certificates**: Free via Cloudflare

## Maintenance

### Update cloudflared Image
```bash
kubectl set image deployment/cloudflared cloudflared=cloudflare/cloudflared:latest -n homelab
kubectl rollout status deployment/cloudflared -n homelab
```

### Rotate Tunnel Secret
```bash
terraform taint random_password.tunnel_secret
terraform apply -target="module.cloudflare_tunnel"
```

### Add New Service
1. Add ingress rule to `cloudflare_zero_trust_tunnel_cloudflared_config`
2. Add to DNS records `for_each` list
3. Add to Zero Trust applications (if authentication needed)
4. Run `terraform apply`</content>
<parameter name="filePath">/Users/rainforest/Repositories/rainforest-homelab/modules/cloudflare-tunnel/README.md