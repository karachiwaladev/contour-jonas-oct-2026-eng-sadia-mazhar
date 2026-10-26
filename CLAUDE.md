# Software factory index

We are building an **AI software factory**: requirements flow from GitHub/Jira into agent loops, skills, hooks, tests, and safe git delivery.

## Progressive disclosure

This file stays **under 100 lines**. It is the map only — not the full spec.

- Read this index first.
- Open the project folder or linked skill/doc for depth.
- Agents load detail on demand (token budget, context window).

## Workspace layout

| Path | Purpose |
|------|---------|
| `.cursor/skills/factory-loop/` | Loop + ticket execute, comment, commit on stop |
| `.cursor/skills/test-scenarios/` | Feature scenario documentation workflow |
| `.cursor/skills/code-review/` | Pre-PR Bugbot review and severity gate |
| `.cursor/hooks/` | Prompt JSONL logging, factory-loop git push on stop |
| `todo/` | Ticket #3 — client-side todo app (IndexedDB) |
| `docs/test-scenarios/` | Per-feature scenarios, status, evidence, traceability |
| `docs/screenshots/` | Browser verification evidence by issue |

## Active projects

Add one row per factory project. Keep folders self-contained.

| Folder | Ticket | Status | Entry |
|--------|--------|--------|-------|
| `todo/` | #3 / #14 / #16 Todo app | #16 in PR review | `todo/index.html` (filters, tags, due date, daily recurrence) |
| _(root)_ | #2 CLAUDE.md | delivered | this file |

## Agent rules (factory)

1. **Build pipeline** — Clarify → Plan → **approval** → Build → **Chrome DevTools verify** → **Bugbot review** → PR.
2. **No destructive** git/shell (no force push, hard reset, mass delete).
3. **Deliver via PR** — feature branch `factory/issue-<n>-<slug>`, PR with `Refs #<n>`, ticket comment with `**Delivered:**`, `**Verified:**`, screenshots (`docs/screenshots/issue-<n>/`). **Wait for manual review; no merge/close without approval.**
4. **Test scenarios** — update `docs/test-scenarios/<feature>.md` with requirements, regression risks, honest statuses, and local evidence alongside feature code.
5. **Code review** — Bugbot Critical/High findings block PR delivery; Medium/Low findings are documented in the PR. Bugbot never replaces manual review.
6. **Commit + push** when `.cursor/factory-loop-active` and agent stop hook runs.

## Links

- Workshop repo: `karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar`
- Loop skill: `.cursor/skills/factory-loop/SKILL.md`
- Scenario skill: `.cursor/skills/test-scenarios/SKILL.md`
- Review skill: `.cursor/skills/code-review/SKILL.md`
