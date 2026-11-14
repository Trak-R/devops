# homenet

Platform chart for a HomeNet cluster. One release installs Traefik, Argo CD, Cloudflare Tunnel, Headlamp, and the OpenEBS Local PV LVM driver.

Cloudflare Tunnel is the only public entry. It forwards `*.example.com` to the Traefik ClusterIP. Traefik routes by Host, so an application chart publishes a hostname with an Ingress and does not change the tunnel rules. The hostname has to sit under `example.com`.

```bash
helm dependency build charts/homenet
helm upgrade --install homenet charts/homenet --namespace homenet --create-namespace
```

## Before install

On k3s, start the server with `--disable=traefik`. The bundled controller would also claim the `traefik` IngressClass.

Nodes that should provision volumes need `lvm2` and a volume group named `homenet`. The chart creates StorageClass `openebs-lvmpv` and does not mark it default, so it does not replace k3s `local-path`.

Create the tunnel credential Secret in the install namespace. `credentials.json` is the file written by `cloudflared tunnel create`. Leave `cloudflare.secret` empty.

```bash
kubectl create secret generic homenet-tunnel-credentials \
  --namespace homenet \
  --from-file=credentials.json=./credentials.json
```

Point Cloudflare DNS for `*.example.com` at that tunnel. Fill `cloudflare.account`, `cloudflare.tunnelName`, and `cloudflare.tunnelId` before the tunnel can register.

## After install

Argo CD is served at `https://argocd.example.com`. Headlamp is served at `https://headlamp.example.com`. Headlamp does not create a login token. Its ServiceAccount is bound to `cluster-admin`. Create a token for `homenet-headlamp` and paste it into the Headlamp login page. The tunnel chart appends a catch-all rule that returns HTTP 404.

This chart does not create Argo CD Applications or Git repository Secrets.
