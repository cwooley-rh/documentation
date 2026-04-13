---
name: validate-pr
description: >-
  This skill should be used when the user asks to "validate a PR",
  "test a documentation PR", "verify docs against a cluster",
  "/validate-pr", or mentions running guide steps against live
  infrastructure for rh-mobb/documentation pull requests.
version: "0.4.0"
user-invocable: true
---

# Validate PR

Validate documentation pull requests by executing guide steps against live
cloud infrastructure, capturing results per section, and posting fixes back
to the upstream PR.

## Invocation

```
/validate-pr <pr-number>
```

## Workflow

Five phases. For detailed procedures, read
[references/workflow.md](references/workflow.md). For recurring issues and
lessons from prior validations, read
[references/known-patterns.md](references/known-patterns.md).

### Phase 1: PR Analysis

Fetch PR metadata and identify test targets.

```bash
gh pr view <number> --repo rh-mobb/documentation \
  --json title,headRefName,headRepositoryOwner,author,files,body
```

From the `files` list, identify guide `index.md` files under `content/`.
Each is a test target. Ignore image-only or metadata-only changes.

For each guide, determine:
- **Cloud provider** from content path and commands in the diff
- **Dependencies** from the guide's prerequisites section (cross-references
  to other guides)
- **Execution order** when multiple guides share infrastructure

Use `scripts/extract-guide-steps.sh <path>` to parse each guide into an
ordered list of sections and bash code blocks.

### Phase 2: Infrastructure

Provision test infrastructure using Terraform for one-command teardown.

| Path prefix      | Provider | Terraform repo             |
|-----------------|----------|---------------------------|
| `content/rosa/`  | AWS      | `rh-mobb/terraform-rosa`  |
| `content/aro/`   | Azure    | `rh-mobb/terraform-aro`   |
| `content/redhat/`| varies   | Infer from guide prereqs  |

For provider-specific variables, login commands, and teardown procedures,
read [references/infra-providers.md](references/infra-providers.md).

**ROSA cluster type rule:** Always provision ROSA HCP (hosted control plane)
clusters unless the guide under test explicitly states it requires a classic
(non-HCP) cluster. HCP clusters provision faster (~20 min vs ~40 min) and
are the current ROSA default. Set `hosted_control_plane = true` in tfvars.

**Before provisioning, confirm with the user:**
- Region/location
- Cluster sizing
- Any existing cluster to reuse
- Estimated cost and time

When the guide itself provisions infrastructure (e.g., `az aro create` in a
quickstart), use Terraform instead and mark those guide sections as SKIP.

### Phase 3: Execution

For each guide, in dependency order:

1. Track every `export` and variable assignment across sections
2. Execute each bash code block in order within its `##` section
3. After each section, record: heading, PASS / FAIL / SKIP, notes
4. On failure: capture error output, diagnose, note the issue, continue
5. Do not abort the entire guide on a single section failure

**SKIP a section when:**
- Terraform already handled it (cluster creation, networking)
- CLI tools are already installed
- The step is interactive/UI-only with no programmatic equivalent

**Flag for user attention when:**
- A step requires browser interaction with no CLI equivalent
- A command modifies billing resources beyond the cluster itself
- Credentials or secrets are needed that are not in the environment

### Phase 4: Report and Fix

Generate a test report per
[references/test-report-template.md](references/test-report-template.md).

Fix commit workflow:
1. Fetch the PR branch: `git fetch <remote> <branch>`
2. Check out the branch locally
3. Apply documentation fixes (corrected commands, added notes, version updates)
4. Commit with sign-off: `git commit -s`
5. Push to `connor` remote (`cwooley-rh/documentation`)
6. Comment on the upstream PR with results and cherry-pick command:
   `gh pr comment <number> --repo rh-mobb/documentation --body "..."`

### Phase 5: Retrospective

After posting the report and before teardown, review what happened during
this validation and feed learnings back into the skill.

