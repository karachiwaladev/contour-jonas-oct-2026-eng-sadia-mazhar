# Security findings ledger

This ledger tracks unresolved and revalidated findings across scoped audits.
Absence of entries does not mean the repository has no vulnerabilities.

| ID | Title | Severity | Confidence | Status | Affected scope | Last validated | Record |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Rules

- Use stable IDs such as `SEC-001`; never reuse an ID.
- Keep detailed evidence in a finding record based on
  `_finding-template.md`.
- Distinguish confirmed vulnerabilities from hypotheses.
- Do not mark a finding resolved until its fix and regression test are
  revalidated.
- A human must document any risk acceptance, owner, and review date.
- Never include secret values, personal data, or full sensitive logs.
