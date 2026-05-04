# PR Batch Validation Plan

**Generated**: 2026-04-27  
**Total Open PRs**: 26  
**Actionable PRs**: ~18 (excluding docs-only/config changes)

---

## Batching Strategy

### Principles

1. **Infrastructure Sharing**: Multiple guides that don't conflict can share a cluster
2. **Resource Isolation**: Guides that install operators/CRDs get dedicated clusters or run sequentially with cleanup between
3. **Region Spreading**: GPU workloads spread across regions to avoid quota limits
4. **Cost Optimization**: Batch guides by infrastructure requirements to minimize cluster provisioning
5. **Conflict Detection**: Identify guides that modify cluster state in incompatible ways

### Conflict Categories

**High Conflict** (needs dedicated cluster or sequential execution):
- Cluster-wide operators (Service Mesh, GPU Operator, Trident)
- CRDs that may clash
- Cluster-level configurations (KMS, networking changes)

**Medium Conflict** (can share if run in different namespaces):
- Namespace-scoped operators
- Application deployments
- Storage CSI drivers (if different storage classes)

**Low Conflict** (easily shareable):
- Metrics/observability integrations
- Identity provider configurations
- Read-only validation guides

---

## Batch Groups

### ROSA Batch 1: Standard HCP Cluster (us-east-1)
**Infrastructure**: 1x ROSA HCP, 3x m5.xlarge workers  
**Estimated Cost**: $1.50/hr × 4 hrs = $6.00  
**PRs**: 5 guides, low conflict

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #916 | cognito-idp | Low | IdP config, already validated |
| #911 | kms | Medium | Cluster-wide but read-only validation |
| #899 | metrics-to-cloudwatch-agent | Low | Metrics export, namespace-scoped |
| #917 | cluster-metrics-to-aws-prometheus | Low | Metrics federation, compatible with #899 |
| #866 | lightspeed-bedrock | Medium | Namespace-scoped, may need API keys |

**Execution Order**:
1. #916 (Cognito IdP) — test identity, cleanup users
2. #917 + #899 (metrics guides) — can run in parallel, both export metrics
3. #911 (KMS) — read-only validation of encryption
4. #866 (Lightspeed) — namespace-scoped, run last

**Shared Setup**:
```bash
export CLUSTER_NAME=cwooley-batch-rosa-1
export AWS_REGION=us-east-1
terraform -chdir=/tmp/terraform-rosa-batch1 apply
```

---

### ROSA Batch 2: GPU Cluster (us-east-2)
**Infrastructure**: 1x ROSA HCP, 2x m5.xlarge + 1x g4dn.xlarge  
**Estimated Cost**: $1.20/hr × 5 hrs = $6.00  
**PRs**: 3 guides, high conflict due to GPU operator

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #912 | gpu (OpenShift AI) | High | GPU Operator, RHOAI, already validated |
| #668 | vllm-transcription-webapp | High | Requires GPU, may conflict with #912 operator versions |
| #909 | rhoai-s3 | Medium | RHOAI + S3, could share with #912 if compatible |

**Execution Strategy**: Sequential with operator cleanup between guides
1. #912 (GPU + RHOAI) — full validation
2. Cleanup: Delete GPU Operator, RHOAI operator
3. #668 (vLLM) — install fresh GPU stack
4. Cleanup: Delete GPU Operator
5. #909 (RHOAI + S3) — reinstall RHOAI, test S3 integration

**Alternative**: Run #909 and #912 together (both use RHOAI), then #668 separately.

---

### ROSA Batch 3: HCP Networking Cluster (ca-central-1)
**Infrastructure**: 1x ROSA HCP, private subnet + NLB  
**Estimated Cost**: $1.20/hr × 3 hrs = $3.60  
**PRs**: 3 guides, low conflict

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #615 | hcp-public-nlb | Low | NLB config, networking |
| #605 | hcp-private-nlb | Low | Compatible with #615, different NLB config |
| #687 | nlb-cf-vpco | Medium | NLB + CloudFront, can share infrastructure |

**Execution Order**: Sequential, each creates different NLB configuration
1. #615 (public NLB) — validate, document NLB ID
2. #605 (private NLB) — different subnet/NLB, no conflict
3. #687 (NLB + CloudFront) — builds on NLB knowledge

---

