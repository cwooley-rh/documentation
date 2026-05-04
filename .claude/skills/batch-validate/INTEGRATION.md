# Batch Validation Integration Guide

This document shows how the batch validation system integrates with existing skills and workflows.

## Current State Analysis

**22 open PRs** in rh-mobb/documentation as of 2026-05-04:
- **8 ROSA PRs**: Standard HCP cluster guides
- **7 ARO PRs**: Various ARO infrastructure and config guides  
- **1 OSD PR**: Documentation/educational content
- **6 Misc PRs**: Cross-platform or AI/ML guides

## Batch Strategy

### ROSA Batch 1: Standard HCP (us-east-1)
**PRs**: 920, 916, 911, 881, 866, 687, 615, 605  
**Infrastructure**: 1x ROSA HCP, 3x m5.xlarge workers  
**Duration**: ~6 hours  
**Cost**: ~$9 (vs $40 individual = 77% savings)

**Execution Groups** (based on conflict analysis):

**Group A - Low Conflict** (can share cluster with namespace cleanup):
- #916: Cognito IdP ✅ (already validated)
- #911: KMS validation (read-only)
- #866: Lightspeed Bedrock (namespace-scoped)
- #687: NLB + CloudFront (networking)

**Group B - Medium Conflict** (sequential with operator cleanup):
- #881: Quay (RDS, ElastiCache, S3)
- #920: (need to check content)

**Group C - Networking** (sequential, different NLB configs):
- #615: HCP public NLB
- #605: HCP private NLB

### ARO Batch 1: Standard (eastus)
**PRs**: 914, 908, 907, 889, 888, 689, 659  
**Infrastructure**: 1x ARO cluster, 3x Standard_D4s_v3  
**Duration**: ~5 hours  
**Cost**: ~$10 (vs $35 individual = 71% savings)

**Execution Groups**:

**Group A - Layered Dependencies**:
- #908: Quickstart + Federated Metrics (builds incrementally)
- #914: Add infra nodes (additive to #908)

**Group B - Storage/CSI**:
- #889: Azure Blob CSI (namespace-scoped)

**Group C - Review Only**:
- #888: Prerequisites doc (no cluster needed)
- #907: ARO checklist (likely review only)

**Group D - Sequential High-Conflict**:
- #659: Backup/restore OADP
- #689: Lightspeed (namespace-scoped)

### Misc/Cross-Platform PRs
**PRs**: 924, 923, 921, 909, 905, 668  

These need individual analysis:
- Check content paths to determine provider
- #909: Likely RHOAI (could batch with GPU cluster)
- #668: AI/ML vLLM (requires GPU)
- #905: Vault CSI (could attach to any batch)

---

## Integration with Existing Skills

### 1. Update `validate-pr` Skill

Add batch-mode support to skip infrastructure provisioning:

```bash
# Current (standalone validation)
/validate-pr 917

# New (batch mode)
/validate-pr 917 --batch-mode --cluster=cwooley-rosa-batch-1 --cleanup=namespace
```

**Changes to validate-pr/SKILL.md**:

```markdown
## Batch Mode

When validating as part of a batch, use `--batch-mode` to reuse infrastructure:

### Arguments

- `--batch-mode`: Skip Phase 2 (infrastructure provisioning)
- `--cluster=<name>`: Cluster name to reuse
- `--cleanup=<level>`: Cleanup level after validation (none|namespace|operator)
- `--batch-state=<path>`: Path to batch state JSON for checkpointing

### Example

```bash
export CLUSTER_NAME=cwooley-rosa-batch-1
export API_URL=https://api.xxxxx.openshiftapps.com:443
export ADMIN_PASSWORD=xxxxx

/validate-pr 917 \
  --batch-mode \
  --cluster=$CLUSTER_NAME \
  --cleanup=namespace \
  --batch-state=/tmp/rosa-batch-1-state.json
```

### Modified Workflow

- **Phase 1**: Same (PR analysis)
- **Phase 2**: SKIP (infrastructure already provisioned)
- **Phase 3**: Login to existing cluster, execute guide
- **Phase 4**: Post individual report to PR
- **Phase 5**: Update batch state, skip teardown
```

**validate-pr skill modifications**:

