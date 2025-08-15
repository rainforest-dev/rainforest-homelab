terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Cloudflare integration removed - using Tailscale + CoreDNS for DNS resolution

resource "helm_release" "traefik" {
  name             = "${var.project_name}-${var.traefik_name}"
  repository       = var.chart_repository
  chart            = "traefik"
  create_namespace = true
  namespace        = var.traefik_namespace

  values = [file("${path.module}/values.yml")]
}


resource "kubectl_manifest" "openwebui-ingress-route" {
  depends_on = [helm_release.traefik]

  yaml_body = <<YAML
    apiVersion: traefik.io/v1alpha1
    kind: IngressRoute
    metadata:
      name: open-webui
      namespace: homelab
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(`open-webui.${var.domain_suffix}`)
          kind: Rule
          services:
          - name: open-webui
            port: 80
  YAML
}


resource "kubectl_manifest" "flowise-ingress-route" {
  depends_on = [helm_release.traefik]

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "flowise"
      namespace = "homelab"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`flowise.${var.domain_suffix}`)"
          kind  = "Rule"
          services = [
            {
              name = "homelab-flowise"
              port = 3000
            }
          ]
        }
      ]
    }
  })
}


resource "kubectl_manifest" "n8n-ingress-route" {
  depends_on = [helm_release.traefik]

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "n8n"
      namespace = "homelab"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`n8n.${var.domain_suffix}`)"
          kind  = "Rule"
          services = [
            {
              name = "homelab-n8n"
              port = 80
            }
          ]
        }
      ]
    }
  })
}

resource "kubectl_manifest" "homepage-ingress-route" {
  depends_on = [helm_release.traefik]

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "homepage"
      namespace = "homelab"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`homepage.${var.domain_suffix}`)"
          kind  = "Rule"
          services = [
            {
              name = "homelab-homepage"
              port = 3000
            }
          ]
        }
      ]
    }
  })
}
