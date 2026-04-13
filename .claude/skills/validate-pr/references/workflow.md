# Detailed Workflow

## Phase 1: PR Analysis

### Fetch PR metadata

```bash
gh pr view <number> --repo rh-mobb/documentation \
  --json title,headRefName,headRepositoryOwner,author,files,body,state
```

### Identify test targets

Filter the `files` list to guide content:
- Keep files matching `content/**/**/index.md`
- Ignore image-only changes, `_index.md` section pages, and non-content files
- For each guide, also read the full file to understand its structure

### Fetch the PR diff

```bash
gh pr diff <number> --repo rh-mobb/documentation
```

Review the diff to understand what changed. Focus on:
- New or modified bash code blocks (commands to validate)
- Changed prerequisites or environment variables
- Structural changes (reordered sections, new sections)

### Determine dependencies between guides

Read each guide's prerequisites section. Look for:
- Links to other guides in the same PR (e.g., `/experts/quickstart-aro.md`)
- Statements like "requires a running cluster" or "assumes you completed..."
- Shared environment variables across guides

Build an execution order: prerequisite guides first.

### Extract steps with the helper script

```bash
bash .claude/skills/validate-pr/scripts/extract-guide-steps.sh \
  content/<section>/<topic>/index.md
```

Review the output to identify:
- Total section and step count
- Interactive/manual steps that need CLI replacements
- Environment variable assignments to track

## Phase 2: Infrastructure

### Pre-flight checks

Before provisioning, verify:

```bash
# Common
which oc && oc version --client
which terraform && terraform version
which gh && gh auth status

# AWS/ROSA
which rosa && rosa whoami
aws sts get-caller-identity

# Azure/ARO
which az && az account show
az provider show -n Microsoft.RedHatOpenShift --query "registrationState"
```

### Provision via Terraform

Clone the appropriate Terraform repo into `/tmp/`, suffixed by PR number
to support parallel sessions:

```bash
# ROSA
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git /tmp/terraform-rosa-$PR

# ARO
git clone --depth=1 https://github.com/rh-mobb/terraform-aro.git /tmp/terraform-aro-$PR
```

Set variables and apply. Use `cwooley-pr$PR` as the cluster name for
isolation. See `infra-providers.md` for provider-specific variable lists.

```bash
cd /tmp/terraform-<provider>-$PR
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

### Log in to the cluster

After provisioning, log in and verify:

```bash
oc login <api-url> --username <user> --password <password>
oc get nodes -o wide
oc get sc
```

Record the cluster name, API URL, console URL, and OCP version for the
test report header.

## Phase 3: Execution

### Pre-execution: check known patterns

Before starting execution, read `known-patterns.md` and scan for patterns
that match this guide. For example:
- Does this guide have a cleanup section? (Missing cleanup is the most
  common issue.)
- Does the cleanup section reference resource names that match the deploy
  steps?
- Are environment variables exported correctly?

Anticipating known issues saves debugging time during execution.

### Environment variable tracking

Maintain a running set of environment variables across sections. When a
guide section contains an `export` or variable assignment, capture it and
carry it forward to subsequent commands.

For guides that set variables from Terraform outputs or cloud CLI responses,
substitute the actual values from the provisioned infrastructure.

### Section-by-section execution

For each `##` heading in the guide:

1. Read all bash code blocks under that heading
2. Determine if the section should be SKIP'd:
   - Terraform already handled it (provisioning, networking)
   - CLI tools already installed
   - Step is purely UI/browser with no CLI equivalent
3. Execute each bash block in order
4. Capture stdout and stderr
5. Determine PASS/FAIL based on exit code and expected output
6. Record the result with notes

### Error handling

When a step fails:
1. Capture the full error output
2. Check for common patterns:
   - **Quota exceeded**: note in report, cannot fix in docs
   - **Timeout**: retry once, then record as environment issue
   - **Permission denied**: check RBAC, note prerequisite gap
   - **Resource not found**: likely a doc issue (wrong name, missing step)
   - **Command not found**: missing prerequisite
3. Determine if the failure is a doc issue (fixable) or environmental (note only)
4. Continue to the next section

### Decision points — pause and ask the user

- Before creating cloud resources outside Terraform (storage accounts, buckets)
- When a step says "modify to suit your environment" or similar
- When credentials are needed that are not in the environment
- Before any destructive operation (delete, uninstall)

