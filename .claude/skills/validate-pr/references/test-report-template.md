# Test Report Template

Use this template for both the local `test-report.md` file and the PR comment
posted via `gh pr comment`.

## PR Comment Format

The PR comment combines the test report with the fix commit reference.
For multi-guide PRs, repeat the per-guide sections.

```markdown
## Validation test results -- <PR title>

Ran end-to-end validation on <cluster-type> (<OCP version>, <region/location>).

### Guide: <guide-title>

**Source:** `<content-path>`

| Section | Status | Notes |
|---------|--------|-------|
| <heading> | PASS | |
| <heading> | FAIL | <what went wrong> |
| <heading> | SKIP | <why skipped> |

<!-- Repeat the table for each guide in the PR -->

### Issues found during testing

1. **<short title>** -- <description of the problem, what was observed vs
   expected, and whether it is a doc issue or environmental>

2. **<short title>** -- <description>

<!-- Number issues sequentially across all guides -->

### Fix commit

<commit-url>

Cherry-pick: `git cherry-pick <sha>`

Changes:
- <bullet summary of each fix>
```

## Local test-report.md Format

The local file includes more detail for reference.

```markdown
# Test Report: <PR title>
**Date:** <YYYY-MM-DD>
**PR:** rh-mobb/documentation#<number>
**Cluster:** <cluster-name> (<cluster-type>)
**OCP Version:** <version>
**Region:** <region or location>

## Guide: <guide-title>

**Source:** `<content-path>`
**Validated version:** <version from front matter>

| Section | Description | Status | Notes |
|---------|-------------|--------|-------|
| 0 | Prerequisites | PASS/FAIL/SKIP | ... |
| 1 | <section heading> | PASS/FAIL/SKIP | ... |
| 2 | <section heading> | PASS/FAIL/SKIP | ... |

<!-- Repeat for each guide -->

## Issues Found

1. **<title>** (Severity: High/Medium/Low/Info)

   <detailed description including error output if applicable>

## Suggested Doc Updates

- <specific recommendation>

## Environment

- `oc` version: <version>
- `az`/`aws`/`rosa` version: <version>
- Terraform version: <version>
- Cluster provisioned via: <terraform-repo or manual>
```

## Status Definitions

| Status | Meaning |
|--------|---------|
| PASS | Step executed successfully, output matches expectations |
| FAIL | Step failed or produced unexpected output; doc issue identified |
| SKIP | Step not executed (Terraform handled it, already installed, UI-only) |

## Severity Definitions

| Severity | Meaning |
|----------|---------|
| High | Blocks progress; user cannot continue the guide without a fix |
| Medium | Causes confusion or requires undocumented workaround |
| Low | Minor inaccuracy; guide still works but text is misleading |
| Info | Version mismatch, cosmetic issue, or enhancement suggestion |
