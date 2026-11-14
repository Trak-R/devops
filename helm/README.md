# Helm

Charts live under `charts/`. CI installs Helm 3.22.1 and uses chart API `v2`.

## trakr

`charts/trakr` packages the TrakR application with one Redpanda broker, Redpanda Connect, and one Postgres instance. Shared defaults live in `values.yaml`. Per-environment overrides are `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml`.

Build the Redpanda and Connect dependencies before linting or installing. `Chart.lock` pins `redpanda` 26.2.6 and `connect` 3.2.36. The downloaded charts are not committed.

```bash
helm dependency build charts/trakr
helm lint charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
helm template trakr charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
```

Image repository defaults to `ghcr.io/trak-r/trakr`; change it when the application image exists.

The Helm workflow installs this chart as release `trakr`. In that namespace the in-cluster endpoints are:

- Kafka bootstrap: `trakr-redpanda:9093`
- Redpanda Connect HTTP: `trakr-connect:80`
- Postgres: `trakr-postgresql:5432`, database `trakr`, user `trakr`

The Redpanda chart would otherwise name its Service `trakr`, which is the application Service, so `redpanda.fullnameOverride` is `trakr-redpanda`. Connect's Service name comes from `connect.nameOverride`. Replace `connect.config` with a real pipeline; the default generates one placeholder message per second so the pod stays up. Postgres keeps its password in the `trakr-postgresql` Secret (`POSTGRES_PASSWORD`). Set `postgresql.auth.existingSecret` to supply `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` yourself. `postgresql.auth.username` and `postgresql.auth.database` must match that Secret, because the probes read them.

Redpanda runs one broker with TLS, external access, and Console turned off. Its chart still requests 1 core, 2.5Gi of memory, and a 20Gi volume. Postgres uses `postgres:17`, a 10Gi volume, and the cluster default storage class.

Deploy runs only from the **Helm** workflow dispatch, and that workflow installs this chart. Add a base64-encoded kubeconfig as the `KUBECONFIG_B64` secret on the target GitHub Environment before the first deploy. The workflow does not create that secret.

## homenet

`charts/homenet` installs the HomeNet platform: Traefik, Argo CD, Cloudflare Tunnel, Headlamp, and OpenEBS Local PV LVM. The tunnel forwards `*.example.com` to Traefik. Applications publish hostnames with Ingress objects.

```bash
helm dependency build charts/homenet
helm lint charts/homenet --values charts/homenet/values.yaml
helm template homenet charts/homenet --values charts/homenet/values.yaml
```

Install, the tunnel Secret, the k3s Traefik flag, and the `homenet` volume group are described in `charts/homenet/README.md`. The Helm workflow lints this chart and does not install it.

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