```python
# Pseudo-code for batch mode detection
if args.batch_mode:
    # Skip infrastructure provisioning
    cluster_name = args.cluster
    api_url = os.getenv('API_URL')
    admin_password = os.getenv('ADMIN_PASSWORD')
    
    # Login to existing cluster
    run(f"oc login {api_url} --username cluster-admin --password {admin_password}")
    
    # Execute guide (Phase 3)
    results = execute_guide(guide_path, cluster_name)
    
    # Cleanup based on level
    if args.cleanup == 'namespace':
        run(f"oc delete namespace pr-{pr_number}-test --ignore-not-found")
    elif args.cleanup == 'operator':
        cleanup_operators()
    
    # Update batch state
    update_batch_state(args.batch_state, pr_number, results)
    
    # Skip teardown (batch orchestrator handles it)
else:
    # Normal standalone validation
    provision_infrastructure()
    execute_guide()
    post_report()
    teardown_infrastructure()
```

---

### 2. Update `provision` Skill

Add batch naming convention support:

```bash
# Current
/provision rosa hcp us-east-1

# New (batch mode)
/provision rosa hcp us-east-1 --batch=rosa-batch-1
```

**Changes to provision/SKILL.md**:

```markdown
## Batch Mode

When provisioning for batch validation, use `--batch=<name>`:

```bash
/provision rosa hcp us-east-1 --batch=rosa-batch-1
```

This sets:
- Cluster name: `cwooley-<batch-name>`
- Terraform directory: `/tmp/terraform-<batch-name>`
- State file: `/tmp/<batch-name>-state.json`
```

---

### 3. Create `batch-validate` Skill

New skill that orchestrates multiple PR validations. See `batch-validate/SKILL.md`.

**Key features**:
- Reads batch definition from `batches/<batch-name>.yaml`
- Provisions shared infrastructure
- Iterates through PRs, running `/validate-pr` in batch mode
- Generates per-PR reports + batch summary
- Handles cleanup between PRs based on conflict level
- Checkpoints progress for resumability

---

## Workflow Example

### Manual Batch Execution (User-Driven)

```bash
# 1. Analyze open PRs
cd /Users/cwooley/projects/documentation
./.claude/skills/batch-validate/scripts/analyze-prs.sh

# 2. Review batch plan
cat .claude/skills/batch-validate/pr-batch-plan.md

# 3. User confirms batch to execute
# User: "Let's run rosa-batch-1"

# 4. Provision infrastructure
/provision rosa hcp us-east-1 --batch=rosa-batch-1
# → Creates cluster cwooley-rosa-batch-1
# → Terraform dir: /tmp/terraform-rosa-batch-1
# → Saves credentials to /tmp/rosa-batch-1-state.json

# 5. Export cluster credentials
export CLUSTER_NAME=cwooley-rosa-batch-1
export API_URL=$(rosa describe cluster -c $CLUSTER_NAME -o json | jq -r '.api.url')
export ADMIN_PASSWORD=$(cat /tmp/rosa-batch-1-state.json | jq -r '.admin_password')

# 6. Validate each PR in sequence
/validate-pr 916 --batch-mode --cluster=$CLUSTER_NAME --cleanup=namespace
# ✅ PASS, namespace deleted

/validate-pr 911 --batch-mode --cluster=$CLUSTER_NAME --cleanup=none
# ✅ PASS, read-only

/validate-pr 866 --batch-mode --cluster=$CLUSTER_NAME --cleanup=namespace
# ✅ PASS, namespace deleted

/validate-pr 687 --batch-mode --cluster=$CLUSTER_NAME --cleanup=namespace
# ⚠️ PASS with 1 issue, namespace deleted

# 7. Generate batch summary
cat > /tmp/rosa-batch-1-summary.md <<EOF
# Batch Summary: rosa-batch-1

- PRs validated: 4
- Passed: 4
- Cost: $5.62
- Duration: 3h 45m
- Savings: $13.38 vs individual
EOF

# 8. Teardown
cd /tmp/terraform-rosa-batch-1
terraform destroy -auto-approve
```

---

### Automated Batch Execution (Skill-Driven)

```bash
# User invokes batch skill
/batch-validate rosa-batch-1

# Claude:
# 1. Reads batches/rosa-batch-1.yaml
# 2. Provisions infrastructure via /provision
# 3. Loops through PRs:
#    for each PR:
#      - /validate-pr <PR> --batch-mode --cluster=... --cleanup=...
#      - Checkpoint state to /tmp/rosa-batch-1-state.json
# 4. Generates batch summary report
# 5. Asks user: "Teardown infrastructure? (yes/no)"
# 6. Destroys infrastructure if confirmed
```

