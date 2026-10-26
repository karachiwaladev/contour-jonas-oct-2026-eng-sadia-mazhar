---
name: test-scenarios
description: Creates and maintains concise feature-specific test scenario documentation. Use while planning, implementing, verifying, or reviewing product features and regression risks.
---

# Test scenarios

Keep one document per feature at `docs/test-scenarios/<feature>.md`. Reuse an
existing document when it covers the changed behavior.

## Workflow

1. Read the issue or requirement, approved plan, affected code, existing tests,
   and existing scenario document.
2. Map each acceptance criterion to at least one scenario. Identify relevant
   validation, boundary, security, data/integration, and regression scenarios.
3. Record unresolved decisions under **Assumptions / open questions** and ask
   the user. Never invent business rules.
4. Create or update the scenario document in the same change as the feature.
5. Add automated tests only when the repository already has a suitable test
   framework. Do not introduce one solely for this workflow.
6. After local verification, update statuses and evidence. Documentation alone
   is not evidence.
7. Revisit the document whenever requirements or implementation behavior
   changes.

## Required document sections

- Feature name and scope
- Requirements and acceptance criteria, with requirement IDs
- Preconditions and test data
- Scenarios
- Assumptions / open questions

The scenarios must cover, where applicable:

- Happy paths
- Negative and validation behavior
- Boundary conditions and edge cases
- Authorization and security
- API, database, and integrations
- Regression risks to existing behavior
- Traceability to requirements

Use `N/A` with a short reason when a category does not apply; do not silently
omit it.

## Scenario table

Use this concise format:

```markdown
| ID | Scenario | Preconditions | Steps / input | Expected result | Type | Status | Evidence |
|----|----------|---------------|---------------|-----------------|------|--------|----------|
| TODO-REC-001 | Create daily task | Empty form | ... | ... | Happy path | Planned | — |
```

- IDs: `<AREA>-<NNN>`, stable and unique within the document.
- Type: use a precise label such as Happy path, Validation, Boundary, Security,
  Database, Integration, or Regression.
- Status: exactly `Planned`, `Automated`, `Passed`, `Failed`, or `Blocked`.
- `Automated` means an automated test exists; link its file or test name.
- `Passed` requires local execution evidence: a test command/result, screenshot,
  or dated browser-verification note. Never infer it from implementation.
- `Failed` and `Blocked` must state the result or blocker in Evidence.
- Keep steps and test data synthetic; never include secrets or real personal
  data.

## Quality gate

Before delivery, confirm:

- Every requirement ID has scenario coverage.
- Changed behavior and its main regression risks are represented.
- Statuses are honest and evidence links resolve.
- The PR and ticket delivery comment link the scenario document.
