---
name: provision
description: >-
  Provision a test cluster via Terraform. Supports ROSA (AWS) and ARO
  (Azure). Use when asked to create a cluster, stand up infrastructure,
  or /provision.
version: "0.1.0"
user-invocable: true
---

# Provision

Stand up a test cluster via Terraform for one-command teardown.

## Invocation

```
/provision <product>
```

Where `<product>` is `rosa` or `aro`. OSD on GCP does not have a
Terraform repo and must be provisioned manually via OCM.

## Workflow

### 1. Pre-flight

Verify CLI tools and credentials. Load the product knowledge base from
`../../products/<product>.md` for product-specific checks.

```bash
# Common
which oc && oc version --client
which terraform && terraform version
which gh && gh auth status

# ROSA
which rosa && rosa whoami
aws sts get-caller-identity

# ARO
which az && az account show
```

For ARO, verify Azure provider registration (see `../../products/aro.md`).

### 2. Confirm with user

Before provisioning, confirm:
- **Region/location** (default: us-east-1 for ROSA, eastus for ARO)
- **Cluster type** (ROSA: HCP default; ARO: standard)
- **Cluster name** (convention: `cwooley-pr<PR>` for validation, or user's choice)
- **Sizing** (default: standard worker nodes; GPU if guide requires it)
- **Estimated cost and time** (ROSA HCP ~20 min, ARO ~35 min)

### 3. Clone and configure

For provider-specific variables, terraform repo URLs, and configuration
details, read [references/providers.md](references/providers.md).

```bash
# Clone terraform repo
git clone --depth=1 <repo-url> /tmp/terraform-<product>-<identifier>
cd /tmp/terraform-<product>-<identifier>

# Set variables (product-specific)
export TF_VAR_cluster_name="<name>"
# ... additional vars from providers.md
```

### 4. Apply

```bash
terraform init
terraform plan -out tf.plan
# Show summary only to reduce context
terraform apply tf.plan 2>&1 | tail -5
```

### 5. Login and verify

```bash
# Product-specific login (see providers.md)
oc login <api-url> --username <user> --password <password>
oc get nodes -o wide
oc get sc
```

### 6. Output

Report to the caller:
- Cluster name
- API URL
- Console URL
- OCP version
- Login credentials
- Terraform directory path

## Parallel Sessions

When provisioning for parallel PR validation, use PR number as identifier:
- **Terraform dir:** `/tmp/terraform-<product>-<PR>`
- **Cluster name:** `cwooley-pr<PR>`

## Guard Rails

- Always confirm before provisioning — never auto-provision
- Report estimated cost and time before user confirms
- For ROSA, always use HCP unless explicitly told otherwise
- For ARO, never set domain to a real public domain
- Pass ROSA token via `$(rosa token)`, not in tfvars files
