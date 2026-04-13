# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Hugo static site for Red Hat MOBB / Cloud Experts documentation. Guides walk users through deploying and configuring workloads on ROSA (AWS), ARO (Azure), and OSD clusters. See `AGENTS.md` for repo structure, build commands, Hugo config, and theme details — do not duplicate that content here.

## Build and preview

```bash
make preview                  # local dev server
hugo --gc --minify --theme rhds  # production-like build
make preview-search           # build + Pagefind search index
```

## Behavioral rules for this repo

### Think before coding
Read the guide end-to-end before making changes. Understand what the guide creates, what it depends on, and what it cleans up. Guides are tested against live cloud infrastructure — a wrong command wastes real time and money.

### Simplicity first
Guides are copy-paste workflows for practitioners. Prefer explicit `oc` / `az` / `aws` commands over scripts, wrappers, or abstractions. Each step should be independently understandable. Don't consolidate steps that a reader needs to run and verify separately.

### Surgical changes
Fix what's broken. Don't rewrite a guide when you're fixing one command. Don't add error handling, retries, or defensive scripting to guide steps — readers need to see what's happening and debug failures themselves. Don't restructure sections, rename headings, or change the narrative flow unless that's the explicit task.

### Goal-driven execution
Every edit should trace back to something that failed, is misleading, or is missing. "Could be improved" is not a reason to change a working guide. If a command works, leave it alone — even if you'd write it differently.

## Guide conventions

- Guides live at `content/<section>/<topic>/index.md` with YAML front matter
- Use `validated_version` in front matter when a guide has been tested against a specific OCP version — do NOT add a separate version disclaimer alert in the body
- Every guide that creates resources MUST have a cleanup section
- Use environment variables at the top so readers can customize names/regions
- Cloud resource names (storage accounts, SPs, IAM roles) should be unique or the guide should tell readers to pick unique names
- Don't hardcode operator CSV versions — use dynamic lookups (e.g., `oc get csv -o name | grep <operator>`)
- `--skip-assignment` on `az ad sp create-for-rbac` is deprecated — don't use it

## PR validation

Guides can be validated by executing their steps against live cloud infrastructure. When doing so:

- Use Terraform-managed infrastructure (`rh-mobb/terraform-rosa` for ROSA, `rh-mobb/terraform-aro` for ARO) for repeatable provisioning and one-command teardown
- Default to ROSA HCP clusters unless the guide explicitly requires classic — HCP is faster and cheaper
- Delete all non-Terraform resources (storage accounts, IAM roles, operators, Helm releases) before running `terraform destroy`
- Track results per section (PASS / FAIL / SKIP) and note every issue with severity
