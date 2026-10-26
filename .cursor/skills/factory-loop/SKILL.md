---
name: factory-loop
description: >-
  Run recurring local agent loops with ticket execute-and-deliver (files/projects),
  safe non-destructive actions, GitHub comments, JSONL logging, and auto commit/push
  on agent stop. Use for factory-loop, /loop ticket factories, or workshop issue automation.
disable-model-invocation: true
---

# Factory Loop

Factory conventions for **local** recurring agent work. For mechanism selection (cloud timer vs local shell), read and follow the Cursor built-in **loop** skill or `/loop` command first; then apply this skill.

## Purpose slug

Derive a stable `<purpose>` from the user prompt:

- Lowercase, words joined with `_`, strip non-alphanumeric (except `_`)
- Example: `say hello world with time` → `hello_world`

| Kind | Sentinel | Regex for `notify_on_output` |
|------|----------|------------------------------|
| Fixed interval | `AGENT_LOOP_TICK_<purpose>` | `^AGENT_LOOP_TICK_<purpose>` |
| Dynamic wake | `AGENT_LOOP_WAKE_<purpose>` | `^AGENT_LOOP_WAKE_<purpose>` |

Payload on the same line as JSON: `{"prompt":"<literal prompt for each tick>"}`.

## Arm a fixed loop (local)

1. Grep terminals for an existing loop with the same sentinel; do not start duplicates.
2. Parse interval: `30s`, `1m`, `5m`, `2h` → seconds (`1 min` → `60`).
3. **Run the prompt once immediately** (before or right after arming; first sentinel must come only after the first sleep).
4. Start background shell with `block_until_ms: 0` and `notify_on_output` on the tick regex.
5. **Track the shell PID** for stop.
6. Confirm: interval, prompt already ran once, approximate first tick time, PID, and that the user can say **stop the loop**.
7. Create **`.cursor/factory-loop-active`** (enables stop-hook commit/push). Remove that file when the user stops the loop.

### PowerShell (Windows)

```powershell
while ($true) {
  Start-Sleep -Seconds <seconds>
  powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/hooks/log-loop-tick.ps1 -Prompt "<prompt>"
  Write-Output 'AGENT_LOOP_TICK_<purpose> {"prompt":"<prompt>"}'
}
```

Shell command title: `Loop every <interval>: <short prompt>`.

### Bash (macOS/Linux)

```bash
while true; do
  sleep <seconds>
  echo 'AGENT_LOOP_TICK_<purpose> {"prompt":"<prompt>"}'
done
```

## On each tick

1. Execute the tick `prompt` once.
2. Keep the user message **brief** (one or two lines unless the prompt requires more).
3. If the system says to "briefly inform the user about the task result", that means run the tick prompt — not meta-commentary about the loop machinery.

### Ticket factory on ticks (required when prompt says so)

If the loop prompt includes **ticket factory**, **post answers**, **factory-loop**, or GitHub work:

1. `gh auth status` — use **SadiaMazhar-000** (or workshop assignee) if EMU blocks writes.
2. List open issues on the workspace repo (`git remote -v`).
3. Pick **one** open issue per tick (lowest number not fully **Delivered**), unless the user asked to batch.
4. Run the **build pipeline** (below) for feature/project tickets; use **Execute** for simple Q&A or tiny docs-only tickets.
5. End the agent turn so the **`stop`** hook can commit/push (screenshots must be committed before the final ticket comment links them).

Do **not** stop at open-issue counts only; monitoring without execute + comment is not ticket factory.

### Timestamp heartbeat pattern

When the prompt includes time (session pattern):

```powershell
Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
```

User-facing line example:

`Hello world` — `2026-10-26 02:13:09 -04:00`

## Stop

