# Security audit workflow

Security audits are evidence-driven and scoped. The repository does not claim
comprehensive security or zero vulnerabilities.

## Current tool status

- DeepSec: not installed or run.
- Cloudflare skills/tools: not installed; Cloudflare is not configured.
- Cursor security-review: available, not run for this setup change.
- Actual model/tool cost for this setup: $0.

See `baseline.md` for the repository surface and
`.cursor/skills/deep-security-audit/SKILL.md` for the procedure.

## Start

1. Define the authorized repository/ref, paths, targets, exclusions, time, and
   cost.
2. Copy `_audit-template.md` to `audits/<date>-<scope>.md`.
3. Read the baseline and unresolved `findings.md`.
4. Record tools as Run, Not run, Failed, or Blocked before recording results.
5. Create detailed findings from `_finding-template.md` and update the ledger.

## Schedule

- Meaningful change: review the diff and affected trust boundaries.
- Release: review applicable changed code, local tests, open High/Critical
  findings, and coverage limitations.
- Periodic: resume an incremental cost-capped DeepSec scan only after approval.
- Remediation: revalidate the finding and run its regression test.
- Infrastructure change: audit only confirmed provider resources.

## Local validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/tools/validate-security-audit.ps1
```

The validator checks documentation structure and evidence presence. It cannot
confirm exploitability, severity, remediation, or whether a test truly passed.
Audit Markdown is reporting evidence only. It never authorizes a factory push;
the local push gate reads the machine-readable current-diff receipt under
`.cursor/hooks/state/security-reviews/`. That receipt is still a local
workflow-integrity control, not tamper-proof attestation. Human PR approval and
protected-branch checks remain the authoritative delivery boundary. Stop hooks
never auto-push, and a passing local receipt still returns a human approval
prompt before remote publication.

## Safety

- Use synthetic local test data.
- Never place secret values or weaponized payloads in audit documents.
- Never scan external targets without explicit authorization.
- Do not install/run paid or source-transmitting tools without approval.
- Fixes, deployments, risk acceptance, and production changes remain human
  decisions.
