---
name: batch-validate
description: >-
  This skill should be used when the user asks to "batch validate PRs",
  "validate multiple PRs together", "run PR validations in batches",
  or wants to optimize infrastructure costs by testing multiple guides
  on shared clusters.
version: "0.1.0"
user-invocable: true
---

# Batch Validate

Validate multiple documentation PRs together by sharing infrastructure where
possible, reducing costs and provisioning time while maintaining test isolation.

## Invocation

```bash
/batch-validate <batch-name>           # Run predefined batch
/batch-validate plan                   # Analyze open PRs and propose batches
/batch-validate rosa-batch-1           # Run ROSA Batch 1 from plan
```

## Workflow

### Phase 0: Batch Planning (if `plan` argument)

Analyze open PRs and group them by infrastructure requirements.

```bash
gh pr list --repo rh-mobb/documentation --limit 50 \
  --json number,title,files,labels,author
```

For each PR:
1. Identify guide paths from `files` (content/**/*.md)
2. Detect provider from path (rosa/, aro/, osd/)
3. Analyze guide requirements:
   - Cluster type (HCP, classic, GPU, networking)
   - Operators installed (cluster-wide vs namespace-scoped)
   - External resources (S3, RDS, storage accounts)
   - Conflict potential (see Conflict Detection below)

Group PRs into batches where:
- Guides share the same provider and region
- Conflict levels allow shared infrastructure
- Total batch duration < 6 hours
- Estimated cost per batch < $15

Output batch plan per [pr-batch-plan.md](pr-batch-plan.md) template.

**Confirm with user before execution**.

---

### Phase 1: Infrastructure Provisioning

Provision shared infrastructure for the batch.

