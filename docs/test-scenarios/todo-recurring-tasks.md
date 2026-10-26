# Todo daily recurring tasks

## Feature and scope

Ticket [#16](https://github.com/karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar/issues/16)
adds daily recurrence to the client-side `todo/` app. Recurrence is stored in
IndexedDB; no API or server is involved.

## Requirements and acceptance criteria

- **R1:** A task can repeat daily.
- **R2:** Completing it creates one next occurrence with due date +1 day.
- **R3:** An optional repeat-until date prevents occurrences after that date.
- **R4:** A repeating task requires a due date.
- **R5:** Existing tasks, filters, tags, due dates, and overdue behavior continue
  to work client-side.

## Preconditions and test data

- Serve `todo/` locally and use a browser with IndexedDB enabled.
- Synthetic tasks: `Water plants` and `<img src=x onerror=alert(1)>`.
- Clear the `todo-app` database when a scenario requires an empty store.
- Browser verification evidence is from 26 Oct 2026 unless noted otherwise.

## Scenarios

| ID | Scenario | Preconditions | Steps / input | Expected result | Type | Status | Evidence |
|----|----------|---------------|---------------|-----------------|------|--------|----------|
| TODO-REC-001 | Create daily task with end date (R1, R3) | Empty form | Add `Water plants`, due 2026-10-26, daily, until 2026-10-27 | Active task shows due date and daily recurrence through 2026-10-27 | Happy path | Passed | [Recurring task](../screenshots/issue-16/02-recurring-task.png) |
| TODO-REC-002 | Complete recurring task (R2) | TODO-REC-001 exists | Select Done | Original remains completed; one active occurrence is created for 2026-10-27 | Happy path | Passed | [Next occurrence](../screenshots/issue-16/03-next-occurrence.png) |
| TODO-REC-003 | Require due date (R4) | Empty form | Enter task, select daily, leave due empty, Add | No task is added; validation explains that a due date is required | Validation | Passed | [Validation](../screenshots/issue-16/01-validation.png) |
| TODO-REC-004 | Reject end date before due date (R3) | Empty form | Due 2026-10-27, until 2026-10-26, Add | No task is added; validation explains the date order | Validation | Planned | — |
| TODO-REC-005 | Stop at end date (R3) | Daily task due 2026-10-27, until 2026-10-27 | Select Done | Task completes and no later occurrence is created | Boundary | Passed | [End-date stop](../screenshots/issue-16/04-end-date-stops.png) |
| TODO-REC-006 | End date equals first due date (R3) | Empty form | Add daily task with equal due and until dates; complete it | Initial task is valid; no next occurrence is created | Boundary | Planned | — |
| TODO-REC-007 | Month and year rollover (R2) | Empty store | Complete daily tasks due 2026-10-31 and 2026-12-31 | Next dates are 2026-11-01 and 2027-01-01 | Boundary | Passed | Browser verification, 26 Oct 2026: both expected dates matched; test records removed |
| TODO-REC-008 | Undo and redo do not duplicate (R2) | First occurrence has created its successor | Undo, then Done again | Existing successor remains the only next occurrence | Regression | Passed | Browser verification, 26 Oct 2026 |
| TODO-REC-009 | Copy tags to successor (R2, R5) | Daily task tagged `home` | Select Done | Next occurrence has tag `home`; tag filter includes it | Regression | Planned | — |
| TODO-REC-010 | Preserve status, tag, and overdue filters (R5) | Mixed recurring and ordinary tasks | Exercise each existing filter | Results follow existing filter semantics | Regression | Planned | — |
| TODO-REC-011 | Migrate existing v2 data (R5) | IndexedDB v2 task without recurrence fields | Load updated app | App upgrades to v3; old task remains non-recurring and usable | Database | Planned | — |
| TODO-REC-012 | Release stale database connection (R5) | Old and new app tabs are open | Trigger v3 upgrade | Old connection closes/reloads; upgraded tab can write | Database | Planned | — |
| TODO-REC-013 | Render script-like task text safely (R5) | Empty form | Add `<img src=x onerror=alert(1)>` | Text displays literally; no script or event handler runs | Security | Planned | — |
| TODO-REC-014 | Delete completed occurrence (R5) | Completed occurrence and active successor exist | Delete completed occurrence | Completed item is removed; active successor remains | Regression | Planned | — |

Authorization is **N/A**: this is a single-user, client-only app with no identity
or authorization boundary. API and external integration scenarios are **N/A**:
the app makes no API calls and sends no data externally. IndexedDB coverage is
included above.

## Assumptions / open questions

- Completing an overdue task schedules from its stored due date, not from today.
- Date-only local arithmetic is expected to remain stable across time zones and
  daylight-saving changes.
- Undoing completion does not remove a successor that was already created.
