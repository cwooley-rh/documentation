# Review Checklist

Structured review criteria for documentation guides. Used by `/review-pr`
for static review and by `/validate-pr` during pre-execution scan. Each
item includes what to check and how to classify findings.

Cross-references `known-patterns.md` for frequency data from past
validation runs.

## Structure

### Cleanup section
- [ ] Guide has a cleanup/teardown section
- [ ] Cleanup removes every resource the guide creates
- [ ] Resource names in cleanup match the deploy steps exactly
- [ ] Cleanup includes: namespaces, operators, helm releases, CRDs,
      ClusterRoles/ClusterRoleBindings, cloud resources
- **Severity if missing:** Medium
- **Pattern frequency:** High (2 of 3 PRs — see known-patterns.md)

### Prerequisites
- [ ] Prerequisites list all required CLI tools
- [ ] Prerequisites link to installation instructions or version requirements
- [ ] Prerequisites state required cluster access level (cluster-admin, etc.)
- [ ] If guide depends on another guide, it links to it

### Section ordering
- [ ] Environment variables are set before they are used
- [ ] Dependencies are created before resources that reference them
- [ ] Operator is installed and ready before creating custom resources

## Variables

### Export statements
- [ ] All variable assignments intended for cross-step use include `export`
- [ ] Variables are set at the top of the guide or in a dedicated section
- **Severity if missing:** Medium

### Quoting
- [ ] Variables in cloud CLI commands are double-quoted (`"$VAR"` not `$VAR`)
- [ ] Note unquoted variables but only flag as failure if they break
- **Severity:** Low (most resource names have no spaces)

### Hardcoded values
- [ ] Resource names, regions, and project IDs use environment variables
- [ ] Users are told where to customize values
- [ ] No hardcoded cluster names, subscription IDs, or account numbers

## CLI Correctness

### Deprecated flags
- [ ] `az ad sp create-for-rbac --skip-assignment` — deprecated, remove it
- [ ] Check for other deprecated flags in `az`, `aws`, `rosa`, `gcloud`
- **Severity:** Medium

### Operator CSV versions
- [ ] Operator installations use dynamic CSV lookup, not hardcoded versions
- [ ] Pattern: `oc get csv -n <ns> -o name | grep <operator>`
- [ ] ClusterPolicy and other CRs extracted from CSV annotations, not pasted
- **Severity:** Medium

### Command accuracy
- [ ] Commands use correct resource names and API groups
- [ ] `oc wait` commands reference resources that actually exist
- [ ] Namespace flags match where resources were created

## Resource Naming

### Globally unique names
- [ ] Azure storage accounts, Key Vaults use unique or parameterized names
- [ ] Guide tells users to choose unique names or generates them
- [ ] Generic names like `aroblobsa` or `mykeyvault` are flagged
- **Severity:** Medium

### Cluster name references
- [ ] `<your-cluster-name>` or equivalent placeholder is consistent
- [ ] Guide explains how to find or set the cluster name

## Front Matter

### Required fields
- [ ] `date` in YYYY-MM-DD format
- [ ] `title` — concise, descriptive
- [ ] `tags` — from approved taxonomy (case-sensitive):
      AAP, ACM, ACS, ARO, DevSpaces, GitOps, GovCloud, IDP, Keycloak,
      Lightspeed, Maximo, OADP, Observability, OCM, ODF, OSD, Quickstarts,
      RHOAI, ROSA, ROSA Classic, ROSA HCP, Service Interconnect, Terraform,
      Virtualization
- [ ] `authors` — list of contributor names

### Optional fields
- [ ] `validated_version` — if set, do NOT add a separate version
      disclaimer alert in the body (the theme auto-displays it)
- [ ] `draft: true` — for unpublished content
- [ ] `aliases` — for URL redirects when moving content

## Links

### Internal cross-links
- [ ] Use root-relative paths starting with `/experts/`
- [ ] Do NOT use fully qualified `https://...` URLs for same-site links
- [ ] Do NOT use Netlify preview URLs

### External links
- [ ] URLs are valid and not behind authentication walls
- [ ] Documentation links point to versioned or stable URLs

## Style

### Em dashes
- [ ] No em dashes (`---`) in content — use commas, colons, parentheses,
      or split into separate sentences
- **This is a hard rule for this site**

### Shortcodes vs raw HTML
- [ ] Use Hugo shortcodes for alerts, notices, tabs, expandable sections
- [ ] Minimize raw HTML — Goldmark allows it but shortcodes are preferred
- [ ] Alert shortcodes: `{{</* alert state="info|warning|danger|success" */>}}`

### Code fences
- [ ] Code blocks use correct language labels (`bash`, `yaml`, `json`)
- [ ] Blocks labeled `json` or `js` must be valid (minify is enabled)

## Product-Specific Checks

### ARO
- [ ] Helm charts checked for RHCOS init container incompatibility
      (hostPath mounts of `/usr/local`, `/opt`)
- [ ] Azure providers registered before provisioning
- [ ] No `--skip-assignment` on SP creation
- [ ] Storage account names are unique or parameterized
- See `products/aro.md` for full ARO knowledge

### ROSA
- [ ] Token passed via `$(rosa token)`, not hardcoded in tfvars
- [ ] HCP used unless guide explicitly requires classic
- [ ] GPU machine pools have correct taints and labels
- [ ] Operator CSV versions use dynamic lookup
- See `products/rosa.md` for full ROSA knowledge

### RHOAI
- [ ] DSCI patched to disable ServiceMesh before DSC creation
- [ ] DSC created manually (operator no longer auto-creates)
- [ ] KServe set to Removed in DSC if not needed

### OSD / GCP
- [ ] Uses `gcloud` commands (not deprecated `gsutil`)
- [ ] References GCP project ID, not project name
- See `products/osd-gcp.md` for full OSD knowledge
