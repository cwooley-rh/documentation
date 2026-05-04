# Open PR Batch Analysis - 2026-05-04

**Total Open PRs**: 23  
**Analysis Date**: 2026-05-04 19:10 UTC  
**Repository**: rh-mobb/documentation

---

## PR Categorization

### ROSA PRs (11)
- #925 - private-ingress-controller-with-alb (images + guide update)
- #920 - cluster-metrics-to-aws-prometheus (metrics federation)
- #916 - cognito-idp ✅ **VALIDATED** (identity)
- #911 - kms (encryption, read-only)
- #909 - rhoai-s3 (RHOAI + S3 integration)
- #881 - quay (S3, RDS, ElastiCache)
- #866 - lightspeed-bedrock ❌ **BLOCKED** (AI, namespace issue)
- #687 - nlb-cf-vpco (NLB + CloudFront)
- #668 - vllm-transcription-webapp (GPU, AI/ML)
- #615 - hcp-public-nlb (networking)
- #605 - hcp-private-nlb (networking)

### ARO PRs (7)
- #914 - add-infra-nodes (infrastructure)
- #908 - quickstart + federated-metrics (baseline + metrics)
- #907 - checklist (docs/review)
- #889 - blob-storage-csi (Azure Blob storage)
- #888 - prereq-list (docs only)
- #689 - lightspeed (AI assistant)
- #659 - backup-restore (doc link addition)

### OSD PRs (1)
- #892 - osd-google-sre-access (educational docs)

### Cross-Platform/Misc (4)
- #924 - otel-instead-of-clf (observability, OpenTelemetry)
- #923 - acm-observability-rosa (ACM observability)
- #921 - rhoai-rosa-s3 (RHOAI + S3, appears to duplicate #909)
- #905 - secrets-store-csi/hashicorp-vault (Vault CSI)

---

## Conflict Analysis

### High Conflict (Cluster-wide operators, CRDs)
- #909, #921 - RHOAI operator (both appear to be same guide)
- #881 - Quay operator + external resources (RDS, ElastiCache)
- #668 - vLLM + GPU operator
- #866 - Lightspeed operator (BLOCKED)
- #689 - Lightspeed operator (ARO)
- #905 - Secrets Store CSI + Vault
- #889 - Azure Blob CSI

### Medium Conflict (Namespace-scoped, metrics)
- #920 - Prometheus federation (namespace-scoped)
- #923 - ACM observability (multi-namespace)
- #924 - OpenTelemetry (namespace-scoped)
- #914 - Infra nodes (additive)

### Low Conflict (Docs, networking, read-only)
- #925 - Ingress controller config (updates existing)
- #916 - Cognito IdP ✅ VALIDATED
- #911 - KMS (read-only validation)
- #908 - ARO quickstart + federated metrics (layered)
- #907 - ARO checklist (docs only)
- #888 - ARO prereq-list (docs only)
- #892 - OSD SRE access (docs only)
- #659 - ARO backup link (docs only)
- #687, #615, #605 - NLB configs (networking)

---

## Proposed Batches (Optimized)

### Batch 1: ROSA Standard + Metrics (Low Conflict)
**Infrastructure**: 1x ROSA HCP, 3x m5.xlarge, us-east-1  
**Duration**: ~4 hours  
**Cost**: ~$6  
**PRs**: 5

| PR | Guide | Conflict | Duration | Cleanup |
|----|-------|----------|----------|---------|
| #916 | cognito-idp | LOW | 45m | namespace |
| #911 | kms | LOW | 30m | none (read-only) |
| #920 | cluster-metrics-prometheus | MEDIUM | 60m | namespace |
| #925 | private-ingress-controller-alb | MEDIUM | 50m | config |
| #687 | nlb-cf-vpco | MEDIUM | 45m | namespace |

**Execution Order**:
1. #916 (Cognito IdP) - already validated, SKIP or re-test
2. #911 (KMS) - read-only validation
3. #920 (Metrics) - namespace-scoped
4. #925 (Ingress controller) - config changes
5. #687 (NLB + CloudFront) - networking

**Estimated**: $6, 4 hours, 5 PRs validated

---

### Batch 2: ROSA Networking (Low Conflict)
**Infrastructure**: 1x ROSA HCP, 3x m5.xlarge, ca-central-1  
**Duration**: ~3 hours  
**Cost**: ~$4.50  
**PRs**: 2