### ROSA Batch 4: Quay + Service Mesh (us-west-2)
**Infrastructure**: 1x ROSA HCP, 3x m5.xlarge  
**Estimated Cost**: $1.50/hr × 4 hrs = $6.00  
**PRs**: 2 guides, high conflict

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #881 | quay (S3, RDS, ElastiCache) | High | External AWS resources, cluster-wide |
| #891 | service-mesh (OSSM 3) | High | Cluster-wide operator, Gateway API |

**Execution Strategy**: Sequential with cleanup
1. #881 (Quay) — provisions RDS, ElastiCache, S3; test Quay deployment
2. Cleanup: Delete Quay operator, external resources
3. #891 (Service Mesh) — install OSSM 3, test Gateway API

---

### ARO Batch 1: Standard Cluster (eastus)
**Infrastructure**: 1x ARO cluster, 3x Standard_D4s_v3  
**Estimated Cost**: $2.00/hr × 4 hrs = $8.00  
**PRs**: 4 guides, medium conflict

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #908 | quickstart + federated-metrics | Medium | Quickstart = baseline, metrics = additive |
| #914 | add-infra-nodes | Medium | Adds nodes, doesn't conflict |
| #889 | blob-storage-csi | Medium | Azure Blob CSI, namespace-scoped |
| #888 | prereq-list | None | Documentation only, no cluster needed |

**Execution Order**:
1. #908 (Quickstart) — establish baseline cluster, then federated-metrics on top
2. #914 (Infra nodes) — add infrastructure nodes, verify scheduling
3. #889 (Blob CSI) — install CSI driver, test blob storage
4. #888 — review only, no execution

---

### ARO Batch 2: Storage & Backup Cluster (westus2)
**Infrastructure**: 1x ARO cluster, 3x Standard_D4s_v3  
**Estimated Cost**: $2.00/hr × 5 hrs = $10.00  
**PRs**: 4 guides, high conflict

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #880 | trident (NetApp storage) | High | Cluster-wide storage operator |
| #872 | backup-restore (OADP) | High | Cluster-wide backup, Azure Storage |
| #659 | backup-restore (reference link) | Low | Doc update to #872 |
| #689 | lightspeed | Medium | Namespace-scoped |

**Execution Strategy**: Sequential with cleanup
1. #880 (Trident) — install NetApp Trident, test storage provisioning, cleanup
2. #872 + #659 (OADP backup) — install OADP, test backup/restore with Azure Storage
3. Cleanup: Remove OADP
4. #689 (Lightspeed) — namespace-scoped, run last

---

### OSD Batch: GCP Documentation Review
**Infrastructure**: None (educational content)  
**Estimated Cost**: $0  
**PRs**: 1 guide

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #892 | osd-google-sre-access | None | Documentation on how Red Hat SREs access OSD |

**Execution**: Review only, no cluster needed. Validate accuracy of WIF/PSC descriptions.

---

### Misc Batch: Cross-Platform Guides
**Infrastructure**: Varies or none  
**PRs**: 2 guides

| PR | Guide | Conflict Level | Notes |
|----|-------|----------------|-------|
| #918 | cloud-services-workload-best-practices | None | Best practices doc, no cluster needed |
| #905 | secrets-store-csi (HashiCorp Vault) | High | Needs cluster (ROSA or ARO), Vault instance |

**Strategy**:
- #918: Review only
- #905: Attach to ROSA Batch 1 or ARO Batch 1, run last after other guides complete

---

## Batch Execution Timeline

### Week 1: ROSA Focus
- **Monday**: ROSA Batch 1 (5 guides, 4 hrs)
- **Tuesday**: ROSA Batch 3 (3 guides, 3 hrs)
- **Wednesday**: ROSA Batch 4 (2 guides, 4 hrs)
- **Thursday**: ROSA Batch 2 (3 guides, 5 hrs) — GPU cluster
- **Friday**: Retrospective, update skills

