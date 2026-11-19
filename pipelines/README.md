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
| `deploy-dev` | Commit one image tag into a values file |

`helm-deploy` does not log into a cluster. The workflow configures kubeconfig first.

`sonarqube` needs `SONAR_TOKEN` and `SONAR_HOST_URL`. The project key defaults to the repository name with `/` replaced by `_`. The Security workflow skips this step until both secrets exist.

`container-push` uses `docker/login-action` and `docker/build-push-action`, the actions GitHub documents for publishing to GHCR. It pushes `ghcr.io/<owner>/<repo>:<commit sha>`. On a push to `main`, that SHA is the merge commit. The workflow token needs `packages: write`. The Security workflow publishes only when a `Dockerfile` is present, then scans that image.

`deploy-dev` checks out a values repository with a token and sets one image tag. It commits and pushes when the tag changes. Installing the chart stays on the Helm workflow.

## adsbtracker

`pipelines/adsbtracker` installs .NET SDK 9.0.304 and runs `dotnet test` on `src/BaseStationReader.sln` first. A failed test stops the job before `container-push` and `cve-scan`. The Dockerfile is `docker/Dockerfile.simulator` and the build context is the repository root. The image is BaseStationReader.Simulator, published as `ghcr.io/<owner>/<repo>:<commit sha>`, lowercased. Every call publishes an image, including pull requests. The tag is the caller commit SHA.

On a push to `main`, after the image push succeeds, the `deploy-dev` job sets `simulator.image.tag` in `helm/charts/trakr/values-dev.yaml` to the merge commit SHA and pushes the commit to `main` on `Trak-R/devops`. The job changes that tag only. `components.simulator` stays as it is in the file. The job runs with concurrency group `deploy-dev-helm-charts-trakr-values-dev` and `cancel-in-progress: false`, so two merges update the file one after another. A failed test or image push skips the job. The CVE scan still exits on fixed high and critical findings, and that failure does not skip the job.

The caller passes `DEVOPS_TOKEN`, a fine-grained PAT with contents write on `Trak-R/devops`. The token must be allowed to push to `main`. Pull requests can omit the secret. A push to `main` with an empty token fails `deploy-dev`.

The adsbtracker repository calls `.github/workflows/adsbtracker.yml`. The caller must grant `contents: read` and `packages: write`. A called workflow cannot raise those permissions.

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
      DEVOPS_TOKEN: ${{ secrets.DEVOPS_TOKEN }}
```

If this repository is private, its Actions access policy must allow the adsbtracker repository to call the workflow. Pull requests from forks do not receive secrets or `packages: write`.

## api

`pipelines/api` installs uv and Python 3.12, syncs the lockfile with `uv sync --frozen --all-packages`, then runs `uv run pytest`, `uv run ruff check .`, and `uv run ruff format --check .`. A failed check stops the job before `container-push` and `cve-scan`. The Dockerfile is `apps/api/Dockerfile` and the build context is the repository root. The image is the API, published as `ghcr.io/<owner>/<repo>:<commit sha>`, lowercased. Celery worker and beat can use that same image. The chart deploys the API process only. The persistence worker and anomaly detector are not published. Every call publishes an image, including pull requests. The tag is the caller commit SHA.

On a push to `main`, after the image push succeeds, the `deploy-dev` job sets `api.image.tag` in `helm/charts/trakr/values-dev.yaml` to the merge commit SHA and pushes the commit to `main` on `Trak-R/devops`. The job changes that tag only. `components.api` stays as it is in the file. The job runs with concurrency group `deploy-dev-helm-charts-trakr-values-dev` and `cancel-in-progress: false`, so an API merge and a simulator merge update the file one after another. A failed test or image push skips the job. The CVE scan still exits on fixed high and critical findings, and that failure does not skip the job.

The caller passes `DEVOPS_TOKEN`, a fine-grained PAT with contents write on `Trak-R/devops`. The token must be allowed to push to `main`. Pull requests can omit the secret. A push to `main` with an empty token fails `deploy-dev`.

The api repository calls `.github/workflows/api.yml`. The caller must grant `contents: read` and `packages: write`. A called workflow cannot raise those permissions.

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
    uses: Trak-R/devops/.github/workflows/api.yml@main
    secrets:
      DEVOPS_TOKEN: ${{ secrets.DEVOPS_TOKEN }}
```

If this repository is private, its Actions access policy must allow the api repository to call the workflow. Pull requests from forks do not receive secrets or `packages: write`.

## connect

`pipelines/connect` runs `connect/test.sh`, which downloads Redpanda Connect 4.115.1 and runs `redpanda-connect test` on `connect/adsb.yaml`. A failed test stops the job before `container-push` and `cve-scan`. The Dockerfile is `connect/Dockerfile` and the build context is `connect/`. Pull requests run the test only. On `main`, the image is published as `ghcr.io/trak-r/connect:<commit sha>`. It is the upstream Connect binary plus the ADS-B pipeline, the placeholder pipeline, and the entrypoint. The tag is that `main` commit SHA.

A push to `main` publishes the image and does not change the chart. `deploy-dev` runs only from a manual dispatch on `main`. That dispatch builds and pushes the same SHA tag, then sets `connect.image.tag` in `helm/charts/trakr/values-dev.yaml` to it and pushes that commit to `main` on `Trak-R/devops`. A dispatch from any other branch fails before it writes the values file. The job changes that tag only. `connect.image.repository` stays `ghcr.io/trak-r/connect`. The job runs with concurrency group `deploy-dev-helm-charts-trakr-values-dev` and `cancel-in-progress: false`, so a Connect dispatch, an API merge, and a simulator merge update the file one after another.

The workflow passes `DEVOPS_TOKEN`, a fine-grained PAT with contents write on `Trak-R/devops`. The token must be allowed to push to `main`. A dispatch on `main` with an empty token fails `deploy-dev`.
