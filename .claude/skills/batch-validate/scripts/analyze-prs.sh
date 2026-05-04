#!/bin/bash
# Analyze open PRs and propose batch groupings
# Usage: analyze-prs.sh [--limit N]

set -euo pipefail

LIMIT="${1:-50}"

echo "Analyzing open PRs for batch validation opportunities..."
echo ""

# Fetch open PRs
prs=$(gh pr list --repo rh-mobb/documentation --limit "$LIMIT" \
  --json number,title,files,author,createdAt \
  --jq '.[] | {number, title, files: [.files[].path], author: .author.login, created: .createdAt}')

# Categorize PRs by provider
rosa_prs=()
aro_prs=()
osd_prs=()
misc_prs=()
docs_only=()

while IFS= read -r pr; do
  number=$(echo "$pr" | jq -r '.number')
  files=$(echo "$pr" | jq -r '.files[]')

  # Check if docs-only (no .md files in content/)
  content_files=$(echo "$files" | grep -E '^content/.*\.md$' | wc -l | tr -d ' ')

  if [[ $content_files -eq 0 ]]; then
    docs_only+=("$number")
    continue
  fi

  # Categorize by path
  if echo "$files" | grep -q '^content/rosa/'; then
    rosa_prs+=("$number")
  elif echo "$files" | grep -q '^content/aro/'; then
    aro_prs+=("$number")
  elif echo "$files" | grep -q '^content/osd/'; then
    osd_prs+=("$number")
  else
    misc_prs+=("$number")
  fi
done < <(echo "$prs" | jq -c '.')

echo "=== PR Categorization ==="
echo ""
echo "ROSA PRs: ${#rosa_prs[@]}"
echo "  ${rosa_prs[@]:-none}"
echo ""
echo "ARO PRs: ${#aro_prs[@]}"
echo "  ${aro_prs[@]:-none}"
echo ""
echo "OSD PRs: ${#osd_prs[@]}"
echo "  ${osd_prs[@]:-none}"
echo ""
echo "Misc PRs: ${#misc_prs[@]}"
echo "  ${misc_prs[@]:-none}"
echo ""
echo "Docs-only PRs: ${#docs_only[@]}"
echo "  ${docs_only[@]:-none}"
echo ""

# Analyze ROSA PRs for GPU requirements
echo "=== ROSA PR Analysis ==="
echo ""

rosa_gpu=()
rosa_standard=()

for pr in "${rosa_prs[@]}"; do
  files=$(gh pr view "$pr" --repo rh-mobb/documentation --json files --jq '.files[].path')

  has_gpu=false
  for file in $files; do
    if [[ -f "$file" ]]; then
      if grep -qE 'nvidia|gpu|g4dn\.|p3\.|p4d\.|Tesla|A100|T4' "$file"; then
        has_gpu=true
        break
      fi
    fi
  done

  if [[ "$has_gpu" == "true" ]]; then
    rosa_gpu+=("$pr")
  else
    rosa_standard+=("$pr")
  fi
done

echo "GPU-required PRs: ${#rosa_gpu[@]}"
echo "  ${rosa_gpu[@]:-none}"
echo ""
echo "Standard PRs: ${#rosa_standard[@]}"
echo "  ${rosa_standard[@]:-none}"
echo ""

# Propose batches
echo "=== Proposed Batches ==="
echo ""

if [[ ${#rosa_standard[@]} -gt 0 ]]; then
  echo "ROSA Batch 1 (Standard HCP, us-east-1)"
  echo "  PRs: ${rosa_standard[@]}"
  echo "  Estimated: 3-5 PRs, 4 hours, \$6"
  echo ""
fi

if [[ ${#rosa_gpu[@]} -gt 0 ]]; then
  echo "ROSA Batch 2 (GPU HCP, us-east-2)"
  echo "  PRs: ${rosa_gpu[@]}"
  echo "  Estimated: 2-3 PRs, 5 hours, \$7"
  echo ""
fi

if [[ ${#aro_prs[@]} -gt 0 ]]; then
  echo "ARO Batch 1 (Standard, eastus)"
  echo "  PRs: ${aro_prs[@]}"
  echo "  Estimated: 3-5 PRs, 4 hours, \$8"
  echo ""
fi

if [[ ${#osd_prs[@]} -gt 0 ]]; then
  echo "OSD Batch 1 (GCP, us-central1)"
  echo "  PRs: ${osd_prs[@]}"
  echo "  Estimated: 2-3 PRs, 4 hours, \$10"
  echo ""
fi

# Summary
total_actionable=$((${#rosa_prs[@]} + ${#aro_prs[@]} + ${#osd_prs[@]} + ${#misc_prs[@]}))
estimated_batches=$((${#rosa_prs[@]} > 0 ? 1 : 0))
estimated_batches=$((estimated_batches + (${#rosa_gpu[@]} > 0 ? 1 : 0)))
estimated_batches=$((estimated_batches + (${#aro_prs[@]} > 0 ? 1 : 0)))
estimated_batches=$((estimated_batches + (${#osd_prs[@]} > 0 ? 1 : 0)))

echo "=== Summary ==="
echo ""
echo "Total PRs analyzed: $(echo "$prs" | jq -s 'length')"
echo "Actionable PRs: $total_actionable"
echo "Docs-only PRs: ${#docs_only[@]}"
echo "Proposed batches: $estimated_batches"
echo ""
echo "Next step: Review batch definitions in batches/ directory"
echo "           or run: /batch-validate <batch-name>"
