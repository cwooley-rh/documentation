---
name: update-guides
description: >-
  Bulk update documentation guides when operator versions, CLI flags, or
  platform APIs change. Use when asked to update docs for a version
  change, deprecation, API rename, or /update-guides.
version: "0.1.0"
user-invocable: true
---

# Update Guides

Search for and update documentation guides affected by a change in
operators, CLI tools, APIs, or platform behavior.

## Invocation

```
/update-guides <change-description>
```

Examples:
- `/update-guides "RHOAI 2.25 requires manual DSC creation"`
- `/update-guides "az ad sp create-for-rbac --skip-assignment deprecated"`
- `/update-guides "GPU Operator CSV v24.9.0 released"`
- `/update-guides "OCP 4.17 changes default StorageClass"`

## Workflow

### 1. Impact analysis

Search across all guide content for the affected component.

```bash
# Search for operator name, CLI flag, or API reference
grep -rl "<search-term>" content/
```

Use the Grep tool to search for:
- Operator names and CSV patterns
- CLI flags and command patterns
- API group/version/kind references
- Environment variable names
- Helm chart names and values

List every affected guide with its content path.

### 2. Change classification

Classify the change to determine update urgency and scope:

| Type | Description | Action |
|------|-------------|--------|
| **Breaking** | Commands fail with errors | Must fix immediately |
| **Deprecation** | Commands warn but still work | Fix proactively |
| **Enhancement** | New option or capability | Add if relevant |
| **Version bump** | New version, same behavior | Update references |

### 3. Load product context

For each affected guide, determine the product from its content path
and load the relevant product knowledge base from `../../products/`.

### 4. Plan updates

For each affected guide:
1. Read the full guide
2. Identify specific lines/sections that need changes
3. Determine if the change affects:
   - Commands (code blocks)
   - Prerequisites (tool versions)
   - Environment variables
   - Cleanup section
   - Front matter (`validated_version`)

Present the update plan to the user before making changes.

### 5. Apply updates

For each guide, apply the changes:
- Replace deprecated commands with current equivalents
- Update operator installation patterns
- Fix API references
- Add notes about version requirements if applicable

After each edit, verify against `../../shared/review-checklist.md`:
- Cleanup section still matches deploy steps
- No new hardcoded values introduced
- Tags and front matter still valid

### 6. Review pass

Run each modified guide through the review checklist to catch
regressions. Check that updates are consistent across all affected
guides — the same change should be applied the same way everywhere.

### 7. Commit

```bash
git add content/<paths>
git commit -s -m '<change-description> across affected guides

Updated guides:
- content/<path1>/index.md
- content/<path2>/index.md

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>'
```

## Common Update Patterns

### Operator CSV version change
```bash
# Find all guides that reference the operator
grep -rl "gpu-operator-certified" content/
```

Check that all matches use dynamic CSV lookup. If any hardcode the CSV
version, replace with:
```bash
CSV_NAME=$(oc get csv -n <namespace> -o name | grep <operator>)
```

### CLI flag deprecation
```bash
# Find all guides using the deprecated flag
grep -rl "\-\-skip-assignment" content/
```

Remove the flag, verify the command works without it, and update any
surrounding explanation.

### API version change
```bash
# Find all guides using the old API version
grep -rl "apiVersion: old/v1" content/
```

Replace with new API version. Check that field names haven't changed
between versions.

## Guard Rails

- Always present the update plan before making changes
- Do not change guides that are not affected by the update
- Do not update `validated_version` unless the guide has been re-tested
- Flag guides that may need live re-validation after the update
- One logical change per commit — don't bundle unrelated updates
- If unsure whether a change breaks a guide, recommend `/validate-pr`
