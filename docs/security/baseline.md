# Repository security baseline

Last reviewed: 2026-10-26
Status: static inspection only; no DeepSec or Cursor security-review scan

## Scope and architecture

The application is a static browser-based todo application under `todo/`.
Client data is stored in IndexedDB. No repository evidence currently shows a
backend, application API, authentication/session system, database server,
external request path, Cloudflare runtime, or Vercel runtime.

This is a starting inventory, not proof that these surfaces are absent at
runtime or that the repository has no vulnerabilities.

## Trust boundaries and assets

| Boundary / asset | Data or operation | Primary concern |
| --- | --- | --- |
| Browser input → DOM | Task text, tags, dates, filters | DOM injection, unsafe parsing |
| Browser → IndexedDB | Local todo records | Integrity, schema migration, local privacy |
| Repository → Cursor agent/hooks | Source, prompts, tool input | Prompt/command injection, path validation |
| Agent stop hook → Git/GitHub | Stage, commit, push, PR workflow | Unintended files, credentials, authorization |
| Prompt logs/screenshots → repository | Prompts, UI/task content | Secrets and personal-data exposure |
| GitHub → agent/maintainers | Issue/PR text, comments, refs, approvals | Prompt/command injection, malicious base refs, forged approval |

## Entry points

- Todo form fields and controls in `todo/index.html` and its scripts.
- IndexedDB records, including records created by older application versions.
- Cursor prompts and tool/hook JSON supplied during local development.
- Shell commands mediated by Cursor hooks.
- Git/GitHub issue, PR, and review content consumed by agents.

## Authentication, authorization, and privilege

- The todo application has no identified authentication or authorization.
- Browser-local data is available to the local browser profile.
- Cursor and shell access inherit the developer workstation's permissions.
- Existing factory stop automation can stage, commit, and push; this is the
  highest-impact automated repository operation and requires narrow staging and
  manual PR review.

## Sensitive data

- Todo text, tags, due dates, and screenshots may contain personal information.
- `.cursor/prompt-log/` may contain prompts, paths, or pasted sensitive data.
- Git credentials, environment variables, and provider tokens must not be
  recorded in findings, command output, or screenshots.
- No tracked application secrets were established by this baseline review.

## Existing controls

- Factory delivery uses feature branches, PRs, Bugbot review, verification
  evidence, and manual approval before merge/issue closure.
- Test-scenario documentation hooks and local validators provide deterministic
  workflow checks.
- The deep-security-audit workflow adds scoped reviews, a findings ledger, and
  approval gates for external or paid tools.
- Factory ticket ingestion scans full issue JSON before use, verifies
  collaborator permission for approval authors, and treats all GitHub text as
  data rather than commands.
- Every code-changing ticket and PR update requires Cursor security-review
  evidence bound to the current diff hash. Critical/High findings, scan failure,
  stale evidence, external PR refs, or an unexpected origin block delivery.

## Priority review areas

1. DOM rendering and all user-controlled todo/tag content.
2. IndexedDB parsing, schema upgrades, recurrence, and destructive actions.
3. PowerShell hooks: command construction, repository path containment, secret
   redaction, and failure behavior.
4. Git staging/push automation and manual-review enforcement.
5. Prompt logs, screenshots, and audit artifacts for accidental disclosure.
6. Third-party browser resources and dependency integrity if introduced.

## Coverage and limitations

- Repository/configuration inspection only.
- DeepSec was not installed or run.
- Cursor security-review was not run.
- Cloudflare tools were not applicable or run.
- No network scan, active exploit, provider API call, deployment, or production
  access occurred.
- Dependency vulnerability coverage is limited until manifests/lockfiles and
  installed tooling are explicitly reviewed.
