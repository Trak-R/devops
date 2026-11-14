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
| `sonarqube` | Scan the workspace and enforce the SonarQube quality gate |
| `cve-scan` | Scan a GHCR image for fixed high and critical CVEs |

`helm-deploy` does not log into a cluster. The workflow configures kubeconfig first.

`sonarqube` needs `SONAR_TOKEN` and `SONAR_HOST_URL`. The project key defaults to the repository name with `/` replaced by `_`. The Security workflow skips this step until both secrets exist.

`cve-scan` pulls `ghcr.io/<owner>/<repo>:<commit sha>` unless an image is passed in. On a push to `main`, that SHA is the merge commit. The step logs in to GHCR with the workflow token and fails when Trivy finds a fixed high or critical vulnerability.
