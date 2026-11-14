# Terraform

```
terraform/
  modules/stack/          shared naming and tags
  environments/
    dev/
    staging/
    prod/
```

Each environment calls `modules/stack`. That module creates no cloud resources yet. Add provider resources there, then pass only environment-specific inputs from `environments/<name>`.

## Backend

`backend.tf` is comments only, so `terraform init` keeps state on disk. Replace it with a remote backend before more than one person applies an environment. Use a distinct state key per environment.

## Apply

Pull requests run format, validate, and plan. Apply is manual:

1. Create GitHub Environments named `dev`, `staging`, and `prod`, and add required reviewers on `staging` and `prod`.
2. Run the **Terraform** workflow with **Run workflow** and pick an environment.
3. When you add a provider, give that job credentials (prefer cloud OIDC over long-lived keys). Until then, apply succeeds because the stack has no resources.
