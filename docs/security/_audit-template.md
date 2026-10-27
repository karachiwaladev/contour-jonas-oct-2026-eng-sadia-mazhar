# Security audit: <scope>

- Audit ID: AUD-YYYY-MM-DD-<slug>
- Date:
- Owner:
- Authorized repository/ref:
- Included paths/assets:
- Exclusions:
- Change/release:
- Diff hash:
- Security-review result: Not run
- Blocking findings:
- Time limit:
- Cost cap:
- External targets authorized: None

## Security boundaries affected

- Entry points:
- Trust boundaries:
- Authentication/authorization:
- Sensitive data:
- Privileged operations:
- Infrastructure/provider resources:

## Checks and evidence

Use only `Run`, `Not run`, `Failed`, or `Blocked`. A planned check is not a
successful check.

| Check | Tool/method | Status | Evidence/reference | Limitation |
| --- | --- | --- | --- | --- |
| Changed-code security review | Cursor security-review / manual diff | Not run | | |
| Repository vulnerability discovery | DeepSec / static inspection | Not run | | |
| Secret exposure | Local deterministic hook/manual review | Not run | | |
| Dependencies/configuration | Existing local tools/manual review | Not run | | |
| Regression tests | Existing local test framework | Not run | | |
| Provider configuration | Applicable provider skill/manual review | Not run | | |

## Findings

| Finding ID | Severity | Confidence | Status | Detailed record |
| --- | --- | --- | --- | --- |

## Completion review

- [ ] Findings distinguish confirmed vulnerabilities from hypotheses.
- [ ] Every finding records root cause, evidence, preconditions, impact, fix,
      regression test, and verification state.
- [ ] Critical/High findings are resolved, explicitly risk-accepted by a human,
      or recorded as blocking.
- [ ] Fixes were revalidated without assuming prior evidence still applies.
- [ ] Failed, blocked, and unexecuted checks are reported.
- [ ] Cost incurred and source-transmission boundaries are reported.
- [ ] No secrets, sensitive logs, or unauthorized target data are included.

## Outcome and limitations

- Actual cost:
- Checks run:
- Checks not run/failed:
- Unresolved risk:
- Follow-up owner/date:
- Manual approval:
