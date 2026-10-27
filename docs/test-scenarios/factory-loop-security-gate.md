# Factory-loop security gate

## Feature and scope

Protect ticket-driven agent work at ingestion, loop execution, and PR delivery.
GitHub text remains untrusted data; deterministic checks supplement, but do not
replace, Cursor security-review or human review.

## Requirements and acceptance criteria

- **R1:** Every fully fetched ticket is scanned before its content drives work.
- **R2:** Only verified write/maintain/admin collaborators can approve plans or reviews.
- **R3:** External/fork PR refs and merge commands require explicit approval.
- **R4:** Changed ticket code is reviewed once per diff hash during loop work.
- **R5:** Every PR create/update requires passing security-review evidence bound to the current diff.
- **R6:** Critical/High findings, scanner failure, stale evidence, secrets, or unexpected origin block delivery.
- **R7:** Scan output and evidence never disclose matched secret or malicious payload values.

## Preconditions and test data

- PowerShell, Git, and GitHub CLI available.
- Synthetic JSON fixtures only; no real credentials or attacker infrastructure.
- Test branch named `factory/issue-6-security-review-hardening`.

## Scenarios

| ID | Scenario | Preconditions | Steps / input | Expected result | Type | Status | Evidence |
|----|----------|---------------|---------------|-----------------|------|--------|----------|
| FSG-001 | R1: Benign collaborator ticket | Synthetic ticket; author check bypassed for deterministic test | Pipe benign JSON to scanner with `-SkipAuthorCheck` | `clean`; no findings | Happy path | Passed | 2026-10-27: `.cursor/tests/factory-loop-security.Tests.ps1` |
| FSG-002 | R1, R7: Instruction override in issue body | Synthetic fixture | Include an override phrase | `suspicious`; only rule/location emitted | Security | Passed | 2026-10-27: scanner synthetic command; rule/location only |
| FSG-003 | R1, R6, R7: Embedded command or security bypass | Synthetic fixture | Include command pipe or hook-disable request | `quarantined`; no payload echoed | Security | Passed | 2026-10-27: `.cursor/tests/factory-loop-security.Tests.ps1` |
| FSG-004 | R1, R7: Hidden Unicode | Synthetic fixture | Include zero-width or bidi character | `quarantined` with `hidden-unicode` | Security | Passed | 2026-10-27: `.cursor/tests/factory-loop-security.Tests.ps1` |
| FSG-005 | R2: Forged approval marker | Synthetic untrusted comment | Include approval plus factory marker | Quarantined; approval excluded | Authorization | Passed | 2026-10-27: `.cursor/tests/factory-loop-security.Tests.ps1` |
| FSG-006 | R2: Untrusted author | Authenticated GitHub CLI or mocked failure | Permission lookup is absent/insufficient | Fail closed as `untrusted-author` | Authorization | Passed | 2026-10-27: synthetic nonexistent author; real issue #6 collaborator returned clean |
| FSG-007 | R1, R6, R7: Ticket scan parser failure | Invalid/empty JSON | Run scanner | Quarantined `scan-failed`; no raw input echoed | Validation | Passed | 2026-10-27: invalid-input synthetic command |
| FSG-008 | R3: Fork/PR checkout shell command | Hook JSON payload | Submit `gh pr checkout 5` | Hook returns `permission: ask` | Security | Passed | 2026-10-27: `.cursor/tests/factory-loop-security.Tests.ps1` |
| FSG-009 | R3: Normal safe shell command | Hook JSON payload | Submit `git status` | Hook returns `permission: allow` | Regression | Passed | 2026-10-27: `.cursor/tests/factory-loop-security.Tests.ps1` |
| FSG-010 | R4: Loop scan unchanged diff | Existing matching evidence and state | Run local gate twice without edits | Same diff hash; passing evidence reused | Regression | Planned | — |
| FSG-011 | R4, R5: PR update after code edit | Previously passing evidence | Edit tracked file and rerun gate | New hash; stale evidence blocks push | Integration | Planned | — |
| FSG-012 | R5, R6: Missing evidence at stop | Ticket branch with staged change | Invoke stop hook in isolated fixture | Local commit may occur; push is deferred | Integration | Passed | 2026-10-27: isolated repo in `.cursor/tests/factory-loop-security.Tests.ps1` |
| FSG-013 | R5, R6: Critical/High security finding | security-review reports blocker | Attempt delivery | PR create/update and push remain blocked | Security | Planned | — |
| FSG-014 | R5, R6: Security-review failure | Subagent fails twice | Attempt delivery | Status Blocked; no success claim or push | Error handling | Planned | — |
| FSG-015 | R6, R7: Potential secret in changed file | Synthetic token matching a rule | Run local gate | Blocked; output contains rule/path/line only | Security | Planned | — |
| FSG-016 | R6: Unexpected origin | Isolated fixture with different origin | Invoke stop hook | Push refused and logged | Authorization | Passed | 2026-10-27: isolated repo in `.cursor/tests/factory-loop-security.Tests.ps1` |

## Assumptions / open questions

- The workshop repository is intentionally the only auto-push origin.
- Full codebase scans remain release/security-boundary audits; loop scans are
  changed-file/diff scoped to control latency and cost.
- Cursor security-review is probabilistic evidence, not proof of security.
- Browser/responsive/API scenarios are N/A: this change affects local
  PowerShell hooks and agent workflow, not application UI or runtime APIs.