1. Kill the tracked loop PID: `Stop-Process -Id <pid> -Force` or `taskkill /PID <pid> /F`.
2. Verify the process is gone; terminal may show `status: failed` and exit `4294967295` — **expected** after force kill.
3. Delete **`.cursor/factory-loop-active`**.
4. If the repo has uncommitted deliverables, run **Finalize git** (below) once before acknowledging loop stop.
5. Do not arm another wake or restart unless the user asks.
6. If a shell **completion** notification arrives after a user-requested stop, one short acknowledgment is enough; do not treat it as a new tick.

## Build pipeline (features & projects)

For any ticket that adds or changes a **product feature**, **app**, or **multi-file project** — follow this order. Do **not** skip to code on ambiguous tickets.

### 1. Clarify

- Read the issue and existing comments.
- Post **`**Clarifying questions:**`** on the issue **or** use **AskQuestion** in chat when the user is present.
- List assumptions (stack, scope, UX, data model, folder). Do not guess silently.

### 2. Plan

- Post **`**Plan:**`** on the issue: scope, files/folders, steps, test/verify approach, out-of-scope.
- In chat, present the same plan and ask for approval.

### 3. Approval gate (hard stop)

**The agent must NEVER approve its own plan** — not by comment, not "with defaults", not because the user asked for a redo/reopen. Reopen/redo only restarts the pipeline at **Clarify**.

Valid approval is exactly one of:

1. The user answers an **AskQuestion** approval prompt in chat ("Approve plan" option), **or**
2. A GitHub comment containing **`Plan approved:`** that was written **after** the latest **Plan** comment and does **not** contain the agent marker `<!-- factory-loop -->`.

Every comment the agent posts must end with the hidden marker `<!-- factory-loop -->` so agent comments can never count as approval.

Procedure:

- After posting **Plan**, immediately call **AskQuestion** (Approve plan / Request changes) with a one-paragraph plan summary. Wait for the answer.
- On loop ticks: if the latest **Plan** has no valid approval, do nothing except re-surface the pending approval in chat (once) — **no code, no files**.
- **Redo / reopen:** post a short "Reopened for redo" comment, then run Clarify → Plan → approval again from scratch.

### 4. Build

- Implement under the path the ticket names (e.g. `todo/`). Match repo conventions. Non-destructive changes only.

### 5. Verify (browser)

- Read the **chrome-devtools** skill (`$3` / DevTools MCP). Prefer **Chrome DevTools MCP** (`navigate_page`, `take_snapshot`, `take_screenshot`) or **cursor-ide-browser** if that is what is connected.
- **Run the app first:** start a static server in the project folder (`python -m http.server <port>` in a background shell), confirm HTTP 200, then open it **side by side** (`browser_navigate` with `position: "side"`, reuse the existing `viewId` from `browser_tabs` if a tab exists). Do not claim "verified" without a running app.
- Exercise every flow named in the ticket; save screenshots to the temp path the tool returns, then copy into the repo.
- Save screenshots under `docs/screenshots/issue-<n>/` (descriptive names, e.g. `01-create-task.png`).

### 6. Deliver (ticket + images)

1. **Commit + push** deliverables and screenshots (Finalize git).
2. Post comment:

```text
**Answer:** <summary of what was built>

**Delivered:** <paths, how to run>

**Verified:** <what you tested in the browser>

**Screenshots:**
![create task](https://github.com/<owner>/<repo>/blob/main/docs/screenshots/issue-<n>/01-create-task.png)
```

Use real `owner/repo` from `git remote`. After push, `blob/main` URLs render on the issue.

(Omit in-progress emoji when fully delivered.)

## Execute (non-feature tickets)

| Ticket type | Action |
|-------------|--------|
| **Question / workshop Q** | **Answer** comment; optional `docs/` if requested. No browser verify unless UI is involved. |
| **Small doc / index** (e.g. `CLAUDE.md` only) | Implement file; comment **Delivered**; browser verify N/A. |
| **Build / feature** | Full **build pipeline** above — never comment-only. |

Rules:

