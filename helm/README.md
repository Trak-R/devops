# Helm

Charts live under `charts/`. CI installs Helm 3.22.1 and uses chart API `v2`.

## trakr

`charts/trakr` packages the TrakR application. Shared defaults live in `values.yaml`. Per-environment overrides are `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml`.

```bash
helm lint charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
helm template trakr charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
```

Image repository defaults to `ghcr.io/trak-r/trakr`; change it when the application image exists.

Deploy runs only from the **Helm** workflow dispatch, and that workflow installs this chart. Add a base64-encoded kubeconfig as the `KUBECONFIG_B64` secret on the target GitHub Environment before the first deploy. The workflow does not create that secret.

## adsbtracker

`charts/adsbtracker` packages Tracker Hub as one replica. Observations stay in SQLite, so the database, write spool, and tracking profiles sit on ReadWriteOnce volumes. `image.repository`, `image.tag`, and `feed.host` are required. Lint fixtures in `charts/adsbtracker/ci/` supply those values.

```bash
helm lint charts/adsbtracker \
  --values charts/adsbtracker/values.yaml \
  --values charts/adsbtracker/ci/default-values.yaml
helm template adsbtracker charts/adsbtracker \
  --values charts/adsbtracker/values.yaml \
  --values charts/adsbtracker/ci/default-values.yaml
```

`ci/ingress-existing-secret-values.yaml` covers Ingress with an external Secret. Install, secrets, and backup notes are in `charts/adsbtracker/README.md`.
