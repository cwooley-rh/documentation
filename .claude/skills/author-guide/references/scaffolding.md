# Guide Scaffolding

Templates and structural patterns for new guides. Use the generic
skeleton as the base, then apply product-specific additions.

## Generic Guide Skeleton

```markdown
---
date: '<YYYY-MM-DD>'
title: '<Guide Title>'
tags: ["<Product>"]
authors:
  - <Author Name>
---

<One-paragraph introduction: what this guide does, why you would use it,
and what the end result is.>

## Prerequisites

* <Product> cluster (<minimum version>+)
* <CLI tool> ([install instructions](<link>))
* <Other prerequisites>

## Environment Variables

Set the following variables for use throughout this guide. Customize
the values to match your environment.

```bash
export CLUSTER_NAME="<your-cluster-name>"
export NAMESPACE="<namespace>"
# ... additional variables
```

## 1. <First Step Title>

<Brief explanation of what this step does.>

```bash
<commands>
```

## 2. <Second Step Title>

<Brief explanation.>

```bash
<commands>
```

## Verify

Confirm that the deployment is working:

```bash
<verification commands>
```

## Cleanup

Remove all resources created by this guide:

```bash
<cleanup commands in reverse order of creation>
```
```

## Product-Specific Additions

### ROSA Prerequisites

```markdown
## Prerequisites

* ROSA cluster (4.14+)
    - [ROSA HCP via Terraform](/experts/rosa/terraform/hcp/) (recommended)
    - [ROSA Classic via CLI](/experts/rosa/sts/)
    - Logged in with cluster-admin access
* `rosa` CLI
* `aws` CLI
* `oc` CLI
```

For GPU guides, add:
```markdown
* GPU-capable instance type available in your region (e.g., `g5.4xlarge`)
```

### ARO Prerequisites

```markdown
## Prerequisites

* ARO cluster (4.14+)
    - [ARO Quickstart](/experts/aro/quickstart/)
    - Logged in with cluster-admin access
* Azure CLI (`az`)
* `oc` CLI
* Azure subscription with sufficient quota (44+ vCPUs)
```

For guides that create Azure resources:
```markdown
## Environment Variables

```bash
export AZR_RESOURCE_GROUP="<your-resource-group>"
export AZR_CLUSTER="<your-cluster-name>"
export AZR_RESOURCE_LOCATION="eastus"
```
```

### OSD / GCP Prerequisites

```markdown
## Prerequisites

* OSD on GCP cluster
    - Provisioned via [OCM console](https://console.redhat.com)
    - Logged in with cluster-admin access
* `gcloud` CLI
* `oc` CLI
```

## Well-Structured Examples

Reference these existing guides as models:

- **ROSA with operators:** `content/rosa/ack/index.md` — good use of
  dynamic CSV lookup, environment variables, cleanup section
- **ARO with Azure integration:** `content/aro/blob-storage-csi/index.md` —
  Azure resource creation, unique naming, Helm install with RHCOS
  considerations
- **Cross-product IDP:** `content/idp/azuread-aro/index.md` — multi-step
  with Azure AD integration, environment variables throughout

## Cleanup Section Patterns

Cleanup should reverse the guide's steps, bottom-up:

```markdown
## Cleanup

Remove the resources created by this guide in reverse order:

```bash
# Remove application / workload
oc delete -f <resource>.yaml -n $NAMESPACE

# Remove operator
oc delete subscription <name> -n <operator-namespace>
CSV_NAME=$(oc get csv -n <operator-namespace> -o name | grep <operator>)
oc delete $CSV_NAME -n <operator-namespace>

# Remove namespace
oc delete namespace $NAMESPACE

# Remove cloud resources (if any)
<az/aws/gcloud delete commands>

# Remove machine pool (if created)
rosa delete machinepool -c $CLUSTER_NAME <pool-name> -y
```
```

Always test cleanup commands — they are the most frequently broken part
of documentation guides (see `../../shared/known-patterns.md`).
