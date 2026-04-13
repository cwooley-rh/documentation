---
name: author-guide
description: >-
  Scaffold a new documentation guide with correct Hugo structure, front
  matter, and section layout. Use when asked to create a new guide, write
  docs, start a new topic, or /author-guide.
version: "0.1.0"
user-invocable: true
---

# Author Guide

Scaffold a new documentation guide with correct structure, front matter,
and product-specific conventions.

## Invocation

```
/author-guide <product> <topic>
```

Examples:
- `/author-guide rosa gpu-machineset`
- `/author-guide aro key-vault-csi`
- `/author-guide osd filestore-rwx`

Valid products: `rosa`, `aro`, `osd`, `redhat`, `idp`, `misc`, `o11y`, `ai-ml`

## Workflow

### 1. Product detection

Validate the product argument. Load the product knowledge base from
`../../products/<product>.md` if one exists (rosa, aro, osd-gcp).

For cross-product sections (`idp`, `misc`, `o11y`, `redhat`), ask the
user which cloud providers the guide targets to load the right product
context.

### 2. Check for existing content

```bash
ls content/<product>/<topic>/ 2>/dev/null
```

If the directory exists, read the existing guide first. Do not overwrite
without confirmation.

### 3. Create directory and file

```bash
mkdir -p content/<product>/<topic>
```

Create `content/<product>/<topic>/index.md` using the scaffolding
reference at [references/scaffolding.md](references/scaffolding.md).

### 4. Front matter

Generate YAML front matter with:
- `date` — today's date in YYYY-MM-DD format
- `title` — derived from topic name, refined by user
- `tags` — from the approved taxonomy (see `../../shared/review-checklist.md`
  for the full list). Must be case-sensitive exact matches.
- `authors` — ask the user or use their git config name

Do NOT add `validated_version` unless the guide has been tested.
Do NOT add `draft: true` unless the user requests it.

### 5. Section scaffolding

Apply the guide skeleton from `references/scaffolding.md`:

1. **Prerequisites** — CLI tools, cluster access, links to dependencies
2. **Environment variables** — `export` statements for customizable values
3. **Numbered steps** — each `##` section covers one logical operation
4. **Verification** — commands to confirm the steps worked
5. **Cleanup** — teardown for every resource created

Product-specific prerequisites and patterns come from the product
knowledge base.

### 6. Review pass

Before presenting the draft, check it against
`../../shared/review-checklist.md`:
- All variables use `export`
- Resource names are parameterized
- Cleanup section exists and covers all created resources
- Tags match the approved taxonomy
- No em dashes
- Internal links use `/experts/` prefix

### 7. Present to user

Show the complete guide for review. Highlight:
- Sections that need the user to fill in specific commands
- Placeholder values that need real values
- Any conventions that differ from the user's request

## Conventions

These rules come from `CLAUDE.md` and apply to all guides:

- **Simplicity first:** Prefer explicit `oc`/`az`/`aws` commands over
  scripts. Each step should be independently understandable.
- **No defensive scripting:** Don't add error handling, retries, or
  conditional logic to guide steps. Readers need to see and debug.
- **Environment variables at top:** Set all customizable values in one
  section so readers know what to change.
- **Mandatory cleanup:** Every guide that creates resources must have a
  cleanup section. No exceptions.
- **Dynamic CSV lookup:** Never hardcode operator CSV versions. Use
  `oc get csv -n <ns> -o name | grep <operator>`.
- **Unique resource names:** If cloud resources require unique names,
  tell users to choose their own or generate with a random suffix.

## Guard Rails

- Never invent tags not in the approved taxonomy
- Never add `validated_version` to a guide that hasn't been tested
- Always include a cleanup section, even for simple guides
- Use `/experts/` prefix for all internal cross-links
- Ask the user before creating files in existing directories
