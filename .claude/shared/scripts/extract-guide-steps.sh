#!/usr/bin/env bash
# extract-guide-steps.sh — Parse a Hugo guide index.md into sections and bash steps
#
# Usage: extract-guide-steps.sh <path-to-index.md>
#
# Output: For each section, prints the heading and numbered bash code blocks.
#         Flags interactive/manual steps with [MANUAL].

set -euo pipefail

FILE="${1:?Usage: extract-guide-steps.sh <path-to-index.md>}"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: File not found: $FILE" >&2
  exit 1
fi

# Strip YAML front matter (everything between the first two --- lines)
CONTENT=$(awk '
  BEGIN { in_front=0; done_front=0 }
  /^---$/ && !done_front { in_front = !in_front; if (!in_front) done_front=1; next }
  done_front { print }
' "$FILE")

SECTION=""
STEP=0
IN_BASH=0
BLOCK=""

while IFS= read -r line; do
  # Detect section headings (## level)
  if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
    SECTION="${BASH_REMATCH[1]}"
    STEP=0
    echo ""
    echo "=== $SECTION ==="
    continue
  fi

  # Detect sub-headings (### level) — append to section context
  if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
    SUBSECTION="${BASH_REMATCH[1]}"
    echo "  --- $SUBSECTION ---"
    continue
  fi

  # Detect start of bash code block (may be indented under list items)
  if [[ "$line" =~ ^[[:space:]]*\`\`\`bash ]] && [[ $IN_BASH -eq 0 ]]; then
    IN_BASH=1
    BLOCK=""
    continue
  fi

  # Detect end of code block (may be indented)
  if [[ "$line" =~ ^[[:space:]]*\`\`\`[[:space:]]*$ ]] && [[ $IN_BASH -eq 1 ]]; then
    IN_BASH=0
    STEP=$((STEP + 1))

    # Check for interactive/manual indicators
    MANUAL_FLAG=""
    if echo "$BLOCK" | grep -qiE '(az login$|browser|click|open .* console|modify to suit)'; then
      MANUAL_FLAG=" [MANUAL]"
    fi

    # Print step with preview (first non-empty line of the block)
    PREVIEW=$(echo "$BLOCK" | grep -v '^[[:space:]]*$' | grep -v '^#' | head -1 | sed 's/^[[:space:]]*//')
    echo "  [$STEP]${MANUAL_FLAG} ${PREVIEW}"
    continue
  fi

  # Accumulate bash block content
  if [[ $IN_BASH -eq 1 ]]; then
    BLOCK+="$line"$'\n'
  fi

done <<< "$CONTENT"
