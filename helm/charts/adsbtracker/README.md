# adsbtracker

Helm chart for a single Tracker Hub pod. The pod stores observations in SQLite, so the chart runs one replica and keeps the database, write spool, and tracking profiles on ReadWriteOnce volumes.

Tracker Hub does not authenticate users. Leave the Service as ClusterIP, or enable the Ingress and enforce access control on the proxy. The pod serves HTTP on port 5000 and exposes `GET /health`.

The container runs as UID 1654 and cannot write the image workdir. The chart puts the SQLite database and log on the data volume, and tracking profiles on the profiles volume. `WebUi__UseHttpsRedirection` stays true. Setting it false makes this image bind port 5000 twice. `Kestrel__Endpoints__Https__Url` is plain HTTP on `127.0.0.1:5001` so Kestrel does not look for a developer certificate.

## Build the image

The chart does not use `davewalker5/adsbtracker`. That image has no health endpoint. Build from the repository root and push the result to a registry the cluster can pull:

```bash
docker build -f docker/Dockerfile.source -t registry.example/adsbtracker:2.39.0 .
docker push registry.example/adsbtracker:2.39.0
```

`docker/Dockerfile.source` targets the machine architecture. On a mixed cluster, set `image.pinAmd64: true` (the default) for an amd64 image.

## Install

`image.repository`, `image.tag`, and `feed.host` are required. `feed.host` must be a hostname or address the pod can reach. `host.docker.internal` is not provided.

```bash
helm install adsbtracker charts/adsbtracker \
  --set image.repository=registry.example/adsbtracker \
  --set image.tag=2.39.0 \
  --set feed.host=dump1090.tracking.svc.cluster.local \
  --set feed.port=30003
```

Blank API keys and a blank Mapbox token are valid. Core tracking does not need them. To supply keys without storing them in a values file, create a Secret and set `existingSecret` to its name. The Secret keys are:

- `ApplicationSettings__ApiServices__0__Key` (AeroDataBox)
- `ApplicationSettings__ApiServices__1__Key` (AirLabs)
- `ApplicationSettings__ApiServices__2__Key` (CheckWX)
- `ApplicationSettings__ApiServices__3__Key` (SkyLink)
- `Mapbox__AccessToken`

Leave `persistence.storageClass` empty to use the cluster default. Choose a block ReadWriteOnce class. SQLite corrupts on NFS and Azure Files.

Changing the ConfigMap or the chart-managed Secret rolls the pod. After rotating an external Secret, restart the pod yourself.

## Ingress

```yaml
ingress:
  enabled: true
  className: traefik
  host: tracker.example.com
  tls:
    enabled: false
```

Set `ingress.tls.enabled` when the Ingress itself terminates TLS, and set `ingress.tls.secretName` to that certificate. Leave TLS off when Cloudflare or another proxy in front of Traefik terminates it. The chart sets nginx proxy read and send timeouts to 3600 seconds so Blazor Server and `/hubs/aircraft` WebSocket connections stay open. Extra annotations are merged on top of those timeouts.

## Upgrade and backup

Stop is graceful: the pod handles SIGTERM and `terminationGracePeriodSeconds` is longer than the tracker stop timeout. Before an upgrade or host migration, back up the data volume and the profiles volume together, including any SQLite `-wal` and `-shm` files. Tracker Hub applies pending migrations on startup.

`helm uninstall` deletes the pod and keeps the volume claims.