| PR | Guide | Conflict | Duration | Cleanup |
|----|-------|----------|----------|---------|
| #615 | hcp-public-nlb | LOW | 45m | config |
| #605 | hcp-private-nlb | LOW | 45m | config |

**Execution Order**:
1. #615 (Public NLB) - create public NLB config
2. #605 (Private NLB) - create private NLB config

**Estimated**: $4.50, 3 hours, 2 PRs validated

---

### Batch 3: ROSA High-Conflict Apps (Sequential)
**Infrastructure**: 1x ROSA HCP, 3x m5.xlarge, us-east-2  
**Duration**: ~5 hours  
**Cost**: ~$7.50  
**PRs**: 2

| PR | Guide | Conflict | Duration | Cleanup |
|----|-------|----------|----------|---------|
| #881 | quay | HIGH | 90m | operator + AWS resources |
| #905 | secrets-store-csi/vault | HIGH | 60m | operator |

**Execution Order**:
1. #881 (Quay) - install Quay, provision RDS/ElastiCache, test
2. Full cleanup - delete Quay operator, RDS, ElastiCache
3. #905 (Vault CSI) - install CSI driver, Vault instance, test

**Estimated**: $7.50, 5 hours, 2 PRs validated

---

### Batch 4: ROSA GPU + AI/ML (High Conflict)
**Infrastructure**: 1x ROSA HCP, 2x m5.xlarge + 1x g4dn.xlarge, us-west-2  
**Duration**: ~5 hours  
**Cost**: ~$6.50  
**PRs**: 2

| PR | Guide | Conflict | Duration | Cleanup |
|----|-------|----------|----------|---------|
| #909 or #921 | rhoai-s3 | HIGH | 90m | operator |
| #668 | vllm-transcription | HIGH | 90m | operator + GPU stack |

**Execution Order**:
1. #909 (RHOAI + S3) - install RHOAI, configure S3, test workbench
2. Full cleanup - delete RHOAI operator
3. #668 (vLLM) - install GPU operator + vLLM, test inference

**Note**: #921 and #909 appear to be the same guide (rhoai-rosa-s3). Verify and test only one.

**Estimated**: $6.50, 5 hours, 2 PRs validated

---

### Batch 5: ARO Standard (Layered)
**Infrastructure**: 1x ARO cluster, 3x Standard_D4s_v3, eastus  
**Duration**: ~5 hours  
**Cost**: ~$10  
**PRs**: 4

| PR | Guide | Conflict | Duration | Cleanup |
|----|-------|----------|----------|---------|
| #908 | quickstart + federated-metrics | MEDIUM | 90m | namespace |
| #914 | add-infra-nodes | MEDIUM | 60m | none (additive) |
| #889 | blob-storage-csi | MEDIUM | 60m | namespace |
| #689 | lightspeed | HIGH | 60m | operator |

**Execution Order**:
1. #908 (Quickstart + Federated Metrics) - establish baseline, add metrics
2. #914 (Add Infra Nodes) - expand cluster with infrastructure nodes
3. #889 (Blob CSI) - install Azure Blob CSI driver
4. #689 (Lightspeed) - install Lightspeed operator (namespace-scoped)

**Estimated**: $10, 5 hours, 4 PRs validated

---

### Batch 6: ARO Docs-Only (No Cluster)
**Infrastructure**: None  
**Duration**: ~1 hour  
**Cost**: $0  
**PRs**: 3

| PR | Guide | Validation Type | Duration |
|----|-------|-----------------|----------|
| #907 | aro-checklist | Review | 15m |
| #888 | aro-prereq-list | Review | 15m |
| #659 | aro-backup-restore | Review link | 15m |

**Execution**: Review-only, no cluster needed. Validate:
- Documentation accuracy
- Link validity
- Prerequisites completeness
- Formatting

**Estimated**: $0, 1 hour, 3 PRs reviewed

---

### Batch 7: Cross-Platform Observability
**Infrastructure**: 1x ROSA HCP, 3x m5.xlarge, us-east-1 (can reuse Batch 1 cluster)  
**Duration**: ~3 hours  
**Cost**: ~$4.50  
**PRs**: 2

| PR | Guide | Conflict | Duration | Cleanup |
|----|-------|----------|----------|---------|
| #924 | otel-instead-of-clf | MEDIUM | 60m | namespace |
| #923 | acm-observability-rosa | MEDIUM | 90m | namespace |

