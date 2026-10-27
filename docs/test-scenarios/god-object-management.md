# God object management guardrails

## Feature and scope

Repository-aware analysis guidance and advisory Cursor hooks for file growth,
approved scope, and completion reporting. This setup does not refactor the todo
application or prove a future refactor's runtime compatibility.

## Requirements and acceptance criteria

- **R1:** Small changes do not produce unnecessary growth warnings.
- **R2:** Substantial growth in a known candidate produces an actionable warning.
- **R3:** Justified large or adjacent changes remain possible.
- **R4:** An executed refactor preserves public behavior and passes applicable tests.
- **R5:** Missing or failing tests are reported honestly.
- **R6:** Existing hooks and skills remain valid.
- **R7:** Malformed input and unsupported baselines fail safely.
- **R8:** Warnings and stop follow-ups are bounded and routine hooks stay within timeout.

## Preconditions and test data

- PowerShell and Git are available on `PATH`.
- Pester 6.2.0 is installed for measured PowerShell code coverage.
- `.cursor/tools/test-god-object-hooks.ps1` creates and removes a disposable
  local Git fixture containing synthetic JavaScript files.
- No secrets, personal data, application records, or network services are used.

## Scenarios

| ID | Scenario | Preconditions | Steps / input | Expected result | Type | Status | Evidence |
|----|----------|---------------|---------------|-----------------|------|--------|----------|
| GOD-001 | Small fix in structured file | R1 fixture baseline | Add one line below configured thresholds | No growth context is emitted | Regression | Passed | `test-god-object-hooks.ps1`: assertion passed, 2026-10-26 |
| GOD-002 | Large feature in known candidate | R2 fixture baseline | Add six lines with fixture threshold five | One warning reports delta and active-candidate status | Happy path | Passed | `test-god-object-hooks.ps1`: assertions passed, 2026-10-26 |
| GOD-003 | Justified adjacent change | R3 active scope with exception | Write the configured exception path | Change remains allowed without scope warning | Boundary | Passed | `test-god-object-hooks.ps1`: assertion passed, 2026-10-26 |
| GOD-004 | R4: Refactor preserves public behavior | Approved future refactor | Execute its existing tests and compatibility checks | Public behavior is unchanged and applicable tests pass | Regression | Planned | No application refactor is part of this setup |
| GOD-005 | Failing test reported honestly | R5 completion fixture | Report a failed synthetic test in all required sections | Completion check accepts the honest result without claiming a pass | Validation | Passed | `test-god-object-hooks.ps1`: assertion passed, 2026-10-26 |
| GOD-006 | R6: Existing factory hooks coexist | Current hook configuration | Parse scripts/config, run neutral existing hook inputs, and validate scenarios | Existing entries remain ordered and checks succeed | Integration | Passed | All PowerShell and JSON parsed; existing scenario hooks returned neutral JSON, 2026-10-26 |
| GOD-007 | Malformed input and missing Git baseline | R7 fixtures | Send empty/malformed JSON and edit an untracked file | Hooks fail open; edit-delta fallback warns safely | Error handling | Passed | `test-god-object-hooks.ps1`: assertions passed, 2026-10-26 |
| GOD-008 | No repetitive loop or timeout | R8 fixtures | Repeat warned write and stop follow-up; time invocations | Warnings are one-shot, follow-up is bounded, each invocation is under five seconds | Performance | Passed | 17 integration assertions passed (latest maximum 1203 ms); 18/18 Pester tests passed with 100% measured line and command coverage, 2026-10-26 |

## Assumptions / open questions

- Actual hook discovery and perceived latency in Cursor require manual
  confirmation in Customize → Hooks and the Hooks output channel.
- PowerShell is available in this Windows workspace; other agent environments
  may need a cross-platform implementation.
- `afterFileEdit` covers Agent writes, not arbitrary shell-created edits.
