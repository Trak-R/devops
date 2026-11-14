# Pipeline steps

Reusable GitHub Actions composite steps. Workflows in `.github/workflows/` call them with `uses: ./pipelines/steps/<name>`.

| Step | Purpose |
| --- | --- |
| `terraform-fmt` | Fail if Terraform files are not formatted |
| `terraform-validate` | Init without a backend and validate one environment |
| `terraform-plan` | Init, validate, and plan one environment |
| `terraform-apply` | Init and apply one environment |
| `helm-lint` | Lint a chart and render it |
| `helm-deploy` | Upgrade or install a chart into the current kube context |

`helm-deploy` does not log into a cluster. The workflow configures kubeconfig first.
