# TrakR devops

Infrastructure, delivery pipelines, and Kubernetes packaging for TrakR.

| Path | What it holds |
| --- | --- |
| `terraform/` | Per-environment stacks and reusable modules |
| `helm/charts/trakr/` | Helm chart for the TrakR application |
| `helm/charts/adsbtracker/` | Helm chart for a single Tracker Hub pod |
| `pipelines/steps/` | Reusable GitHub Actions steps |
| `pipelines/adsbtracker/` | Pipeline that publishes the BaseStation simulator image |
| `pipelines/api/` | Pipeline that publishes the TrakR API image |
| `.github/workflows/` | Workflows that call those steps and pipelines |

Dev Terraform provisions a Proxmox k3s cluster with one control plane and optional workers. Staging and prod standardize naming and tags. `trakr` renders the application plus one Redpanda broker, Redpanda Connect, and one Postgres instance. The API is included when `components.api` is true, from templates in `helm/charts/trakr/templates/api/`. The BaseStation simulator is included when `components.simulator` is true, from templates in `helm/charts/trakr/templates/simulator/`. `adsbtracker` can still render on its own as one StatefulSet replica, a Service, persistent volumes, and an optional Ingress.

## Local checks

```bash
make fmt-check
make terraform-validate
make helm-lint
make helm-template
```

Terraform 1.17.2 and Helm 3.22.1 match the versions installed in CI. `make helm-lint` and `make helm-template` check `helm/charts/trakr`. Lint `adsbtracker` with the commands in `helm/README.md`.
