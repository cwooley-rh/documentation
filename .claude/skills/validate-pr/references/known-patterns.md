# Known Patterns

Recurring issues and lessons learned from validation testing. Check this
file during Phase 3 (execution) to anticipate problems, and update it
during Phase 5 (retrospective) with new findings.

## Common Documentation Issues

### Missing cleanup sections
**Frequency:** High (2 of 3 PRs tested)
**Seen in:** PR #899 (CloudWatch Agent), PR #908 (Federated Metrics)

Guides often include deployment steps but no teardown instructions. Left
behind resources include: IAM roles, CloudWatch log groups, helm releases,
namespaces, storage accounts, ClusterRoles/ClusterRoleBindings.

**During execution:** When you reach the end of a guide and there is no
cleanup section, flag it as a Medium-severity issue and write one in the
fix commit. Include teardown for every resource the guide created.

### Stale resource names in cleanup
**Frequency:** Medium
**Seen in:** PR #908 (Federated Metrics — referenced `federated-metrics-operators` chart that didn't exist)

Cleanup sections may reference old resource names from prior versions of
the guide that no longer match what was installed.

**During execution:** Cross-reference every cleanup command against the
actual resources created in the deploy steps. Check helm release names,
namespace names, and operator deployment names.

### Missing `export` on environment variables
**Frequency:** Medium
**Seen in:** PR #908 (ARO Quickstart — original guide had variables without `export`)

Variables set without `export` are not available to subshells or subsequent
commands run in separate shell invocations.

**During execution:** Check that all variable assignments intended for use
across steps include `export`.

### Unquoted variable references in commands
**Frequency:** Medium
**Seen in:** PR #908 (ARO Quickstart — `$AZR_RESOURCE_GROUP` vs `"$AZR_RESOURCE_GROUP"`)

Variables used in `az` or `aws` CLI commands should be double-quoted to
prevent word splitting on values containing spaces.

**During execution:** Note unquoted variables but don't flag as failures
unless they actually break (most resource names won't have spaces).

### Hardcoded image versions
**Frequency:** Low
**Seen in:** PR #899 (CloudWatch Agent — `amazon/cloudwatch-agent:1.300040.0b650`)

Container image tags may be outdated. Unless the guide breaks, note as
Info severity. Don't change image versions without testing the new one.

## Infrastructure Failure Modes

### ROSA token expiry during long provisions
**Frequency:** High with classic clusters, rare with HCP
**Seen in:** PR #899 (token expired during ~40 min classic provision)

OCM tokens expire after ~15 minutes. Classic ROSA clusters take 35-45 min
to provision, so the token always expires mid-create.

**Mitigation:** Use HCP clusters (default). If classic is required, check
cluster status via `rosa describe cluster -c <name>` after token failure.
The cluster likely completed. Re-run `terraform apply` with a fresh token
to sync state.

### Non-Terraform resources block `terraform destroy`
**Frequency:** High
**Seen in:** PR #908 (storage account created during federated-metrics
guide blocked resource group deletion), PR #899 (IAM role and CW log group
created outside Terraform)

Guides often create cloud resources (storage accounts, IAM roles, log
groups) that Terraform doesn't manage. These must be deleted before or
alongside `terraform destroy`.

**Mitigation:** During execution, track every cloud resource created
outside Terraform. Before teardown, delete these first. Consider adding
them to the Terraform config if feasible.

### Terraform directory corruption
**Frequency:** Low
**Seen in:** PR #899 (`/tmp/terraform-rosa` directory contents were
overwritten, losing `.tf` files but keeping state)

The `/tmp/terraform-*` directories can be clobbered by other processes or
by accidentally running commands in the wrong directory.

**Mitigation:** Back up `terraform.tfstate` before long operations. If
`.tf` files are lost but state remains, re-clone the repo and restore the
state file.

### DNS propagation delay after cluster ready
**Frequency:** Medium (ROSA HCP)
**Seen in:** PR #899 (cluster state was "ready" but DNS returned NXDOMAIN
for ~2 minutes)

ROSA reports the cluster as ready before DNS fully propagates. API URL
may not resolve immediately.

**Mitigation:** After cluster is "ready", wait for DNS resolution before
attempting `oc login`. Check with `nslookup` or retry with short delays.

## Execution Patterns

### OAuth proxy in front of web UIs
**Frequency:** Medium
**Seen in:** PR #908 (Grafana behind OpenShift OAuth proxy)

Some guides deploy UIs that end up behind an OpenShift OAuth proxy. API
calls with basic auth get 302 redirects to OAuth instead of responding.

**Impact:** Cannot verify dashboards/UI via curl with basic auth. Validate
by confirming the route returns 302, pods are running, and backing resources
(datasources, dashboards) are created correctly.

### Operator deployment names change across versions
**Frequency:** Medium
**Seen in:** PR #908 (Grafana operator deployment changed from
`grafana-operator-controller-manager` to `grafana-operator-controller-manager-v5`)

OLM-managed operators may change deployment names between versions.

**During execution:** If `oc rollout status` fails with NotFound, list
deployments in the namespace to find the actual name.

### DSCI/DSC ordering in RHOAI
**Frequency:** Specific to RHOAI guides
**Seen in:** PR #909 (ServiceMesh blocker prevented auto-creation of DSC)

RHOAI 2.25+ requires patching DSCI to disable ServiceMesh before the DSC
can be created manually. The operator no longer auto-creates a DSC.

**During execution:** For RHOAI guides, check if DSC exists after operator
install. If not, patch DSCI first, then create DSC manually with KServe
set to Removed.

### `sed -i` behaves differently on macOS
**Frequency:** Low
**Seen in:** PR #899 (guide uses `sed -i.bak` which is the macOS-safe
form, but leaves `.bak` files behind)

GNU `sed -i` and BSD `sed -i` have different syntax. The `.bak` suffix
form works on both but creates backup files.

**Impact:** Not a doc issue — the guide correctly uses the portable form.
Just be aware of leftover `.bak` files during testing.
