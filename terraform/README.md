# Terraform

```
terraform/
  modules/stack/          shared naming and tags
  modules/k3s-cluster/    Proxmox VMs and k3s cloud-init
  environments/
    dev/                  one control plane and two workers
    staging/              names and tags only
    prod/                 names and tags only
```

Dev calls `modules/k3s-cluster`. That module downloads the Ubuntu 24.04 cloud image, builds a template, and clones one control-plane VM and two worker VMs. Cloud-init installs k3s `v1.37.2+k3s1`. Workers join `https://<control-plane-ip>:6443` with a token Terraform generates, and retry until the API answers. Staging and prod still only publish a name prefix and tags.

## Proxmox

Copy `environments/dev/terraform.tfvars.example` to `terraform.tfvars` and export the API token. The token is not stored in tfvars.

```bash
export PROXMOX_VE_API_TOKEN="terraform@pve!trakr=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev plan
```

The endpoint is the API URL, including the port, for example `https://proxmox.example.com:8006/`.

The token needs these privileges on the target path: `VM.Allocate`, `VM.Clone`, `VM.Config.*`, `VM.PowerMgmt`, `Datastore.Allocate`, `Datastore.AllocateTemplate`, `SDN.Use`, `Sys.Audit`, and `Sys.Modify`. The image download uses the Proxmox download API, which requires the two `Sys` privileges. The image datastore must allow Import. The snippet datastore must allow Snippets. The k3s token is stored in Terraform state and in those snippets, so keep state private.

Defaults are 2 vCPU and 4 GB RAM. The control plane disk is 32 GB and each worker disk is 40 GB.

## Kubeconfig

Kubeconfig is not copied into Terraform state. After the control plane finishes cloud-init:

```bash
ssh ubuntu@<control-plane-ip> sudo cat /etc/rancher/k3s/k3s.yaml
```

Replace `127.0.0.1` in that file with the control-plane address from the `api_url` output.

## Backend

`backend.tf` is comments only, so `terraform init` keeps state on disk. Replace it with a remote backend before more than one person applies an environment. Use a distinct state key per environment.

## Apply

Pull requests validate every environment. They plan staging and prod. Dev plan calls the Proxmox API, so it runs only when the repository secrets `PROXMOX_VE_ENDPOINT` and `PROXMOX_VE_API_TOKEN` are set. A real dev plan also needs `PROXMOX_NODE_NAME`, `PROXMOX_GATEWAY`, `PROXMOX_CONTROL_PLANE_ADDRESS`, `PROXMOX_WORKER_ADDRESSES` (a JSON list of two CIDRs), and `PROXMOX_SSH_PUBLIC_KEY`. `PROXMOX_VE_INSECURE` is optional and defaults to `true`.

Apply is manual:

1. Create GitHub Environments named `dev`, `staging`, and `prod`, and add required reviewers on `staging` and `prod`.
2. Put the Proxmox secrets above on the `dev` environment.
3. Run the **Terraform** workflow with **Run workflow** and pick an environment.
