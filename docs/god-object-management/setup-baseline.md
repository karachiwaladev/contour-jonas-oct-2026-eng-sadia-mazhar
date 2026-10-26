# God object management setup baseline

Recorded before guardrail implementation on 2026-10-26.

## Repository

- Branch: `factory/scenario-documentation-hooks`
- Product: static HTML/CSS/JavaScript todo app using IndexedDB
- Factory tooling: PowerShell command hooks, Markdown skills, MDC rules
- Build/package manager: none
- Automated application tests: none
- Existing validation:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/tools/validate-test-scenarios.ps1`

## Existing Cursor configuration

`.cursor/hooks.json` uses schema version 1 and currently registers:

- `beforeSubmitPrompt`: prompt logging
- `afterFileEdit` and `postToolUse`: scenario-file tracking and reminders
- `stop`: scenario validation, prompt flushing, then conditional commit/push
- `sessionEnd`: prompt flushing

The scenario hooks, test-scenario skill/rule, validator, and related index
changes were already uncommitted when this setup began. They are preserved as
the implementation baseline rather than overwritten.

Existing reusable conventions:

- PowerShell reads hook JSON from stdin and writes JSON only to stdout.
- Project hook commands run from the repository root.
- Per-conversation state lives under `.cursor/hooks/state/`.
- Advisory hooks fail open and use one-shot state flags.
- Stop follow-ups use `loop_limit: 1`.

## Initial responsibility review

### Primary candidate: `todo/app.js`

- Size at baseline: 282 lines.
- Responsibilities: IndexedDB setup/migrations, task normalization, recurrence,
  CRUD, filters, tag collection, DOM rendering, form validation, events, and
  application startup.
- Coupling: shared database and DOM state; render handlers call persistence and
  refresh logic directly.
- Change concentration: all three recorded todo feature commits changed this
  file (`884cc8d`, `2ee112f`, `9b6f66f`).
- Classification: structural improvement opportunity, not a confirmed defect.
  No split is justified by line count alone.

### Secondary review candidates

- `.cursor/hooks/scenario-hook-common.ps1` (157 lines): shared scenario state,
  path classification, and persistence.
- `.cursor/tools/validate-test-scenarios.ps1` (187 lines): scenario discovery,
  parsing, validation, evidence checks, and output formatting.
- `.cursor/skills/factory-loop/SKILL.md`: broad delivery workflow documentation.

These are candidates for analysis only. This setup does not refactor them.

## Protected scope

Implementation is limited to `.cursor/`, `docs/`, and the `CLAUDE.md` index.
No file under `todo/` will be edited during guardrail setup.
