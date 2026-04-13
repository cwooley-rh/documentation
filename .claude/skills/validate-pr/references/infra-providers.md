# Infrastructure Providers

All paths below use `$PR` as the PR number being validated. For single-PR
sessions, `$PR` can be omitted (use bare `/tmp/terraform-rosa`). For
parallel sessions, always include it to prevent state collisions.

## AWS / ROSA

> **Default to HCP.** Always provision ROSA HCP (hosted control plane)
> clusters unless the guide under test explicitly requires a classic cluster.
> HCP is faster (~20 min vs ~40 min), cheaper, and is the current ROSA
> default. Only set `hosted_control_plane = false` if the guide explicitly
> says "classic" or tests classic-only features.

### Terraform repo

```
https://github.com/rh-mobb/terraform-rosa.git
```

### Pre-flight

```bash
which rosa && rosa whoami
aws sts get-caller-identity
```

### Variables

```bash
export TF_VAR_token="$(rosa token)"  # preferred: uses current CLI session
# Alternative: TF_VAR_token="$(jq -r .refresh_token ~/Library/Application\ Support/ocm/ocm.json)"

export TF_VAR_cluster_name="<name>"
export TF_VAR_admin_password='Passw0rd12345!'
export TF_VAR_developer_password=''
export TF_VAR_private=false
export TF_VAR_hosted_control_plane=true   # HCP default — only change if guide requires classic
export TF_VAR_multi_az=false
```

### Provision

```bash
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git /tmp/terraform-rosa-$PR
cd /tmp/terraform-rosa-$PR
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

> For parallel sessions, use a unique cluster name per PR:
> `export TF_VAR_cluster_name="cwooley-pr$PR"`

### Login

```bash
oc login $(terraform output -raw cluster_api_url) \
  --username admin --password "$TF_VAR_admin_password"
```

### Key outputs

```bash
terraform output -raw cluster_api_url
terraform output -raw cluster_console_url
terraform output -raw cluster_name
```

### Teardown

```bash
cd /tmp/terraform-rosa-$PR
TF_VAR_token=$(rosa token) terraform destroy -auto-approve
```

### Typical timing

- HCP: ~20 minutes
- Classic: ~45 minutes

### Known issues

- **Token expiry:** ROSA OCM tokens expire during long classic cluster
  provisions (~40 min). If `terraform apply` fails mid-create with an
  "access and refresh tokens are unavailable" error, check `rosa describe
  cluster -c <name>` — the cluster may have finished. Re-run `terraform
  apply` with a fresh token to sync state, or use HCP to avoid the issue.
- **Pass token via env var or `rosa token`**, not in tfvars, to avoid
  stale tokens in files.

---

## Azure / ARO

### Terraform repo

```
https://github.com/rh-mobb/terraform-aro.git
```

### Pre-flight

```bash
which az && az account show --query '{sub:id,name:name}' -o table
az provider show -n Microsoft.RedHatOpenShift --query "registrationState" -o tsv
az provider show -n Microsoft.Compute --query "registrationState" -o tsv
az provider show -n Microsoft.Storage --query "registrationState" -o tsv
az provider show -n Microsoft.Authorization --query "registrationState" -o tsv
```

Register providers if not already registered:

```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

### Variables

Check the Terraform repo's `variables.tf` for the current variable list.
Common variables:

```bash
export TF_VAR_cluster_name="<name>"
export TF_VAR_location="eastus"
export TF_VAR_pull_secret_path="~/Downloads/pull-secret.txt"
```

### Provision

```bash
git clone --depth=1 https://github.com/rh-mobb/terraform-aro.git /tmp/terraform-aro-$PR
cd /tmp/terraform-aro-$PR
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

> For parallel sessions, use a unique cluster name per PR:
> `export TF_VAR_cluster_name="cwooley-pr$PR"`

### Login

```bash
API_URL=$(terraform output -raw api_server_url)
KUBEADMIN_PASS=$(terraform output -raw kubeadmin_password)
oc login "$API_URL" --username kubeadmin --password "$KUBEADMIN_PASS"
```

If the Terraform module does not expose these outputs, retrieve them via
Azure CLI:

```bash
AZR_RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AZR_CLUSTER=$(terraform output -raw cluster_name)

API_URL=$(az aro show -g "$AZR_RESOURCE_GROUP" -n "$AZR_CLUSTER" \
  --query apiserverProfile.url -o tsv)
KUBEADMIN_PASS=$(az aro list-credentials -g "$AZR_RESOURCE_GROUP" \
  -n "$AZR_CLUSTER" --query kubeadminPassword -o tsv)

oc login "$API_URL" --username kubeadmin --password "$KUBEADMIN_PASS"
```

### Key outputs

```bash
terraform output -raw api_server_url
terraform output -raw console_url
terraform output -raw kubeadmin_password
terraform output -raw resource_group_name
terraform output -raw cluster_name
```

### Teardown

```bash
cd /tmp/terraform-aro-$PR
terraform destroy -auto-approve
```

### Typical timing

- ARO: 30-45 minutes

### Azure-specific notes

- ARO requires a minimum of 44 vCPUs in the target region. Check quota:
  ```bash
  az vm list-usage --location eastus -o table | grep -i "total regional"
  ```
- A Red Hat pull secret is recommended but optional. Without it, access to
  Red Hat container catalog images and OperatorHub entries is limited.
- Resource providers must be registered before provisioning. The pre-flight
  section handles this.

---

## Shared Cluster Patterns

When a PR contains multiple guides that depend on the same cluster:

1. Provision the cluster once using Terraform
2. Execute the prerequisite guide first (e.g., quickstart)
3. Mark provisioning sections of subsequent guides as SKIP
4. Share environment variables across guides (cluster name, API URL, etc.)
5. Run each guide's cleanup section only if it does not destroy the cluster
6. Destroy the Terraform-managed cluster only after all guides are validated
