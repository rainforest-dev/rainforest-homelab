resource "helm_release" "homepage" {
  name             = "homepage"
  repository       = "https://jameswynn.github.io/helm-charts"
  chart            = "homepage"
  namespace        = "homelab"
  create_namespace = true

  values = [file("modules/homepage/values.yml")]
}