```bash
# Example: ROSA Batch 1
export BATCH_NAME=rosa-batch-1
export CLUSTER_NAME=cwooley-$BATCH_NAME
export AWS_REGION=us-east-1

git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git \
  /tmp/terraform-$BATCH_NAME

cd /tmp/terraform-$BATCH_NAME
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

Capture cluster credentials and store in batch state file:
```bash
cat > /tmp/${BATCH_NAME}-state.json <<EOF
{
  "batch_name": "$BATCH_NAME",
  "cluster_name": "$CLUSTER_NAME",
  "provider": "rosa",
  "region": "$AWS_REGION",
  "api_url": "$(rosa describe cluster -c $CLUSTER_NAME -o json | jq -r '.api.url')",
  "console_url": "$(rosa describe cluster -c $CLUSTER_NAME -o json | jq -r '.console.url')",
  "terraform_dir": "/tmp/terraform-$BATCH_NAME",
  "prs": [916, 911, 899, 917, 866],
  "status": "provisioned",
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

---

### Phase 2: Sequential PR Validation

For each PR in the batch, run validation using the shared cluster.

```bash
for PR in 916 911 899 917 866; do
  echo "=== Validating PR #$PR ==="
  
  # Fetch PR branch
  gh pr view $PR --repo rh-mobb/documentation \
    --json headRefName,headRepositoryOwner
  
  # Read guide from PR branch
  git fetch origin pull/$PR/head:pr-$PR
  git checkout pr-$PR
  
  # Execute guide steps (reusing cluster credentials)
  export CLUSTER=$CLUSTER_NAME
  oc login $API_URL --username cluster-admin --password $ADMIN_PASSWORD
  
  # Run validation (Phase 3 from validate-pr skill)
  validate_guide content/<path>/index.md
  
  # Capture results
  echo "$PR: $RESULT" >> /tmp/${BATCH_NAME}-results.txt
  
  # Cleanup between guides
  if [[ "$CLEANUP_LEVEL" == "namespace" ]]; then
    oc delete namespace pr-$PR-test --ignore-not-found
  elif [[ "$CLEANUP_LEVEL" == "operator" ]]; then
    cleanup_operators  # Delete CSVs, subscriptions, CRDs
  fi
  
  git checkout agentic-workflows  # return to base branch
done
```

**Cleanup Levels**:
- `none` — no cleanup, next guide builds on previous state (e.g., layered dependencies)
- `namespace` — delete test namespace, keep cluster-wide resources
- `operator` — delete operators and CRDs, reset to clean cluster state
- `full` — destroy and reprovision cluster (not recommended for batches)

**Checkpoint After Each PR**:
```bash
jq --arg pr "$PR" --arg status "$RESULT" \
  '.results += [{pr: $pr, status: $status, timestamp: now}]' \
  /tmp/${BATCH_NAME}-state.json > /tmp/${BATCH_NAME}-state.tmp
mv /tmp/${BATCH_NAME}-state.tmp /tmp/${BATCH_NAME}-state.json
```

---

### Phase 3: Report Generation

Generate individual reports per PR and a batch summary report.

**Per-PR Reports**: Same format as `validate-pr` skill, posted as PR comments.

**Batch Summary Report**:
```markdown
# Batch Validation Summary: rosa-batch-1

**Date**: 2026-04-27  
**Cluster**: cwooley-rosa-batch-1  
**Region**: us-east-1  
**Duration**: 3h 45m  
**Cost**: $5.62  

## Results

| PR | Guide | Status | Issues | Report |
|----|-------|--------|--------|--------|
| #916 | cognito-idp | ✅ PASS | 0 | [link](#916) |
| #911 | kms | ✅ PASS | 0 | [link](#911) |
| #899 | metrics-cloudwatch | ⚠️ PASS | 1 minor | [link](#899) |
| #917 | metrics-prometheus | ✅ PASS | 0 | [link](#917) |
| #866 | lightspeed-bedrock | ❌ FAIL | 1 blocker | [link](#866) |

## Summary

- **Total PRs**: 5
- **Passed**: 4
- **Failed**: 1
- **Cost Savings**: $18.38 (vs individual testing)

## Infrastructure

- **Provider**: AWS (ROSA HCP)
- **Cluster Version**: 4.21.9
- **Workers**: 3x m5.xlarge
- **Terraform**: /tmp/terraform-rosa-batch-1

## Next Steps

1. Fix PR #866 blocker issue (Bedrock API key configuration)
2. Re-run #866 individually after fix
3. Approve PRs #916, #911, #899, #917
```

---

### Phase 4: Teardown

Destroy shared infrastructure after all validations complete.

```bash
# Confirm with user first
read -p "Teardown batch infrastructure? (yes/no): " CONFIRM

if [[ "$CONFIRM" == "yes" ]]; then
  cd /tmp/terraform-$BATCH_NAME
  terraform destroy -auto-approve
  
  # Update batch state
  jq '.status = "destroyed" | .end_time = now' \
    /tmp/${BATCH_NAME}-state.json > /tmp/${BATCH_NAME}-state.tmp
  mv /tmp/${BATCH_NAME}-state.tmp /tmp/${BATCH_NAME}-state.json
  
  echo "Batch $BATCH_NAME infrastructure destroyed."
fi
```

---

## Conflict Detection

### Conflict Levels

**HIGH** — Requires dedicated cluster or sequential execution with full cleanup:
- Cluster-wide operators (GPU, Service Mesh, storage)
- CRDs that may clash
- Networking changes (CNI, ingress controllers)
- Cluster-level encryption (KMS, FIPS)

**MEDIUM** — Can share cluster with namespace isolation or sequential execution:
- Namespace-scoped operators
- Application deployments
- Storage CSI drivers (different storage classes)

**LOW** — Easily shareable, minimal cleanup needed:
- Metrics/observability integrations (export data, no state)
- Identity provider configurations (additive)
- Read-only validation guides

### Conflict Detection Script

```bash
#!/bin/bash
# .claude/skills/batch-validate/scripts/detect-conflicts.sh

detect_conflicts() {
  local guide_a=$1
  local guide_b=$2
  
  conflicts=""
  
  # Check for cluster-wide operators
  ops_a=$(grep -E "kind: Subscription|kind: ClusterServiceVersion" "$guide_a" | wc -l)
  ops_b=$(grep -E "kind: Subscription|kind: ClusterServiceVersion" "$guide_b" | wc -l)
  
  if [[ $ops_a -gt 0 && $ops_b -gt 0 ]]; then
    conflicts+="Both install operators (HIGH conflict)\n"
  fi
  
  # Check for CRDs
  crds_a=$(grep -E "kind: CustomResourceDefinition" "$guide_a" | wc -l)
  crds_b=$(grep -E "kind: CustomResourceDefinition" "$guide_b" | wc -l)
  
  if [[ $crds_a -gt 0 && $crds_b -gt 0 ]]; then
    conflicts+="Both define CRDs (MEDIUM conflict)\n"
  fi
  
  # Check for GPU requirements
  gpu_a=$(grep -E "nvidia.com/gpu|gpu-operator|g4dn\.|p3\." "$guide_a" | wc -l)
  gpu_b=$(grep -E "nvidia.com/gpu|gpu-operator|g4dn\.|p3\." "$guide_b" | wc -l)
  
  if [[ $gpu_a -gt 0 && $gpu_b -gt 0 ]]; then
    conflicts+="Both require GPU (HIGH conflict - single GPU node)\n"
  fi
  
  # Check for namespace scope
  ns_a=$(grep -E "namespace:" "$guide_a" | sort -u | wc -l)
  ns_b=$(grep -E "namespace:" "$guide_b" | sort -u | wc -l)
  
  if [[ $ns_a -gt 1 || $ns_b -gt 1 ]]; then
    conflicts+="Multi-namespace resources (MEDIUM conflict)\n"
  fi
  
  if [[ -z "$conflicts" ]]; then
    echo "LOW - Guides can run in parallel"
  else
    echo -e "$conflicts"
  fi
}

# Usage: detect-conflicts.sh guide1.md guide2.md
detect_conflicts "$1" "$2"
```

---

## Batch Definitions

Batch configurations live in `batches/<batch-name>.yaml`:

```yaml
# batches/rosa-batch-1.yaml
name: rosa-batch-1
provider: rosa
region: us-east-1
cluster_type: hcp
workers:
  count: 3
  instance_type: m5.xlarge

prs:
  - number: 916
    guide: content/rosa/cognito-idp/index.md
    cleanup_level: namespace
    estimated_duration: 45m
    
  - number: 911
    guide: content/rosa/kms/index.md
    cleanup_level: none  # read-only
    estimated_duration: 30m
    
  - number: 899
    guide: content/rosa/metrics-to-cloudwatch-agent/index.md
    cleanup_level: namespace
    estimated_duration: 50m
    
  - number: 917
    guide: content/rosa/cluster-metrics-to-aws-prometheus/index.md
    cleanup_level: namespace
    estimated_duration: 60m
    depends_on: [899]  # both export metrics, can coexist
    
  - number: 866
    guide: content/rosa/lightspeed-bedrock/index.md
    cleanup_level: namespace
    estimated_duration: 40m

total_estimated_duration: 4h
total_estimated_cost: $6.00
```

---

## Integration with validate-pr

The `validate-pr` skill gains batch-mode support:

```bash
/validate-pr 917 \
  --batch-mode \
  --cluster=cwooley-rosa-batch-1 \
  --cleanup=namespace \
  --batch-state=/tmp/rosa-batch-1-state.json
```

**New Parameters**:
- `--batch-mode`: Skip infrastructure provisioning, use existing cluster
- `--cluster=<name>`: Cluster name to reuse
- `--cleanup=<level>`: Cleanup level after validation (none, namespace, operator)
- `--batch-state=<path>`: Path to batch state JSON for checkpointing

**Modified Behavior**:
- Phase 2 (Infrastructure): Skip if `--batch-mode` enabled
- Phase 3 (Execution): Login to existing cluster from `--cluster` arg
- Phase 4 (Report): Include batch context in report
- Phase 5 (Retrospective): Update batch state file

---

## Guard Rails

1. **Always confirm batch plan** before provisioning infrastructure
2. **Show total estimated cost** across all PRs in batch
3. **Checkpoint after each PR** — batch can be resumed if interrupted
4. **Independent PR reports** — each PR gets individual report + comment
5. **Conflict warnings** — alert user if batching high-conflict guides
6. **Rollback support** — if PR N fails, can skip and continue with PR N+1
7. **Manual override** — user can force cleanup level or skip a PR
8. **State persistence** — batch state survives session restarts

---

## Parallel Batches

Multiple batches can run in parallel using git worktrees and separate Terraform directories:

```bash
# Terminal 1: ROSA Batch 1
cd .worktrees/rosa-batch-1
claude --model sonnet -p "/batch-validate rosa-batch-1"

# Terminal 2: ARO Batch 1  
cd .worktrees/aro-batch-1
claude --model sonnet -p "/batch-validate aro-batch-1"

# Terminal 3: ROSA Batch 2 (GPU, different region)
cd .worktrees/rosa-batch-2
claude --model sonnet -p "/batch-validate rosa-batch-2"
```

**Setup**:
```bash
# Create worktrees
git worktree add .worktrees/rosa-batch-1 agentic-workflows
git worktree add .worktrees/aro-batch-1 agentic-workflows
git worktree add .worktrees/rosa-batch-2 agentic-workflows

# Clone Terraform repos
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git \
  /tmp/terraform-rosa-batch-1
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git \
  /tmp/terraform-rosa-batch-2
git clone --depth=1 https://github.com/rh-mobb/terraform-aro.git \
  /tmp/terraform-aro-batch-1
```

---

## Cost Tracking

Track costs per batch and aggregate across all batches:

```bash
# After batch completion
cat > /tmp/batch-cost-summary.json <<EOF
{
  "batches": [
    {
      "name": "rosa-batch-1",
      "provider": "aws",
      "cost": 6.00,
      "duration_hours": 4,
      "prs_validated": 5
    },
    {
      "name": "rosa-batch-2", 
      "provider": "aws",
      "cost": 6.00,
      "duration_hours": 5,
      "prs_validated": 3
    },
    {
      "name": "aro-batch-1",
      "provider": "azure",
      "cost": 8.00,
      "duration_hours": 4,
      "prs_validated": 4
    }
  ],
  "total_cost": 20.00,
  "total_prs": 12,
  "cost_per_pr": 1.67,
  "savings_vs_individual": 40.00
}
EOF
```

---

## Example Execution

```bash
# User initiates batch validation
$ /batch-validate plan

# Claude analyzes open PRs, outputs:
# - 6 batches proposed
# - Total cost: $39.60
# - Total PRs: 18
# - Estimated time: 25 hours (can run 3 batches in parallel = ~9 hours wall time)

# User approves ROSA Batch 1
$ /batch-validate rosa-batch-1

# Claude:
# 1. Provisions ROSA HCP cluster in us-east-1
# 2. Validates PRs 916, 911, 899, 917, 866 sequentially
# 3. Posts individual reports to each PR
# 4. Generates batch summary report
# 5. Asks user: "Teardown infrastructure? (yes/no)"
# 6. User confirms, cluster destroyed

# Batch complete, move to next batch or parallel execution
```

---

## Future Enhancements

1. **Auto-batch scheduling**: Analyze PRs daily, auto-generate batch plans
2. **Cost prediction API**: Query AWS/Azure pricing APIs for accurate estimates
3. **Batch resume**: If batch fails mid-execution, resume from checkpoint
4. **Conflict ML model**: Train model to predict guide conflicts from content
5. **Batch optimization**: Genetic algorithm to find optimal batch groupings
6. **Real-time dashboards**: Web UI showing batch progress, costs, results
7. **Slack integration**: Post batch summaries to team channel
