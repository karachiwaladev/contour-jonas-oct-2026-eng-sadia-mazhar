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
6. After implementation is complete, run the **Post-development browser
   testing** workflow below. Update statuses and evidence; documentation alone
   is not evidence.
7. Revisit the document whenever requirements or implementation behavior
   changes.

## During-development workflow

Keep the affected source and its scenario document side by side throughout
implementation:

1. Reuse the existing feature document. For a new feature, copy
   `docs/test-scenarios/_template.md` to a descriptive filename.
2. Before or during coding, map acceptance criteria to scenarios and keep
   unexecuted scenarios `Planned`.
3. After behavior, validation, data flow, or integration changes, update the
   corresponding scenarios and expected results in the same change.
4. Treat the edit-hook reminder as a prompt to review coverage, not a command
   to create another document. Generated files, dependencies, build outputs,
   screenshots, and irrelevant edits do not require scenario changes.
5. Run the local structural validator:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/tools/validate-test-scenarios.ps1
   ```

6. Resolve missing fields, duplicate IDs, broken evidence links, and uncovered
   requirement IDs before delivery. The validator checks documentation
   structure only; it never decides whether a test passed.
7. After implementation, use the browser-testing workflow below to update
   actual results separately from the planned cases.

## Post-development browser testing

Use Chrome DevTools after coding and local static checks pass:

1. Read the `chrome-devtools` skill. Start the app locally using its established
   command and confirm the target URL returns HTTP 200.
2. Use Chrome DevTools `list_pages`, then `select_page`, `navigate_page`, or
   `new_page` as needed. Take a fresh `take_snapshot` before interacting.
3. Execute the changed feature's acceptance scenarios first, then its highest
   regression risks. Use synthetic data and follow the documented steps and
   expected result exactly.
4. Inspect console messages and relevant network requests. A visually correct
   screen with an unexpected console error or failed request is not a pass.
5. Use a fresh snapshot after state changes. Capture screenshots for important
   states and save them under `docs/screenshots/issue-<n>/`.
6. Record the actual result in the scenario document:
   - `Passed`: observed result matches expected result; link evidence.
   - `Failed`: record the mismatch and evidence. Do not change application
     behavior unless the approved requirements require a fix.
   - `Blocked`: record the environmental or data blocker.
   - `Automated`: retain only when an automated test exists; browser execution
     may additionally establish `Passed`.
   - `Planned`: leave scenarios not executed in this run unchanged.
7. Remove synthetic records created during testing when safe. Confirm existing
   data and unchanged behavior still work.
8. Do not claim verification or deliver the feature while required acceptance
   scenarios are Failed or Blocked. Report the blocker or return to
   implementation, then rerun affected scenarios.

If Chrome DevTools cannot connect, follow its troubleshooting guidance and
report the blocker. Do not substitute screenshots or code inspection for an
executed browser scenario.

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
