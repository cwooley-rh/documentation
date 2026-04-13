---
name: teardown
description: >-
  Destroy test infrastructure with a pre-flight audit for non-Terraform
  resources. Use when asked to tear down a cluster, clean up
  infrastructure, or /teardown.
version: "0.1.0"
user-invocable: true
---

# Teardown

Destroy test infrastructure safely. Audits for non-Terraform resources
before running `terraform destroy` to prevent orphaned cloud resources.

## Invocation

```
/teardown <product> [terraform-dir]
```

Examples:
- `/teardown rosa /tmp/terraform-rosa-912`
- `/teardown aro` (uses default `/tmp/terraform-aro`)

## Workflow

### 1. Audit non-Terraform resources

Before destroying, list resources created by guide execution that
Terraform does not manage. These **block** `terraform destroy` if they
exist in the same resource group or VPC.

**AWS / ROSA:**
```bash
CLUSTER_NAME="<cluster-name>"

# IAM roles created by ROSA or guides
aws iam list-roles --query "Roles[?contains(RoleName, \`$CLUSTER_NAME\`)].[RoleName]" --output text

# CloudWatch log groups
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/containerinsights/$CLUSTER_NAME" \
  --query 'logGroups[].logGroupName' --output text

# S3 buckets created by guides
aws s3 ls | grep "$CLUSTER_NAME"
```

**Azure / ARO:**
```bash
AZR_RESOURCE_GROUP="<resource-group>"

# All resources in the resource group
az resource list --resource-group "$AZR_RESOURCE_GROUP" -o table

# Storage accounts
az storage account list -g "$AZR_RESOURCE_GROUP" -o table

# Service principals (check by name pattern)
az ad sp list --display-name "<cluster-or-guide-prefix>" --query '[].displayName' -o tsv
```

Present the list to the user and confirm before proceeding.

### 2. Clean non-TF resources

Delete each non-Terraform resource. Common patterns:

**Kubernetes resources (run before cluster destroy):**
```bash
# Helm releases
helm list -A | grep <guide-pattern>
helm uninstall <release> -n <namespace>

# Operators installed by guide
oc delete subscription <name> -n <namespace>
oc delete csv <name> -n <namespace>

# Namespaces created by guide
oc delete namespace <name>
```

**AWS resources:**
```bash
# IAM roles (detach policies first)
for role in $(aws iam list-roles --query "Roles[?contains(RoleName, \`$CLUSTER_NAME\`)].[RoleName]" --output text); do
  for arn in $(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text); do
    aws iam detach-role-policy --role-name "$role" --policy-arn "$arn"
  done
  aws iam delete-role --role-name "$role"
done

# CloudWatch log groups
aws logs delete-log-group --log-group-name "<group>"

# S3 buckets (empty first)
aws s3 rb s3://<bucket> --force
```

**Azure resources:**
```bash
# Storage accounts
az storage account delete -n <name> -g "$AZR_RESOURCE_GROUP" -y

# Service principals
az ad sp delete --id <sp-id>
```

### 3. Terraform destroy

```bash
cd <terraform-dir>

# ROSA: refresh token before destroy
TF_VAR_token=$(rosa token) terraform destroy -auto-approve

# ARO: no token needed
terraform destroy -auto-approve
```

### 4. Verify

Confirm no orphaned resources remain:

```bash
# AWS
aws iam list-roles --query "Roles[?contains(RoleName, \`$CLUSTER_NAME\`)]" --output text
aws logs describe-log-groups --log-group-name-prefix "/aws/containerinsights/$CLUSTER_NAME"

# Azure
az resource list --resource-group "$AZR_RESOURCE_GROUP" -o table 2>/dev/null
```

### 5. Local cleanup

```bash
# Remove terraform directory
rm -rf <terraform-dir>

# Worktree cleanup (parallel sessions)
git worktree remove .worktrees/pr-<PR> 2>/dev/null
git branch -D validate-pr-<PR> 2>/dev/null
```

## Guard Rails

- **Always confirm** before destroying any resources
- **Always audit** non-TF resources first — skipping this leaves orphaned
  resources that incur costs
- **Never run terraform destroy without explicit user permission**
- If terraform destroy fails, check for remaining non-TF resources that
  block deletion
- For ROSA, always refresh the token before destroy (`TF_VAR_token=$(rosa token)`)
