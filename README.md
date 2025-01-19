## Services

### PostgreSQL

- default port: 5432
- default user: postgres
- default password:

```bash
echo $(kubectl get secret --namespace homelab postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
```
