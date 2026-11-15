# Helm

Charts live under `charts/`. CI installs Helm 3.22.1 and uses chart API `v2`.

## trakr

`charts/trakr` packages the TrakR application with one Redpanda broker, Redpanda Connect, and one Postgres instance. Tracker Hub is included when `components.adsbtracker` is true. Shared defaults live in `values.yaml`. Per-environment overrides are `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml`.

Build the dependencies before linting or installing. `Chart.lock` pins `redpanda` 26.2.6, `connect` 3.2.36, and `adsbtracker` 0.1.0 from `oci://ghcr.io/trak-r/charts`. The downloaded charts are not committed. That GHCR package is private, so `helm registry login ghcr.io` has to succeed before `helm dependency build`.

```bash
helm dependency build charts/trakr
helm lint charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
helm template trakr charts/trakr --values charts/trakr/values.yaml --values charts/trakr/values-dev.yaml
```

Image repository defaults to `ghcr.io/trak-r/trakr`; change it when the application image exists. Pods that pull from GHCR use the `trakr-ghcr` image pull secret. Create that docker-registry Secret in the release namespace before install:

```bash
kubectl create secret docker-registry trakr-ghcr \
  --namespace trakr \
  --docker-server=ghcr.io \
  --docker-username="$GHCR_USERNAME" \
  --docker-password="$GHCR_TOKEN"
```

`$GHCR_TOKEN` needs `read:packages`. The username is the GitHub user or organization that owns the token.

The Helm workflow installs this chart as release `trakr`. In that namespace the in-cluster endpoints are:

- Kafka bootstrap: `trakr-redpanda:9093`
- Redpanda Connect HTTP: `trakr-connect:80`
- Postgres: `trakr-postgresql:5432`, database `trakr`, user `trakr`
- Tracker Hub, when enabled: `trakr-adsbtracker:80`

The Redpanda chart would otherwise name its Service `trakr`, which is the application Service, so `redpanda.fullnameOverride` is `trakr-redpanda`. Connect's Service name comes from `connect.nameOverride`. `connect.adsb.enabled` defaults to false, and that pipeline generates one placeholder message per second so the pod stays up. Set `connect.adsb.enabled` and `connect.adsb.address` to the BaseStation `host:port` (the same value as `adsbtracker.feed`) to read that TCP stream and write each SBS line to the `adsb.basestation` topic on `trakr-redpanda:9093`. Dev does this for `trakr-adsbtracker:30003`. The feed server accepts a second TCP client, because Tracker Hub keeps its own connection. Redpanda creates the topic on the first produce. Postgres keeps its password in the `trakr-postgresql` Secret (`POSTGRES_PASSWORD`). Set `postgresql.auth.existingSecret` to supply `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` yourself. `postgresql.auth.username` and `postgresql.auth.database` must match that Secret, because the probes read them.

Redpanda runs one broker with TLS and external access turned off. `redpanda.console.enabled` defaults to false. Dev turns Console on and serves it at `https://trakr-redpanda.vibeify.co` through the Console chart Ingress, HTTP and Traefik, with no login. Add that hostname on the Cloudflare tunnel. Its chart still requests 1 core, 2.5Gi of memory, and a 20Gi volume. Postgres uses `postgres:17`, a 10Gi volume, and the cluster default storage class. pgAdmin is included when `components.pgadmin` is true. Its login password is generated into the `trakr-pgadmin` Secret (`PGADMIN_DEFAULT_PASSWORD`). Dev serves it at `https://trakr-pgadmin.vibeify.co` and preloads the TrakR Postgres server.

`components.adsbtracker` defaults to false. Turning it on renders Tracker Hub from `oci://ghcr.io/trak-r/charts/adsbtracker` in the TrakR release namespace. Set `adsbtracker.image.repository`, `adsbtracker.image.tag`, and `adsbtracker.feed.host` in the same values file. Dev turns it on, sets `adsbtracker.persistence.storageClass` to `openebs-lvmpv`, and serves the chart Ingress at `https://trakr-adsbtracker.vibeify.co`. That Ingress is HTTP and Traefik. Add the hostname on the Cloudflare tunnel. Database path, log path, profiles path, and the Kestrel bind settings live in the adsbtracker chart.

Deploy runs only from the **Helm** workflow dispatch, and that workflow installs this chart. Add a base64-encoded kubeconfig as the `KUBECONFIG_B64` secret on the target GitHub Environment before the first deploy. The workflow does not create that secret.

## homenet

`charts/homenet` installs the HomeNet platform: Argo CD, Headlamp, OpenEBS Local PV LVM, and a cloudflared connector for the remotely managed tunnel `vibeify-tunnel`. K3s manages Traefik. Public hostnames are configured on that tunnel. Applications publish hostnames with Ingress objects.

```bash
helm dependency build charts/homenet
helm lint charts/homenet --values charts/homenet/values.yaml
helm template homenet charts/homenet --values charts/homenet/values.yaml
```

Install, the tunnel token Secret, and the `openebs-vg` volume group are described in `charts/homenet/README.md`. The Helm workflow lints this chart and does not install it.

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