## Phase 4: Report and Fix

### Generate test report

Use the template from `test-report-template.md`. Fill in:
- Cluster details (name, version, region, provider)
- Per-guide section results
- Issues found with descriptions
- Fix commit reference

### Apply documentation fixes

Common fix patterns:
- **Wrong command**: replace with the working command
- **Missing step**: add the step in the right location
- **Outdated version**: update `validated_version` in front matter
- **Hardcoded values**: parameterize with environment variables
- **Wrong resource name**: update to match actual API object names
- **Missing prerequisite**: add to prerequisites section

### Commit and push

```bash
# Fetch the PR branch
git fetch <author-remote> <branch>
git checkout <branch>

# Make fixes, then commit
git add content/<path>/index.md
git commit -sm 'Fix <guide> based on validation testing on OCP <version>

<summary of changes>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>'

# Push to connor remote
git push connor <branch>
```

### Comment on the PR

```bash
gh pr comment <number> --repo rh-mobb/documentation --body "$(cat <<'EOF'
## Validation test results -- <guide-title>
...
EOF
)"
```

Use the full template from `test-report-template.md`.

## Phase 5: Retrospective

Before teardown, review what happened and update the skill.

### Review checklist

Walk through these questions and act on any "yes":

1. **New doc pattern?** Did a documentation issue appear that we've seen
   before in a different PR? If so, update `known-patterns.md` — either
   add a new entry or increment the frequency and add the new PR to
   "Seen in."

2. **New infra failure?** Did Terraform, cloud providers, or tooling fail
   in an unexpected way? Add it to the "Infrastructure Failure Modes"
   section of `known-patterns.md` with the mitigation that worked.

3. **New workaround?** Did we discover a provider-specific trick (flag,
   env var, timing)? Update `infra-providers.md`.

4. **User feedback?** Did the user correct our approach or confirm a
   non-obvious choice? Save a memory file.

5. **Guard rail gap?** Did we do something risky that the skill should
   have warned about? Add to the Guard Rails section in `SKILL.md`.

### Commit the updates

When running in a worktree (parallel sessions), do NOT checkout a shared
branch — git forbids two worktrees on the same branch. Use a PR-specific
retrospective branch instead:

```bash
git checkout -b retro/pr-$PR

# Make edits to references/known-patterns.md, infra-providers.md, etc.
git add .claude/skills/validate-pr/
git commit -s -m 'Update validate-pr skill from PR #<N> retrospective

- <list changes made>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>'

git push connor retro/pr-$PR
```

When running solo (not in a worktree), you can commit directly to
`agentic-workflows`:

```bash
git stash
git checkout agentic-workflows
# Make edits
git add .claude/skills/validate-pr/
git commit -s -m 'Update validate-pr skill from PR #<N> retrospective'
git push connor agentic-workflows
git checkout -
git stash pop
```

After parallel sessions finish, the orchestrator merges retro branches:

```bash
git checkout agentic-workflows
git merge retro/pr-912 retro/pr-917  # etc.
git push connor agentic-workflows
git branch -d retro/pr-912 retro/pr-917
```

### Track what changed

The commit message should list what was updated so future reads of
`git log` on the skill branch show the learning history:
- "Added missing-cleanup pattern from PR #899"
- "Updated token expiry mitigation from PR #899"
- "Added ROSA HCP default rule from user feedback"

## Cleanup

After the retrospective, prompt the user before cleanup:

1. **Non-Terraform resources first**: Delete any cloud resources created
   by the guide outside of Terraform (storage accounts, IAM roles, log
   groups, helm releases). These block `terraform destroy` if they're
   inside the same resource group / VPC.
2. **Terraform-managed resources**: `terraform destroy -auto-approve`
3. **Verify**: Check that no orphaned resources remain:
   ```bash
   # AWS
   aws iam list-roles --query 'Roles[?contains(RoleName, `<cluster>`)]'
   aws logs describe-log-groups --log-group-name-prefix "/aws/containerinsights/<cluster>"

   # Azure
   az resource list --resource-group <rg> -o table
   ```
4. **Local temp files**: remove `/tmp/terraform-*-$PR` directories
5. **Worktree cleanup** (parallel sessions):
   ```bash
   git worktree remove .worktrees/pr-$PR
   git branch -D validate-pr-$PR
   ```