**Update `references/known-patterns.md` when:**
- A doc issue appeared that matches an existing pattern (increment frequency)
- A new recurring pattern emerged (seen in 2+ PRs)
- An infrastructure failure mode was hit for the first time
- A workaround was discovered that future runs should know about

**Update `references/infra-providers.md` when:**
- A new Terraform variable or flag was needed
- A provider-specific workaround was required
- Timing estimates changed based on observed provision times

**Save a memory when:**
- The user expressed a preference that should persist across sessions
- A cross-session rule was established (e.g., "always use HCP")

**Commit skill updates:**
```bash
git checkout feature/validate-pr-skill
# Edit references/known-patterns.md, infra-providers.md, etc.
git add .claude/skills/validate-pr/
git commit -s -m 'Update validate-pr skill from PR #<N> retrospective'
git push connor feature/validate-pr-skill
git checkout -   # return to previous branch
```

**Questions to ask during retrospective:**
1. What broke that was NOT the guide's fault? (infra failure → known-patterns)
2. What doc problem appeared for the 2nd+ time? (pattern → known-patterns)
3. What should the skill have warned about up front? (guard rail → SKILL.md)
4. Were non-Terraform resources created that blocked teardown? (→ infra-providers)
5. Did the user correct our approach? (preference → memory)

## Multi-Guide PRs

When a PR changes multiple guides:
- Identify dependency order (e.g., quickstart before federated-metrics)
- Share infrastructure between guides that use the same cluster
- Report per-guide results in separate sections of the test report
- One fix commit covers all guides in the PR

## Parallel Execution

Multiple PRs can be validated simultaneously by running separate Claude
sessions, each in an isolated git worktree with its own Terraform directory.

### Setup (run once per parallel batch)

```bash
# For each PR:
PR=912
git fetch origin pull/$PR/head:validate-pr-$PR
git worktree add .worktrees/pr-$PR validate-pr-$PR
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git /tmp/terraform-rosa-$PR
```

### Launch agents

```bash
# Terminal 1
cd .worktrees/pr-912 && claude -p "/validate-pr 912"

# Terminal 2
cd .worktrees/pr-917 && claude -p "/validate-pr 917"
```

Each agent inherits the PR number from its invocation. All paths are
parameterized by PR number:
- **Worktree:** `.worktrees/pr-<PR>`
- **Terraform:** `/tmp/terraform-<provider>-<PR>`
- **Cluster name:** `cwooley-pr<PR>`
- **Fix branch:** `fix/<topic>` (pushed from the worktree independently)

### Retrospective isolation

Agents must NOT checkout shared branches (like `agentic-workflows`) from
inside a worktree — git forbids two worktrees on the same branch. Instead,
each agent writes retrospective updates to a PR-specific branch:

```bash
git checkout -b retro/pr-$PR
# edit known-patterns.md
git commit && git push connor retro/pr-$PR
```

After all agents finish, merge retrospectives from the main worktree:

```bash
cd /Users/cwooley/projects/documentation
git checkout agentic-workflows
for branch in retro/pr-912 retro/pr-917; do
  git merge $branch
done
git push connor agentic-workflows
```

### Cleanup

```bash
# Per-PR (after terraform destroy completes)
git worktree remove .worktrees/pr-$PR
git branch -D validate-pr-$PR
rm -rf /tmp/terraform-<provider>-$PR
```

### Region spreading for GPU workloads

When multiple PRs need GPU instances, spread across regions to avoid
quota collisions:

| Session | Region |
|---------|--------|
| 1 | us-east-1 |
| 2 | us-east-2 |
| 3 | us-west-2 |
| 4 | ca-central-1 |

## Guard Rails

- Always confirm infrastructure cost and provisioning before creating resources
- Never run `terraform destroy` without explicit user permission
- Never run destructive cluster operations (delete namespace, helm uninstall)
  without asking first
- If a guide step creates cloud resources outside Terraform (storage accounts,
  S3 buckets), note them for manual cleanup or flag that they should be added
  to the Terraform config
- Keep terminal session alive for environment variable continuity
