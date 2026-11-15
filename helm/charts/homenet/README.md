# homenet

Platform chart for a HomeNet cluster. One release installs Argo CD, Headlamp, the OpenEBS Local PV LVM driver, and a cloudflared connector for the remotely managed Cloudflare Tunnel `vibeify-tunnel`. K3s installs and manages Traefik.

Cloudflare Tunnel is the only public entry. Public hostnames and their origins are configured on `vibeify-tunnel` in Cloudflare. Point those origins at the K3s Traefik service, `http://traefik.kube-system.svc.cluster.local:80`. Traefik routes by Host, so an application chart publishes a hostname with an Ingress. Argo CD and Headlamp use the K3s `traefik` IngressClass.

```bash
helm dependency build charts/homenet
helm upgrade --install homenet charts/homenet --namespace homenet --create-namespace
```

## Before install

Nodes that should provision volumes need `lvm2` and a volume group named `openebs-vg`. The dev Terraform module creates that group on a blank secondary disk. The chart creates StorageClass `openebs-lvmpv` and does not mark it default, so it does not replace k3s `local-path`. The OpenEBS LVM node mounts the K3s kubelet directory `/var/lib/rancher/k3s/agent/kubelet`.

Create the tunnel token Secret in the install namespace. The token is the remotely managed credential for `vibeify-tunnel`. Copy it from the Cloudflare dashboard or API. The chart reads key `token` from Secret `homenet-cloudflare-token` and passes it to cloudflared as `TUNNEL_TOKEN`.

```bash
kubectl create secret generic homenet-cloudflare-token \
  --namespace homenet \
  --from-literal=token="$TUNNEL_TOKEN"
```

## After install

Argo CD is served at `https://argocd.example.com`. Headlamp is served at `https://headlamp.example.com`. Headlamp does not create a login token. Its ServiceAccount is bound to `cluster-admin`. Create a token for `homenet-headlamp` and paste it into the Headlamp login page. The `homenet-cloudflared` Deployment runs `cloudflared tunnel run` and joins `vibeify-tunnel` with the token from `homenet-cloudflare-token`.

This chart does not create Argo CD Applications or Git repository Secrets.
