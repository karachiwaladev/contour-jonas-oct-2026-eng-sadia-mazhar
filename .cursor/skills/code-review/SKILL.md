---
name: code-review
description: Runs a read-only Bugbot review of feature branch changes and applies the factory severity gate. Use after implementation and browser testing, before opening or updating a pull request.
---

# Bugbot code review

Run this review after implementation and Chrome DevTools verification, before
PR delivery. Bugbot reviews only; it does not replace tests or manual approval.

## Review priorities

Review in this order:

1. Correctness and reproducible bugs
2. Security vulnerabilities and unsafe data handling
3. Breaking changes and regressions
4. Performance and unnecessary API or database calls
5. Error handling and edge cases
6. Maintainability and consistency with the existing architecture
7. Missing or inadequate tests

Report concrete, actionable findings. Prefer evidence and a reproducible failure
path over speculative concerns.

## Review

1. Confirm the feature branch is checked out and local changes are committed.
2. Identify the intended PR base. For stacked work, use the parent feature
   branch, not the repository default branch.
3. Read the `review-bugbot` skill and launch exactly one Bugbot subagent:
   - Description: exactly `Bugbot`
   - Run in background: `false`
   - Diff: `branch changes`
   - Full Repository Path: the absolute repository path
   - Base Branch: include when the intended base is not the default branch
4. Do not send code or test data to an external service. Bugbot operates on the
   local repository diff.
5. Record every finding with severity, file and line, and concise description.
   If none are found, record `Bugbot found no bugs`.

Prompt shape:

```text
Full Repository Path: <absolute repository path>
Diff: branch changes
Base Branch: <include only for a known non-default PR base>
Custom Instructions: Prioritize correctness and reproducible bugs; security vulnerabilities and unsafe data handling; breaking changes and regressions; performance and unnecessary API/database calls; error handling and edge cases; maintainability and consistency with existing architecture; and missing or inadequate tests.
```

## Severity gate

- **Critical / High:** block PR delivery. Present findings to the user and ask
  whether to fix them. Do not fix findings without that explicit instruction.
- **Medium / Low:** do not block delivery. Include unresolved findings in the
  PR under **Bugbot review**.
- **Unknown severity:** treat as High until classified.
- **Review failure:** mark the review Blocked and stop delivery; report the
  failure instead of claiming review success.

After approved fixes:

1. Rerun relevant static and Chrome DevTools scenarios.
2. Rerun Bugbot once against the updated branch.
3. Deliver only when no Critical or High findings remain.

## Delivery evidence

Add this section to the PR:

```markdown
## Bugbot review

- Result: No bugs | Non-blocking findings | Blocked
- Blocking findings: 0
- Non-blocking findings: <count and links/locations>
```

Bugbot approval is not human approval. The PR still waits for manual review,
and the agent must not merge or close the ticket.
