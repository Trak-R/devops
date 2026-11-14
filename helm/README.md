# Helm

`charts/trakr` packages the TrakR application. Shared defaults live in `values.yaml`. Per-environment overrides are `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml`.

```bash
helm lint charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
helm template trakr charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
```

CI installs Helm 3.22.1 and uses chart API `v2`. Image repository defaults to `ghcr.io/trak-r/trakr`; change it when the application image exists.

Deploy runs only from the **Helm** workflow dispatch. Add a base64-encoded kubeconfig as the `KUBECONFIG_B64` secret on the target GitHub Environment before the first deploy. The workflow does not create that secret.
