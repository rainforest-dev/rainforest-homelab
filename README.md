## Services

### PostgreSQL

- default port: 5432
- default user: postgres
- default password:

```bash
echo $(kubectl get secret --namespace homelab postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```

### Traefik

```bash
kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name --namespace=homelab) --namespace=homelab 8080:8080
```