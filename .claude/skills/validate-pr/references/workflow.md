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

Clone the appropriate Terraform repo into `/tmp/`:

```bash
# ROSA
git clone --depth=1 https://github.com/rh-mobb/terraform-rosa.git /tmp/terraform-rosa

# ARO
git clone --depth=1 https://github.com/rh-mobb/terraform-aro.git /tmp/terraform-aro
```

Set variables and apply. See `infra-providers.md` for provider-specific
variable lists.

```bash
cd /tmp/terraform-<provider>
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

## Cleanup

After reporting, prompt the user before cleanup:

1. Terraform-managed resources: `terraform destroy -auto-approve`
2. Guide-created resources (storage accounts, helm releases, namespaces):
   run the guide's cleanup section if present
3. Local temp files: remove `/tmp/terraform-*`, model dirs, scripts
