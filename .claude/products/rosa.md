# ROSA Product Knowledge Base

Product-specific knowledge for guides under `content/rosa/` or tagged
`ROSA`, `ROSA HCP`, or `ROSA Classic`. Loaded on-demand by workflow
skills when the target guide's content path or tags match.

## CLI Tools

| Tool | Purpose | Version check |
|------|---------|---------------|
| `rosa` | Cluster lifecycle, machine pools, IDPs | `rosa version` |
| `aws` | IAM, EC2, S3, CloudWatch, EFS | `aws --version` |
| `oc` | Cluster operations | `oc version --client` |
| `jq` | JSON processing | `jq --version` |
| `terraform` | Infrastructure provisioning | `terraform version` |

Pre-flight:
```bash
rosa whoami
aws sts get-caller-identity
```

## Cluster Types

### HCP (Hosted Control Plane) — Default

Always provision HCP unless the guide explicitly requires classic. HCP is
faster (~20 min vs ~40 min), cheaper, and is the current ROSA default.

- Control plane runs in Red Hat's account (not customer VPC)
- Machine pools are the only customer-managed compute
- `rosa create machinepool` works the same as classic
- Some features differ: no cluster-admin by default (use `rosa create admin`)

### Classic (STS)

Use only when the guide explicitly says "classic" or tests classic-only
features (e.g., cluster-admin RBAC, in-cluster etcd access).

- Full control plane in customer VPC
- Longer provision time (~40-45 min)
- Token expiry is a major risk (see Known Pitfalls)

## STS / IAM Patterns

ROSA uses AWS STS (Security Token Service) for authentication:
- **Account roles:** Installer, Support, Worker, Control Plane
- **Operator roles:** Per-namespace IAM roles for cluster operators
- **Pod Identity / IRSA:** Workload-level AWS access via service account annotations
- **Cross-account access:** Guides may create roles in separate AWS accounts

When validating STS guides, check that:
- Role trust policies reference the correct OIDC provider
- Role names include the cluster name for uniqueness
- Cleanup removes all roles (account + operator)

## Networking

- **PrivateLink clusters:** API and ingress are private; requires VPN or bastion
- **Local Zones:** GPU/edge workloads in AWS Local Zones
- **VPC requirements:** ROSA needs specific subnet tagging (`kubernetes.io/role/elb`)
- **Ingress:** AWS ALB/NLB via Load Balancer Operator or ingress controller

## Operators

### GPU Operator (NVIDIA)
- CSV versions change frequently; always use dynamic lookup:
  ```bash
  CSV_NAME=$(oc get csv -n nvidia-gpu-operator -o name | grep gpu-operator-certified)
  ```
- ClusterPolicy should be extracted from CSV annotations, not hardcoded
- GPU machine pools need taints: `nvidia.com/gpu=present:NoSchedule`
- Instance types: `g5.xlarge` (1 GPU), `g5.4xlarge` (1 GPU, more CPU/RAM), `p3`/`p4` for multi-GPU

### RHOAI (Red Hat OpenShift AI)
- RHOAI 2.25+ requires patching DSCI to disable ServiceMesh before DSC creation
- Operator no longer auto-creates DSC; create manually with KServe set to Removed
- Dashboard hardware profiles configured via OdhDashboardConfig

### NFD (Node Feature Discovery)
- Required before GPU Operator; discovers and labels GPU nodes
- Namespace: `openshift-nfd`
- Operator group targets `openshift-nfd` namespace

## Terraform Variables

From `rh-mobb/terraform-rosa`:

| Variable | Default | Notes |
|----------|---------|-------|
| `token` | — | Use `$(rosa token)`, not hardcoded |
| `cluster_name` | — | Use `cwooley-pr<PR>` for test clusters |
| `hosted_control_plane` | `true` | Only set `false` if guide requires classic |
| `admin_password` | — | Set for cluster admin access |
| `developer_password` | `""` | Leave empty unless needed |
| `private` | `false` | PrivateLink cluster |
| `multi_az` | `false` | Multi-AZ deployment |
| `region` | — | Defaults to AWS CLI default region |
| `compute_machine_type` | varies | e.g., `m5.xlarge` |

## Quota and Region Rules

- GPU instances (`g5`, `p3`, `p4`) have per-region vCPU quotas
- Check quota: `aws service-quotas get-service-quota --service-code ec2 --quota-code L-DB2E81BA`
- When running parallel GPU validations, spread across regions:

| Session | Region |
|---------|--------|
| 1 | us-east-1 |
| 2 | us-east-2 |
| 3 | us-west-2 |
| 4 | ca-central-1 |

## Known Pitfalls

### Token expiry
OCM tokens expire after ~15 min. Classic clusters take 35-45 min to
provision, so the token always expires. HCP clusters (~20 min) usually
complete before expiry but can still hit it.

**Mitigation:** Always pass token via `TF_VAR_token=$(rosa token)` (not
in tfvars files). After a token error, check `rosa describe cluster -c
<name>` — the cluster likely completed. Re-run `terraform apply` with a
fresh token to sync state.

### DNS propagation delay
Cluster reports "ready" before DNS propagates. API URL returns NXDOMAIN
for ~2 min after ready state.

**Mitigation:** Wait for `nslookup` to resolve before `oc login`.

### `sed -i` on macOS
BSD `sed -i` requires an extension argument. Guides should use
`sed -i.bak` for portability but this leaves `.bak` files.

### Non-TF resources
Guides create IAM roles, CloudWatch log groups, S3 buckets, and Helm
releases outside Terraform. These block `terraform destroy` and must be
cleaned up first. Track every resource created during execution.
