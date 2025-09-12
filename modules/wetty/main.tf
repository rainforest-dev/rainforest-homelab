# Wetty deployment using kubectl manifests
resource "kubectl_manifest" "wetty_deployment" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${var.project_name}-wetty
  namespace: ${var.namespace}
  labels:
    app: ${var.project_name}-wetty
    project: ${var.project_name}
    environment: ${var.environment}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${var.project_name}-wetty
  template:
    metadata:
      labels:
        app: ${var.project_name}-wetty
        project: ${var.project_name}
        environment: ${var.environment}
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: wetty
        image: wettyoss/wetty:latest
        ports:
        - containerPort: ${var.wetty_port}
          name: http
        env:
        - name: WETTY_USER
          value: "${var.wetty_user}"
        - name: WETTY_PORT  
          value: "${var.wetty_port}"
        # Add SSH user creation for terminal access
        command: ["/bin/sh"]
        args:
        - -c
        - |
          # Create user if it doesn't exist
          if ! id "${var.wetty_user}" &>/dev/null; then
            adduser -D -s /bin/bash "${var.wetty_user}"
            echo "${var.wetty_user}:wetty123" | chpasswd
          fi
          # Start wetty
          exec node app.js --port ${var.wetty_port} --host 0.0.0.0
        resources:
          limits:
            cpu: ${var.cpu_limit}
            memory: ${var.memory_limit}
          requests:
            cpu: 50m
            memory: 64Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
YAML

  depends_on = [kubectl_manifest.wetty_service]
}

# Wetty service (ClusterIP only - no external exposure)
resource "kubectl_manifest" "wetty_service" {
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: ${var.project_name}-wetty
  namespace: ${var.namespace}
  labels:
    app: ${var.project_name}-wetty
    project: ${var.project_name}
    environment: ${var.environment}
spec:
  type: ClusterIP
  ports:
  - port: ${var.wetty_port}
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: ${var.project_name}-wetty
YAML
}

# Optional: ConfigMap for custom Wetty configuration
resource "kubectl_manifest" "wetty_configmap" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${var.project_name}-wetty-config
  namespace: ${var.namespace}
  labels:
    app: ${var.project_name}-wetty
    project: ${var.project_name}
    environment: ${var.environment}
data:
  wetty.conf: |
    # Wetty configuration
    port=${var.wetty_port}
    host=0.0.0.0
    title="Homelab Terminal"
    allowroot=false
YAML
}