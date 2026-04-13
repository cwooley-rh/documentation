# OSD on GCP Product Knowledge Base

Product-specific knowledge for guides under `content/osd/` or tagged
`OSD`. Loaded on-demand by workflow skills when the target guide's
content path or tags match.

## CLI Tools

| Tool | Purpose | Version check |
|------|---------|---------------|
| `gcloud` | GCP resource management | `gcloud version` |
| `oc` | Cluster operations | `oc version --client` |
| `jq` | JSON processing | `jq --version` |

Pre-flight:
```bash
gcloud auth list
gcloud config get-value project
```

## Cluster Provisioning

There is no `rh-mobb/terraform-osd` repository. OSD on GCP clusters are
provisioned via:
- **OCM console** (console.redhat.com) — UI-based
- **OCM CLI** — `ocm create cluster`

When validating OSD guides, provisioning is typically manual or the guide
itself walks through the process. Mark provisioning sections as SKIP if
a cluster is already available.

## GCP Services Referenced in Guides

### Filestore
- GCE-PD is the default StorageClass on OSD/GCP
- Filestore provides ReadWriteMany (RWX) volumes
- Requires Filestore API enabled: `gcloud services enable file.googleapis.com`

### Cloud Next Gen Firewall
- GCP-specific network security
- Configured via VPC firewall rules or Cloud Armor

### Service Accounts
- GCP uses service accounts (not IAM roles like AWS or service principals
  like Azure) for workload identity
- Workload Identity Federation enables cross-cloud access (e.g., OSD on
  GCP accessing Azure resources)

## Guide Landscape

OSD on GCP has the smallest guide footprint (~7 guides). Common topics:
- Filestore integration
- VPC/networking configuration (preexisting VPC)
- Cloud Next Gen Firewall
- Ingress controller configuration
- Cross-cloud Workload Identity Federation

## Content Conventions

OSD guides follow the same conventions as ROSA and ARO guides (front
matter, cleanup sections, env vars) but use `gcloud` instead of `aws`
or `az` for cloud operations.

When authoring or reviewing OSD guides:
- Use `gcloud` commands (not `gsutil` which is deprecated for most ops)
- Reference GCP project ID, not project name
- Use `--format=json` or `--format=value(field)` for scriptable output
- Cleanup should remove Filestore instances, firewall rules, and service
  accounts created by the guide