**Execution Order**:
1. #924 (OpenTelemetry) - install OTel operator, configure collectors
2. #923 (ACM Observability) - install ACM, configure observability

**Estimated**: $4.50, 3 hours, 2 PRs validated

---

### Batch 8: OSD Educational (No Cluster)
**Infrastructure**: None  
**Duration**: 30 minutes  
**Cost**: $0  
**PRs**: 1

| PR | Guide | Validation Type | Duration |
|----|-------|-----------------|----------|
| #892 | osd-google-sre-access | Review | 30m |

**Execution**: Review-only. Validate:
- WIF/PSC architecture descriptions
- Process documentation accuracy
- Diagram clarity

**Estimated**: $0, 30 minutes, 1 PR reviewed

---

## Summary Statistics

### By Infrastructure

| Provider | Batches | PRs | Duration | Cost |
|----------|---------|-----|----------|------|
| ROSA | 5 | 13 | 20 hrs | ~$29 |
| ARO | 2 | 7 | 6 hrs | ~$10 |
| Docs-Only | 2 | 4 | 1.5 hrs | $0 |
| **Total** | **9** | **24** | **27.5 hrs** | **~$39** |

### Cost Comparison

| Approach | Cost | Time |
|----------|------|------|
| Individual (24 PRs × $5) | $120 | ~48 hours |
| Batched (9 batches) | $39 | ~27.5 hours |
| **Savings** | **$81 (68%)** | **20.5 hours (43%)** |

### Parallel Execution Potential

If running 3 batches in parallel:
- **Wall time**: ~9 hours (vs 48 hours individual)
- **Time savings**: **81%**

---

## Recommended Execution Order

### Week 1: ROSA Focus
- **Mon**: Batch 1 (ROSA Standard + Metrics) - 5 PRs, 4 hrs, $6
- **Tue**: Batch 2 (ROSA Networking) - 2 PRs, 3 hrs, $4.50
- **Wed**: Batch 3 (ROSA High-Conflict) - 2 PRs, 5 hrs, $7.50
- **Thu**: Batch 4 (ROSA GPU + AI/ML) - 2 PRs, 5 hrs, $6.50
- **Fri**: Batch 7 (Cross-Platform Obs) - 2 PRs, 3 hrs, $4.50

**Week 1 Total**: 13 PRs, 20 hrs, $29

### Week 2: ARO + Reviews
- **Mon**: Batch 5 (ARO Standard) - 4 PRs, 5 hrs, $10
- **Tue**: Batch 6 (ARO Docs) - 3 PRs, 1 hr, $0
- **Wed**: Batch 8 (OSD Docs) - 1 PR, 0.5 hrs, $0
- **Thu-Fri**: Fix commits, PR comments, retrospective updates

**Week 2 Total**: 8 PRs, 6.5 hrs, $10

---

## Risk Assessment

### High-Risk PRs (May Block Batch)

1. **#866 - Lightspeed Bedrock** ❌ Already blocked (namespace issue)
2. **#909/#921 - RHOAI S3** - May have RHOAI resource requirements (needs verification)
3. **#881 - Quay** - External AWS resources (RDS, ElastiCache) - cleanup complexity

### Medium-Risk PRs

1. **#668 - vLLM GPU** - GPU requirements, operator complexity
2. **#689 - ARO Lightspeed** - Same namespace issue as #866?
3. **#905 - Vault CSI** - Requires Vault instance setup

### Low-Risk PRs

All docs-only and networking PRs (#907, #888, #659, #892, #615, #605, #687)

---

## Pre-Flight Checks Needed

Before batch execution:

1. **Verify #909 vs #921**: Are these the same guide? Test only one.
2. **Fix #866**: Namespace issue must be resolved before testing
3. **Check #689**: Does ARO Lightspeed have same namespace issue?
4. **AWS Quotas**: Verify GPU instance availability in us-west-2
5. **Azure Quotas**: Verify ARO cluster quota in eastus
6. **Bedrock Access**: Verify models available if testing #866 (after fix)

---

## Next Steps

1. **Review this batch plan**
2. **Choose first batch to execute** (recommend Batch 1 or Batch 6)
3. **Update batch-validate skill** with learnings from conservative test
4. **Execute batches sequentially or in parallel**

