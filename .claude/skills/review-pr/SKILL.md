---
name: review-pr
description: >-
  Static review of documentation PRs for style, conventions, and known
  issues. Use when asked to review a PR, check docs quality, or
  /review-pr. Does NOT provision infrastructure or execute commands
  against a cluster.
version: "0.1.0"
user-invocable: true
---

# Review PR

Review documentation pull requests for correctness, conventions, and
known issues without provisioning infrastructure. For live validation
against a cluster, use `/validate-pr` instead.

## Invocation

```
/review-pr <pr-number>
/review-pr <path-to-guide>
```

## Workflow

### Phase 1: Analysis

#### Fetch PR metadata

```bash
gh pr view <number> --repo rh-mobb/documentation \
  --json title,headRefName,headRepositoryOwner,author,files,body,state
```

#### Fetch the diff

```bash
gh pr diff <number> --repo rh-mobb/documentation
```

#### Identify test targets

From the `files` list:
- Keep files matching `content/**/**/index.md`
- Ignore image-only changes, `_index.md` section pages, non-content files
- For each guide, read the full file

#### Detect product

Determine the product from the content path:
- `content/rosa/` → load `../../products/rosa.md`
- `content/aro/` → load `../../products/aro.md`
- `content/osd/` → load `../../products/osd-gcp.md`
- `content/redhat/`, `content/idp/`, etc. → infer from guide content and tags

#### Extract steps

Use the shared script to enumerate sections and code blocks:

```bash
bash ../../shared/scripts/extract-guide-steps.sh <path-to-guide>
```

### Phase 2: Review

For each guide, walk through these checks systematically.

#### 2a. Review checklist

Read `../../shared/review-checklist.md` and apply every applicable check
to the guide content. Work through the checklist section by section:

1. **Structure** — cleanup section, prerequisites, section ordering
2. **Variables** — export statements, quoting, hardcoded values
3. **CLI correctness** — deprecated flags, CSV versions, command accuracy
4. **Resource naming** — globally unique names, cluster name references
5. **Front matter** — required fields, tag taxonomy, validated_version
6. **Links** — internal cross-links, external URLs
7. **Style** — em dashes, shortcodes, code fences
8. **Product-specific** — checks from the loaded product knowledge base

#### 2b. Known patterns

Read `../../shared/known-patterns.md` and check if the guide matches any
documented pattern. Pay special attention to High-frequency patterns:
- Missing cleanup sections
- Stale resource names in cleanup
- Missing `export` on variables

#### 2c. Diff-specific review

Focus on what changed in the PR diff:
- New or modified bash code blocks — are commands correct?
- Changed prerequisites — are new tools mentioned?
- Structural changes — do section references still hold?
- Removed content — does cleanup still reference removed resources?

### Phase 3: Report

Generate a structured review comment and post it on the PR.

```bash
gh pr comment <number> --repo rh-mobb/documentation --body "$(cat <<'EOF'
## Documentation review -- <guide-title>

**Source:** `<content-path>`
**Product:** <ROSA|ARO|OSD>

### Findings

| # | Check | Severity | Description |
|---|-------|----------|-------------|
| 1 | <checklist item> | High/Medium/Low/Info | <what was found> |
| 2 | ... | ... | ... |

### Summary

- **High:** <count> (blocks user progress)
- **Medium:** <count> (causes confusion)
- **Low:** <count> (minor inaccuracy)
- **Info:** <count> (suggestions)

### Notes

<any additional context, questions for the author, or things that
need live validation to confirm>
EOF
)"
```

## Scope Boundaries

This skill does NOT:
- Execute commands against a cluster
- Provision infrastructure
- Modify guide files (use `/validate-pr` for fixes)
- Run `terraform`, `oc`, `rosa`, `az`, or `aws` commands

It only reads files, applies the checklist, and posts a comment.

## When to Escalate to `/validate-pr`

Recommend live validation when:
- Commands look suspicious but cannot be verified without a cluster
- The guide installs an operator whose behavior may have changed
- Resource names or API groups cannot be verified statically
- The guide has not been validated recently (no `validated_version`)

## Token Optimization

- Load the product knowledge base only for the detected product
- Read `review-checklist.md` once at the start of Phase 2
- Read `known-patterns.md` once at the start of Phase 2
- Do not read `workflow.md` or `test-report-template.md` (those are
  validate-specific)
- Use `/effort low` for systematic checklist application
