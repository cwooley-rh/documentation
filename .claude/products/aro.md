# ARO Product Knowledge Base

Product-specific knowledge for guides under `content/aro/` or tagged
`ARO`. Loaded on-demand by workflow skills when the target guide's
content path or tags match.

## CLI Tools

| Tool | Purpose | Version check |
|------|---------|---------------|
| `az` | Azure resource management | `az version` |
| `oc` | Cluster operations | `oc version --client` |
| `jq` | JSON processing | `jq --version` |
| `helm` | Package management | `helm version` |
| `terraform` | Infrastructure provisioning | `terraform version` |

Pre-flight:
```bash
az account show --query '{sub:id,name:name}' -o table
```

## Azure Provider Registration

Four providers must be registered before provisioning ARO:

```bash
az provider show -n Microsoft.RedHatOpenShift --query "registrationState" -o tsv
az provider show -n Microsoft.Compute --query "registrationState" -o tsv
az provider show -n Microsoft.Storage --query "registrationState" -o tsv
az provider show -n Microsoft.Authorization --query "registrationState" -o tsv
```

Register if not already registered:
```bash
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait
```

## Service Principal Creation

**CRITICAL:** The `--skip-assignment` flag on `az ad sp create-for-rbac`
is deprecated. Do not use it. Remove it from any guide that includes it
and verify the command works without it.

```bash
az ad sp create-for-rbac --name <sp-name> --role Contributor \
  --scopes /subscriptions/<sub-id>/resourceGroups/<rg>
```

## Networking

- **VNet requirements:** ARO requires a VNet with at least two subnets
  (master + worker), each with minimum /27 CIDR
- **Private clusters:** Private API server and ingress via Azure Private
  Endpoints; requires VPN or bastion for access
- **DNS domain variable:** Never set the terraform-aro `domain` variable
  to a real public domain (e.g., `api.redhat.com`). Omit it to get a
  random domain, or use a clearly fake/unique value. Setting it to a real
  domain breaks cluster provisioning.

## RHCOS Compatibility

ARO runs Red Hat CoreOS (RHCOS) on all nodes. Key differences from
standard Linux distributions:

- `/usr/local` is a symlink to `../var/usrlocal`
- Helm charts with init containers that mount `/usr/local` as a hostPath
  will fail with `Init:CreateContainerError`
- `/opt` may also be read-only or a symlink

**Mitigation for Helm charts:**
1. Disable init containers via `--set` flags (e.g.,
   `--set node.enableBlobfuseProxy=false --set node.enableAznfsMount=false`)
2. If init containers cannot be disabled via values, patch the DaemonSet
   after install:
   ```bash
   oc patch daemonset <name> --type json \
     -p '[{"op": "remove", "path": "/spec/template/spec/initContainers"}]'
   ```

**During review:** When an ARO guide installs a Helm chart, check the
chart's templates for hostPath volumes targeting `/usr/local` or `/opt`.

## Terraform Variables

From `rh-mobb/terraform-aro`:

| Variable | Default | Notes |
|----------|---------|-------|
| `cluster_name` | — | Use `cwooley-pr<PR>` for test clusters |
| `location` | `eastus` | Check quota in target region |
| `pull_secret_path` | — | Path to Red Hat pull secret (recommended) |
| `domain` | — | **Omit for random**; never use a real public domain |

## Resource Naming

Azure storage accounts and Key Vaults require **globally unique** names.
Generic names like `aroblobsa` will fail if already taken.

**During review/authoring:** Ensure guides either:
- Use environment variables so users pick unique names
- Include a note telling users to choose a unique name
- Generate names with a random suffix (e.g., `aroblobsa$(date +%s)`)

## Quota

ARO requires a minimum of 44 vCPUs in the target region. Check quota:
```bash
az vm list-usage --location eastus -o table | grep -i "total regional"
```

## Timing

- ARO cluster provisioning: 30-45 minutes
- No token expiry risk (Azure CLI sessions are long-lived)

## Non-TF Resources

Guides commonly create these resources outside Terraform:
- Storage accounts (for blob CSI, monitoring)
- Service principals and role assignments
- Key Vaults and secrets
- Helm releases (operators, CSI drivers)
- Azure Policy assignments

All must be deleted before `terraform destroy` — they block resource
group deletion.

## Known Issues

### Pull secret
A Red Hat pull secret is recommended but optional. Without it, access to
Red Hat container catalog images and OperatorHub entries is limited.

### Provider registration timing
Provider registration can take several minutes. The `--wait` flag handles
this, but scripts without it may fail with "provider not registered."
