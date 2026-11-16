# Helm

Charts live under `charts/`. CI installs Helm 3.22.1 and uses chart API `v2`.

## trakr

`charts/trakr` packages the TrakR application with one Redpanda broker, Redpanda Connect, and one Postgres instance. The API is included when `components.api` is true. The BaseStation simulator is included when `components.simulator` is true. Shared defaults live in `values.yaml`. Per-environment overrides are `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml`.

Build the dependencies before linting or installing. `Chart.lock` pins `redpanda` 26.2.6 and `connect` 3.2.36. The downloaded charts are not committed.

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
- API, when `components.api` is true: `<fullname>-api:80`
- BaseStation simulator, when enabled: `<fullname>-simulator:30003`

The Redpanda chart would otherwise name its Service `trakr`, which is the application Service, so `redpanda.fullnameOverride` is `trakr-redpanda`. Connect's Service name comes from `connect.nameOverride`. `connect.adsb.enabled` defaults to false, and that pipeline generates one placeholder message per second so the pod stays up. Set `connect.adsb.enabled` to read that TCP stream and write each valid SBS MSG line as JSON to the `adsb.basestation` topic on `trakr-redpanda:9093`. A line is valid when its message type is MSG and HexIdent, the fifth comma-separated field, is a 6-digit hex address. The pipeline uppercases that address and stores it as the Kafka record key and as `address`. The JSON fields are the BaseStation reader message: `messageType`, `transmissionType`, `generated`, `callsign`, `altitude`, `groundSpeed`, `track`, `latitude`, `longitude`, `verticalRate`, `squawk`, `alert`, `emergency`, `spi`, and `isOnGround`. Empty and unparseable fields are omitted. Explicit `0` and `false` stay. A line that is not a MSG record is published to `adsb.basestation.dlq` with reason `not_msg`. A MSG line with no valid ICAO24 is published there with reason `invalid_icao`. The dead-letter value is JSON with `reason` and the original `line`. Both outputs use the murmur2 partitioner and an idempotent producer (`max_in_flight_requests: 1`), so records that share a key stay on one partition in produce order. An empty `connect.adsb.address` uses this release's simulator Service, `<fullname>-simulator:30003`. Dev leaves the address empty. A release named `trakr-dev` connects to `trakr-dev-simulator:30003`. Redpanda creates the topic on the first produce. Postgres keeps its password in the `trakr-postgresql` Secret (`POSTGRES_PASSWORD`). Set `postgresql.auth.existingSecret` to supply `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` yourself. `postgresql.auth.username` and `postgresql.auth.database` must match that Secret, because the probes read them.

Redpanda runs one broker with TLS and external access turned off. `redpanda.console.enabled` defaults to false. Dev turns Console on and serves it at `https://trakr-redpanda.vibeify.co` through the Console chart Ingress, HTTP and Traefik, with no login. Add that hostname on the Cloudflare tunnel. Its chart still requests 1 core, 2.5Gi of memory, and a 20Gi volume. Postgres uses `postgres:17`, a 10Gi volume, and the cluster default storage class. pgAdmin is included when `components.pgadmin` is true. Its login password is generated into the `trakr-pgadmin` Secret (`PGADMIN_DEFAULT_PASSWORD`). Dev serves it at `https://trakr-pgadmin.vibeify.co` and preloads the TrakR Postgres server.

`components.api` defaults to false. Turning it on renders the TrakR API from `templates/api/`. Set `api.image.repository` and `api.image.tag` in the same values file. The tag is the commit SHA of an image built from `apps/api/Dockerfile` in the API repository. The container command stays the image default, `uvicorn` on port 8000, and probes call `GET /health`. `DB_HOST`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` come from this chart's Postgres Secret, so the API uses database `trakr`. `SECRET_KEY` is generated into the `<fullname>-api` Secret. Set `api.auth.existingSecret` to supply `SECRET_KEY` yourself. `DEBUG` is `false`. `CORS_ORIGINS` defaults to `["*"]`. `LOG_FILE` is an empty string, so the process logs to stdout and does not create `logs/app.log`. The published image has to skip that file when `LOG_FILE` is empty. An image that still creates `logs/app.log` fails on the read-only root filesystem. The pod runs as UID 65532, drops all capabilities, and mounts an emptyDir at `/tmp`. Redis, Celery, and MinIO are not deployed. Dev preconfigures the Ingress at `https://trakr-api.vibeify.co` through Traefik and leaves `components.api` false until `api.image.tag` is set. Add that hostname on the Cloudflare tunnel.

`components.simulator` defaults to false. Turning it on renders BaseStationReader.Simulator in the TrakR release namespace from `templates/simulator/`. Set `simulator.image.repository` and `simulator.image.tag` in the same values file. The tag is the commit SHA of an image built from `docker/Dockerfile.simulator`. Dev turns it on. The feed Service is `<fullname>-simulator:30003`. The pod listens on every interface, writes its log to an emptyDir, and has no Ingress.

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
