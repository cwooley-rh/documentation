# Batch Validate Skill

Optimize PR validation costs and time by grouping multiple guides onto shared infrastructure.

## Quick Start

```bash
# Analyze open PRs and propose batches
/batch-validate plan

# Execute a predefined batch
/batch-validate rosa-batch-1

# Analyze PR conflicts manually
./scripts/detect-conflicts.sh content/rosa/gpu/index.md content/rosa/service-mesh/index.md
```

## Structure

```
batch-validate/
├── SKILL.md                    # Main skill definition and workflows
├── README.md                   # This file
├── pr-batch-plan.md           # Current batch plan (generated 2026-04-27)
├── batches/                   # Batch definition YAML files
│   ├── rosa-batch-1.yaml      # Standard ROSA HCP (5 PRs)
│   ├── rosa-batch-2.yaml      # GPU ROSA HCP (3 PRs)
│   ├── aro-batch-1.yaml       # ARO standard (4 PRs)
│   └── ...                    # More batches as needed
└── scripts/
    ├── analyze-prs.sh         # Analyze open PRs, propose batches
    └── detect-conflicts.sh    # Detect conflicts between two guides
```

## Batch Definitions

Each batch is defined in `batches/<batch-name>.yaml` with:

- **Infrastructure**: Provider, region, cluster config
- **PRs**: List of PR numbers with guides, cleanup levels, estimates
- **Execution order**: Dependencies and sequencing
- **Cost estimates**: Per-PR and total costs

See `batches/rosa-batch-1.yaml` for a complete example.

## Integration with validate-pr

The `validate-pr` skill supports batch mode:

```bash
/validate-pr 917 --batch-mode --cluster=cwooley-rosa-batch-1 --cleanup=namespace
```

This skips infrastructure provisioning and reuses an existing cluster.

## Conflict Levels

- **LOW**: Guides can run in parallel (e.g., multiple metrics exporters)
- **MEDIUM**: Sequential with namespace cleanup (e.g., namespace-scoped operators)
- **HIGH**: Sequential with operator cleanup or separate clusters (e.g., GPU Operator, Service Mesh)

## Cost Savings

Batching reduces costs by:

1. **Shared infrastructure**: 5 PRs on 1 cluster vs 5 separate clusters
2. **Reduced provisioning time**: 1x 20min provision vs 5x 20min
3. **Regional optimization**: Spread GPU workloads across regions to avoid quota issues

**Example**: ROSA Batch 1 validates 5 PRs for $6 total vs $30 individually = **80% cost reduction**

## Parallel Batches

Run multiple batches simultaneously using git worktrees:

```bash
# Terminal 1
cd .worktrees/rosa-batch-1 && /batch-validate rosa-batch-1

# Terminal 2
cd .worktrees/aro-batch-1 && /batch-validate aro-batch-1
```

See SKILL.md "Parallel Batches" section for setup instructions.

## Current Batch Plan

As of 2026-04-27, we have 18 actionable PRs grouped into 6 batches:

| Batch | Provider | PRs | Duration | Cost |
|-------|----------|-----|----------|------|
| rosa-batch-1 | AWS | 5 | 4h | $6 |
| rosa-batch-2 | AWS | 3 | 5h | $6.50 |
| rosa-batch-3 | AWS | 3 | 3h | $3.60 |
| rosa-batch-4 | AWS | 2 | 4h | $6 |
| aro-batch-1 | Azure | 4 | 4h | $8 |
| aro-batch-2 | Azure | 4 | 5h | $10 |

**Total**: 25 hours, $40 (vs $90 individual = 56% savings)

See `pr-batch-plan.md` for full details.

## Guard Rails

- Always confirm batch plan before provisioning
- Show total cost estimate upfront
- Checkpoint after each PR (resume-able)
- Independent per-PR reports
- Manual override for cleanup levels

## Next Steps

1. Review `pr-batch-plan.md` for current batch plan
2. Execute batches sequentially or in parallel
3. Post individual reports to each PR
4. Generate batch summary report
5. Teardown infrastructure after user confirmation
