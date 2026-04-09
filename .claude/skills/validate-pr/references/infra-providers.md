# Infrastructure Providers

## AWS / ROSA

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
export TF_VAR_token="$(jq -r .refresh_token \
  ~/Library/Application\ Support/ocm/ocm.json)"  # macOS
# Linux: ~/.config/ocm/ocm.json

export TF_VAR_cluster_name="<name>"
export TF_VAR_admin_password='Passw0rd12345!'
export TF_VAR_developer_password=''
export TF_VAR_private=false
export TF_VAR_hosted_control_plane=true   # HCP is faster (~20 min)
export TF_VAR_multi_az=false
```

### Provision

```bash
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git /tmp/terraform-rosa
cd /tmp/terraform-rosa
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

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
cd /tmp/terraform-rosa
terraform destroy -auto-approve
```

### Typical timing

- HCP: ~20 minutes
- Classic: ~45 minutes

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
git clone --depth=1 https://github.com/rh-mobb/terraform-aro.git /tmp/terraform-aro
cd /tmp/terraform-aro
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

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
cd /tmp/terraform-aro
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
