# Terraform

```
terraform/
  modules/stack/          shared naming and tags
  modules/k3s-cluster/    Proxmox VMs and k3s cloud-init
  environments/
    dev/                  one control plane and optional workers
    staging/              names and tags only
    prod/                 names and tags only
```

Dev calls `modules/k3s-cluster`. That module downloads the Ubuntu 24.04 cloud image, builds a template, and clones one control-plane VM. Cloud-init installs k3s `v1.37.2+k3s1`. The server has no control-plane taint, so it stays schedulable with or without workers. `worker_addresses` lists the worker CIDRs. An empty list creates no worker VMs. Each worker is named from its IP and joins `https://<control-plane-ip>:6443` with a token Terraform generates. Adding or removing an address changes only that worker. Staging and prod still only publish a name prefix and tags.

## Proxmox

Copy `environments/dev/terraform.tfvars.example` to `terraform.tfvars` and export the API token. The token is not stored in tfvars.

```bash
export PROXMOX_VE_API_TOKEN="terraform@pve!trakr=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev plan
```

The endpoint is the API URL, including the port, for example `https://proxmox.example.com:8006/`.

The token needs these privileges on the target path: `VM.Allocate`, `VM.Clone`, `VM.Config.*`, `VM.PowerMgmt`, `Datastore.Allocate`, `Datastore.AllocateTemplate`, `SDN.Use`, `Sys.Audit`, and `Sys.Modify`. The image download uses the Proxmox download API, which requires the two `Sys` privileges. The image datastore must allow Import. The snippet datastore must allow Snippets. The k3s token is stored in Terraform state and in those snippets, so keep state private.

The module defaults are 2 vCPU and 4 GB RAM. Dev sets the control plane to 4 vCPU and 8 GB. Changing those values updates the existing VM in place and may reboot it. The module boot-disk defaults are 32 GB for the control plane and 40 GB for each worker. Dev sets the control-plane boot disk to 64 GB. The template boot disk stays at the smaller of those two sizes, then the control plane grows after clone. Proxmox rejects a shrink, and a shrink can replace the disk.

Dev also attaches a 500 GB secondary disk to the control plane on `datastore_id`, which is `local-lvm` in the example. `data_disk_gb = 0` omits it. Workers do not get this disk. The disk uses Proxmox interface `virtio1` and serial `openebs-vg`. The guest script finds it at `/dev/disk/by-id/virtio-openebs-vg` and does not use `/dev/vdb`. On a blank disk it creates LVM volume group `openebs-vg` and no logical volumes. A disk that already has a signature, partition, filesystem, or other volume group is left unchanged. Terraform does not install OpenEBS. The HomeNet chart's StorageClass expects that volume group when OpenEBS is installed later.

Setting `data_disk_gb` back to 0 deletes the `virtio1` volume in Proxmox, including its data. Changing `data_volume_group` changes the virtio serial. The script will not move or wipe a volume group that already exists.

A VM that has already finished its first boot does not run cloud-init again. After this change, disk attachment and the boot-disk resize still happen through Proxmox. The guest script is installed on the next cloud-init run, which for an existing VM means `sudo cloud-init clean --logs` and a reboot. That re-runs the k3s install as well. A new VM runs the script on first boot.

Workers that were already applied under the old index keys `1` and `2` are replaced once, because each worker is now identified by its CIDR. The control plane is not replaced by that change.

## Kubeconfig

Kubeconfig is not copied into Terraform state. After the control plane finishes cloud-init:

```bash
ssh ubuntu@<control-plane-ip> sudo cat /etc/rancher/k3s/k3s.yaml
```

Replace `127.0.0.1` in that file with the control-plane address from the `api_url` output.

## Backend

`backend.tf` is comments only, so `terraform init` keeps state on disk. Replace it with a remote backend before more than one person applies an environment. Use a distinct state key per environment.

## Apply

Pull requests validate every environment. They plan staging and prod. Dev plan calls the Proxmox API, so it runs only when the repository secrets `PROXMOX_VE_ENDPOINT` and `PROXMOX_VE_API_TOKEN` are set. A real dev plan also needs `PROXMOX_NODE_NAME`, `PROXMOX_GATEWAY`, `PROXMOX_CONTROL_PLANE_ADDRESS`, and `PROXMOX_SSH_PUBLIC_KEY`. `PROXMOX_WORKER_ADDRESSES` is an optional JSON list of worker CIDRs and defaults to `[]`. `PROXMOX_VE_INSECURE` is optional and defaults to `true`.

Apply is manual:

1. Create GitHub Environments named `dev`, `staging`, and `prod`, and add required reviewers on `staging` and `prod`.
2. Put the Proxmox secrets above on the `dev` environment.
3. Run the **Terraform** workflow with **Run workflow** and pick an environment.
