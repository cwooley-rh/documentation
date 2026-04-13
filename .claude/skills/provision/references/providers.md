# Provider-Specific Provisioning

Provisioning commands, variables, and login procedures per cloud provider.
For product-specific context (why HCP is default, domain gotchas, quota
rules), see the product knowledge bases at `../../products/`.

All paths use `$ID` as a session identifier (PR number, cluster name, or
other unique value) to support parallel sessions.

---

## AWS / ROSA

### Terraform repo

```
https://github.com/rh-mobb/terraform-rosa.git
```

### Variables

```bash
export TF_VAR_token="$(rosa token)"
export TF_VAR_cluster_name="<name>"
export TF_VAR_admin_password='Passw0rd12345!'
export TF_VAR_developer_password=''
export TF_VAR_private=false
export TF_VAR_hosted_control_plane=true
export TF_VAR_multi_az=false
```

### Provision

```bash
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git /tmp/terraform-rosa-$ID
cd /tmp/terraform-rosa-$ID
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

### Timing

- HCP: ~20 minutes
- Classic: ~45 minutes

---

## Azure / ARO

### Terraform repo

```
https://github.com/rh-mobb/terraform-aro.git
```

### Variables

Check the Terraform repo's `variables.tf` for the current variable list.

```bash
export TF_VAR_cluster_name="<name>"
export TF_VAR_location="eastus"
export TF_VAR_pull_secret_path="~/Downloads/pull-secret.txt"
```

### Provision

```bash
git clone --depth=1 https://github.com/rh-mobb/terraform-aro.git /tmp/terraform-aro-$ID
cd /tmp/terraform-aro-$ID
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

If Terraform outputs are not available, use Azure CLI:

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

### Timing

- ARO: 30-45 minutes

---

## Shared Cluster Patterns

When multiple guides depend on the same cluster:

1. Provision the cluster once using Terraform
2. Execute the prerequisite guide first (e.g., quickstart)
3. Mark provisioning sections of subsequent guides as SKIP
4. Share environment variables across guides (cluster name, API URL, etc.)
5. Run each guide's cleanup section only if it does not destroy the cluster
6. Destroy the Terraform-managed cluster only after all guides are validated
