# DevOps Code Review Checklist

## Security
- [ ] No secrets in manifests or pipelines
- [ ] RBAC configured
- [ ] Network policies considered

## Kubernetes
- [ ] Resource limits defined
- [ ] Health checks (liveness/readiness)
- [ ] Proper labels and selectors

## CI/CD
- [ ] Pipelines stored as code
- [ ] Stages: build → test → scan → deploy
- [ ] Rollback strategy defined
