terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

# configure the helm provider to use the orbstack cluster
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "orbstack"
  }
}

# resource "kubernetes_secret" "cloudflare" {
#   metadata {
#     name      = "cloudflare-api-credentials"
#     namespace = "traefik"
#   }
#   type = "Opaque"
#   data = {
#     "email"  = base64encode(var.cloudflare_email)
#     "apiKey" = base64encode(var.cloudflare_api_key)
#   }
# }

resource "helm_release" "traefik" {
  name             = var.traefik_name
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  create_namespace = true
  namespace        = var.traefik_namespace

  values = [file("modules/traefik/values.yml")]
}

resource "kubectl_manifest" "openspeedtest-ingress-route" {
  depends_on = [helm_release.traefik]

  yaml_body = <<YAML
    apiVersion: traefik.io/v1alpha1
    kind: IngressRoute
    metadata:
      name: openspeedtest
      namespace: homelab
    spec:
      entryPoints:
        - websecure
      routes:
        - match: Host(`openspeedtest.k8s.orb.local`)
          kind: Rule
          services:
          - name: openspeedtest
            port: 3000
  YAML
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
        - match: Host(`open-webui.k8s.orb.local`)
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
          match = "Host(`flowise.k8s.orb.local`)"
          kind  = "Rule"
          services = [
            {
              name = "flowise"
              port = 3000
            }
          ]
        }
      ]
    }
  })
}

resource "kubectl_manifest" "calibre-ingress-route" {
  depends_on = [helm_release.traefik]

  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "calibre"
      namespace = "homelab"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          match = "Host(`calibre.k8s.orb.local`)"
          kind  = "Rule"
          services = [
            {
              name = "calibre"
              port = 8083
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
          match = "Host(`n8n.k8s.orb.local`)"
          kind  = "Rule"
          services = [
            {
              name = "n8n"
              port = 80
            }
          ]
        }
      ]
    }
  })
}
