---
name: god-object-management
description: Analyzes possible God Objects, maps responsibilities and dependencies, proposes bounded tickets, and executes only approved architecture changes. Use when files are growing, responsibilities are mixed, implementation placement is unclear, or the user requests God Object analysis or distribution.
---

# God object management

Treat size as a discovery signal, never as proof. Use the repository's existing
architecture and distinguish structural opportunities from confirmed defects.
Do not move code merely to reduce line count or create one class per method.

## Modes

- **Analyze:** inspect and report; do not edit application code.
- **Plan:** prioritize findings and draft bounded tickets; do not execute them.
- **Execute:** implement one explicitly approved ticket only.
- **Verify:** check a completed ticket without expanding its scope.

If the requested mode is unclear and would permit code changes, ask before
editing.

## 1. Discover repository facts

Read the repository index, source layout, rules, skills, build/test
configuration, and relevant history. Prefer established abstractions and the
closest similar implementation.

Find candidates using several signals:

- file growth and size relative to neighboring files;
- distinct business, persistence, UI, integration, validation, or orchestration
  responsibilities;
- inbound and outbound coupling;
- mutable shared state and side effects;
- change concentration or churn from Git history, when available;
- test difficulty, regression history, or repeated merge conflicts.

Exclude generated, vendored, minified, dependency, build, coverage, state, and
log files. Report when history, callers, or tests are unavailable.

## 2. Inspect each candidate

Before recommending change, inspect:

1. Public interfaces and behavior that consumers rely on.
2. Callers, imports, dependencies, shared state, I/O, and side effects.
3. Existing tests, scenario documents, fixtures, and validation commands.
4. Existing modules that already own related responsibilities.
5. Architectural constraints that make the current placement intentional.

Do not infer runtime behavior or test success from code inspection alone.

## 3. Produce a responsibility map

For each responsibility, record:

- evidence: symbols, paths, callers, state, and side effects;
- current owner and proposed owner;
- cohesion with neighboring responsibilities;
- public behavior that must remain stable;
- confidence and unresolved facts.

Classify findings as:

- **Confirmed defect:** observable incorrect behavior with evidence.
- **Structural opportunity:** maintainability or distribution improvement
  without a demonstrated user-facing defect.
- **Intentional concentration:** justified orchestration or repository
  constraint; no split recommended.

## 4. Prioritize and recommend ownership

Rank work by user impact, urgency, confidence, effort, regression risk, and
dependency order. Recommend an existing abstraction first. Propose a new
abstraction only when its responsibility and boundary are clear.

Prefer seams that preserve public behavior, such as isolating persistence,
domain policy, presentation, or external integration. Avoid broad rewrites.

## 5. Draft bounded tickets

Use this format:

```markdown
## [Ticket title]
- Finding: [confirmed defect or structural opportunity]
- Scope: [specific files/responsibility]
- Out of scope: [explicit exclusions]
- Acceptance criteria:
  - [observable behavior or boundary]
- Dependencies: [ticket IDs or none]
- Regression scenarios: [existing and new checks]
- Public compatibility: [interfaces that must remain stable]
- Rollback: [small-change reversal approach]
- Uncertainty: [unknown facts]
```

Keep each ticket independently reviewable. Order prerequisite seams before
dependent moves.

## 6. Approval and active scope

Execute only an explicitly requested or approved ticket. Before editing:

1. Identify the destination of every new responsibility.
2. List approved paths and any justified adjacent paths.
3. Write `.cursor/hooks/state/god-object-active-scope.json`:

```json
{
  "version": 1,
  "mode": "implementation",
  "ticket": "ticket identifier or short title",
  "approved_paths": ["path/or/directory/"],
  "candidate_paths": ["path/to/candidate.ext"],
  "exceptions": [
    { "path": "adjacent/path.ext", "reason": "why it is required" }
  ],
  "architecture_decisions": ["responsibility -> owner"],
  "intentionally_incomplete": false
}
```

Use repository-relative forward-slash paths. For investigation, set
`mode` to `investigation`; completion enforcement will be skipped. Set
`intentionally_incomplete` only when the user requested a partial handoff.
Remove or replace stale scope before another ticket.

## 7. Execute one bounded change

- Re-read the destination abstraction and its tests.
- Preserve existing interfaces unless the ticket explicitly changes them.
- Move one coherent responsibility at a time.
- Add or update tests for changed behavior using the existing framework.
- Avoid unrelated cleanup, renaming, formatting, or dependency changes.
- Stop and ask if evidence contradicts the approved ownership or scope.

## 8. Verify and report

Run the smallest relevant checks, then broader established checks when safe.
Inspect the final diff for approved scope, API compatibility, and architecture
boundaries. Never claim a test passed without command or browser evidence.

For this repository's guardrail evaluation, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/tools/eval-god-object-management.ps1
```

Measured PowerShell coverage uses Pester and targets the shared deterministic
hook helpers. Run it directly with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/tools/measure-god-object-coverage.ps1
```

Completion reports must include:

- **Changed files:** exact paths and purpose.
- **Tests:** commands/scenarios and actual result, including failures.
- **Architecture:** responsibility ownership and compatibility decisions.
- **Unresolved:** assumptions, risks, manual checks, or `None`.

## Usage examples

- `/god-object-management analyze todo/app.js`
- `/god-object-management map responsibilities and draft tickets; do not edit`
- `/god-object-management execute only the approved persistence-extraction ticket`
- `/god-object-management verify the current ticket and report scope drift`
