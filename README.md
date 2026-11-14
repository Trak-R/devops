# TrakR devops

Infrastructure, delivery pipelines, and Kubernetes packaging for TrakR.

| Path | What it holds |
| --- | --- |
| `terraform/` | Per-environment stacks and reusable modules |
| `helm/charts/trakr/` | Helm chart for the TrakR application |
| `pipelines/steps/` | Reusable GitHub Actions steps |
| `.github/workflows/` | Workflows that call those steps |

No cloud provider is selected yet. Terraform currently standardizes naming and tags. The Helm chart renders a Deployment, Service, and optional Ingress.

## Local checks

```bash
make fmt-check
make terraform-validate
make helm-lint
make helm-template
```

Terraform 1.17.2 and Helm 3.22.1 match the versions installed in CI.