---

## File Structure After Integration

```
.claude/
├── skills/
│   ├── provision/
│   │   ├── SKILL.md                 # ✏️ UPDATE: add --batch flag
│   │   └── references/
│   │       └── providers.md
│   ├── validate-pr/
│   │   ├── SKILL.md                 # ✏️ UPDATE: add batch mode section
│   │   └── references/
│   │       └── workflow.md
│   └── batch-validate/              # ✅ NEW SKILL
│       ├── SKILL.md                 # Main skill definition
│       ├── README.md                # Quick start guide
│       ├── INTEGRATION.md           # This file
│       ├── pr-batch-plan.md         # Current batch plan (2026-04-27)
│       ├── batches/
│       │   ├── rosa-batch-1.yaml    # Batch definitions
│       │   ├── rosa-batch-2.yaml
│       │   └── aro-batch-1.yaml
│       └── scripts/
│           ├── analyze-prs.sh       # Analyze open PRs
│           └── detect-conflicts.sh  # Conflict detection
├── shared/                          # ✅ FUTURE: shared utilities
│   ├── known-patterns.md            # Already exists
│   └── scripts/
│       └── extract-guide-steps.sh   # Already exists
└── products/                        # Already exists
    ├── rosa.md
    ├── aro.md
    └── osd-gcp.md
```

---

## Migration Path

### Phase 1: Create Infrastructure ✅ DONE
- Created `batch-validate` skill directory
- Created batch definition YAMLs (rosa-batch-1, rosa-batch-2, aro-batch-1)
- Created conflict detection script
- Created PR analysis script
- Created batch planning document

### Phase 2: Update Existing Skills (NEXT)
- Update `validate-pr/SKILL.md` to add batch mode section
- Update `provision/SKILL.md` to add batch naming convention
- Test batch mode flags manually before full integration

### Phase 3: Implement Orchestration
- Implement batch-validate skill orchestration logic
- Test sequential PR validation on shared cluster
- Validate cleanup levels work correctly
- Test checkpointing and resume

### Phase 4: Production Use
- Run first production batch (rosa-batch-1 or aro-batch-1)
- Document learnings and edge cases
- Refine conflict detection heuristics
- Automate batch plan generation

---

## Cost Comparison

### Current Approach (Individual Validation)
- 22 PRs × $5 avg per PR = **$110 total**
- 22 PRs × 45 min avg = **16.5 hours**
- 22 cluster provisions × 20 min = **7.3 hours provisioning**
- **Total time**: ~24 hours

### Batched Approach
- 3 batches × $10 avg per batch = **$30 total**
- 3 batches × 5 hours = **15 hours execution**
- 3 cluster provisions × 20 min = **1 hour provisioning**
- **Total time**: ~16 hours

**Savings**: $80 (73%) and 8 hours (33%)

If run in parallel (3 batches simultaneously):
- **Wall time**: ~6 hours (vs 24 hours sequential individual)
- **Savings**: 75% time reduction

---

## Next Steps

1. **Review this integration plan** with user
2. **Update validate-pr and provision skills** with batch mode support
3. **Test batch mode manually** with 2-3 PRs on shared cluster
4. **Run first production batch** (recommend rosa-batch-1 or aro-batch-1)
5. **Iterate and refine** based on real-world batch execution
6. **Automate batch planning** with ML-based conflict detection (future)

---

## Questions for User

1. **Approval to modify existing skills?** 
   - Add batch mode to `validate-pr/SKILL.md`
   - Add batch naming to `provision/SKILL.md`

2. **Preferred first batch to execute?**
   - rosa-batch-1 (8 PRs, $9, 6 hrs)
   - aro-batch-1 (7 PRs, $10, 5 hrs)
   - Custom batch (user specifies PRs)

3. **Parallel vs Sequential batch execution?**
   - Run 3 batches in parallel (faster, higher concurrency)
   - Run batches sequentially (simpler, easier to debug)

4. **Cleanup preferences?**
   - Conservative: operator-level cleanup between all PRs
   - Aggressive: namespace-level cleanup where possible (faster)
   - Manual: ask before each cleanup decision