### Week 2: ARO Focus  
- **Monday**: ARO Batch 1 (4 guides, 4 hrs)
- **Tuesday**: ARO Batch 2 (4 guides, 5 hrs)
- **Wednesday**: Misc reviews (#918, #892, #905)
- **Thursday**: Fix commits, PR comments, follow-ups
- **Friday**: Final retrospective, skill updates

---

## Infrastructure Reuse Patterns

### Pattern 1: Sequential on Shared Cluster
**When**: Guides have medium conflict but don't need full cluster rebuild
```bash
# Guide 1
test_guide_1
cleanup_namespace
delete_operators

# Guide 2  
test_guide_2
cleanup_namespace
```

### Pattern 2: Parallel in Separate Namespaces
**When**: Guides are namespace-scoped with no cluster-wide changes
```bash
# Terminal 1
export NAMESPACE=pr-917-test
test_guide_917

# Terminal 2 (same cluster)
export NAMESPACE=pr-899-test
test_guide_899
```

### Pattern 3: Layered Dependencies
**When**: Later guide builds on earlier guide's setup
```bash
# Guide 1: Quickstart (provisions cluster, basic config)
test_quickstart

# Guide 2: Federated Metrics (adds to cluster from Guide 1)
test_federated_metrics  # reuses cluster from quickstart
```

---

## Cost Estimates

| Batch | Provider | Duration | Cost/hr | Total |
|-------|----------|----------|---------|-------|
| ROSA Batch 1 | AWS | 4 hrs | $1.50 | $6.00 |
| ROSA Batch 2 | AWS | 5 hrs | $1.20 | $6.00 |
| ROSA Batch 3 | AWS | 3 hrs | $1.20 | $3.60 |
| ROSA Batch 4 | AWS | 4 hrs | $1.50 | $6.00 |
| ARO Batch 1 | Azure | 4 hrs | $2.00 | $8.00 |
| ARO Batch 2 | Azure | 5 hrs | $2.00 | $10.00 |
| **Total** | | **25 hrs** | | **$39.60** |

**Savings vs Individual**: ~60% cost reduction
- Individual testing: 18 PRs × $5 avg = $90
- Batched testing: $39.60
- **Savings**: $50.40

---

## Conflict Detection Algorithm

```python
def detect_conflicts(guide_a, guide_b):
    """
    Determine if two guides can run on the same cluster
    """
    conflicts = []
    
    # Cluster-wide operators conflict
    if guide_a.installs_operator and guide_b.installs_operator:
        if guide_a.operator_name == guide_b.operator_name:
            conflicts.append("Same operator, different versions")
        else:
            conflicts.append("Multiple cluster-wide operators")
    
    # CRD conflicts
    if set(guide_a.crds) & set(guide_b.crds):
        conflicts.append("Overlapping CRD definitions")
    
    # Namespace conflicts
    if guide_a.namespace == guide_b.namespace and not guide_a.namespace_scoped:
        conflicts.append("Non-namespaced resources in same namespace")
    
    # Resource quota conflicts
    if guide_a.requires_gpu and guide_b.requires_gpu:
        conflicts.append("Both require GPU (single GPU node)")
    
    return conflicts

def can_run_parallel(guide_a, guide_b):
    """True if guides can run simultaneously"""
    return (
        len(detect_conflicts(guide_a, guide_b)) == 0 and
        guide_a.namespace_scoped and
        guide_b.namespace_scoped
    )

def can_run_sequential(guide_a, guide_b):
    """True if guide_b can run after guide_a with cleanup"""
    conflicts = detect_conflicts(guide_a, guide_b)
    # Even with conflicts, sequential works if cleanup is possible
    return guide_a.has_cleanup_section
```

---

## Integration Points

### 1. Update `validate-pr` Skill
Add `--batch-mode` flag and cluster reuse logic:
```bash
/validate-pr 917 --batch-mode --cluster=cwooley-batch-rosa-1
```

### 2. Create `batch-validate` Skill
New skill that orchestrates multiple PR validations:
```bash
/batch-validate rosa-batch-1  # validates PRs 916,911,899,917,866
```

### 3. Update `provision` Skill
Add batch naming convention:
```bash
/provision rosa hcp us-east-1 --batch-name=rosa-batch-1
```

---

## Guard Rails

1. **Always confirm batch plan with user before provisioning**
2. **Show estimated total cost across all batches**
3. **Checkpoint after each guide**: save results, allow continuation if one fails
4. **Independent teardown**: each batch can be torn down independently
5. **Conflict warnings**: alert if batching guides that may interfere
6. **Rollback support**: if guide N fails, can continue with guide N+1 after cleanup

---

## Next Steps

1. **Review this plan** with user for approval
2. **Create batch-validate skill** with orchestration logic
3. **Update validate-pr skill** to support `--batch-mode` and `--cluster` args
4. **Update provision skill** to support batch naming conventions
5. **Create conflict detection utility** to analyze guide requirements
6. **Build batch execution dashboard** to track progress across batches
