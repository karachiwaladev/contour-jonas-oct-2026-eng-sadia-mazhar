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
| `.cursor/hooks/` | Prompt JSONL logging, factory-loop git push on stop |
| `todo/` | Ticket #3 — client-side todo app (IndexedDB) |
| `docs/` | Optional workshop answers and specs (add per ticket) |

## Active projects

Add one row per factory project. Keep folders self-contained.

| Folder | Ticket | Status | Entry |
|--------|--------|--------|-------|
| `todo/` | #3 Todo app | delivered | `todo/index.html` |
| _(root)_ | #2 CLAUDE.md | delivered | this file |

## Agent rules (factory)

1. **Build pipeline** — Clarify → Plan → **approval** → Build → **Chrome DevTools verify** → screenshots on ticket.
2. **No destructive** git/shell (no force push, hard reset, mass delete).
3. **Deliver** — push first, then GitHub comment with `**Delivered:**`, `**Verified:**`, screenshot links under `docs/screenshots/issue-<n>/`.
4. **Commit + push** when `.cursor/factory-loop-active` and agent stop hook runs.

## Links

- Workshop repo: `karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar`
- Loop skill: `.cursor/skills/factory-loop/SKILL.md`