- **Allowed:** new files/folders, edits, docs, skills, non-destructive shell (build, test, `gh issue comment`).
- **Forbidden (never):** `git push --force`, `git reset --hard`, mass delete, `rm -rf` / `Remove-Item -Recurse` on broad paths, dropping data, closing issues without user ask, committing `.env`/secrets, disabling hooks/security.

## Finalize git (every agent stop)

When **`.cursor/factory-loop-active`** exists and the ticket tick changed the repo:

1. `git status` — stage deliverables only; exclude `.cursor/prompt-log/`, `.cursor/hooks/state/`, `.tmp/`.
2. `git commit -m "factory-loop: <issue # or short title>"`
3. `git push` (never `--force`).

The **stop** hook runs `.cursor/hooks/factory-loop-commit-push-on-stop.ps1` as a backup with the same rules. Reload Cursor after hook changes.

## GitHub ticket factory

Use on a tick or as a one-shot when the prompt says to handle tickets/issues.

### Auth (before ticket work)

1. `gh auth status` — if not logged in, run `gh auth login` (user must approve).
2. Optional Cursor GitHub MCP: `GetDynamicTools` on `plugin-github-github`; if only `mcp_auth` is listed or tools are in error, call `mcp_auth` once. On timeout, tell the user to reconnect GitHub under **Settings → MCP**; **gh** remains the fallback for issues.

### Discover

- Workspace: `git remote -v` for default repo.
- Account: `gh auth status`, `gh api user --jq .login`.
- Issues: `gh issue list -R owner/repo --state open --json number,title,body,url`.
- Full context: `gh issue view <n> -R owner/repo --json title,body,comments`.

### Respond

Use the stage-appropriate template (**Clarifying questions**, **Plan**, or final **Answer** / **Delivered** / **Verified** / **Screenshots** from the build pipeline). Post via `gh issue comment`; verify on GitHub.

### Multiple GitHub accounts (EMU vs workshop)

Before posting, run `gh auth status` and note the **active** account (`gh api user --jq .login`).

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| 403 `Enterprise Managed User` on comment | Active account is EMU; external org repo (e.g. `karachiwaladev`) | `gh auth switch -u <workshop-user>` then retry |
| Reads work, writes fail | Same as above | Use the assignee/collaborator login for that repo, not EMU |
| Comment URL returned but user sees nothing | Wrong account or verify skipped | `gh api repos/.../issues/<n>/comments --jq length` |

Workshop pattern (validated): **SadiaMazhar-000** can comment on `karachiwaladev/contour-jonas-oct-2026-eng-sadia-mazhar`; **Sadia-Mazhar_Jonas** (EMU) cannot write there.

If write still returns EMU 403 after switching:

- Do not bypass with alternate upload hosts or repeated identical posts.
- Provide exact markdown to paste on the issue in the browser.
- Enterprise policy requires admin change; repo settings alone do not fix EMU blocks.

## Checklist (agent)

```
- [ ] Read loop skill; pick cloud timer OR local monitored shell
- [ ] Unique <purpose> and sentinel
- [ ] No duplicate loop in terminals
- [ ] Prompt executed once before first tick
- [ ] PID tracked
- [ ] Tick output brief
- [ ] Stop kills PID; no re-arm unless asked
- [ ] GitHub: active account can write; switch with `gh auth switch` if EMU 403
- [ ] Build tickets: Clarify → Plan → AskQuestion approval before code (never self-approve)
- [ ] Every agent comment ends with `<!-- factory-loop -->`
- [ ] App running side by side before claiming Verified
- [ ] Browser verify via DevTools MCP; screenshots in `docs/screenshots/issue-<n>/`
- [ ] Push before issue comment with screenshot links
- [ ] No destructive git/shell/file actions
- [ ] factory-loop-active flag while loop armed
- [ ] Commit + push on stop (hook or manual)
```

## Examples

Session-derived flows: [examples.md](examples.md).
