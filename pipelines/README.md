# Pipeline steps

Reusable GitHub Actions composite steps. Workflows in this repository call them with `uses: ./pipelines/steps/<name>`. A pipeline under `pipelines/<name>/` combines those steps for one application repository. It calls them with `$/`, which stays pointed at this repository when another repository runs the workflow.

| Step | Purpose |
| --- | --- |
| `terraform-fmt` | Fail if Terraform files are not formatted |
| `terraform-validate` | Init without a backend and validate one environment |
| `terraform-plan` | Init, validate, and plan one environment |
| `terraform-apply` | Init and apply one environment |
| `helm-lint` | Lint a chart and render it |
| `helm-deploy` | Upgrade or install a chart into the current kube context |
| `sonarqube` | Scan the workspace and enforce the SonarQube quality gate |
| `container-push` | Build an image and push it to GHCR, tagged with the commit SHA |
| `cve-scan` | Scan a GHCR image for fixed high and critical CVEs |

`helm-deploy` does not log into a cluster. The workflow configures kubeconfig first.

`sonarqube` needs `SONAR_TOKEN` and `SONAR_HOST_URL`. The project key defaults to the repository name with `/` replaced by `_`. The Security workflow skips this step until both secrets exist.

`container-push` uses `docker/login-action` and `docker/build-push-action`, the actions GitHub documents for publishing to GHCR. It pushes `ghcr.io/<owner>/<repo>:<commit sha>`. On a push to `main`, that SHA is the merge commit. The workflow token needs `packages: write`. The Security workflow publishes only when a `Dockerfile` is present, then scans that image.

## adsbtracker

`pipelines/adsbtracker` runs `sonarqube`, then `container-push`, then `cve-scan`. SonarQube runs first, so a failed quality gate stops the job before the image is pushed. The Dockerfile is `docker/Dockerfile.source` and the build context is the repository root. The image is `ghcr.io/<owner>/<repo>:<commit sha>`, lowercased. Every call publishes an image, including pull requests. The tag is the caller commit SHA.

The adsbtracker repository calls `.github/workflows/adsbtracker.yml`. That workflow requires `SONAR_TOKEN` and `SONAR_HOST_URL`. It does not skip SonarQube when they are missing. The caller must grant `contents: read` and `packages: write`. A called workflow cannot raise those permissions.

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
  packages: write
jobs:
  ci:
    uses: Trak-R/devops/.github/workflows/adsbtracker.yml@main
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

If this repository is private, its Actions access policy must allow the adsbtracker repository to call the workflow. Pull requests from forks do not receive secrets or `packages: write`.
