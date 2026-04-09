# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hugo static documentation site for Red Hat MOBB/Cloud Experts team, covering Managed OpenShift products (ROSA, ARO, OSD). Deployed on Netlify with Pagefind client-side search. Theme is `rhds` (Red Hat Design System).

## Build Commands

| Command | Purpose |
|---------|---------|
| `make preview` | Local dev server at http://localhost:1313/experts (includes drafts) |
| `make preview-search` | Build + Pagefind index + dev server (search works end-to-end) |
| `make search-index` | Build Pagefind index only |
| `make publish` | Production build (minified) |
| `hugo --gc --minify --theme rhds` | Verification build (matches Netlify deploy) |

There is no test suite. Quality gates are Hugo build success + manual browser checks.

## Content Structure

- Guides live at `content/<section>/<topic>/index.md` (e.g., `content/rosa/some-topic/index.md`)
- Section landing pages use `content/<section>/_index.md`
- Major sections: `rosa/`, `aro/`, `osd/`, `misc/`, `idp/`, `o11y/`, `redhat/`, `ai-ml/`, `tags/`
- The site publishes under `/experts/` path prefix (`publishDir = "public/experts"`)

### Front Matter

```yaml
---
date: 'YYYY-MM-DD'
title: Page Title
tags: ["ROSA", "Quickstarts"]
authors:
  - Author Name
validated_version: "4.20"  # optional
---
```

- `validated_version` auto-generates a version disclaimer; do NOT also add a manual `alert` shortcode for the same purpose
- Tags are **case- and spacing-sensitive**; use only established tags from `CONTRIBUTING.md`

## Key Rules

- **No em dashes** (`---`) in content. Use commas, parentheses, colons, or split sentences.
- **Internal links** must be root-relative starting with `/experts/` (e.g., `/experts/rosa/some-topic/`). Never hardcode hostnames.
- **Do not modify** `themes/rhds/` for content-only tasks.
- **Do not invent new tags** without maintainer approval.
- **Commits require sign-off**: use `git commit -s` (DCO).
- Goldmark is configured with `unsafe = true` so raw HTML works, but prefer semantic Markdown.
- Prefer existing shortcodes (`alert`, `notice`, `expand`, `tabs`/`tab`, `mermaid`, `include`) over ad-hoc HTML.

## ROSA Best Practices Triple

Three files work as one editorial unit and must stay in sync:

1. `content/rosa/best-practices-recommendations/index.md` (authoritative source)
2. `content/rosa/best-practices-checklist/index.md` (derivative checklist)
3. `static/rosa/best-practices-checklist-decisions.csv` (CSV export of summary table)

**Do not** silently update sibling files. Propose a plan and get explicit permission before cross-file edits.

## Environment

- Hugo 0.157.0 (must match version in `netlify.toml`)
- Node 18+ (for Pagefind dev dependency)
- `make preview-search` requires writing to disk; do NOT use `hugo server -M` / `--renderToMemory` if search must work

## Additional Agent Guidance

See `AGENTS.md` for detailed automation-oriented defaults, repo-specific gotchas, and the full verification workflow.
